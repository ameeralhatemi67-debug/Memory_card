// Shop (Shop.dc.html + ShopHold) and Deck preview (Preview.dc.html), wired to the library.
import { html, Component, Ico, Nav, Grip, cx, polar, clamp } from './ui.js';
import { SHOP, SHOP_CATS, POOLS } from './content.js';
import * as E from './engine.js';

const SHAPES = {
  squircle: polar((a) => 31 * Math.pow(Math.pow(Math.abs(Math.cos(a)), 4) + Math.pow(Math.abs(Math.sin(a)), 4), -0.25) + 2.2 * Math.sin(4 * a + 0.8), 96),
  scallop: polar((a) => 31 + 3.2 * Math.cos(8 * a), 96),
  burst: polar((a) => 29 + 5 * Math.cos(12 * a), 120),
  blob: polar((a) => 31 + 3.5 * Math.sin(3 * a) + 2 * Math.cos(5 * a + 1), 96)
};
const ACTIONS = [
  { id: 'pin', label: 'Pin to favourites', short: 'Pin', shape: 'scallop', tilt: 8, icon: 'pin' },
  { id: 'share', label: 'Share deck', short: 'Share', shape: 'squircle', tilt: -6, icon: 'share' },
  { id: 'similar', label: 'Find similar decks', short: 'Similar', shape: 'burst', tilt: 0, icon: 'search' },
  { id: 'save', label: 'Save to a folder', short: 'Save', shape: 'blob', tilt: -10, icon: 'save' }
];
const SORTS = [
  { value: 'popular', label: 'Popular', note: 'Our picks first' },
  { value: 'small', label: 'Fewest cards', note: 'Quick wins' },
  { value: 'large', label: 'Most cards', note: 'Go deep' },
  { value: 'az', label: 'A to Z' }
];
export const cardCount = (s) => POOLS[s.pool].rows.trim().split('\n').length;
const catDot = (cat) => (SHOP_CATS.find((c) => c.id === cat) || {}).dot;

function badgeSpots(h, H) {
  const cx0 = h.x + h.w / 2, cy0 = h.y + h.h / 2;
  const toRight = cx0 < 195;
  const angles = toRight ? [-55, -20, 15, 50] : [235, 200, 165, 130];
  const rx = h.w / 2 + 52, ry = h.h / 2 + 44;
  return angles.map((a) => {
    const r = (a * Math.PI) / 180;
    return { x: Math.round(clamp(cx0 + Math.cos(r) * rx - 38, 6, 390 - 82)), y: Math.round(clamp(cy0 + Math.sin(r) * ry - 36, 80, H - 112 - 98)) };
  });
}

function MiniStack({ mono, dot, hold }) {
  return html`<span aria-hidden="true" class="mini-stack">
    <span class="ms-b2" style=${hold ? 'background:#9D9D9D' : ''}></span>
    <span class="ms-b1" style=${hold ? 'background:#747474' : ''}></span>
    <span class="ms-tab" style=${'background:' + dot}></span>
    <span class="ms-front d" style=${hold ? 'background:#333333;color:#F1F1F1' : ''}>${mono}</span>
  </span>`;
}

