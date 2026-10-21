// Study stack — port of Study.dc.html, driven by the real stack engine. Plus the Today summary (Goal.dc.html).
import { html, Component, Ico, Nav, cx, SEAL, PEACH, RED, speak } from './ui.js';
import * as E from './engine.js';

const CARD_W = 276;

function termSize(text, kind) {
  const n = text.length;
  if (kind === 'code') return n > 22 ? 19 : n > 14 ? 22 : 26;
  return n > 30 ? 24 : n > 20 ? 28 : n > 12 ? 32 : 36;
}

export class Study extends Component {
  constructor(props) {
    super(props);
    this.state = { revealed: false, dx: 0, anim: false, busy: false, note: null, showGoal: false, speaking: false, focusL: false, focusR: false, warm: 0 };
    this.dragging = false;
    this.moved = false;
    this.snaps = [];
    this.shownAt = performance.now();
  }
  componentDidMount() {
    this.props.app.studyRef = this;
    const warm = this.props.warm || 0;
    if (warm) this.showNote({ text: 'Warm-up: your ' + warm + ' weakest cards first', plain: true }, 4200);
  }
  componentWillUnmount() {
    if (this.props.app.studyRef === this) this.props.app.studyRef = null;
    clearTimeout(this.noteTimer);
  }
  componentDidUpdate(prev) {
    if (prev.deckId !== this.props.deckId) {
      this.snaps = [];
      this.setState({ revealed: false, dx: 0, note: null });
    }
  }
  deck() {
    return this.props.st.decks[this.props.deckId];
  }
  mode() {
    return this.props.st.settings.reveal;
  }
  showNote(note, ms) {
    clearTimeout(this.noteTimer);
    this.setState({ note });
    this.noteTimer = setTimeout(() => this.setState({ note: null }), ms || 5000);
  }

  // ---- gestures ----
  handleDown(e) {
    if (this.state.busy) return;
    if (e.target && e.target.closest && e.target.closest('button')) return;
    const k = this.props.app.scale();
    this.k = k;
    this.sx = e.clientX / k;
    this.dragging = true;
    this.moved = false;
    this.locked = false;
    this.curDx = 0;
    this.el = e.currentTarget;
    this.pid = e.pointerId;
    this.setState({ anim: false });
  }
  handleMove(e) {
    if (!this.dragging) return;
    const dx = e.clientX / this.k - this.sx;
    if (!this.moved && Math.abs(dx) > 6) {
      this.moved = true;
      try { this.el.setPointerCapture(this.pid); } catch (err) {}
    }
    if (!this.moved) return;
    const lock = Math.abs(dx) >= 0.6 * CARD_W;
    if (lock && !this.locked) this.props.app.fx.buzz(10);
    this.locked = lock;
    this.curDx = dx;
    this.setState({ dx });
  }
  handleUp() {
    if (!this.dragging) return;
    this.dragging = false;
    const dx = this.curDx || 0;
    if (!this.moved) {
      const m = this.mode();
      if (!this.state.revealed && (m === 'Tap card' || m === 'Flip')) this.reveal();
      return;
    }
    if (Math.abs(dx) >= 0.6 * CARD_W) this.commit(dx > 0);
    else this.setState({ dx: 0, anim: true });
  }

