// Keeps the judge's actions on their way to the server, strictly in order and one request at a
// time. An item stays in storage until the server has answered, so a lost connection or a reload
// loses nothing. Sending again is safe: the server recognises events by client_id.

const RETRY_DELAYS = [1000, 2000, 5000]

export class PermanentError extends Error {
  constructor(status) {
    super(`The server refused the request: ${status}`)
    this.status = status
  }
}

const wait = (ms) => new Promise((resolve) => { setTimeout(resolve, ms) })

export class SendQueue {
  constructor({ post, remove, storage, storageKey, onStatus, sleep = wait }) {
    Object.assign(this, { post, remove, storage, storageKey, onStatus, sleep })
    this.items = this.load()
    this.current = null
    this.draining = null
    this.failures = 0
  }

  enqueue(events) {
    this.items.push({ type: "post", events })
    this.persist()
    this.flush()
  }

  enqueueDelete(actionId) {
    if (!this.dropUnsent(actionId)) this.items.push({ type: "delete", actionId })
    this.persist()
    this.flush()
  }

  flush() {
    this.draining ??= this.drain().finally(() => { this.draining = null })
    return this.draining
  }

  // Not yet sent means nothing to tell the server. A group on its way is another matter: it may
  // already have arrived, so it gets a deletion of its own.
  dropUnsent(actionId) {
    const inQueue = (item) => item !== this.current && item.type === "post" && item.events.some((event) => event.action_id === actionId)
    if (!this.items.some(inQueue)) return false

    this.items = this.items
      .map((item) => (inQueue(item) ? { ...item, events: item.events.filter((event) => event.action_id !== actionId) } : item))
      .filter((item) => item.type !== "post" || item.events.length > 0)
    return true
  }

  async drain() {
    while (this.items.length > 0) {
      this.onStatus("saving")
      const stop = await this.sendFirst()
      if (stop) return
    }
    this.onStatus("saved")
  }

  async sendFirst() {
    [this.current] = this.items
    try {
      await this.deliver(this.current)
      this.items = this.items.filter((item) => item !== this.current)
      this.failures = 0
      this.persist()
      return false
    } catch (error) {
      if (error instanceof PermanentError) {
        this.onStatus("rejected")
        return true
      }
      this.onStatus("offline")
      await this.sleep(RETRY_DELAYS[Math.min(this.failures, RETRY_DELAYS.length - 1)])
      this.failures += 1
      return false
    } finally {
      this.current = null
    }
  }

  deliver(item) {
    return item.type === "post" ? this.post(item.events) : this.remove(item.actionId)
  }

  load() {
    try {
      return JSON.parse(this.storage.getItem(this.storageKey)) ?? []
    } catch {
      return []
    }
  }

  persist() {
    try {
      this.storage.setItem(this.storageKey, JSON.stringify(this.items))
    } catch {
      // Storage can be full or blocked. The queue still works until the page closes.
    }
  }
}

// What the journal looks like once everything still in the queue has reached the server.
export function applyQueued(serverEvents, items) {
  let events = serverEvents
  const removed = []
  items.forEach((item) => {
    if (item.type === "post") {
      const known = new Set(events.map((event) => event.client_id))
      events = [...events, ...item.events.filter((event) => !known.has(event.client_id))]
    } else {
      removed.push(...events.filter((event) => event.action_id === item.actionId))
      events = events.filter((event) => event.action_id !== item.actionId)
    }
  })
  return { events, removed }
}