export class Shop extends Component {
  constructor(props) {
    super(props);
    this.state = { cat: 'all', query: '', hold: null, sort: 'popular' };
    this.timer = null;
    this.held = false;
    this.start = null;
  }
  componentDidMount() {
    if (this.props.demoHold) setTimeout(() => this.demoHold(), 350);
  }
  componentWillUnmount() {
    clearTimeout(this.timer);
    cancelAnimationFrame(this.raf);
  }
  demoHold() {
    const el = this.root && this.root.querySelector('[data-shop-id="s-de-a2"]');
    if (el) this.openHoldFor(el, 's-de-a2');
  }
  openHoldFor(el, id) {
    const root = el.closest('[data-shop-root]');
    if (!root) return;
    const r = el.getBoundingClientRect(), rr = root.getBoundingClientRect();
    const k = rr.width / 390 || 1;
    this.holdT = performance.now();
    cancelAnimationFrame(this.raf);
    const tick = () => {
      this.now = performance.now();
      this.forceUpdate();
      if (this.state.hold) this.raf = requestAnimationFrame(tick);
    };
    this.props.app.fx.buzz(14);
    this.props.app.fx.pop();
    this.setState({ hold: { id, x: (r.left - rr.left) / k, y: (r.top - rr.top) / k, w: r.width / k, h: r.height / k } }, () => { this.raf = requestAnimationFrame(tick); });
  }
  pressStart(e, id) {
    clearTimeout(this.timer);
    this.held = false;
    this.start = { x: e.clientX, y: e.clientY };
    const el = e.currentTarget;
    this.timer = setTimeout(() => {
      this.held = true;
      this.openHoldFor(el, id);
    }, 430);
  }
  act(a, s) {
    const { app, st } = this.props;
    this.setState({ hold: null });
    if (a.id === 'pin') {
      const on = st.shopPins.includes(s.id);
      app.mut((x) => { x.shopPins = on ? x.shopPins.filter((y) => y !== s.id) : [s.id].concat(x.shopPins); });
      app.toast(on ? 'Removed from favourites' : 'Pinned to favourites');
    } else if (a.id === 'share') {
      try { navigator.clipboard.writeText(s.name + ' — a Memory Card deck, ' + cardCount(s) + ' cards').catch(() => {}); } catch (e) {}
      app.toast('Share link copied');
    } else if (a.id === 'similar') {
      this.setState({ cat: s.cat, query: '' });
      app.toast('Showing similar decks');
    } else {
      app.pickFolder({ title: 'Save to a folder', subtitle: s.name + ' · ' + cardCount(s) + ' cards', onPick: (fid) => app.addShopDeck(s.id, fid) });
    }
  }
  sorted(list) {
    const by = this.state.sort;
    const a = list.slice();
    if (by === 'small') a.sort((x, y) => cardCount(x) - cardCount(y));
    if (by === 'large') a.sort((x, y) => cardCount(y) - cardCount(x));
    if (by === 'az') a.sort((x, y) => x.name.localeCompare(y.name));
    return a;
  }

