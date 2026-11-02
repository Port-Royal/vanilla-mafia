import { beforeEach, describe, expect, it, vi } from "vitest"
import { applyQueued, PermanentError, SendQueue } from "../../../app/javascript/live_protocol/send_queue.js"

const event = (client_id, action_id = client_id) => ({ client_id, action_id })

function memoryStorage(initial = {}) {
  const data = { ...initial }
  return { getItem: (key) => data[key] ?? null, setItem: (key, value) => { data[key] = value }, data }
}

function deferred() {
  let resolve
  let reject
  const promise = new Promise((res, rej) => { resolve = res; reject = rej })
  return { promise, resolve, reject }
}

describe("SendQueue", () => {
  let posted
  let removed
  let statuses
  let storage
  let delays
  let post
  let remove

  const build = () => new SendQueue({
    post,
    remove,
    storage,
    storageKey: "queue",
    onStatus: (status) => statuses.push(status),
    sleep: (ms) => { delays.push(ms); return Promise.resolve() }
  })

  beforeEach(() => {
    posted = []
    removed = []
    statuses = []
    delays = []
    storage = memoryStorage()
    post = vi.fn(async (events) => { posted.push(events) })
    remove = vi.fn(async (id) => { removed.push(id) })
  })

  it("sends events in order", async () => {
    const queue = build()
    queue.enqueue([event("a")])
    queue.enqueue([event("b")])
    await queue.flush()

    expect(posted).toEqual([[event("a")], [event("b")]])
  })

  it("sends one request at a time", async () => {
    const first = deferred()
    post = vi.fn(() => first.promise)
    const queue = build()
    queue.enqueue([event("a")])
    queue.enqueue([event("b")])
    await Promise.resolve()

    expect(post).toHaveBeenCalledTimes(1)
    first.resolve()
    await queue.flush()
    expect(post).toHaveBeenCalledTimes(2)
  })

  it("keeps order between events and deletions", async () => {
    const order = []
    post = vi.fn(async () => { order.push("post") })
    remove = vi.fn(async () => { order.push("remove") })
    const gate = deferred()
    post.mockImplementationOnce(() => gate.promise.then(() => order.push("post")))
    const queue = build()
    queue.enqueue([event("a", "x")])
    queue.enqueueDelete("x")
    queue.enqueue([event("b")])
    gate.resolve()
    await queue.flush()

    expect(order).toEqual(["post", "remove", "post"])
  })

  it("reports saving, then saved", async () => {
    const queue = build()
    queue.enqueue([event("a")])
    await queue.flush()

    expect([statuses[0], statuses.at(-1)]).toEqual(["saving", "saved"])
  })

  it("does nothing on an empty queue", async () => {
    await build().flush()

    expect(post).not.toHaveBeenCalled()
  })

  it("retries a failed request after 1, 2, 5, 5 seconds", async () => {
    const fails = [new TypeError("x"), new TypeError("x"), new TypeError("x"), new TypeError("x")]
    post = vi.fn(async () => { if (fails.length) throw fails.shift() })
    const queue = build()
    queue.enqueue([event("a")])
    await queue.flush()

    expect([delays, post.mock.calls.length]).toEqual([[1000, 2000, 5000, 5000], 5])
  })

  it("keeps the delay at 5 seconds", async () => {
    let fails = 6
    post = vi.fn(async () => { if (fails > 0) { fails -= 1; throw new TypeError("x") } })
    const queue = build()
    queue.enqueue([event("a")])
    await queue.flush()

    expect(delays).toEqual([1000, 2000, 5000, 5000, 5000, 5000])
  })

  it("starts the delays over after a success", async () => {
    let fails = 1
    post = vi.fn(async () => { if (fails > 0) { fails -= 1; throw new TypeError("x") } })
    const queue = build()
    queue.enqueue([event("a")])
    await queue.flush()
    fails = 1
    queue.enqueue([event("b")])
    await queue.flush()

    expect(delays).toEqual([1000, 1000])
  })

  it("reports offline during a failure and saved after it", async () => {
    let fails = 1
    post = vi.fn(async () => { if (fails > 0) { fails -= 1; throw new TypeError("x") } })
    const queue = build()
    queue.enqueue([event("a")])
    await queue.flush()

    expect(statuses).toEqual(["saving", "offline", "saving", "saved"])
  })

  it("keeps the item through a failure", async () => {
    let fails = 1
    post = vi.fn(async () => { if (fails > 0) { fails -= 1; throw new TypeError("x") } })
    const queue = build()
    queue.enqueue([event("a")])
    await queue.flush()

    expect(post.mock.calls.map(([events]) => events)).toEqual([[event("a")], [event("a")]])
  })

  it("stops on a refusal and keeps the item", async () => {
    post = vi.fn(async () => { throw new PermanentError(422) })
    const queue = build()
    queue.enqueue([event("a")])
    await queue.flush()

    expect([statuses.at(-1), delays, JSON.parse(storage.data.queue).length]).toEqual(["rejected", [], 1])
  })

  it("tries again on the next enqueue after a refusal", async () => {
    post = vi.fn(async () => { throw new PermanentError(422) })
    const queue = build()
    queue.enqueue([event("a")])
    await queue.flush()
    post = vi.fn(async () => {})
    queue.post = post
    queue.enqueue([event("b")])
    await queue.flush()

    expect(statuses.at(-1)).toBe("saved")
  })

  it("empties the storage when everything is sent", async () => {
    const queue = build()
    queue.enqueue([event("a")])
    await queue.flush()

    expect(JSON.parse(storage.data.queue)).toEqual([])
  })

  it("keeps an unsent item in the storage while it is being sent", async () => {
    const gate = deferred()
    post = vi.fn(() => gate.promise)
    const queue = build()
    queue.enqueue([event("a")])

    expect(JSON.parse(storage.data.queue)).toEqual([{ type: "post", events: [event("a")] }])
    gate.resolve()
    await queue.flush()
  })

  it("continues the queue after a restart with the same storage", async () => {
    storage = memoryStorage({ queue: JSON.stringify([{ type: "post", events: [event("a")] }, { type: "delete", actionId: "z" }]) })
    const queue = build()
    await queue.flush()

    expect([posted, removed]).toEqual([[[event("a")]], ["z"]])
  })

  it("starts empty on unreadable storage", async () => {
    storage = memoryStorage({ queue: "{not json" })
    const queue = build()

    expect(queue.items).toEqual([])
  })

  it.each(["0", "{}", "null", '"text"'])("starts empty when the storage holds %s", (stored) => {
    storage = memoryStorage({ queue: stored })

    expect(build().items).toEqual([])
  })

  it("keeps working when the storage refuses to write", async () => {
    storage.setItem = () => { throw new Error("quota") }
    const queue = build()
    queue.enqueue([event("a")])
    await queue.flush()

    expect(posted).toEqual([[event("a")]])
  })

  it("drops an unsent group with no request", async () => {
    const gate = deferred()
    post = vi.fn(() => gate.promise)
    const queue = build()
    queue.enqueue([event("first")])
    queue.enqueue([event("a", "x"), event("b", "x")])
    queue.enqueueDelete("x")
    gate.resolve()
    await queue.flush()

    expect([post.mock.calls.length, remove.mock.calls.length]).toEqual([1, 0])
  })

  it("drops only that group", async () => {
    const gate = deferred()
    post = vi.fn(() => gate.promise)
    const queue = build()
    queue.enqueue([event("first")])
    queue.enqueue([event("a", "x"), event("b", "y")])
    queue.enqueueDelete("x")

    expect(queue.items[1].events).toEqual([event("b", "y")])
    gate.resolve()
    await queue.flush()
  })

  it("sends a deletion for a group already on its way", async () => {
    const gate = deferred()
    post = vi.fn(() => gate.promise)
    const queue = build()
    queue.enqueue([event("a", "x")])
    queue.enqueueDelete("x")
    gate.resolve()
    await queue.flush()

    expect(removed).toEqual(["x"])
  })

  it("sends a deletion for a group already saved", async () => {
    const queue = build()
    queue.enqueueDelete("x")
    await queue.flush()

    expect(removed).toEqual(["x"])
  })

  it("starts sending a deletion by itself", async () => {
    build().enqueueDelete("x")
    await Promise.resolve()

    expect(remove).toHaveBeenCalledWith("x")
  })

  it("drops a group past a deletion already waiting", async () => {
    const gate = deferred()
    post = vi.fn(() => gate.promise)
    const queue = build()
    queue.enqueue([event("first")])
    queue.enqueueDelete("z")
    queue.enqueue([event("a", "x")])
    queue.enqueueDelete("x")

    expect(queue.items.slice(1)).toEqual([{ type: "delete", actionId: "z" }])
    gate.resolve()
    await queue.flush()
  })

  it("does not take a deletion for the group it names", async () => {
    const gate = deferred()
    post = vi.fn(() => gate.promise)
    const queue = build()
    queue.enqueue([event("first")])
    queue.enqueueDelete("x")
    queue.enqueueDelete("x")

    expect(queue.items.slice(1)).toEqual([{ type: "delete", actionId: "x" }, { type: "delete", actionId: "x" }])
    gate.resolve()
    await queue.flush()
  })

  it("still sends a deletion for a group that failed, since it may have arrived", async () => {
    const pause = deferred()
    let fails = 1
    post = vi.fn(async () => { if (fails > 0) { fails -= 1; throw new TypeError("x") } })
    const queue = new SendQueue({ post, remove, storage, storageKey: "queue", onStatus: () => {}, sleep: () => pause.promise })
    queue.enqueue([event("a", "x")])
    await new Promise((resolve) => { setTimeout(resolve) })
    queue.enqueueDelete("x")
    pause.resolve()
    await queue.flush()

    expect(remove).toHaveBeenCalledWith("x")
  })

  it("persists the deletion", () => {
    remove = vi.fn(() => new Promise(() => {}))
    build().enqueueDelete("x")

    expect(JSON.parse(storage.data.queue)).toEqual([{ type: "delete", actionId: "x" }])
  })
})

describe("applyQueued", () => {
  it("adds unsent events after the server's", () => {
    expect(applyQueued([event("a")], [{ type: "post", events: [event("b")] }]).events).toEqual([event("a"), event("b")])
  })

  it("does not double an event the server already has", () => {
    expect(applyQueued([event("a")], [{ type: "post", events: [event("a")] }]).events).toEqual([event("a")])
  })

  it("applies unsent deletions and names what they removed", () => {
    const server = [event("a", "x"), event("b", "y")]

    expect(applyQueued(server, [{ type: "delete", actionId: "y" }])).toEqual({ events: [event("a", "x")], removed: [event("b", "y")] })
  })

  it("applies them in queue order", () => {
    const items = [{ type: "post", events: [event("b", "y")] }, { type: "delete", actionId: "y" }]

    expect(applyQueued([], items)).toEqual({ events: [], removed: [event("b", "y")] })
  })
})
