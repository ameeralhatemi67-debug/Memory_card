// Memory Card prototype — the repetition engine (RES-47 §5, "Endless Stack + Shadow FSRS") and the app store.
// The stack decides the order. FSRS-6 only predicts: memory health, the stepped fan, slipping counts, warm-up.
import { POOLS, LIBRARY, SHOP } from './content.js';

export const DAY = 86400000;
export const HOUR = 3600000;
const KEY = 'memory-card-prototype-v1';

// ---------- clock (the Lab can move it forward) ----------
export const now = (st) => Date.now() + (st.clockOffset || 0);
// Day boundary at 04:00 local time (RES-47 §5.6).
export function dayKey(ts) {
  const d = new Date(ts - 4 * HOUR);
  return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
}
export function dayIndex(key) {
  const [y, m, d] = key.split('-').map(Number);
  return Math.round(Date.UTC(y, m - 1, d) / DAY);
}
export function keyOfIndex(i) {
  const d = new Date(i * DAY);
  return d.getUTCFullYear() + '-' + String(d.getUTCMonth() + 1).padStart(2, '0') + '-' + String(d.getUTCDate()).padStart(2, '0');
}

// ---------- FSRS-6 (default parameters) — prediction only ----------
const W = [0.212, 1.2931, 2.3065, 8.2956, 6.4133, 0.8334, 3.0194, 0.001, 1.8722, 0.1666, 0.796, 1.4835,
  0.0614, 0.2629, 1.6483, 0.6014, 1.8729, 0.5425, 0.0912, 0.0658, 0.1542];
const DECAY = -W[20];
const FACTOR = Math.pow(0.9, 1 / DECAY) - 1;
const d0 = (g) => W[4] - Math.exp(W[5] * (g - 1)) + 1;
const clampD = (d) => Math.min(10, Math.max(1, d));

export function recall(c, at) {
  if (!c || !c.s) return null;
  const t = Math.max(0, (at - c.last) / DAY);
  return Math.pow(1 + FACTOR * t / c.s, DECAY);
}

function fsrsReview(c, ok, at) {
  const g = ok ? 3 : 1;
  if (!c.s) {
    c.s = W[g - 1];
    c.d = clampD(d0(g));
  } else {
    const t = (at - c.last) / DAY;
    const r = recall(c, at);
    if (t < 1) {                                   // same-day repeat: FSRS-6 short-term formula
      let inc = Math.exp(W[17] * (g - 3 + W[18])) * Math.pow(c.s, -W[19]);
      if (g >= 3) inc = Math.max(1, inc);
      c.s *= inc;
    } else if (ok) {
      c.s *= 1 + Math.exp(W[8]) * (11 - c.d) * Math.pow(c.s, -W[9]) * (Math.exp(W[10] * (1 - r)) - 1);
    } else {
      const sf = W[11] * Math.pow(c.d, -W[12]) * (Math.pow(c.s + 1, W[13]) - 1) * Math.exp(W[14] * (1 - r));
      c.s = Math.min(c.s, sf);
    }
    const dp = c.d - W[6] * (g - 3) * (10 - c.d) / 9;
    c.d = clampD(W[7] * d0(4) + (1 - W[7]) * dp);
  }
  c.s = Math.max(0.01, c.s);
  c.last = at;
}

// ---------- pacing (RES-47 §5.2) ----------
export const PACE_TARGET = { Relaxed: 0.8, Balanced: 0.75, Intense: null };
const START_ACTIVE = 15;

