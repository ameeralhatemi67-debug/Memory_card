// Decks (home) — port of Main.dc.html + DeckActions + EmptyFolder.dc.html, wired to the store.
import { html, Component, Ico, Nav, cx, BLUE, PEACH, GREEN, DELETE, RED } from './ui.js';
import * as E from './engine.js';

// Stepped swipe detents (text_Mockup §3, RES-02/RES-03): option 1 at 65px, option 2 at 125px.
const STEP_1 = 65, STEP_2 = 125, SPAN_2 = STEP_2 - STEP_1, GAP = 10, MARGIN = 20;

// Four-phase "inward gravity": resists leaving rest, slides freely, then is pulled into each detent.
function gravity(raw) {
  const a = Math.abs(raw);
  if (a <= STEP_1) {
    const p = a / STEP_1;
    if (p < 0.1) return a * 0.35;
    if (p < 0.9) return a;
    return STEP_1 - (STEP_1 - a) * 0.35;
  }
  const d2 = a - STEP_1;
  const p2 = Math.min(1, d2 / SPAN_2);
  if (p2 < 0.1) return STEP_1 + d2 * 0.35;
  if (p2 < 0.9) return STEP_1 + d2;
  if (a <= STEP_2) return STEP_2 - (STEP_2 - (STEP_1 + d2)) * 0.35;
  return STEP_2 + Math.min(22, (a - STEP_2) * 0.22);
}

export class Decks extends Component {
  constructor(props) {
    super(props);
    this.state = { open: null, drag: null, anim: null, removing: null };
    this.ptr = null;
    this.justDragged = false;
  }
  componentWillUnmount() {
    cancelAnimationFrame(this.raf);
  }
  componentDidUpdate(prev) {
    if (prev.folderId !== this.props.folderId && (this.state.open || this.state.anim)) this.setState({ open: null, anim: null });
  }

  // Spring with an opening overshoot (+12px) and a squash rebound (-9px).
  animateTo(id, dir, from, target, overshoot) {
    cancelAnimationFrame(this.raf);
    let cur = from, vel = 0, over = target;
    if (overshoot) {
      if (target > from) over = target + 12;
      else if (from > target + 1) over = target - 9;
    }
    let phase = overshoot && Math.abs(over - target) > 1 ? 'over' : 'settle';
    const step = () => {
      const dest = phase === 'over' ? over : target;
      vel = (vel + (dest - cur) * 0.16) * 0.74;
      cur += vel;
      if (phase === 'over' && Math.abs(cur - over) < 1.2) phase = 'settle';
      else if (phase === 'settle' && Math.abs(cur - target) < 0.3 && Math.abs(vel) < 0.15) {
        this.setState({ anim: null, open: target ? { id, d: dir * target } : null });
        return;
      }
      this.setState({ anim: { id, val: Math.max(0, cur), dir } });
      this.raf = requestAnimationFrame(step);
    };
    step();
  }