  reveal() {
    if (this.state.revealed) return;
    this.props.app.fx.click();
    this.setState({ revealed: true, note: null });
  }
  needsReveal() {
    return this.mode() !== 'Front only' && !this.state.revealed;
  }
  commit(ok) {
    const deck = this.deck();
    if (this.state.busy || !deck || !deck.stack.length) return;
    if (this.needsReveal()) {
      const m = this.mode();
      const hint = m === 'Flip' ? 'Flip the card to check first' : m === 'Tap icon' ? 'Show the answer to check first' : 'Tap the card to check first';
      this.setState({ dx: 0, anim: true });
      this.showNote({ text: hint, plain: true }, 2200);
      return;
    }
    const app = this.props.app;
    if (ok) app.fx.good(); else app.fx.thud();
    app.fx.buzz(16);
    this.setState({ busy: true, anim: true, dx: ok ? 640 : -640 });
    setTimeout(() => this.apply(ok), this.props.reduced ? 150 : 230);
  }
  apply(ok) {
    const app = this.props.app;
    const deck = this.deck();
    if (!deck) return;
    const snap = E.snapshot(this.props.st, deck);
    let res;
    const dwell = performance.now() - this.shownAt;
    app.mut((st) => { res = E.swipe(st, st.decks[deck.id], ok, dwell); });
    this.snaps.push(snap);
    if (this.snaps.length > 30) this.snaps.shift();
    this.shownAt = performance.now();
    this.setState({ revealed: false, dx: 0, anim: false, busy: false, showGoal: res.goalNow });
    if (res.goalNow) app.fx.fanfare();
    if (res.leech) this.showNote({ text: 'This card keeps slipping', edit: true }, 6000);
    else this.showNote({ text: res.text + (res.introduced ? ' · new card in' : ''), undo: true });
  }
  undo() {
    const snap = this.snaps.pop();
    if (!snap) {
      this.showNote({ text: 'Nothing to undo', plain: true }, 1600);
      return;
    }
    this.props.app.mut((st) => E.restore(st, snap));
    this.shownAt = performance.now();
    this.setState({ revealed: true, dx: 0, anim: false, showGoal: false });
    this.showNote({ text: 'Undone', plain: true }, 1600);
  }
  key(e) {
    if (this.state.showGoal) return false;
    if (e.key === 'ArrowRight') { this.commit(true); return true; }
    if (e.key === 'ArrowLeft') { this.commit(false); return true; }
    if (e.key === ' ' || e.key === 'Enter') { this.reveal(); return true; }
    if (e.key === 'z' || e.key === 'Backspace') { this.undo(); return true; }
    return false;
  }