  render() {
    const { app, st, H, pushed } = this.props;
    const s = this.state;
    const q = s.query.trim().toLowerCase();
    const added = (sd) => st.shopAdded[sd.id] && st.decks[st.shopAdded[sd.id]];
    const tile = (sd) => html`<button key=${sd.id} type="button" class="shop-tile" data-shop-id=${sd.id} draggable="false" aria-label=${sd.name + ', ' + cardCount(sd) + ' cards. Press and hold for quick actions'}
        onDragStart=${(e) => e.preventDefault()} onContextMenu=${(e) => e.preventDefault()}
        onPointerDown=${(e) => this.pressStart(e, sd.id)}
        onPointerMove=${(e) => { if (this.start && Math.hypot(e.clientX - this.start.x, e.clientY - this.start.y) > 8) clearTimeout(this.timer); }}
        onPointerUp=${() => clearTimeout(this.timer)} onPointerLeave=${() => clearTimeout(this.timer)} onPointerCancel=${() => clearTimeout(this.timer)}
        onClick=${(e) => { if (this.held) { e.preventDefault(); this.held = false; return; } app.open('preview', { shopId: sd.id }); }}>
      <${MiniStack} mono=${sd.mono} dot=${catDot(sd.cat)} />
      <span class="tile-name d">${st.shopPins.includes(sd.id) && html`<span style="display:inline-block;width:13px;height:13px;margin-right:4px;vertical-align:1px">${Ico.pin()}</span>`}${sd.name}</span>
      <span class="tile-meta">${cardCount(sd)} cards · ${sd.level}${added(sd) ? ' · added' : ''}</span>
    </button>`;
    let sections = SHOP_CATS.filter((c) => s.cat === 'all' || s.cat === c.id).map((c) => {
      const decks = this.sorted(SHOP.filter((d) => d.cat === c.id && (!q || d.name.toLowerCase().includes(q))));
      return { name: c.name, decks };
    }).filter((x) => x.decks.length);
    const pins = SHOP.filter((d) => st.shopPins.includes(d.id));
    if (s.cat === 'all' && !q && pins.length) sections = [{ name: 'Favourites', decks: pins }].concat(sections);
    const hero = SHOP[0];
    const cats = [{ id: 'all', name: 'All', dot: null }].concat(SHOP_CATS);
    const h = s.hold;
    const hs = h && SHOP.find((x) => x.id === h.id);
    const spots = h ? badgeSpots(h, H) : [];
    const since = (this.now || performance.now()) - (this.holdT || 0);
    return html`<div class="scr" id="screen-shop" data-screen="Shop" data-shop-root="1" ref=${(el) => (this.root = el)}>
      <header class=${cx('hdr', pushed && 'hide')}>
        <button class="ibtn" aria-label="Open folders" onClick=${() => app.open('drawer')}><span style="width:28px;height:36px">${Ico.logo()}</span></button>
        <div class="hdr-title d" style="font-size:26px">Shop</div>
        <button class="ibtn" aria-label="Menu" onClick=${(ev) => app.menu('shop', ev)}><span style="width:8px;height:26px">${Ico.dots()}</span></button>
      </header>
      <div class=${cx('push', pushed && 'on')}>
        <div class="shop-search">
          <label style="flex:1;position:relative;display:block" for="shop-q">
            <span class="sr">Search decks</span>
            <span aria-hidden="true" style="position:absolute;left:14px;top:13px;width:24px;height:24px;color:var(--muted)">${Ico.search()}</span>
            <input id="shop-q" class="search" value=${s.query} placeholder="Search decks" onInput=${(e) => this.setState({ query: e.target.value })} />
          </label>
          <button class="filter-btn" aria-label="Sort and filter" onClick=${() => app.openSub('choice', { title: 'Sort decks', value: s.sort, options: SORTS, onPick: (v) => this.setState({ sort: v }) })}><span style="width:24px;height:24px">${Ico.filter()}</span></button>
        </div>
        <div role="tablist" aria-label="Categories" class="cats">
          ${cats.map((c) => {
            const on = s.cat === c.id;
            return html`<button key=${c.id} role="tab" aria-selected=${on ? 'true' : 'false'} class=${cx('cat', on && 'on')} onClick=${() => this.setState({ cat: c.id })}>
              <span aria-hidden="true" class="dot" style=${'background:' + (c.dot || (on ? 'var(--canvas)' : 'var(--ink)'))}></span>${c.name}</button>`;
          })}
        </div>
        <div class="shop-scroll">
          ${s.cat === 'all' && !q && html`<button class="hero" onClick=${() => app.open('preview', { shopId: hero.id })}>
            <div style="position:absolute;left:18px;top:18px;width:180px;text-align:left">
              <div class="eyebrow on-ink">Start here</div>
              <div class="d" style="margin-top:6px;font-size:24px;line-height:1">${hero.name}</div>
              <div style="margin-top:4px;font-size:14px;font-weight:600;color:var(--muted-on-ink)">${cardCount(hero)} cards · with audio</div>
              <span class="hero-cta">${added(hero) ? 'Added · study it' : 'Preview'}</span>
            </div>
            <span aria-hidden="true" class="hero-b2"></span><span aria-hidden="true" class="hero-b1"></span>
            <span aria-hidden="true" class="hero-tab"></span><span aria-hidden="true" class="hero-front d">${hero.mono}</span>
          </button>`}
          ${sections.map((sec) => html`<section key=${sec.name} aria-label=${sec.name} style="margin-top:18px">
            <div class="sec-head"><h2 class="d">${sec.name}</h2><span>${sec.decks.length} ${sec.decks.length === 1 ? 'deck' : 'decks'}</span></div>
            <div class="tile-grid">${sec.decks.map(tile)}</div>
          </section>`)}
          ${!sections.length && html`<p style="margin:40px 0 0;text-align:center;font-size:17px;font-weight:600;color:var(--muted)">No decks match “${s.query}”.</p>`}
          <p style="margin:20px 0 0;font-size:14px;font-weight:500;color:var(--muted);text-align:center">Press and hold a deck for quick actions</p>
        </div>
        <div aria-hidden="true" class="shop-fade"></div>
        <${Nav} app=${app} current="shop" />
      </div>
      ${h && hs && html`<div role="dialog" aria-modal="true" aria-label=${'Quick actions for ' + hs.name} style="position:absolute;inset:0;z-index:30">
        <button aria-label="Close quick actions" class="hold-dim" onClick=${() => this.setState({ hold: null })}></button>
        <div aria-hidden="true" class="hold-tile" style=${'left:' + Math.round(h.x) + 'px;top:' + Math.round(h.y) + 'px;width:' + Math.round(h.w) + 'px;height:' + Math.round(h.h) + 'px'}>
          <${MiniStack} mono=${hs.mono} dot=${catDot(hs.cat)} hold=${true} />
          <span class="tile-name d">${hs.name}</span>
          <span class="tile-meta" style="color:#555">${cardCount(hs)} cards · ${hs.level}</span>
        </div>
        ${ACTIONS.map((a, i) => {
          const u = Math.max(0, Math.min(1, (since - i * 45) / 240));
          const sc = u < 0.7 ? 0.4 + 0.68 * (u / 0.7) : 1.08 - 0.08 * ((u - 0.7) / 0.3);
          const dy = this.props.reduced ? 0 : -2 * (1 - Math.cos((since / 2600) * Math.PI * 2 + i * 0.8));
          const label = a.id === 'pin' && st.shopPins.includes(hs.id) ? 'Unpin' : a.short;
          return html`<button key=${a.id} class="badge-btn" aria-label=${a.id === 'pin' && st.shopPins.includes(hs.id) ? 'Remove from favourites' : a.label} onClick=${() => this.act(a, hs)}
            style=${'left:' + spots[i].x + 'px;top:' + spots[i].y + 'px;transform:translateY(' + dy.toFixed(2) + 'px) scale(' + sc.toFixed(3) + ');opacity:' + Math.min(1, u * 2).toFixed(3)}>
            <span style="position:relative;display:block;width:72px;height:72px">
              <svg width="72" height="72" viewBox="-40 -40 80 80" aria-hidden="true" style=${'position:absolute;inset:0;transform:rotate(' + a.tilt + 'deg)'}><path d=${SHAPES[a.shape]} fill="#F1F1F1" stroke="#F1F1F1" stroke-width="3" stroke-linejoin="round"/></svg>
              <span style="position:absolute;left:22px;top:22px;width:28px;height:28px;color:#333333">${Ico[a.icon]()}</span>
            </span>
            <span style="font-size:14px;font-weight:700;color:#F1F1F1">${label}</span>
          </button>`;
        })}
      </div>`}
    </div>`;
  }
}