  down(e, id) {
    if (this.state.removing) return;
    cancelAnimationFrame(this.raf);
    const s = this.state;
    const k = this.props.app.scale();
    let base = 0;
    if (s.anim && s.anim.id === id) base = s.anim.dir * s.anim.val;
    else if (s.open && s.open.id === id) base = s.open.d;
    this.ptr = { id, sx: e.clientX / k - base, sy: e.clientY / k, base, moved: false, el: e.currentTarget, pid: e.pointerId, k };
    const patch = { anim: null };
    if (s.open && s.open.id !== id) patch.open = null;
    this.setState(patch);
  }
  move(e) {
    const p = this.ptr;
    if (!p) return;
    const x = e.clientX / p.k, y = e.clientY / p.k;
    const dx = x - p.sx;
    if (!p.moved) {
      const ddx = Math.abs(x - (p.sx + p.base));
      const ddy = Math.abs(y - p.sy);
      if (ddy > 10 && ddy > ddx) { this.ptr = null; return; }
      if (ddx < 6) return;
      p.moved = true;
      try { p.el.setPointerCapture(p.pid); } catch (err) {}
    }
    this.cur = { id: p.id, raw: Math.abs(dx), dir: dx < 0 ? -1 : 1 };
    this.setState({ drag: this.cur });
  }
  up() {
    const p = this.ptr;
    this.ptr = null;
    if (!p) return;
    if (!p.moved) {
      if (p.base !== 0) {
        this.justDragged = true;
        this.animateTo(p.id, Math.sign(p.base), Math.abs(p.base), 0, false);
      }
      return;
    }
    this.justDragged = true;
    const d = this.cur;
    this.cur = null;
    if (!d) return;
    const from = gravity(d.raw);
    this.setState({ drag: null });
    const app = this.props.app;
    const crossed = d.raw > STEP_1 * 0.5;
    if (crossed) app.fx.buzz(8);
    if (d.raw <= STEP_1) {
      if (d.raw / STEP_1 < 0.5) this.animateTo(p.id, d.dir, from, 0, false);
      else this.animateTo(p.id, d.dir, from, STEP_1, true);
    } else if ((d.raw - STEP_1) / SPAN_2 < 0.5) {
      this.animateTo(p.id, d.dir, from, STEP_1, false);
    } else {
      this.animateTo(p.id, d.dir, from, STEP_2, true);
    }
  }
  close(id, e) {
    this.animateTo(id, Math.sign(e) || 1, Math.abs(e), 0, false);
  }
  remove(id, kind) {
    const app = this.props.app;
    this.setState({ removing: { id, kind }, open: null, anim: null });
    app.fx.pop();
    setTimeout(() => {
      this.setState({ removing: null });
      if (kind === 'delete') app.deleteDeck(id);
      else app.archiveDeck(id);
    }, 360);
  }

