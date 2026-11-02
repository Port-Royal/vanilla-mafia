// "234к, 67ч, 9ш" or "234r, 67b, 9s": digits before a letter are seats, and anything else is the plan.
// A letter that begins a word ("2 красных") is plan text, so it must not be followed by another letter.
const GROUP = /(\d[\d\s]*?)\s*([кчшrbs])(?!\p{L})/giu
const LISTS = { к: "red", r: "red", ч: "black", b: "black", ш: "sheriff", s: "sheriff" }

const seatsIn = (digits) => digits.match(/10|\d/g).map((seat) => (seat === "0" ? 10 : Number(seat)))

export function parseWill(raw) {
  const lists = { red: [], black: [], sheriff: [] }
  const rest = raw.replace(GROUP, (_group, digits, letter) => {
    lists[LISTS[letter.toLowerCase()]].push(...seatsIn(digits.replace(/\s/g, "")))
    return ""
  })
  return { ...lists, plan: rest.replace(/\s+/g, " ").replace(/^[\s,]+|[\s,]+$/g, "") }
}
