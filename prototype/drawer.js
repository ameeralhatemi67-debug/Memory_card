// Folder drawer — port of Drawer.dc.html (parametric folder silhouettes, inverse luminance, deck pills, hold-to-reorder, delete mode).
import { html, Component, Ico, cx, BLUE, PEACH, RED, DELETE } from './ui.js';

const Z3 = [[BLUE, PEACH, RED], [PEACH, RED, BLUE], [RED, BLUE, PEACH]];
const W = 340, FH = 175, HEAD = 45, SPAN = 36, R = 28, ALPHA = 0.45, TOP = 84;
function tabWidth(name) {
  return Math.min(230, Math.max(92, name.length * 11.5 + 44));
}
function silhouette(tw) {
  const p1 = tw + ALPHA * SPAN, p2 = tw + (1 - ALPHA) * SPAN, p3 = tw + SPAN;
  return 'M' + R + ' 0 L' + tw + ' 0 C' + p1 + ' 0 ' + p2 + ' ' + HEAD + ' ' + p3 + ' ' + HEAD +
    ' L' + (W - R) + ' ' + HEAD + ' A' + R + ' ' + R + ' 0 0 1 ' + W + ' ' + (HEAD + R) +
    ' L' + W + ' ' + (FH - R) + ' A' + R + ' ' + R + ' 0 0 1 ' + (W - R) + ' ' + FH +
    ' L' + R + ' ' + FH + ' A' + R + ' ' + R + ' 0 0 1 0 ' + (FH - R) + ' L0 ' + R + ' A' + R + ' ' + R + ' 0 0 1 ' + R + ' 0 Z';
}
function gray(l) {
  const v = Math.round(Math.max(0, Math.min(100, l)) * 2.55).toString(16).padStart(2, '0');
  return '#' + v + v + v;
}
// Inverted luminance: light mode climbs 5% lighter per folder, dark mode 5% darker.
function shade(i, dark) {
  const start = dark ? Math.max(10, 95 - i * 5) : Math.min(90, 20 + i * 5);
  const end = dark ? Math.max(5, start - 5) : Math.max(10, start - 5);
  const text = dark ? (start >= 65 ? '#1E1E1E' : '#FFFFFF') : (start < 45 ? '#FFFFFF' : '#1E1E1E');
  return { c1: gray(start), c2: gray(end), text, meta: text === '#FFFFFF' ? 'rgba(255,255,255,0.72)' : 'rgba(30,30,30,0.72)' };
}

// text_Mockup keyframes replayed by a JS clock. Rows: [t 0..1, values...], smoothstep between rows.
const PILL_UP = { ms: 450, rows: [[0, 90, 0], [0.6, -10, 1], [0.85, 2, 1], [1, 0, 1]] };
const PILL_DOWN = { ms: 450, rows: [[0, 0, 1], [0.3, -4, 1], [0.7, 65, 0.7], [1, 110, 0]] };
const PILL_JUMP = { ms: 400, rows: [[0, 0, 1], [0.4, -12, 1], [0.75, -2, 1], [1, 0, 1]] };
const FOLDER_IN = { ms: 600, rows: [[0, -381, -5, 0], [0.6, 14, 1, 1], [0.82, -3, -0.3, 1], [1, 0, 0, 1]] };
const BOUNCE = { ms: 450, rows: [[0, 0, 1], [0.35, -9, 1.012], [0.7, 2, 0.996], [1, 0, 1]] };
const EXCITE = { ms: 600, rows: [[0, 0, 1], [0.3, -7, 1.01], [0.6, 2, 1], [1, 0, 1]] };
const RECOIL = { ms: 400, rows: [[0, 0, 0, 1, 1], [0.35, -6, -4, 1.1, 0.9], [1, 0, 60, 0.4, 0]] };
function sample(anim, elapsed) {
  const rows = anim.rows;
  const u = elapsed / anim.ms;
  if (u <= 0) return rows[0].slice(1);
  if (u >= 1) return rows[rows.length - 1].slice(1);
  let i = 1;
  while (rows[i][0] < u) i++;
  const a = rows[i - 1], b = rows[i];
  let k = (u - a[0]) / (b[0] - a[0]);
  k = k * k * (3 - 2 * k);
  return a.slice(1).map((v, j) => v + (b[j + 1] - v) * k);
}