  render() {
    const { app, st, ta, H, reduced, pushed } = this.props;
    const deck = this.deck();
    if (!deck) return html`<div class="scr"></div>`;
    const s = this.state;
    const mode = this.mode();
    const gp = E.goalProgress(st);
    const k = Math.max(0, 844 - H);
    const extra = Math.max(0, H - 844);
    const cardTop = Math.round(160 - k * 0.5 + extra * 0.35);
    const cardH = Math.round(384 - k * 0.35);
    const earTop = H - 268;
    const top = st.cards[deck.stack[0]];
    const next = st.cards[deck.stack[1]];
    const n = deck.stack.length;
    const dx = s.dx;
    const p = Math.min(1, Math.abs(dx) / CARD_W);
    const rot = Math.max(-28, Math.min(28, dx * 0.09));
    const dy = Math.min(140, dx * dx * 0.0005);
    const sc = 1 - 0.14 * p;
    const cardTf = reduced ? 'translateX(' + dx.toFixed(1) + 'px)' : 'translate(' + dx.toFixed(1) + 'px, ' + dy.toFixed(1) + 'px) rotate(' + rot.toFixed(2) + 'deg) scale(' + sc.toFixed(3) + ')';
    const cardOp = reduced ? (1 - p * 0.7).toFixed(2) : 1;
    const inL = s.focusL ? 1 : dx < 0 ? Math.min(1, -dx / (0.4 * CARD_W)) : 0;
    const inR = s.focusR ? 1 : dx > 0 ? Math.min(1, dx / (0.4 * CARD_W)) : 0;
    const commitL = dx <= -0.6 * CARD_W, commitR = dx >= 0.6 * CARD_W;
    const earTr = this.dragging ? 'transform 60ms linear' : 'transform 340ms cubic-bezier(.34,1.35,.5,1)';
    const above = [4, 3, 2, 1].filter((i) => i < n).map((i) => html`<div key=${'a' + i} class="layer" style=${'top:' + (cardTop - 17 * i) + 'px;height:' + cardH + 'px;background:linear-gradient(to bottom,' + ta.above[i - 1][0] + ' 0px,' + ta.above[i - 1][1] + ' 17px)'}></div>`);
    const below = [3, 2, 1].filter((i) => i < n).map((i) => html`<div key=${'b' + i} class="layer" style=${'top:' + (cardTop + 17 * i) + 'px;height:' + cardH + 'px;background:' + ta.below[i - 1]}></div>`);
    const lang = deck.lang;
    const flip = mode === 'Flip';
    const speakText = top ? (top.rev ? top.b : top.f) : '';
    const answerLong = top && top.b.length > 22;
    const compact = cardH < 370;
    const sub = 'Today ' + Math.min(gp.done, gp.goal) + ' / ' + gp.goal + ' · stack of ' + n + (deck.reservoir.length ? ' · ' + deck.reservoir.length + ' waiting' : '');

    const speakBtn = lang && html`<button class="speak d" style=${'height:' + (compact ? 64 : 84) + 'px'} aria-label="Play pronunciation" onClick=${(ev) => {
      ev.stopPropagation();
      this.setState({ speaking: true });
      speak(speakText, lang, () => this.setState({ speaking: false }));
    }}>${Ico.speaker()}<span>${s.speaking ? 'Playing…' : 'Hear it'}</span></button>`;

    const front = top && html`<div class="face">
      <div class="card-label">${top.l || deck.tag || 'card'}</div>
      <div class=${cx('card-term', deck.kind === 'code' ? 'code' : 'd')} style=${'font-size:' + termSize(top.f, deck.kind) + 'px'} dir="auto">${top.f}</div>
      ${top.e && (!flip || !s.revealed) && html`<div class="card-ex" dir="auto">${top.e}</div>`}
      ${top.img && html`<img class="card-img" src=${top.img} alt="" />`}
      <div style="flex:1"></div>
      ${mode !== 'Front only' && !flip && (s.revealed
        ? html`<div class=${cx('answer d', answerLong && 'long')} aria-live="polite" dir="auto">${top.b}</div>`
        : mode === 'Tap card'
          ? html`<button class="reveal-btn" onClick=${() => this.reveal()}>Tap to reveal</button>`
          : html`<button class="reveal-btn icon" onClick=${() => this.reveal()}>${Ico.eye()}<span>Show answer</span></button>`)}
      ${flip && html`<div class="flip-hint">Tap the card to flip it</div>`}
      ${mode === 'Front only' && html`<div class="flip-hint">Self-check · swipe right if you knew it</div>`}
      ${speakBtn}
    </div>`;
    const back = top && flip && html`<div class="face back">
      <div class="card-label" style="color:#333333aa">Answer</div>
      <div class="card-term d" style=${'font-size:' + termSize(top.b, '') + 'px;color:#333333'} dir="auto">${top.b}</div>
      ${top.e && html`<div class="card-ex" style="color:#333333b0" dir="auto">${top.e}</div>`}
      <div style="flex:1"></div>
      ${speakBtn}
    </div>`;

    return html`<div class="scr" id="screen-study" data-screen="Study">
      <header class=${cx('hdr study-hdr', pushed && 'hide')}>
        <button class="ibtn" aria-label="Back to decks" onClick=${() => app.home()}><span style="width:28px;height:36px">${Ico.logo()}</span></button>
        <div style="flex:1;min-width:0">
          <div class="d ell" style="font-size:23px;line-height:1">${deck.name}</div>
          <div class="hdr-sub">${sub}</div>
        </div>
        <button class="ibtn" aria-label="Menu" onClick=${(ev) => app.menu('study', ev)}><span style="width:8px;height:26px">${Ico.dots()}</span></button>
      </header>
      <div class=${cx('push', pushed && 'on')}>
        <div class="goalbar" role="progressbar" aria-label="Daily goal" aria-valuemin="0" aria-valuemax=${gp.goal} aria-valuenow=${gp.done}>
          <div style=${'width:' + Math.min(100, Math.round((gp.done / gp.goal) * 100)) + '%'}></div>
        </div>
        ${n === 0 ? html`<div class="layer empty-card" style=${'top:' + cardTop + 'px;height:' + cardH + 'px'}>
            <div class="d" style="font-size:34px;line-height:1.05">No cards yet</div>
            <div style="font-size:16px;font-weight:500;color:var(--muted-on-ink);margin-top:8px">Write the first one and it joins this stack.</div>
            <div style="flex:1"></div>
            <button class="reveal-btn" onClick=${() => app.create({ deckId: deck.id })}>Add a card</button>
          </div>` : html`
          ${below}${above}
          ${next && html`<div aria-hidden="true" class="layer card-under" style=${'top:' + cardTop + 'px;height:' + cardH + 'px'}>
            <div style=${'opacity:' + p.toFixed(2)}>
              <div class="card-label">${next.l || deck.tag}</div>
              <div class=${cx('card-term', deck.kind === 'code' ? 'code' : 'd')} style=${'font-size:' + termSize(next.f, deck.kind) + 'px'} dir="auto">${next.f}</div>
            </div>
          </div>`}
          <div key=${top.id} class=${cx('card-top', flip && 'flipper', flip && s.revealed && 'flipped')} onPointerDown=${(e) => this.handleDown(e)} onPointerMove=${(e) => this.handleMove(e)} onPointerUp=${() => this.handleUp()} onPointerCancel=${() => this.handleUp()}
            style=${'top:' + cardTop + 'px;height:' + cardH + 'px;transform:' + cardTf + ';opacity:' + cardOp + ';transition:' + (s.anim ? 'transform 240ms cubic-bezier(.2,.8,.2,1), opacity 240ms' : 'none')}>
            <div class="card-inner">${front}${back}</div>
          </div>`}
        <button class="ear left" onClick=${() => this.commit(false)} onFocus=${() => this.setState({ focusL: true })} onBlur=${() => this.setState({ focusL: false })} aria-label="Didn't remember — bring it back soon"
          style=${'top:' + earTop + 'px;transform:rotate(' + (48 * (1 - inL) + (commitL ? -5 : 0)).toFixed(2) + 'deg);transition:' + earTr}>
          <span class="ear-back" style="left:-42px;transform:rotate(30deg)"></span>
          <span class="ear-front" style="left:-48px"></span>
          <span class="ear-ico" style="left:10px">${Ico.again()}</span>
        </button>
        <button class="ear right" onClick=${() => this.commit(true)} onFocus=${() => this.setState({ focusR: true })} onBlur=${() => this.setState({ focusR: false })} aria-label="Remembered — show it later"
          style=${'top:' + earTop + 'px;transform:rotate(' + (-48 * (1 - inR) + (commitR ? 5 : 0)).toFixed(2) + 'deg);transition:' + earTr}>
          <span class="ear-back" style="left:42px;transform:rotate(-30deg)"></span>
          <span class="ear-front" style="left:48px"></span>
          <span class="ear-ico" style="left:52px">${Ico.done()}</span>
        </button>
        ${s.note && html`<div class="note-chip" aria-live="polite" style=${'top:' + (H - 194) + 'px'}>
          <span>${s.note.text}</span>
          ${s.note.undo && html`<button class="chip-btn" onClick=${() => this.undo()}>${Ico.undo()} Undo</button>`}
          ${s.note.edit && html`<button class="chip-btn" onClick=${() => { const prevId = deck.stack[deck.stack.length - 1]; app.create({ editCardId: prevId }); }}>Rewrite it</button>`}
          ${s.note.plain && html`<span style="width:10px"></span>`}
        </div>`}
        <${Nav} app=${app} current="study" />
      </div>
      ${s.showGoal && html`<div class="dialog-dim" role="dialog" aria-modal="true" aria-label="Daily goal reached">
        <div class="goal-card pop-in">
          <svg width="96" height="96" viewBox="-50 -50 100 100" aria-hidden="true" class="seal-spin"><path d=${SEAL} fill=${RED}/><circle r="31" fill="none" stroke="#F1F1F1" stroke-opacity="0.55" stroke-width="2"/><path d="M-14 1 -4 11 15-10" fill="none" stroke="#F1F1F1" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/></svg>
          <div class="d" style="font-size:34px;line-height:1.05;margin-top:14px">Today's goal — done</div>
          <div class="goal-copy">${gp.done} cards reviewed · streak ${st.profile.streak} ${st.profile.streak === 1 ? 'day' : 'days'}. The stack keeps going if you do.</div>
          <button class="btn-ink d" style="margin-top:20px;width:100%;height:52px;font-size:24px" onClick=${() => this.setState({ showGoal: false })}>Keep going</button>
          <button class="btn-soft" style="margin-top:10px;width:100%;height:48px;box-shadow:none" onClick=${() => { this.setState({ showGoal: false }); app.go('today'); }}>See today's summary</button>
        </div>
      </div>`}
    </div>`;
  }
}

