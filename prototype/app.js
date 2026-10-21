// Memory Card prototype — app root: routing, overlays, actions, theme, the phone frame and the Lab panel.
import { html, render, Component, Ico, TA, fx, cx, Seg } from './ui.js';
import * as E from './engine.js';
import { Decks } from './decks.js';
import { Study, Today } from './study.js';
import { Drawer } from './drawer.js';
import { Editor, FolderPicker, Rename, Choice, Menu } from './create.js';
import { Shop, Preview } from './shop.js';
import { Profile, Settings } from './you.js';

const NAV_ROUTES = ['decks', 'study', 'shop'];
const SCREEN_NAMES = { decks: 'Decks', study: 'Study', today: 'Today', shop: 'Shop', profile: 'Profile', settings: 'Settings' };
const OVERLAY_NAMES = { drawer: 'Folder drawer', editor: 'Create card', preview: 'Deck preview' };

function capability(name) {
  try {
    if (window.claude && typeof window.claude.use === 'function') return window.claude.use(name).catch(() => null);
  } catch (e) {}
  return Promise.resolve(null);
}
function systemDark() {
  const a = document.documentElement.getAttribute('data-theme');
  if (a === 'dark') return true;
  if (a === 'light') return false;
  return !!(window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches);
}
function systemReduced() {
  return !!(window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches);
}
const fmtTime = (ts) => new Date(ts).toLocaleString([], { weekday: 'short', day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' });

class App extends Component {
  constructor() {
    super();
    this.st = E.load() || E.seedStore(Date.now());
    E.ensureToday(this.st);
    E.save(this.st);
    fx.on = this.st.settings.sounds;
    fx.haptic = this.st.settings.haptics;
    this.caps = {};
    this.studyRef = null;
    this.state = { route: { name: 'decks', params: {} }, hist: [], ov: null, sub: null, toast: null, sw: window.innerWidth, sh: window.innerHeight, lab: false, notesOk: null, resetAsk: false, v: 0 };
    this.app = this.makeApi();
  }
  componentDidMount() {
    this.ro = new ResizeObserver(() => this.measure());
    if (this.stage) this.ro.observe(this.stage);
    window.addEventListener('resize', () => this.measure());
    this.measure();
    const mq = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)');
    if (mq && mq.addEventListener) mq.addEventListener('change', () => this.forceUpdate());
    this.mo = new MutationObserver(() => this.forceUpdate());
    this.mo.observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] });
    document.addEventListener('keydown', (e) => this.onKey(e));
    this.dayTimer = setInterval(() => { if (E.ensureToday(this.st)) this.commit(); }, 30000);
    capability('comments').then((c) => { this.caps.comments = c; this.setState({ notesOk: !!c }); });
    capability('downloads').then((d) => { this.caps.downloads = d; });
  }
  measure() {
    const el = this.stage;
    const w = window.innerWidth;
    const sw = el ? el.clientWidth : w, sh = el ? el.clientHeight : window.innerHeight;
    if (sw !== this.state.sw || sh !== this.state.sh) this.setState({ sw, sh });
  }
  commit() {
    E.save(this.st);
    this.setState({ v: this.state.v + 1 });
  }
  mobile() {
    return window.innerWidth < 760;
  }
  geometry() {
    const { sw, sh } = this.state;
    if (this.mobile()) {
      const s = Math.min(sw / 390, sh / 760);
      const H = Math.max(760, Math.floor(sh / s));
      return { s, H, x: Math.max(0, (sw - 390 * s) / 2), y: 0 };
    }
    const H = 844;
    const s = Math.min(1, (sh - 40) / (H + 24), (sw - 24) / (390 + 24));
    return { s, H, x: 0, y: 0 };
  }
  dark() {
    const t = this.st.settings.theme;
    return t === 'Dark' ? true : t === 'Light' ? false : systemDark();
  }
  reduced() {
    return this.st.settings.reduced || systemReduced();
  }
  onKey(e) {
    const tag = (e.target && e.target.tagName) || '';
    if (e.key === 'Escape') {
      if (this.state.sub) this.app.closeSub();
      else if (this.state.ov) this.app.close();
      else if (this.state.lab) this.setState({ lab: false });
      return;
    }
    if (/INPUT|TEXTAREA|SELECT/.test(tag)) return;
    if (this.state.route.name === 'study' && !this.state.ov && !this.state.sub && this.app.studyRef && this.app.studyRef.key(e)) e.preventDefault();
  }

  // ---------- the API every screen gets ----------
  makeApi() {
    const self = this;
    const st = () => self.st;
    const api = {
      fx,
      scale: () => self.geometry().s,
      capability: async (name) => (name in self.caps ? self.caps[name] : (self.caps[name] = await capability(name))),
      mut(fn) {
        fn(self.st);
        self.commit();
      },
      go(name, params, opts) {
        const replace = opts && opts.replace;
        const hist = replace ? self.state.hist : self.state.hist.concat([self.state.route]).slice(-20);
        self.setState({ route: { name, params: params || {} }, hist, ov: null, sub: null });
      },
      back() {
        const h = self.state.hist;
        if (!h.length) return api.home();
        self.setState({ route: h[h.length - 1], hist: h.slice(0, -1), ov: null, sub: null });
      },
      home() {
        self.setState({ route: { name: 'decks', params: {} }, hist: [], ov: null, sub: null });
      },
      open(kind, params) {
        self.setState({ ov: { kind, params: params || {}, closing: false, key: Date.now() }, sub: null });
      },
      close() {
        if (!self.state.ov) return;
        self.setState({ ov: Object.assign({}, self.state.ov, { closing: true }), sub: null });
        clearTimeout(self.ovTimer);
        self.ovTimer = setTimeout(() => self.setState({ ov: null }), 230);
      },
      openSub(kind, params) {
        self.setState({ sub: { kind, params: params || {}, closing: false, key: Date.now() } });
      },
      closeSub() {
        if (!self.state.sub) return;
        self.setState({ sub: Object.assign({}, self.state.sub, { closing: true }) });
        clearTimeout(self.subTimer);
        self.subTimer = setTimeout(() => self.setState({ sub: null }), 200);
      },
      toast(text, undo) {
        clearTimeout(self.toastTimer);
        self.setState({ toast: { text, undo: undo || null, id: Date.now() } });
        self.toastTimer = setTimeout(() => self.setState({ toast: null }), undo ? 3600 : 2000);
      },
      study(deckId) {
        let warm = 0;
        api.mut((s) => {
          const f = E.folderOf(s, deckId);
          if (f) s.currentFolder = f.id;
          s.lastDeck = deckId;
          warm = E.prepareDeck(s, s.decks[deckId]);
        });
        if (self.state.route.name === 'study') self.setState({ route: { name: 'study', params: { deckId, warm, k: Date.now() } }, ov: null, sub: null });
        else api.go('study', { deckId, warm, k: Date.now() });
      },
      keepGoing() {
        const s = st();
        const cur = s.folders.find((f) => f.id === s.currentFolder);
        const id = [s.today.lastDeck, s.lastDeck, cur && cur.deckIds[0]].find((x) => x && s.decks[x]);
        if (id) api.study(id); else api.home();
      },
      create(params) {
        const p = Object.assign({}, params || {});
        if (!p.deckId && !p.newDeck && !p.editCardId && self.state.route.name === 'study') p.deckId = self.state.route.params.deckId;
        api.open('editor', p);
      },
      afterCreate(deckId, n) {
        const s = st();
        if (!deckId || !s.decks[deckId]) return;
        if (self.state.route.name === 'study' && self.state.route.params.deckId === deckId) {
          if (n) api.toast(n + (n === 1 ? ' card' : ' cards') + ' added to this stack');
          return;
        }
        const f = E.folderOf(s, deckId);
        if (n) api.toast(n + (n === 1 ? ' card' : ' cards') + ' added to ' + s.decks[deckId].name);
        api.openFolder(f.id, deckId);
      },
      openFolder(fid, highlight) {
        api.mut((s) => {
          s.currentFolder = fid;
          s.recentFolders = [fid].concat(s.recentFolders.filter((x) => x !== fid)).slice(0, 3);
        });
        self.setState({ route: { name: 'decks', params: { highlight: highlight || null, k: Date.now() } }, hist: [], ov: null, sub: null });
      },
      deleteDeck(id) {
        const s = st();
        const deck = s.decks[id];
        const f = E.folderOf(s, id);
        const index = f.deckIds.indexOf(id);
        const cards = deck.cardIds.map((c) => s.cards[c]);
        api.mut((x) => {
          f.deckIds.splice(index, 1);
          deck.cardIds.forEach((c) => delete x.cards[c]);
          delete x.decks[id];
          Object.keys(x.shopAdded).forEach((k) => { if (x.shopAdded[k] === id) delete x.shopAdded[k]; });
        });
        api.toast('Deleted ' + deck.name, () => api.mut((x) => {
          x.decks[id] = deck;
          cards.forEach((c) => (x.cards[c.id] = c));
          const ff = x.folders.find((y) => y.id === f.id);
          if (ff) ff.deckIds.splice(Math.min(index, ff.deckIds.length), 0, id);
          if (deck.shopId) x.shopAdded[deck.shopId] = id;
        }));
      },
      archiveDeck(id) {
        const s = st();
        const deck = s.decks[id];
        const from = E.folderOf(s, id);
        const index = from.deckIds.indexOf(id);
        let to;
        if (from.id === 'f-archive') to = s.folders.find((f) => f.id === deck.prevFolder) || s.folders.find((f) => f.id !== 'f-archive');
        else to = s.folders.find((f) => f.id === 'f-archive');
        if (!to) {
          api.mut((x) => x.folders.push({ id: 'f-archive', name: 'Archive', deckIds: [] }));
          to = st().folders.find((f) => f.id === 'f-archive');
        }
        const prevPrev = deck.prevFolder;
        api.mut(() => {
          from.deckIds.splice(index, 1);
          to.deckIds.unshift(id);
          deck.prevFolder = from.id === 'f-archive' ? null : from.id;
        });
        const restoring = from.id === 'f-archive';
        api.toast((restoring ? 'Restored ' + deck.name + ' to ' + to.name : 'Archived ' + deck.name), () => api.mut(() => {
          to.deckIds = to.deckIds.filter((x) => x !== id);
          from.deckIds.splice(Math.min(index, from.deckIds.length), 0, id);
          deck.prevFolder = prevPrev;
        }));
      },
      moveDeck(id) {
        const s = st();
        const from = E.folderOf(s, id);
        api.pickFolder({
          title: 'Move to…', subtitle: s.decks[id].name, exclude: [from.id],
          onPick: (fid) => {
            const index = from.deckIds.indexOf(id);
            const to = st().folders.find((f) => f.id === fid);
            api.mut(() => {
              from.deckIds.splice(index, 1);
              to.deckIds.unshift(id);
            });
            api.toast('Moved to ' + to.name, () => api.mut(() => {
              to.deckIds = to.deckIds.filter((x) => x !== id);
              from.deckIds.splice(Math.min(index, from.deckIds.length), 0, id);
            }));
          }
        });
      },
      togglePin(id) {
        const d = st().decks[id];
        api.mut(() => { d.pinned = !d.pinned; });
        api.toast(d.pinned ? 'Pinned ' + d.name + ' to the top' : 'Unpinned ' + d.name);
      },
      pickFolder(params) {
        api.openSub('picker', params);
      },
      newFolder() {
        let id;
        api.mut((s) => {
          id = 'f' + E.uid('');
          s.folders.unshift({ id, name: 'New folder', deckIds: [] });
        });
        api.openSub('rename', { title: 'Name the folder', value: 'New folder', onSave: (name) => api.mut((s) => { const f = s.folders.find((x) => x.id === id); if (f) f.name = name; }) });
      },
      renameFolder(fid) {
        const f = st().folders.find((x) => x.id === fid);
        api.openSub('rename', { title: 'Rename folder', value: f.name, onSave: (name) => api.mut(() => { f.name = name; }) });
      },
      deleteFolder(fid) {
        const s = st();
        const index = s.folders.findIndex((f) => f.id === fid);
        const folder = s.folders[index];
        const decks = folder.deckIds.map((id) => s.decks[id]).filter(Boolean);
        const cards = [];
        decks.forEach((d) => d.cardIds.forEach((c) => cards.push(s.cards[c])));
        api.mut((x) => {
          x.folders.splice(index, 1);
          decks.forEach((d) => {
            d.cardIds.forEach((c) => delete x.cards[c]);
            delete x.decks[d.id];
            Object.keys(x.shopAdded).forEach((k) => { if (x.shopAdded[k] === d.id) delete x.shopAdded[k]; });
          });
          x.recentFolders = x.recentFolders.filter((r) => r !== fid);
          if (x.currentFolder === fid && x.folders.length) x.currentFolder = x.folders[0].id;
        });
        api.toast('Deleted ' + folder.name + (decks.length ? ' · ' + decks.length + (decks.length === 1 ? ' deck' : ' decks') : ''), () => api.mut((x) => {
          x.folders.splice(Math.min(index, x.folders.length), 0, folder);
          decks.forEach((d) => { x.decks[d.id] = d; if (d.shopId) x.shopAdded[d.shopId] = d.id; });
          cards.forEach((c) => (x.cards[c.id] = c));
        }));
      },
      addShopDeck(shopId, fid) {
        let deck;
        api.mut((s) => { deck = E.addShopDeck(s, shopId, fid); });
        const f = st().folders.find((x) => x.id === fid);
        api.fx.good();
        api.openFolder(fid, deck.id);
        api.toast('Added ' + deck.cardIds.length + ' cards to ' + f.name);
      },
      setSetting(key, v) {
        api.mut((s) => {
          s.settings[key] = v;
          if (key === 'pace' && v === 'Intense') Object.values(s.decks).forEach((d) => { d.stack = d.stack.concat(d.reservoir); d.reservoir = []; });
          if (key === 'goal') {
            s.today.goalHit = s.today.goalHit && E.goalProgress(s).reached;
          }
        });
        fx.on = st().settings.sounds;
        fx.haptic = st().settings.haptics;
        if (key === 'sounds' && v) fx.click();
        if (key === 'haptics' && v) fx.buzz(12);
      },
      setTheme(v) {
        api.mut((s) => { s.settings.theme = v; });
      },
      replaceStore(obj) {
        self.st = obj;
        E.ensureToday(self.st);
        self.st.clockOffset = self.st.clockOffset || 0;
        self.setState({ route: { name: 'decks', params: {} }, hist: [], ov: null, sub: null });
        self.commit();
      },
      resetAll() {
        E.clearSaved();
        self.st = E.seedStore(Date.now());
        E.ensureToday(self.st);
        self.setState({ route: { name: 'decks', params: {} }, hist: [], ov: null, sub: null, resetAsk: false, lab: false });
        self.commit();
        api.toast('Prototype data reset');
      },
      shiftClock(ms) {
        api.mut((s) => {
          s.clockOffset = ms === null ? 0 : (s.clockOffset || 0) + ms;
          E.ensureToday(s);
        });
        const ev = st().profile.lastEvents || [];
        api.toast(ms === null ? 'Back to the real time' : ev.includes('broken') ? 'A day passed without the goal · streak reset' : ev.includes('shield') ? 'A grace shield covered the missed day' : 'Clock moved forward');
      },
      menu(kind, ev) {
        const s = st();
        const note = { label: 'Leave a note on this screen', act: () => api.note() };
        let items;
        if (kind === 'study') {
          const deck = s.decks[self.state.route.params.deckId];
          const top = deck && deck.stack[0];
          items = [
            { label: 'Edit this card', act: () => api.create({ editCardId: top }), disabled: !top },
            { label: 'Add a card to this deck', act: () => api.create({ deckId: deck.id }) },
            { label: 'Undo last swipe', act: () => api.studyRef && api.studyRef.undo() },
            { label: 'Pace', hint: s.settings.pace, act: () => api.openSub('choice', { title: 'Pace', value: s.settings.pace, onPick: (v) => api.setSetting('pace', v),
              options: [{ value: 'Relaxed', label: 'Relaxed', note: 'New cards join while you remember 80%' }, { value: 'Balanced', label: 'Balanced', note: 'New cards join while you remember 75%' }, { value: 'Intense', label: 'Intense', note: 'Every card in the stack from day one' }] }) },
            { label: "Today's progress", act: () => api.go('today') },
            note
          ];
        } else if (kind === 'shop') {
          items = [{ label: 'Profile', act: () => api.go('profile') }, { label: 'Settings', act: () => api.go('settings') }, note];
        } else {
          items = [
            { label: 'Profile', act: () => api.go('profile') },
            { label: "Today's progress", act: () => api.go('today') },
            { label: 'Settings', act: () => api.go('settings') },
            { label: 'New deck in this folder', act: () => api.create({ newDeck: true, folderId: s.currentFolder }) },
            { label: 'Import CSV', act: () => api.create({ mode: 'import' }) },
            { label: 'Rename folder', act: () => api.renameFolder(s.currentFolder) },
            note
          ];
        }
        api.openSub('menu', { items, top: 64 });
      },
      note(el) {
        const c = self.caps.comments;
        const target = el || self.noteTarget();
        if (!c || !target) {
          api.toast('Notes work on the published page in claude.ai');
          return;
        }
        c.openComposer({ element: target }).then((r) => {
          if (r && r.opened === false) api.toast('Finish the open note first');
        }).catch(() => api.toast('Notes are off in this view'));
      },
      demoGoal() {
        api.keepGoing();
        setTimeout(() => { if (api.studyRef) { api.studyRef.setState({ showGoal: true }); fx.fanfare(); } }, 80);
      },
      emptyFolder() {
        let f = st().folders.find((x) => x.deckIds.length === 0 && x.id !== 'f-archive');
        if (!f) {
          api.mut((s) => s.folders.splice(Math.max(0, s.folders.length - 1), 0, { id: 'f-bio', name: 'Biology', deckIds: [] }));
          f = st().folders.find((x) => x.id === 'f-bio');
        }
        api.openFolder(f.id);
      }
    };
    return api;
  }
  noteTarget() {
    const phone = this.phone;
    if (!phone) return null;
    return phone.querySelector('.sheet:not(.short)') || phone.querySelector('.drawer-panel') || phone.querySelector('.scr');
  }
  where() {
    const r = this.state.route;
    const ov = this.state.ov;
    return (ov && !ov.closing && OVERLAY_NAMES[ov.kind]) || SCREEN_NAMES[r.name] || r.name;
  }

  renderScreen(H, dark, ta, reduced) {
    const { route, ov } = this.state;
    const app = this.app, st = this.st;
    const pushed = ov && ov.kind === 'drawer' && !ov.closing;
    const p = route.params || {};
    const common = { app, st, H, dark, ta, reduced, pushed };
    switch (route.name) {
      case 'study':
        if (st.decks[p.deckId]) return html`<${Study} key=${'study' + p.deckId} ...${common} deckId=${p.deckId} warm=${p.warm} />`;
        return html`<${Decks} ...${common} folderId=${st.currentFolder} />`;
      case 'today': return html`<${Today} ...${common} />`;
      case 'shop': return html`<${Shop} key=${'shop' + (p.demoHold ? p.k : '')} ...${common} demoHold=${p.demoHold} />`;
      case 'profile': return html`<${Profile} ...${common} />`;
      case 'settings': return html`<${Settings} ...${common} />`;
      default: return html`<${Decks} key=${'decks' + (p.k || '')} ...${common} folderId=${st.currentFolder} highlight=${p.highlight} />`;
    }
  }
  renderOverlay(H, dark, ta, reduced) {
    const { ov } = this.state;
    if (!ov) return null;
    const props = { app: this.app, st: this.st, H, dark, ta, reduced, params: ov.params, closing: ov.closing, key: ov.key };
    if (ov.kind === 'drawer') return html`<${Drawer} ...${props} />`;
    if (ov.kind === 'editor') return html`<${Editor} ...${props} />`;
    if (ov.kind === 'preview') return html`<${Preview} ...${props} />`;
    return null;
  }
  renderSub() {
    const { sub } = this.state;
    if (!sub) return null;
    const props = { app: this.app, st: this.st, params: sub.params, closing: sub.closing, key: sub.key };
    if (sub.kind === 'picker') return html`<${FolderPicker} ...${props} />`;
    if (sub.kind === 'rename') return html`<${Rename} ...${props} />`;
    if (sub.kind === 'choice') return html`<${Choice} ...${props} />`;
    if (sub.kind === 'menu') return html`<${Menu} ...${props} />`;
    return null;
  }

  render() {
    const g = this.geometry();
    const dark = this.dark();
    const reduced = this.reduced();
    const ta = dark ? TA.dark : TA.light;
    const mobile = this.mobile();
    const { route, toast } = this.state;
    const navBottom = NAV_ROUTES.includes(route.name) ? 124 : 28;
    const phone = html`<div class=${cx('phone', dark && 'dark', reduced && 'reduced')} ref=${(el) => (this.phone = el)}
        style=${'width:390px;height:' + g.H + 'px;transform:scale(' + g.s.toFixed(4) + ');left:' + (mobile ? g.x.toFixed(1) + 'px' : '12px') + ';top:' + (mobile ? '0' : '12px')}>
      ${this.renderScreen(g.H, dark, ta, reduced)}
      ${this.renderOverlay(g.H, dark, ta, reduced)}
      ${this.renderSub()}
      ${toast && html`<div key=${toast.id} class="toast" role="status" style=${'bottom:' + navBottom + 'px'}>
        <span>${toast.text}</span>
        ${toast.undo ? html`<button class="toast-undo" onClick=${() => { const u = toast.undo; this.setState({ toast: null }); u(); }}>Undo</button>` : html`<span style="width:10px"></span>`}
      </div>`}
    </div>`;
    const lab = html`<${Lab} app=${this.app} st=${this.st} route=${route} where=${this.where()} notesOk=${this.state.notesOk} dark=${dark}
      resetAsk=${this.state.resetAsk} setResetAsk=${(v) => this.setState({ resetAsk: v })} close=${mobile ? () => this.setState({ lab: false }) : null} />`;
    if (mobile) {
      return html`<div class="mobile-stage" ref=${(el) => (this.stage = el)} style=${'background:' + (dark ? '#333333' : '#F1F1F1')}>
        ${phone}
        <button class="lab-tab" aria-label="Open the prototype lab" onClick=${() => this.setState({ lab: true })}>LAB</button>
        ${this.state.lab && html`<div class="lab-sheet" role="dialog" aria-label="Prototype lab">${lab}</div>`}
      </div>`;
    }
    return html`<div class="shell">
      <aside class="panel left" aria-label="About this prototype"><${Guide} app=${this.app} /></aside>
      <div class="stage" ref=${(el) => (this.stage = el)}>
        <div class="device" style=${'width:' + Math.round(390 * g.s + 24) + 'px;height:' + Math.round(g.H * g.s + 24) + 'px;border-radius:' + Math.round(36 * g.s + 12) + 'px'}>${phone}</div>
      </div>
      <aside class="panel right" aria-label="Prototype lab">${lab}</aside>
    </div>`;
  }
}