export class Drawer extends Component {
  constructor(props) {
    super(props);
    this.state = { exit: null, floating: null, fear: false, deleting: null, hoverPill: null };
    this.ptr = null;
    this.timer = null;
    this.suppress = false;
    this.pressed = null;
    this.pillAnim = {};
    this.folderAnim = {};
    this.exciteT = -1e9;
    this.t0 = performance.now();
    this.now = this.t0;
  }
  componentDidMount() {
    const tick = () => {
      this.now = performance.now();
      this.forceUpdate();
      this.raf = requestAnimationFrame(tick);
    };
    this.raf = requestAnimationFrame(tick);
    if (this.props.excite) this.exciteT = performance.now();
  }
  componentWillUnmount() {
    cancelAnimationFrame(this.raf);
    clearTimeout(this.timer);
    clearTimeout(this.exitTimer);
  }
  excite() {
    this.exciteT = performance.now();
  }

  select(id) {
    const { app, st } = this.props;
    const now = performance.now();
    this.folderAnim[id] = { anim: BOUNCE, t: now };
    app.fx.click();
    const recent = st.recentFolders.filter((x) => st.folders.some((f) => f.id === x));
    if (recent[0] === id) {
      this.pillAnim[id] = { anim: PILL_JUMP, t: now };
      setTimeout(() => app.openFolder(id), 260);
      return;
    }
    const next = [id].concat(recent.filter((x) => x !== id));
    const dropped = next.length > 3 ? next.pop() : null;
    this.pillAnim[id] = { anim: PILL_UP, t: now };
    if (dropped) this.pillAnim[dropped] = { anim: PILL_DOWN, t: now };
    app.mut((s) => { s.recentFolders = next; });
    this.setState({ exit: dropped });
    clearTimeout(this.exitTimer);
    this.exitTimer = setTimeout(() => this.setState({ exit: null }), 620);
  }
  down(e, id) {
    if (this.state.deleting) return;
    clearTimeout(this.timer);
    const el = e.currentTarget;
    this.pressed = id;
    this.ptr = { id, y0: e.clientY, el, pid: e.pointerId };
    if (this.state.fear) return;
    this.timer = setTimeout(() => {
      try { el.setPointerCapture(this.ptr.pid); } catch (err) {}
      this.props.app.fx.buzz(12);
      this.setState({ floating: id });
    }, 350);
  }
  move(e) {
    const p = this.ptr;
    if (!p) return;
    if (!this.state.floating) {
      if (Math.abs(e.clientY - p.y0) > 8) { clearTimeout(this.timer); this.pressed = null; }
      return;
    }
    const root = p.el.closest('[data-drawer-root]');
    if (!root) return;
    const rr = root.getBoundingClientRect();
    const k = rr.width / 390 || 1;
    const y = (e.clientY - rr.top) / k - 64 - TOP;
    const { st, app } = this.props;
    const step = this.step();
    const from = st.folders.findIndex((f) => f.id === this.state.floating);
    const to = Math.max(0, Math.min(st.folders.length - 1, Math.floor((y + 20) / step)));
    if (from >= 0 && to !== from) {
      app.mut((s) => {
        const item = s.folders.splice(from, 1)[0];
        s.folders.splice(to, 0, item);
      });
      app.fx.click();
    }
  }
  up() {
    clearTimeout(this.timer);
    this.ptr = null;
    this.pressed = null;
    if (this.state.floating) {
      this.suppress = true;
      this.setState({ floating: null });
      this.props.app.toast('New order saved');
    }
  }
  click(id) {
    if (this.suppress) { this.suppress = false; return; }
    if (this.state.fear) {
      this.folderAnim[id] = { anim: RECOIL, t: performance.now() };
      this.setState({ deleting: id });
      this.props.app.fx.thud();
      setTimeout(() => {
        this.setState({ deleting: null });
        this.props.app.deleteFolder(id);
      }, 420);
      return;
    }
    this.select(id);
  }
  step() {
    const n = this.props.st.folders.length;
    return n > 1 ? Math.min(65, Math.max(40, Math.floor((this.props.H - 308) / (n - 1)))) : 65;
  }