  render() {
    const { app, st, ta, pushed, highlight, folderId } = this.props;
    const folder = st.folders.find((f) => f.id === folderId) || st.folders[0];
    const at = E.now(st);
    const s = this.state;
    const isArchive = folder.id === 'f-archive';
    const ids = folder.deckIds.filter((id) => st.decks[id]);
    const ordered = ids.filter((id) => st.decks[id].pinned).concat(ids.filter((id) => !st.decks[id].pinned));
    const folderStats = E.libraryStats(st, at, folder.id);
    const streak = E.liveStreak(st);
    const empty = ordered.length === 0;

    const rows = ordered.map((id) => {
      const d = st.decks[id];
      const ds = E.deckStats(st, d, at);
      let e = 0, dir = 0, live = false;
      if (s.drag && s.drag.id === id) { e = gravity(s.drag.raw); dir = s.drag.dir; live = true; }
      else if (s.anim && s.anim.id === id) { e = s.anim.val; dir = s.anim.dir; live = true; }
      else if (s.open && s.open.id === id) { e = Math.abs(s.open.d); dir = Math.sign(s.open.d); }
      if (e < 0.5) { e = 0; dir = 0; }
      const excess = Math.max(0, e - STEP_2);
      const second = e <= STEP_1 ? 0 : Math.min(65, e - STEP_1) + excess * 0.45;
      const progress = e / STEP_1;
      const sinkOp = Math.min(1, progress * 1.5).toFixed(3);
      const stop = Math.max(0, 100 - progress * 20).toFixed(1);
      const rm = s.removing && s.removing.id === id ? s.removing.kind : null;
      const tr = live ? 'none' : 'transform 260ms cubic-bezier(.2,.8,.2,1), width 260ms cubic-bezier(.2,.8,.2,1)';
      const meta = ds.total + ' cards · ' + (ds.fresh === ds.total ? 'new' : ds.slip ? ds.slip + ' slipping' : 'all fresh') + (d.reservoir.length ? ' · ' + d.reservoir.length + ' waiting' : '');
      const fan = [0, 1, 2, 3, 4].map((i) => 'right:' + (-10 + (4 - i) * 15) + 'px;bottom:' + (-40 + i * 8) + 'px;transform:rotate(' + (-16 + i * 3) + 'deg);background:' + (i < ds.steps ? ta.fanOn[i] : ta.fanOff) + ';');
      const wrapStyle = 'overflow:' + (rm ? 'hidden' : 'visible') + ';height:' + (rm === 'delete' ? 0 : 72) + 'px;margin-bottom:' + (rm === 'delete' ? 0 : 12) +
        'px;opacity:' + (rm ? 0 : 1) + ';transform:' + (rm === 'archive' ? 'translateX(-110%)' : 'none') + ';';
      return html`<div key=${id} class=${cx('deck-row', highlight === id && 'flash')} style=${wrapStyle}>
        <div class="act-layer right" style=${'width:' + (dir < 0 ? e.toFixed(1) : 0) + 'px;transition:' + tr}>
          <button class="act act-r" aria-label="Delete deck" tabindex=${dir < 0 ? 0 : -1} onClick=${() => this.remove(id, 'delete')} style=${'background:' + DELETE + ';z-index:1;justify-content:flex-start;width:' + (dir < 0 ? e.toFixed(1) : 0) + 'px;transition:' + tr}>
            <span class="act-ico" style="width:65px"><span style="width:20px;height:20px">${Ico.x()}</span></span>
          </button>
          <button class="act act-r" aria-label=${isArchive ? 'Restore deck' : 'Archive deck'} tabindex=${dir < 0 ? 0 : -1} onClick=${() => this.remove(id, 'archive')} style=${'background:' + PEACH + ';z-index:2;box-shadow:-3px 0 8px rgba(0,0,0,0.18);width:' + (dir < 0 ? second.toFixed(1) : 0) + 'px;transition:' + tr}>
            <span class="act-ico" style="width:65px"><span style=${'width:20px;height:22px;' + (isArchive ? 'transform:rotate(180deg)' : '')}>${Ico.archive()}</span></span>
          </button>
        </div>
        <div class="act-layer left" style=${'width:' + (dir > 0 ? e.toFixed(1) : 0) + 'px;transition:' + tr}>
          <button class="act act-l" aria-label="Move deck to another folder" tabindex=${dir > 0 ? 0 : -1} onClick=${() => { this.close(id, e); app.moveDeck(id); }} style=${'background:' + BLUE + ';z-index:1;justify-content:flex-end;width:' + (dir > 0 ? e.toFixed(1) : 0) + 'px;transition:' + tr}>
            <span class="act-ico" style="width:58px"><span style="width:24px;height:18px">${Ico.move()}</span></span>
          </button>
          <button class="act act-l" aria-label=${d.pinned ? 'Unpin deck' : 'Pin deck to the top'} tabindex=${dir > 0 ? 0 : -1} onClick=${() => { this.setState({ open: null, anim: null }); app.togglePin(id); }} style=${'background:' + GREEN + ';z-index:2;box-shadow:3px 0 8px rgba(0,0,0,0.18);width:' + (dir > 0 ? second.toFixed(1) : 0) + 'px;transition:' + tr}>
            <span class="act-ico" style="width:54px"><span style="width:22px;height:22px">${Ico.pin()}</span></span>
          </button>
        </div>
        <button type="button" class="deck-bar" draggable="false" aria-label=${d.name + ', ' + ds.total + ' cards. Swipe left to delete or archive, right to move or pin'}
          onDragStart=${(ev) => ev.preventDefault()} onPointerDown=${(ev) => this.down(ev, id)} onPointerMove=${(ev) => this.move(ev)} onPointerUp=${() => this.up()} onPointerCancel=${() => this.up()}
          onClick=${(ev) => {
            if (this.justDragged || (s.open && s.open.id === id)) { ev.preventDefault(); this.justDragged = false; return; }
            app.study(id);
          }}
          style=${'transform:translateX(' + (dir === 0 ? 0 : (dir * Math.max(0, e + GAP - MARGIN)).toFixed(1)) + 'px);transition:' + tr}>
          <span class="deck-name d">
            ${d.pinned && html`<span style="width:15px;height:15px;flex:none;color:${GREEN}">${Ico.pin()}</span>`}
            <span class="ell">${d.name}</span>
          </span>
          <span class="deck-meta">${meta}</span>
          ${fan.map((f, i) => html`<span key=${i} class="fan" style=${f}></span>`)}
        </button>
        <div aria-hidden="true" class="sink" style=${'left:0;background:linear-gradient(to left, var(--canvas-clear) 0%, var(--canvas) ' + stop + '%);opacity:' + (dir < 0 ? sinkOp : 0)}></div>
        <div aria-hidden="true" class="sink" style=${'right:0;background:linear-gradient(to right, var(--canvas-clear) 0%, var(--canvas) ' + stop + '%);opacity:' + (dir > 0 ? sinkOp : 0)}></div>
      </div>`;
    });

    return html`<div class="scr" id="screen-decks" data-screen="Decks">
      <header class=${cx('hdr', pushed && 'hide')}>
        <button class="ibtn" aria-label="Open folders" onClick=${() => app.open('drawer')}><span style="width:28px;height:36px">${Ico.logo()}</span></button>
        <div class="hdr-title d ell">${folder.name}</div>
        ${!empty && html`<button class="streak-pill" aria-label=${'Streak ' + streak + ' days, ' + folderStats.slip + ' cards slipping in this folder. Open today'} onClick=${() => app.go('today')}>
          ${Ico.flame()}<span>${streak}</span><span class="muted">· ${folderStats.slip} due</span>
        </button>`}
        <button class="ibtn" aria-label="Menu" onClick=${(ev) => app.menu('decks', ev)}><span style="width:8px;height:26px">${Ico.dots()}</span></button>
      </header>
      <div class=${cx('push', pushed && 'on')}>
        ${empty ? html`<${EmptyFolder} app=${app} folder=${folder} H=${this.props.H} reduced=${this.props.reduced} dark=${this.props.dark} />` : html`
          <main class="deck-list">${rows}</main>
          <div class="list-fade"></div>`}
        <${Nav} app=${app} current="home" />
      </div>
    </div>`;
  }
}