// ---------- the left panel: what this is and where to jump ----------
function Jump({ app }) {
  const shopPreview = () => { app.go('shop'); setTimeout(() => app.open('preview', { shopId: 's-de-a1' }), 60); };
  const items = [
    ['Decks', () => app.home()], ['Study', () => app.keepGoing()], ['Goal reached', () => app.demoGoal()], ['Today', () => app.go('today')],
    ['Folders', () => { app.home(); setTimeout(() => app.open('drawer'), 30); }], ['Empty folder', () => app.emptyFolder()], ['New card', () => app.create()], ['Import CSV', () => app.create({ mode: 'import' })],
    ['Shop', () => app.go('shop')], ['Shop · hold', () => app.go('shop', { demoHold: true, k: Date.now() })], ['Preview', shopPreview], ['Profile', () => app.go('profile')], ['Settings', () => app.go('settings')]
  ];
  return html`<div class="jump">${items.map(([label, fn]) => html`<button key=${label} class="jump-btn" onClick=${fn}>${label}</button>`)}</div>`;
}
function Guide({ app }) {
  return html`<div class="panel-inner">
    <div class="brand"><span class="brand-logo">${Ico.logo()}</span><div><div class="brand-name">Memory Card</div><div class="brand-sub">Playable prototype · v0.1</div></div></div>
    <p class="lede">Every screen from the design canvas, connected and running on real data. Decks, cards, settings and progress are kept in this browser.</p>
    <h3>Try this</h3>
    <ul class="tries">
      <li>Open a deck, tap the card, swipe right if you knew it, left if you didn't.</li>
      <li>Swipe a deck bar sideways: one step, then two.</li>
      <li>Open the folders, hold one to reorder, tap one twice to open it.</li>
      <li>In the shop, press and hold a deck.</li>
      <li>Write a card with <b>+</b>, or paste a list under Import CSV.</li>
      <li>Move the clock a few days on and watch decks start slipping.</li>
    </ul>
    <h3>Keys while studying</h3>
    <p class="keys"><kbd>←</kbd> didn't know <kbd>→</kbd> knew it <kbd>Space</kbd> reveal <kbd>Z</kbd> undo</p>
    <h3>Jump to</h3>
    <${Jump} app=${app} />
  </div>`;
}