  folderMotion(f, i, now) {
    const s = this.state;
    const reduced = this.props.reduced;
    let x = 0, y = 0, rot = 0, sc = 1, op = 1;
    const fa = this.folderAnim[f.id];
    const sinceOpen = now - this.t0;
    if (s.deleting === f.id && fa && fa.anim === RECOIL) {
      [x, y, sc, op] = sample(RECOIL, now - fa.t);
    } else if (s.floating === f.id) {
      const w = (1 - Math.cos((now / 1700) * Math.PI * 2)) / 2;
      sc = 1 + 0.03 * w;
      y = -6 - 3 * w;
    } else if (s.fear && !reduced) {
      const ph = (now / 350) * Math.PI + i * 0.9;
      x = 2 * Math.sin(ph);
      y = Math.sin(ph * 1.3 + 1);
      rot = 2.6 * Math.sin(ph + 0.4) - 0.6;
    } else if (now - this.exciteT < EXCITE.ms + i * 35) {
      [y, sc] = sample(EXCITE, now - this.exciteT - i * 35);
    } else if (fa && fa.anim === BOUNCE && now - fa.t < BOUNCE.ms) {
      [y, sc] = sample(BOUNCE, now - fa.t);
    } else if (!reduced && sinceOpen < FOLDER_IN.ms + i * 55) {
      [x, rot, op] = sample(FOLDER_IN, sinceOpen - i * 55);
    }
    if (this.pressed === f.id && !s.floating && !s.fear) sc *= 0.985;
    return { tf: 'translate(' + x.toFixed(1) + 'px, ' + y.toFixed(1) + 'px) rotate(' + rot.toFixed(2) + 'deg) scale(' + sc.toFixed(4) + ')', op: op.toFixed(3) };
  }
  pillMotion(f, i, k, now) {
    const s = this.state;
    const pa = this.pillAnim[f.id];
    const sinceOpen = now - this.t0;
    let y = 0, op = 1;
    if (pa && now - pa.t < pa.anim.ms + 120) {
      [y, op] = sample(pa.anim, now - pa.t - k * 40);
    } else if (!this.props.reduced && sinceOpen < 360 + i * 55 + k * 45 + PILL_UP.ms) {
      [y, op] = sample(PILL_UP, sinceOpen - (360 + i * 55 + k * 45));
    } else if (!s.fear && !s.floating && !this.props.reduced) {
      y = -2.5 * (1 - Math.cos((now / 2800) * Math.PI * 2 + i * 0.95 + k * 0.6));
    }
    if (s.hoverPill === f.id + ':' + k) y -= 10;
    return { y: y.toFixed(1), op: op.toFixed(3) };
  }