// ---------- Empty folder ----------
const MARKS = [{ x: 192, y: 76, tilt: 8, size: 22 }, { x: 207, y: 58, tilt: 12, size: 28 }, { x: 222, y: 42, tilt: 16, size: 34 }];
const STARTERS = [
  { id: 's-de-a1', mono: 'De', name: 'German · A1 Basics', bg: BLUE },
  { id: 's-py', mono: 'Py', name: 'Python · Syntax', bg: PEACH },
  { id: 's-es', mono: 'Es', name: 'Spanish · Basics', bg: null }
];
class BrainArt extends Component {
  componentDidMount() {
    if (this.props.reduced) return;
    const tick = () => {
      this.now = performance.now();
      this.forceUpdate();
      this.raf = requestAnimationFrame(tick);
    };
    this.raf = requestAnimationFrame(tick);
  }
  componentWillUnmount() {
    cancelAnimationFrame(this.raf);
  }
  render({ size }) {
    const now = this.now || 0;
    const breathe = 1 + 0.018 * Math.sin((now / 3200) * Math.PI * 2);
    return html`<svg width=${240 * size} height=${190 * size} viewBox="0 0 240 190" role="img" aria-label="A brain with question marks floating above it" style="filter:var(--art);overflow:visible">
      <g transform=${'translate(100 100) scale(' + breathe.toFixed(4) + ') translate(-100 -100)'}>
        <g transform="translate(-8 18)">
          <path d="M136 116 C138 134 141 148 147 160 C150 165 158 165 160 160 C155 148 153 134 155 118 Z" fill="var(--ink2)"/>
          <path d="M134 120 C142 108 170 104 184 114 C194 122 190 138 174 141 C158 144 142 138 134 128 Z" fill="var(--ink2)"/>
          <g fill="none" stroke="var(--canvas)" stroke-width="2.5" stroke-linecap="round" opacity="0.85">
            <path d="M142 120 C154 114 170 114 182 121"/><path d="M140 128 C154 123 170 124 184 130"/><path d="M146 135 C156 132 166 133 176 137"/>
          </g>
          <path d="M40 110 C22 96 20 62 42 50 C48 30 78 22 92 34 C104 18 134 18 144 32 C160 24 184 40 180 62 C196 74 190 104 170 108 C160 116 142 112 132 118 C118 132 84 134 70 122 C58 130 38 124 40 110 Z" fill="var(--ink)"/>
          <g fill="none" stroke="var(--canvas)" stroke-width="4" stroke-linecap="round" stroke-linejoin="round">
            <path d="M64 104 C84 96 106 98 130 90"/><path d="M114 26 C106 44 118 58 104 86"/><path d="M48 64 C58 56 70 61 77 52"/>
            <path d="M38 86 C50 79 62 86 76 77"/><path d="M84 34 C80 46 92 52 86 68"/><path d="M132 38 C140 52 152 46 160 58"/>
            <path d="M124 70 C138 63 150 73 166 66"/><path d="M168 82 C178 88 172 98 180 102"/><path d="M80 118 C94 110 110 118 126 109"/>
          </g>
          <path d="M52 52 C60 42 74 36 86 38" fill="none" stroke="var(--gloss)" stroke-width="5" stroke-linecap="round"/>
        </g>
      </g>
      ${MARKS.map((m, i) => {
        const a = (now / 4000) * Math.PI * 2 + i * 0.8;
        const tf = 'translate(' + (m.x + 3 * Math.sin(a)).toFixed(2) + ' ' + (m.y - 3 * Math.cos(a)).toFixed(2) + ') rotate(' + m.tilt + ')';
        return html`<text key=${i} x="0" y="0" text-anchor="middle" font-family="'Bernard MT Condensed','Noto Serif Display',Georgia,serif" font-size=${m.size} font-weight="800" fill=${RED} transform=${tf}>?</text>`;
      })}
    </svg>`;
  }
}