// ---------- the Lab: notes, engine X-ray, clock ----------
function Lab({ app, st, route, where, notesOk, resetAsk, setResetAsk, close }) {
  const at = E.now(st);
  const deckId = route.name === 'study' ? route.params.deckId : st.lastDeck;
  const deck = deckId && st.decks[deckId];
  const ds = deck && E.deckStats(st, deck, at);
  const ls = st.lastSwipe && st.lastSwipe.deckId === deckId ? st.lastSwipe : null;
  const gp = E.goalProgress(st);
  const days = Math.round((st.clockOffset || 0) / E.DAY * 10) / 10;
  const pct = (x) => (x == null ? '—' : Math.round(x * 100) + '%');
  return html`<div class="panel-inner">
    ${close && html`<div class="row-between" style="margin-bottom:6px"><div class="brand-name">Lab</div><button class="lab-close" onClick=${close} aria-label="Close the lab">Close</button></div>`}
    <section class="lab-card note-card">
      <button class="note-btn" onClick=${() => { if (close) close(); setTimeout(() => app.note(), close ? 60 : 0); }}>${Ico.note()} Leave a note on this screen</button>
      <p class="hint">${notesOk === false ? 'Notes open the claude.ai comment box. They work on the published page.' : 'Pinned to ' + where + '. Your notes stay on this page, and I read them in our next session.'}</p>
    </section>
    ${close && html`<section class="lab-card"><h3>Jump to</h3><${Jump} app=${{ ...app, go: (...a) => { close(); app.go(...a); }, open: (...a) => { close(); app.open(...a); }, home: () => { close(); app.home(); }, keepGoing: () => { close(); app.keepGoing(); }, demoGoal: () => { close(); app.demoGoal(); }, emptyFolder: () => { close(); app.emptyFolder(); }, create: (p) => { close(); app.create(p); } }} /></section>`}
    <section class="lab-card">
      <h3>Engine X-ray</h3>
      ${deck ? html`
        <div class="xr-title">${deck.name}</div>
        <div class="xr-grid">
          <span>Pace</span><b>${st.settings.pace}${st.settings.pace !== 'Intense' ? ' · joins at ' + Math.round(E.PACE_TARGET[st.settings.pace] * 100) + '%' : ''}</b>
          <span>Felt success</span><b>${pct(deck.ema)}</b>
          <span>In the stack</span><b>${deck.stack.length} active · ${deck.reservoir.length} waiting</b>
          <span>Memory health</span><b>${pct(ds.health)} · ${ds.slip} slipping</b>
          <span>Fan</span><b>${ds.steps} of 5 steps (${ds.good}/${ds.total} ≥ 90%)</b>
        </div>
        ${ls && html`<p class="xr-last">${ls.ok ? 'Knew' : 'Missed'} “${ls.card}” → ${ls.ok ? 'sent to the back' : ls.leech ? 'leech, moved to the end' : 'back in ' + ls.n + ' (success rate ' + Math.round(ls.rate * 100) + '%)'}${ls.introduced ? ' · new card joined: “' + ls.introduced + '”' : ''}</p>`}
        <ol class="xr-stack">
          ${deck.stack.slice(0, 10).map((id, i) => {
            const c = st.cards[id];
            const r = E.recall(c, at);
            return html`<li key=${id}><span class="xr-pos">${i + 1}</span><span class="xr-term" dir="auto">${c.f}</span><span class="xr-r" style=${'--r:' + (r == null ? 0 : r)}>${r == null ? 'new' : Math.round(r * 100) + '%'}</span></li>`;
          })}
        </ol>
        <p class="hint">Order comes from the stack. The % is FSRS-6's predicted recall, used only for health, the fan and “slipping”.</p>
      ` : html`<p class="hint">Open a deck to see its stack here.</p>`}
    </section>
    <section class="lab-card">
      <h3>Today</h3>
      <div class="xr-grid">
        <span>Goal</span><b>${gp.done} / ${gp.goal}${gp.reached ? ' · reached' : ''}</b>
        <span>Slipping at 04:00</span><b>${st.today.slipStart.length} cards · ${gp.slipLeft} unseen</b>
        <span>Streak</span><b>${E.liveStreak(st)} days · ${st.profile.shields} shields</b>
      </div>
    </section>
    <section class="lab-card">
      <h3>Clock</h3>
      <p class="xr-title" style="font-size:15px">${fmtTime(at)}${days ? ' · +' + days + ' d' : ''}</p>
      <div class="jump">
        <button class="jump-btn" onClick=${() => app.shiftClock(E.HOUR * 6)}>+6 hours</button>
        <button class="jump-btn" onClick=${() => app.shiftClock(E.DAY)}>+1 day</button>
        <button class="jump-btn" onClick=${() => app.shiftClock(E.DAY * 3)}>+3 days</button>
        <button class="jump-btn" disabled=${!st.clockOffset} onClick=${() => app.shiftClock(null)}>Real time</button>
      </div>
      <p class="hint">A new day starts at 04:00. Skip a day without the goal and a grace shield covers it; after 2+ days away, a deck opens with its weakest cards first.</p>
    </section>
    <section class="lab-card">
      <h3>Theme</h3>
      <${Seg} label="Theme" options=${['Light', 'Dark', 'System']} value=${st.settings.theme} onPick=${(v) => app.setTheme(v)} cls="lab-seg" />
    </section>
    <section class="lab-card">
      ${resetAsk ? html`<div class="row-between"><span style="font-weight:600">Reset decks, cards and progress?</span>
          <span style="display:flex;gap:6px"><button class="jump-btn" onClick=${() => setResetAsk(false)}>Keep</button><button class="jump-btn danger" onClick=${() => app.resetAll()}>Reset</button></span></div>`
        : html`<button class="jump-btn wide" onClick=${() => setResetAsk(true)}>Reset prototype data</button>`}
    </section>
  </div>`;
}

const mount = document.getElementById('app');
mount.textContent = '';
render(html`<${App} />`, mount);