  render() {
    const { app, st, dark, ta, closing, H } = this.props;
    const s = this.state;
    const now = this.now;
    const step = this.step();
    const recent = st.recentFolders;
    const folders = st.folders.map((f, i) => {
      const tw = tabWidth(f.name);
      const sh = shade(i, dark);
      const m = this.folderMotion(f, i, now);
      const decks = f.deckIds.map((id) => st.decks[id]).filter(Boolean).sort((a, b) => (b.lastStudied || 0) - (a.lastStudied || 0)).slice(0, 3);
      const showPills = (recent.includes(f.id) || s.exit === f.id) && decks.length > 0;
      const isOpen = !s.fear && recent[0] === f.id;
      const count = f.deckIds.length + (f.deckIds.length === 1 ? ' deck' : ' decks');
      return html`<div key=${f.id} class="folder" onPointerDown=${(e) => this.down(e, f.id)} onClick=${() => this.click(f.id)} onContextMenu=${(e) => e.preventDefault()}
        style=${'top:' + (TOP + i * step) + 'px;z-index:' + (s.floating === f.id ? 100 : i + 1) + ';filter:' + (s.floating === f.id ? 'drop-shadow(0 22px 34px rgba(0,0,0,0.5))' : 'drop-shadow(0 6px 12px rgba(0,0,0,' + ta.folderShadow + '))') + ';transform:' + m.tf + ';opacity:' + m.op}>
        ${showPills && decks.map((d, k) => {
          const pm = this.pillMotion(f, i, k, now);
          const key = f.id + ':' + k;
          return html`<button key=${key} class="pill" aria-label=${'Study ' + d.name} onPointerDown=${(e) => e.stopPropagation()}
            onClick=${(e) => { e.stopPropagation(); app.close(); app.study(d.id); }}
            onPointerEnter=${() => this.setState({ hoverPill: key })} onPointerLeave=${() => this.setState({ hoverPill: null })}
            style=${'left:' + (tw + SPAN - 16 + k * 53) + 'px;z-index:' + (k + 1) + ';background:' + Z3[i % 3][k] + ';transform:translateY(' + pm.y + 'px);opacity:' + pm.op}></button>`;
        })}
        <svg aria-hidden="true" width="340" height="175" viewBox="0 0 340 175" style="position:absolute;left:0;top:0;z-index:5;pointer-events:none">
          <defs><linearGradient id=${'fg' + (dark ? 'd' : 'l') + f.id} x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color=${sh.c1}/><stop offset="1" stop-color=${sh.c2}/></linearGradient></defs>
          <path d=${silhouette(tw)} fill=${'url(#fg' + (dark ? 'd' : 'l') + f.id + ')'} style="pointer-events:auto;cursor:pointer"/>
        </svg>
        <div class="folder-name d" style=${'width:' + tw + 'px;color:' + sh.text}>${f.name}</div>
        ${isOpen && html`<button class="folder-open" style=${'color:' + sh.text} onPointerDown=${(e) => e.stopPropagation()} onClick=${(e) => { e.stopPropagation(); app.openFolder(f.id); }}>Open ${count} <span aria-hidden="true">›</span></button>`}
        ${!s.fear && !isOpen && html`<span aria-hidden="true" class="folder-count" style=${'color:' + sh.meta}>${count}</span>`}
        ${s.fear && html`<span aria-hidden="true" class="fear-x"><span style="width:11px;height:11px">${Ico.x()}</span></span>`}
      </div>`;
    });
    return html`<div class=${cx('drawer-wrap', closing && 'closing')} data-drawer-root="1">
      <div class="drawer-dim" onClick=${() => app.close()}></div>
      <button class="drawer-close" aria-label="Close folders" onClick=${() => app.close()}><span style="width:28px;height:36px">${Ico.logo()}</span></button>
      <nav class="drawer-panel" aria-label="Folders" onPointerMove=${(e) => this.move(e)} onPointerUp=${() => this.up()} onPointerCancel=${() => this.up()} onPointerLeave=${() => this.up()} style=${'height:' + (H - 64) + 'px'}>
        <button class="drawer-gear" aria-label="Settings" onClick=${() => { app.close(); app.go('settings'); }}><span style="width:30px;height:34px">${Ico.gear()}</span></button>
        ${folders}
        ${st.folders.length === 0 && html`<div style="position:absolute;left:24px;right:24px;top:160px;text-align:center">
          <div class="d" style="font-size:40px">Empty mind</div>
          <div style="margin-top:8px;font-size:16px;font-weight:500;color:var(--muted)">Make a folder to start.</div>
        </div>`}
        <div aria-hidden="true" class="drawer-fade"></div>
        <button class="fear-btn" aria-pressed=${s.fear ? 'true' : 'false'} onClick=${() => this.setState({ fear: !s.fear })} style=${'background:' + (s.fear ? DELETE : 'var(--soft)') + ';color:' + (s.fear ? '#333333' : 'var(--ink)')}>
          <span style="width:13px;height:13px">${Ico.x()}</span>${s.fear ? 'Done' : 'Delete'}
        </button>
        <button class="new-folder" aria-label="New folder" onClick=${() => { this.setState({ fear: false }); this.excite(); app.newFolder(); }}>${Ico.newFolder()}</button>
      </nav>
    </div>`;
  }
}