// ---------- Deck preview sheet ----------
export class Preview extends Component {
  constructor(props) {
    super(props);
    const { st, params } = props;
    const sd = SHOP.find((x) => x.id === params.shopId);
    const home = st.folders.find((f) => f.name === sd.home && f.id !== 'f-archive');
    const cur = st.folders.find((f) => f.id === st.currentFolder && f.id !== 'f-archive');
    this.state = { flipped: false, folder: (home || cur || st.folders[0]).id };
  }
  render() {
    const { app, st, params, closing } = this.props;
    const sd = SHOP.find((x) => x.id === params.shopId);
    const pool = POOLS[sd.pool];
    const sample = E.parsePool(sd.pool)[0];
    const n = cardCount(sd);
    const f = this.state.flipped;
    const addedId = st.shopAdded[sd.id] && st.decks[st.shopAdded[sd.id]] ? st.shopAdded[sd.id] : null;
    const addedFolder = addedId && E.folderOf(st, addedId);
    const home = st.folders.find((x) => x.name === sd.home && x.id !== 'f-archive');
    const ids = [];
    const push = (fo) => { if (fo && fo.id !== 'f-archive' && !ids.includes(fo.id)) ids.push(fo.id); };
    push(home);
    push(st.folders.find((x) => x.id === st.currentFolder));
    st.folders.forEach((x) => { if (ids.length < 3) push(x); });
    const newName = home ? sd.name.split(' · ')[0] : sd.home;
    const isNew = this.state.folder === '__new';
    const target = st.folders.find((x) => x.id === this.state.folder);
    const add = () => {
      let fid = this.state.folder;
      if (isNew) app.mut((s) => { fid = 'f' + E.uid(''); s.folders.splice(Math.max(0, s.folders.length - 1), 0, { id: fid, name: newName, deckIds: [] }); });
      app.close();
      app.addShopDeck(sd.id, fid);
    };
    return html`<div class=${cx('sheet-wrap', closing && 'closing')}>
      <div class="sheet-dim" onClick=${() => app.close()}></div>
      <section class="sheet" role="dialog" aria-label=${sd.name} style="top:64px">
        <${Grip} />
        <div class="sheet-body" style="gap:0">
          <div style="position:relative;height:196px;margin-top:14px;flex:none">
            <div aria-hidden="true" class="pv-back2"></div>
            <div aria-hidden="true" class="pv-back1"></div>
            <button class="pv-card" onClick=${() => this.setState({ flipped: !f })} aria-label=${f ? 'Answer: ' + sample.b + '. Tap to flip back' : 'Sample card: ' + sample.f + '. Tap to flip'}
              style=${f ? 'background:#FFC680;color:#333333' : ''}>
              <span style="font-size:12px;font-weight:700;letter-spacing:1.2px;text-transform:uppercase;opacity:.75">${f ? 'Answer' : sample.l || pool.tag}</span>
              <span class=${pool.kind === 'code' ? 'code' : 'd'} style=${'font-size:' + (pool.kind === 'code' ? 20 : sample.f.length > 14 ? 26 : 34) + 'px;line-height:1.05;padding:0 12px'} dir="auto">${f ? sample.b : sample.f}</span>
            </button>
            <div style="position:absolute;left:0;right:0;bottom:0;text-align:center;font-size:13px;font-weight:600;color:var(--muted)">Sample card · tap to flip</div>
          </div>
          <h1 class="d" style="margin:12px 0 0;font-size:38px;line-height:1">${sd.name}</h1>
          <div style="margin-top:6px;font-size:15px;font-weight:600;color:var(--muted)">Memory Card Originals · Free</div>
          <div class="tiles" style="margin:14px 0 0;gap:8px">
            <div class="tile sm"><div class="d" style="font-size:26px;line-height:1">${n}</div><div class="tile-label">cards</div></div>
            <div class="tile sm"><div class="d" style="font-size:26px;line-height:1">${sd.level}</div><div class="tile-label">level</div></div>
            <div class="tile sm"><div class="d" style="font-size:26px;line-height:1">${pool.lang ? 'Audio' : 'Text'}</div><div class="tile-label">${pool.lang ? 'every card' : 'no audio'}</div></div>
          </div>
          <p style="margin:12px 0 0;font-size:16px;font-weight:500;line-height:1.4">${sd.desc}</p>
          ${addedId ? html`<p style="margin:14px 0 0;font-size:15px;font-weight:600;color:var(--muted)">Already in your ${addedFolder ? addedFolder.name : ''} folder.</p>` : html`
            <div class="eyebrow" style="margin-top:14px">Add to folder</div>
            <div role="radiogroup" aria-label="Folder" style="margin-top:8px;display:flex;gap:8px;flex-wrap:wrap">
              ${ids.map((id) => {
                const fo = st.folders.find((x) => x.id === id);
                const on = this.state.folder === id;
                return html`<button key=${id} role="radio" aria-checked=${on ? 'true' : 'false'} class=${cx('cat', on && 'on')} style="height:36px" onClick=${() => this.setState({ folder: id })}>${fo.name}</button>`;
              })}
              <button role="radio" aria-checked=${isNew ? 'true' : 'false'} class=${cx('cat', isNew && 'on')} style="height:36px" onClick=${() => this.setState({ folder: '__new' })}>+ New folder</button>
            </div>`}
          <div style="flex:1;min-height:12px"></div>
          ${addedId
            ? html`<button class="btn-ink d" style="height:58px;font-size:25px;flex:none" onClick=${() => { app.close(); app.study(addedId); }}>Study it now</button>`
            : html`<button class="btn-ink d" style="height:58px;font-size:25px;flex:none" onClick=${add}>Add ${n} cards to ${isNew ? 'a new folder' : target ? target.name : 'a folder'}</button>`}
        </div>
      </section>
    </div>`;
  }
}