// ---------- helpers ----------
let seq = 0;
export const uid = (p) => p + Date.now().toString(36) + (seq++).toString(36) + Math.floor(Math.random() * 1e4).toString(36);
function rng(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6D2B79F5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
function shuffle(a, r) {
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(r() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}
export function parsePool(key) {
  const p = POOLS[key];
  return p.rows.trim().split('\n').map((line) => {
    const [f, b, l, e] = line.split(' | ').map((x) => (x || '').trim());
    return { f, b, l: l || p.tag || '', e: e || '' };
  });
}

// ---------- decks and cards ----------
export function folderOf(st, deckId) {
  return st.folders.find((f) => f.deckIds.includes(deckId));
}
export function makeDeck(st, { name, folderId, lang, kind, tag, shopId }) {
  const id = uid('d');
  st.decks[id] = { id, name, lang: lang || '', kind: kind || '', tag: tag || '', cardIds: [], stack: [], reservoir: [], pinned: false,
    ema: 0.75, lastStudied: 0, created: now(st), shopId: shopId || null, prevFolder: null };
  const f = st.folders.find((x) => x.id === folderId) || st.folders[0];
  f.deckIds.unshift(id);
  return st.decks[id];
}
function makeCard(st, deck, data) {
  const id = uid('c');
  st.cards[id] = { id, deckId: deck.id, f: data.f, b: data.b, l: data.l || '', e: data.e || '', img: data.img || '', sib: data.sib || null, rev: !!data.rev,
    s: 0, d: 0, last: 0, reps: 0, lapses: 0, succ: 0, leech: false };
  deck.cardIds.push(id);
  return st.cards[id];
}
// Fresh decks start with up to 15 active cards; the rest wait in the reservoir unless the pace is Intense.
export function addCardsToNewDeck(st, deck, rows, reverse) {
  const ids = [];
  rows.forEach((r) => {
    const c = makeCard(st, deck, r);
    ids.push(c.id);
    if (reverse) {
      const rc = makeCard(st, deck, { f: r.b, b: r.f, l: 'reverse', e: '', rev: true, sib: c.id });
      c.sib = rc.id;
      ids.push(rc.id);
    }
  });
  const intense = st.settings.pace === 'Intense';
  const front = ids.filter((id) => !st.cards[id].rev);
  const backs = ids.filter((id) => st.cards[id].rev);
  const ordered = front.concat(backs);                          // reverse siblings start far apart
  const k = intense ? ordered.length : Math.min(START_ACTIVE, ordered.length);
  deck.stack = ordered.slice(0, k);
  deck.reservoir = ordered.slice(k);
  return ids;
}
// A card the user writes into an existing deck enters 3 positions from the top; its reverse 10 further down.
export function addCardToDeck(st, deck, data, reverse) {
  const c = makeCard(st, deck, data);
  const at = Math.min(3, deck.stack.length);
  deck.stack.splice(at, 0, c.id);
  if (reverse) {
    const rc = makeCard(st, deck, { f: data.b, b: data.f, l: 'reverse', rev: true, sib: c.id, img: '' });
    c.sib = rc.id;
    deck.stack.splice(Math.min(at + 11, deck.stack.length), 0, rc.id);
  }
  return c;
}
export function deleteCard(st, cardId) {
  const c = st.cards[cardId];
  if (!c) return;
  const d = st.decks[c.deckId];
  d.cardIds = d.cardIds.filter((x) => x !== cardId);
  d.stack = d.stack.filter((x) => x !== cardId);
  d.reservoir = d.reservoir.filter((x) => x !== cardId);
  delete st.cards[cardId];
  if (c.sib && st.cards[c.sib]) st.cards[c.sib].sib = null;
}
export function addShopDeck(st, shopId, folderId) {
  const s = SHOP.find((x) => x.id === shopId);
  const pool = POOLS[s.pool];
  const deck = makeDeck(st, { name: s.name, folderId, lang: pool.lang, kind: pool.kind, tag: pool.tag, shopId });
  addCardsToNewDeck(st, deck, parsePool(s.pool), false);
  st.shopAdded[shopId] = deck.id;
  return deck;
}

// ---------- stats (all FSRS-driven) ----------
export function deckStats(st, deck, at) {
  let slip = 0, good = 0, fresh = 0, sumR = 0, nR = 0, tomorrow = 0;
  for (const id of deck.cardIds) {
    const c = st.cards[id];
    const r = recall(c, at);
    if (r == null) { fresh++; continue; }
    nR++;
    sumR += r;
    if (r < 0.9) slip++;
    else {
      good++;
      if (recall(c, at + DAY) < 0.9) tomorrow++;
    }
  }
  const total = deck.cardIds.length;
  return { total, slip, good, fresh, tomorrow, health: nR ? sumR / nR : null, steps: total ? Math.floor((5 * good) / total + 1e-9) : 0 };
}
export function libraryStats(st, at, folderId) {
  let slip = 0, good = 0, total = 0, sumR = 0, nR = 0, tomorrow = 0;
  for (const f of st.folders) {
    if (folderId && f.id !== folderId) continue;
    if (!folderId && f.id === 'f-archive') continue;
    for (const id of f.deckIds) {
      const s = deckStats(st, st.decks[id], at);
      slip += s.slip; good += s.good; total += s.total; tomorrow += s.tomorrow;
      if (s.health != null) { sumR += s.health * (s.total - s.fresh); nR += s.total - s.fresh; }
    }
  }
  return { slip, good, total, tomorrow, health: nR ? sumR / nR : null };
}

// ---------- the day, the goal and the streak (RES-47 §5.4, FES-46) ----------
function slippingIds(st, at) {
  const out = [];
  for (const f of st.folders) {
    if (f.id === 'f-archive') continue;
    for (const did of f.deckIds) for (const id of st.decks[did].cardIds) {
      const r = recall(st.cards[id], at);
      if (r != null && r < 0.9) out.push(id);
    }
  }
  return out;
}
export function ensureToday(st) {
  const at = now(st);
  const key = dayKey(at);
  if (st.today && st.today.day === key) return false;
  const p = st.profile;
  if (st.today && st.today.done) p.history[st.today.day] = (p.history[st.today.day] || 0) + st.today.done;
  const month = key.slice(0, 7);
  if (p.shieldMonth !== month) { p.shieldMonth = month; p.shields = 2; }
  // Days missed since the last goal: a grace shield covers each one, otherwise the streak breaks.
  let last = dayIndex(p.lastGoalDay);
  const today = dayIndex(key);
  p.lastEvents = [];
  for (let d = last + 1; d < today; d++) {
    if (p.streak > 0 && p.shields > 0) { p.shields--; p.lastEvents.push('shield'); }
    else if (p.streak > 0) { p.streak = 0; p.lastEvents.push('broken'); }
    last = d;
  }
  p.lastGoalDay = keyOfIndex(last);
  st.today = { day: key, done: 0, ok: 0, fail: 0, ms: 0, seen: [], slipStart: slippingIds(st, at), goalHit: false, decks: {} };
  return true;
}
export function goalProgress(st) {
  const t = st.today;
  const goal = st.settings.goal;
  const seen = new Set(t.seen);
  const slipLeft = t.slipStart.filter((id) => st.cards[id] && !seen.has(id)).length;
  return { done: t.done, goal, slipLeft, reached: t.done >= goal || (t.slipStart.length > 0 && slipLeft === 0) };
}
export function liveStreak(st) {
  const p = st.profile;
  const gap = dayIndex(st.today.day) - dayIndex(p.lastGoalDay);
  return gap <= 1 || st.today.goalHit ? p.streak : 0;
}

// ---------- the study loop (RES-47 §5.1) ----------
export function prepareDeck(st, deck) {
  const at = now(st);
  if (!deck.stack.length && deck.reservoir.length) deck.stack = deck.reservoir.splice(0, START_ACTIVE);
  // Warm-up after a break of 2+ days: the 20 weakest active cards move to the top.
  let warm = 0;
  if (deck.lastStudied && at - deck.lastStudied >= 2 * DAY) {
    const scored = deck.stack.map((id, i) => ({ id, i, r: recall(st.cards[id], at) })).filter((x) => x.r != null);
    scored.sort((a, b) => a.r - b.r);
    const weak = scored.slice(0, 20).map((x) => x.id);
    if (weak.length) {
      const set = new Set(weak);
      deck.stack = weak.concat(deck.stack.filter((id) => !set.has(id)));
      warm = weak.length;
    }
    deck.lastStudied = at;
  }
  return warm;
}

export function snapshot(st, deck) {
  const id = deck.stack[0];
  return {
    deckId: deck.id, stack: deck.stack.slice(), reservoir: deck.reservoir.slice(), ema: deck.ema, lastStudied: deck.lastStudied,
    card: id ? JSON.parse(JSON.stringify(st.cards[id])) : null,
    today: JSON.parse(JSON.stringify(st.today)),
    profile: { streak: st.profile.streak, lastGoalDay: st.profile.lastGoalDay },
    logLen: st.log.length
  };
}
export function restore(st, snap) {
  const deck = st.decks[snap.deckId];
  if (!deck) return;
  deck.stack = snap.stack; deck.reservoir = snap.reservoir; deck.ema = snap.ema; deck.lastStudied = snap.lastStudied;
  if (snap.card && st.cards[snap.card.id]) st.cards[snap.card.id] = snap.card;
  st.today = snap.today;
  st.profile.streak = snap.profile.streak;
  st.profile.lastGoalDay = snap.profile.lastGoalDay;
  st.log.length = Math.min(st.log.length, snap.logLen);
}

// Swipe right: back of the stack. Swipe left: back in N = round(8 + 12 x success rate), clamped to [8, 20],
// never closer than 5 cards; in a stack shorter than 6 it goes to the end.
export function swipe(st, deck, ok, dwellMs) {
  const at = now(st);
  const id = deck.stack[0];
  const c = st.cards[id];
  const rBefore = recall(c, at);
  const posBefore = 0;
  const rest = deck.stack.slice(1);
  c.reps++;
  if (ok) c.succ++; else c.lapses++;
  const rate = c.reps ? c.succ / c.reps : 0;
  let n = rest.length;
  let text;
  let leech = false;
  if (ok) {
    rest.push(id);
    text = 'Sent to the back';
  } else if (c.lapses >= 8 && !c.leech) {
    c.leech = true;
    leech = true;
    rest.push(id);
    text = 'Keeps slipping · moved to the end';
  } else {
    if (rest.length >= 6) {
      n = Math.round(8 + 12 * rate);
      n = Math.max(8, Math.min(20, n));
      n = Math.max(5, Math.min(n, rest.length));
      // Reverse siblings stay at least 10 cards apart.
      const si = c.sib ? rest.indexOf(c.sib) : -1;
      if (si >= 0 && Math.abs(si - n) < 10 && rest.length > si + 10) n = si + 10;
    }
    rest.splice(n, 0, id);
    text = n >= rest.length - 1 ? 'Back at the end' : 'Back in ' + n + ' cards';
  }
  fsrsReview(c, ok, at);
  deck.ema = deck.ema + 0.05 * ((ok ? 1 : 0) - deck.ema);
  let introduced = null;
  const target = PACE_TARGET[st.settings.pace];
  if (deck.reservoir.length && (target == null || deck.ema >= target)) {
    introduced = deck.reservoir.shift();
    rest.splice(Math.min(3, rest.length), 0, introduced);
  }
  deck.stack = rest;
  deck.lastStudied = at;
  const t = st.today;
  t.done++;
  if (ok) t.ok++; else t.fail++;
  if (!t.seen.includes(id)) t.seen.push(id);
  t.decks[deck.id] = (t.decks[deck.id] || 0) + 1;
  t.ms += Math.min(60000, dwellMs || 0);
  t.lastDeck = deck.id;
  st.log.push({ ts: at, card: id, deck: deck.id, grade: ok ? 1 : 0, pos: posBefore, n: ok ? null : n, r: rBefore, s: c.s, d: c.d, ema: deck.ema });
  if (st.log.length > 3000) st.log.splice(0, st.log.length - 3000);
  st.lastSwipe = { deckId: deck.id, card: c.f, ok, n: ok ? null : n, rate, rBefore, introduced: introduced ? st.cards[introduced].f : null, leech, at };
  // The goal: every card slipping at the start of the day seen once, or the swipe target, whichever comes first.
  let goalNow = false;
  if (!t.goalHit && goalProgress(st).reached) {
    t.goalHit = true;
    goalNow = true;
    const p = st.profile;
    const gap = dayIndex(t.day) - dayIndex(p.lastGoalDay);
    p.streak = gap === 1 ? p.streak + 1 : 1;
    p.lastGoalDay = t.day;
  }
  return { text, n, introduced, leech, goalNow };
}

// ---------- CSV / pasted text import ----------
export function detectSep(text) {
  const lines = text.split('\n').filter((l) => l.trim());
  const cands = [['\t', 'Tab'], [';', 'Semicolon'], [',', 'Comma']];
  for (const [ch, name] of cands) {
    if (lines.length && lines.filter((l) => l.includes(ch)).length >= Math.ceil(lines.length / 2)) return [ch, name];
  }
  return [null, 'No separator found'];
}
export function parseImport(text) {
  const [sep, sepName] = detectSep(text);
  const rows = [];
  let skipped = 0;
  for (const l of text.split('\n').filter((x) => x.trim())) {
    const i = sep ? l.indexOf(sep) : -1;
    const f = i >= 0 ? l.slice(0, i).trim().replace(/^"|"$/g, '') : '';
    const b = i >= 0 ? l.slice(i + 1).trim().replace(/^"|"$/g, '') : '';
    if (f && b) rows.push({ f, b }); else skipped++;
  }
  return { sepName, rows, skipped };
}

// ---------- first launch ----------
const HEAT = [2, 0, 1, 3, 2, 0, 0, 1, 2, 2, 0, 3, 1, 0, 2, 3, 0, 1, 2, 4, 0, 0, 1, 2, 3, 2, 1, 3, 2, 4, 2, 3, 1, 2, 3];
const HEAT_SWIPES = [0, 9, 22, 41, 68];

export function seedStore(realNow) {
  const r = rng(47);
  const st = {
    v: 1, clockOffset: 0, folders: [], decks: {}, cards: {}, log: [], shopPins: [], shopAdded: {},
    currentFolder: 'f-lang', recentFolders: ['f-lang', 'f-de', 'f-code'],
    settings: { reveal: 'Tap card', pace: 'Balanced', goal: 20, theme: 'System', sounds: true, haptics: true, reduced: false, remind: '19:00' },
    profile: { streak: 7, shields: 2, shieldMonth: dayKey(realNow).slice(0, 7), lastGoalDay: keyOfIndex(dayIndex(dayKey(realNow)) - 1),
      since: new Date(realNow).getFullYear(), history: {}, lastEvents: [] },
    today: null, lastSwipe: null
  };
  const todayIdx = dayIndex(dayKey(realNow));
  for (let i = 1; i < HEAT.length; i++) {
    const v = HEAT[i];
    if (v) st.profile.history[keyOfIndex(todayIdx - (HEAT.length - i))] = HEAT_SWIPES[v];
  }
  for (const lf of LIBRARY) {
    const folder = { id: lf.id, name: lf.name, deckIds: [] };
    st.folders.push(folder);
    for (const [name, poolKey, slip, fresh, ago] of lf.decks) {
      const pool = POOLS[poolKey];
      const deck = makeDeck(st, { name, folderId: folder.id, lang: pool.lang, kind: pool.kind, tag: pool.tag });
      folder.deckIds.push(folder.deckIds.shift());                 // keep the library order
      const rows = parsePool(poolKey);
      const ids = rows.map((row) => makeCard(st, deck, row).id);
      const order = shuffle(ids.map((_, i) => i), r);
      const slipSet = new Set(order.slice(0, slip));
      const freshSet = new Set(order.slice(slip, slip + fresh));
      const lastAt = realNow - ago * DAY - r() * 6 * HOUR;
      ids.forEach((id, i) => {
        const c = st.cards[id];
        if (freshSet.has(i)) return;
        c.d = 3 + r() * 4;
        if (slipSet.has(i)) {
          c.s = 0.8 + r() * 5;
          c.last = Math.min(lastAt, realNow - c.s * (1.4 + r() * 2) * DAY);
          c.lapses = 1 + Math.floor(r() * 3);
        } else {
          c.s = ago * 1.6 + 5 + r() * 45;
          c.last = Math.max(realNow - c.s * 0.8 * DAY, Math.min(lastAt, realNow - r() * c.s * 0.8 * DAY));
          c.lapses = Math.floor(r() * 2);
        }
        c.reps = c.lapses + 2 + Math.floor(r() * 6);
        c.succ = c.reps - c.lapses;
      });
      deck.stack = shuffle(ids.slice(), r);
      deck.lastStudied = lastAt;
      deck.ema = 0.72 + r() * 0.16;
    }
  }
  return st;
}

// ---------- persistence ----------
export function load() {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return null;
    const st = JSON.parse(raw);
    return st && st.v === 1 ? st : null;
  } catch (e) {
    return null;
  }
}
export function save(st) {
  try {
    localStorage.setItem(KEY, JSON.stringify(st));
    return true;
  } catch (e) {
    return false;
  }
}
export function clearSaved() {
  try { localStorage.removeItem(KEY); } catch (e) {}
}
export function validBackup(obj) {
  return obj && obj.v === 1 && Array.isArray(obj.folders) && obj.decks && obj.cards && obj.settings && obj.profile;
}