// ---------- Today (Goal.dc.html) ----------
export function Today({ app, st }) {
  const at = E.now(st);
  const gp = E.goalProgress(st);
  const t = st.today;
  const lib = E.libraryStats(st, at);
  const streak = E.liveStreak(st);
  const health = lib.health == null ? 0 : Math.round(lib.health * 100);
  const lastDeck = t.lastDeck && st.decks[t.lastDeck];
  const mins = Math.max(t.done ? 1 : 0, Math.round(t.ms / 60000));
  const used = 2 - st.profile.shields;
  const left = Math.max(0, gp.goal - gp.done);
  const stat = (v, label) => html`<div class="tile"><div class="d" style="font-size:36px;line-height:1">${v}</div><div class="tile-label">${label}</div></div>`;
  const events = st.profile.lastEvents || [];
  return html`<div class="scr" id="screen-today" data-screen="Today">
    <header class="hdr">
      <button class="ibtn" aria-label="Back to decks" onClick=${() => app.home()}><span style="width:28px;height:36px">${Ico.logo()}</span></button>
      <div class="hdr-title d">Today</div>
    </header>
    <div class="scroll" style="top:76px;bottom:150px">
      <section style="display:flex;flex-direction:column;align-items:center;padding:8px 24px 0">
        <div style="position:relative;width:168px;height:168px">
          <svg width="168" height="168" viewBox="-50 -50 100 100" aria-hidden="true" style=${'filter:var(--seal-shadow);' + (gp.reached ? '' : 'opacity:.9')}>
            <path d=${SEAL} fill=${gp.reached ? RED : 'var(--soft)'} stroke=${gp.reached ? 'none' : 'var(--line)'} stroke-width="1.4"/>
            <circle r="33" fill="none" stroke=${gp.reached ? '#F1F1F1' : 'var(--muted)'} stroke-opacity="0.5" stroke-width="1.6"/>
            <circle r="28" fill="none" stroke=${gp.reached ? '#F1F1F1' : 'var(--muted)'} stroke-opacity="0.35" stroke-width="1"/>
          </svg>
          <div class="d seal-word" style=${'color:' + (gp.reached ? '#F1F1F1' : 'var(--ink)')}>${gp.reached ? 'DONE' : gp.done + '/' + gp.goal}</div>
        </div>
        <h1 class="d" style="margin:14px 0 0;font-size:42px;line-height:1;text-align:center">${gp.reached ? 'Goal reached' : left + ' to go'}</h1>
        <p class="today-sub">${(lastDeck ? lastDeck.name + ' · ' : '') + mins + ' min' + (gp.reached ? '' : ' · or see every slipping card once (' + gp.slipLeft + ' left)')}</p>
      </section>
      <section aria-label="Session stats" class="tiles">${stat(t.done, 'reviewed')}${stat(t.ok, 'remembered')}${stat(t.fail, 'relearned')}</section>
      <section aria-label="Streak" class="streak-card">
        ${Ico.flame(26, 30)}
        <div style="flex:1">
          <div class="d" style="font-size:26px;line-height:1">${streak}-day streak</div>
          <div style="font-size:14px;font-weight:500;color:var(--muted-on-ink);margin-top:3px">${st.profile.shields} grace ${st.profile.shields === 1 ? 'shield' : 'shields'} left this month${events.includes('shield') ? ' · one covered a missed day' : events.includes('broken') ? ' · streak reset after a missed day' : ''}</div>
        </div>
        <div style="display:flex;gap:4px" aria-hidden="true">${[0, 1].map((i) => html`<span key=${i}>${Ico.shield(22, 26, i < used)}</span>`)}</div>
      </section>
      <section aria-label="Memory health" class="health">
        <div style="display:flex;justify-content:space-between;align-items:baseline">
          <div style="font-size:16px;font-weight:700">Memory health</div>
          <div class="d" style="font-size:26px">${health}%</div>
        </div>
        <div class="track"><div style=${'width:' + health + '%'}></div></div>
        <div style="margin-top:8px;font-size:14px;font-weight:500;color:var(--muted)">Predicted recall right now. ${lib.tomorrow} ${lib.tomorrow === 1 ? 'card starts' : 'cards start'} slipping tomorrow.</div>
      </section>
    </div>
    <div class="bottom-actions">
      <button class="btn-ink d" style="height:56px;font-size:26px" onClick=${() => app.keepGoing()}>Keep going</button>
      <button class="btn-soft" style="height:50px" onClick=${() => app.home()}>Back to decks</button>
    </div>
  </div>`;
}