function EmptyFolder({ app, folder, H, reduced, dark }) {
  const size = H < 820 ? 0.72 : 1;
  return html`<div class="empty">
    <section class="empty-top" style=${'padding-top:' + (H < 820 ? 4 : 34) + 'px'}>
      <${BrainArt} size=${size} reduced=${reduced} />
      <h1 class="d" style="margin:18px 0 0;font-size:46px;line-height:1">Empty mind</h1>
      <p class="empty-copy">${folder.id === 'f-archive' ? 'Nothing archived. Swipe a deck left twice to archive it.' : 'Nothing to remember in this folder yet.'}</p>
      <button class="btn-ink d" style="margin-top:22px;width:100%;height:56px;font-size:24px" onClick=${() => app.go('shop')}>Look for something to remember</button>
      <button class="btn-soft" style="margin-top:10px;width:100%;height:50px" onClick=${() => app.create({ newDeck: true, folderId: folder.id })}>Create a deck</button>
    </section>
    <section aria-label="Start here" class="starters">
      <div class="eyebrow">Start here</div>
      <div class="starter-grid">
        ${STARTERS.map((s) => html`<button key=${s.id} class="starter" onClick=${() => app.open('preview', { shopId: s.id })}
            style=${'background:' + (s.bg || (dark ? '#F1F1F1' : '#333333')) + ';color:' + (s.bg ? '#333333' : dark ? '#333333' : '#F1F1F1')}>
          <span class="d" style="font-size:30px;line-height:1;text-align:center;padding-top:6px">${s.mono}</span>
          <span style="font-size:13px;font-weight:700;line-height:1.15;text-align:left">${s.name}</span>
        </button>`)}
      </div>
    </section>
  </div>`;
}
