// Create card / Import CSV sheet (Editor.dc.html) and the small sheets and menus the prototype needs.
import { html, Component, Ico, Toggle, Grip, cx, PEACH, DELETE } from './ui.js';
import * as E from './engine.js';

const SAMPLE = 'der Apfel; the apple\ndie Birne; the pear\ndie Milch; the milk\ndas Brot; the bread\ndie Butter; the butter';

function shrinkImage(file) {
  return new Promise((resolve, reject) => {
    const fr = new FileReader();
    fr.onerror = reject;
    fr.onload = () => {
      const img = new Image();
      img.onerror = reject;
      img.onload = () => {
        const k = Math.min(1, 480 / Math.max(img.width, img.height));
        const c = document.createElement('canvas');
        c.width = Math.round(img.width * k);
        c.height = Math.round(img.height * k);
        c.getContext('2d').drawImage(img, 0, 0, c.width, c.height);
        resolve(c.toDataURL('image/jpeg', 0.8));
      };
      img.src = fr.result;
    };
    fr.readAsDataURL(file);
  });
}

export class Editor extends Component {
  constructor(props) {
    super(props);
    const { st, params } = props;
    const edit = params.editCardId && st.cards[params.editCardId];
    let deckId = edit ? edit.deckId : params.deckId;
    const cur = st.folders.find((f) => f.id === st.currentFolder);
    if (!deckId && !params.newDeck) deckId = (st.lastDeck && st.decks[st.lastDeck] && cur && cur.deckIds.includes(st.lastDeck) && st.lastDeck) || (cur && cur.deckIds[0]);
    this.state = {
      tab: params.mode === 'import' ? 'import' : 'card',
      edit: !!edit,
      deckId: deckId || null,
      newDeck: !!params.newDeck || !deckId,
      newDeckName: '',
      f: edit ? edit.f : '', b: edit ? edit.b : '', e: edit ? edit.e : '', img: edit ? edit.img : '',
      reverse: true, saved: 0, err: '', csv: SAMPLE, picker: false, confirmDelete: false
    };
  }
  folderForNew() {
    const { st, params } = this.props;
    let fid = params.folderId || st.currentFolder;
    if (fid === 'f-archive' || !st.folders.some((f) => f.id === fid)) fid = (st.folders.find((f) => f.id !== 'f-archive') || st.folders[0]).id;
    return fid;
  }
  targetDeck(st) {
    if (this.state.newDeck) {
      const name = this.state.newDeckName.trim() || (this.state.tab === 'import' ? 'Imported cards' : 'New deck');
      const deck = E.makeDeck(st, { name, folderId: this.folderForNew() });
      return deck;
    }
    return st.decks[this.state.deckId];
  }
  saveCard(close) {
    const { app } = this.props;
    const f = this.state.f.trim(), b = this.state.b.trim();
    if (!f && !b && close && !this.state.edit) {
      app.close();
      if (this.state.saved) app.afterCreate(this.state.deckId, this.state.saved);
      return;
    }
    if (!f || !b) {
      this.setState({ err: !f && !b ? 'Write a front and a back' : !f ? 'The front is empty' : 'The back is empty' });
      app.fx.thud();
      return;
    }
    if (this.state.edit) {
      app.mut((st) => Object.assign(st.cards[this.props.params.editCardId], { f, b, e: this.state.e.trim(), img: this.state.img }));
      app.close();
      app.toast('Card saved');
      return;
    }
    let deckId;
    app.mut((st) => {
      const deck = this.targetDeck(st);
      E.addCardToDeck(st, deck, { f, b, e: this.state.e.trim(), img: this.state.img }, this.state.reverse);
      deckId = deck.id;
    });
    app.fx.pop();
    const saved = this.state.saved + 1;
    this.setState({ deckId, newDeck: false, f: '', b: '', e: '', img: '', saved, err: '' });
    if (close) {
      app.close();
      app.afterCreate(deckId, saved);
    } else if (this.frontEl) this.frontEl.focus();
  }
  deleteCard() {
    const { app, params } = this.props;
    if (!this.state.confirmDelete) { this.setState({ confirmDelete: true }); return; }
    app.mut((st) => E.deleteCard(st, params.editCardId));
    app.close();
    app.toast('Card deleted');
  }
  doImport(rows) {
    const { app } = this.props;
    if (!rows.length) return;
    let deck;
    app.mut((st) => {
      deck = this.targetDeck(st);
      if (!deck.cardIds.length) E.addCardsToNewDeck(st, deck, rows, false);
      else {
        const intense = st.settings.pace === 'Intense';
        rows.forEach((r) => {
          const id = E.addCardToDeck(st, deck, r, false).id;
          deck.stack = deck.stack.filter((x) => x !== id);
          (intense ? deck.stack : deck.reservoir).push(id);
        });
      }
    });
    app.close();
    app.toast('Imported ' + rows.length + ' cards into ' + deck.name);
    app.afterCreate(deck.id, 0);
  }
  readFile(e) {
    const file = e.target.files && e.target.files[0];
    if (!file) return;
    const fr = new FileReader();
    fr.onload = () => this.setState({ csv: String(fr.result || '') });
    fr.readAsText(file);
    e.target.value = '';
  }
  async pickImage(e) {
    const file = e.target.files && e.target.files[0];
    e.target.value = '';
    if (!file) return;
    try {
      const img = await shrinkImage(file);
      this.setState({ img });
    } catch (err) {
      this.props.app.toast('That image could not be read');
    }
  }

  deckChip() {
    const { st } = this.props;
    const s = this.state;
    const label = s.newDeck ? 'New deck' : (st.decks[s.deckId] || {}).name || 'Choose a deck';
    return html`<div class="chip-wrap">
      <button type="button" class="chip" aria-haspopup="listbox" aria-expanded=${s.picker ? 'true' : 'false'} onClick=${() => this.setState({ picker: !s.picker })}>${label} ▾</button>
      ${s.picker && html`<div class="popover deck-pop" role="listbox" aria-label="Deck">
        <button role="option" class="pop-item strong" onClick=${() => this.setState({ newDeck: true, picker: false })}>+ New deck</button>
        ${st.folders.filter((f) => f.id !== 'f-archive' && f.deckIds.length).map((f) => html`<div key=${f.id}>
          <div class="pop-head">${f.name}</div>
          ${f.deckIds.map((id) => st.decks[id] && html`<button key=${id} role="option" aria-selected=${!s.newDeck && s.deckId === id ? 'true' : 'false'} class=${cx('pop-item', !s.newDeck && s.deckId === id && 'on')}
            onClick=${() => this.setState({ deckId: id, newDeck: false, picker: false })}>${st.decks[id].name}</button>`)}
        </div>`)}
      </div>`}
    </div>`;
  }
  newDeckField() {
    const { st } = this.props;
    const folder = st.folders.find((f) => f.id === this.folderForNew());
    return this.state.newDeck && html`<label class="field-label" for="ed-deckname">New deck name <span style="font-weight:600">· in ${folder ? folder.name : ''}</span>
      <input id="ed-deckname" class="field" value=${this.state.newDeckName} placeholder=${this.state.tab === 'import' ? 'Imported cards' : 'e.g. German · Kitchen'} onInput=${(e) => this.setState({ newDeckName: e.target.value })} />
    </label>`;
  }

  render() {
    const { app, closing, H } = this.props;
    const s = this.state;
    const isCard = s.tab === 'card';
    const imp = E.parseImport(s.csv);
    return html`<div class=${cx('sheet-wrap', closing && 'closing')}>
      <div class="sheet-dim" onClick=${() => app.close()}></div>
      <section class="sheet" role="dialog" aria-label=${s.edit ? 'Edit card' : 'Create'} style="top:96px">
        <${Grip} />
        ${!s.edit && html`<div class="seg tabs" role="tablist" style="grid-template-columns:repeat(2,minmax(0,1fr))">
          <button role="tab" aria-selected=${isCard ? 'true' : 'false'} class=${isCard ? 'on' : ''} onClick=${() => this.setState({ tab: 'card', picker: false })}>Card</button>
          <button role="tab" aria-selected=${!isCard ? 'true' : 'false'} class=${!isCard ? 'on' : ''} onClick=${() => this.setState({ tab: 'import', picker: false })}>Import CSV</button>
        </div>`}
        <div class="sheet-body">
        ${isCard ? html`
          <div style="display:flex;align-items:center;justify-content:space-between;gap:10px">
            <h1 class="d" style="margin:0;font-size:32px;line-height:1">${s.edit ? 'Edit card' : 'New card'}</h1>
            ${!s.edit && this.deckChip()}
          </div>
          ${this.newDeckField()}
          <label class="field-label" for="ed-front">Front
            <input id="ed-front" ref=${(el) => (this.frontEl = el)} class="field d" style="font-size:24px" value=${s.f} placeholder="Word, question or prompt" onInput=${(e) => this.setState({ f: e.target.value, err: '' })} />
          </label>
          <label class="field-label" for="ed-back">Back
            <input id="ed-back" class="field" style="font-size:19px;font-weight:600" value=${s.b} placeholder="Meaning or answer" onInput=${(e) => this.setState({ b: e.target.value, err: '' })}
              onKeyDown=${(e) => { if (e.key === 'Enter') this.saveCard(false); }} />
          </label>
          <label class="field-label" for="ed-ex">Example or hint (optional)
            <textarea id="ed-ex" class="field area" rows="2" placeholder="A sentence that uses it" value=${s.e} onInput=${(e) => this.setState({ e: e.target.value })}></textarea>
          </label>
          ${s.img ? html`<div class="img-row"><img src=${s.img} alt="Card image" /><button class="btn-soft" style="height:40px;padding:0 14px" onClick=${() => this.setState({ img: '' })}>Remove image</button></div>`
            : html`<label class="add-image" for="ed-img">${Ico.plus(20, 2.6)} Add image<input id="ed-img" type="file" accept="image/*" style="display:none" onChange=${(e) => this.pickImage(e)} /></label>`}
          ${!s.edit && html`<div class="row-between" style="padding:4px 2px">
            <div>
              <div style="font-size:16px;font-weight:700">Also study back → front</div>
              <div style="font-size:14px;font-weight:500;color:var(--muted)">Creates a reverse card, kept apart in the stack</div>
            </div>
            <${Toggle} on=${s.reverse} label="Also study back to front" onFlip=${() => this.setState({ reverse: !s.reverse })} />
          </div>`}
          ${s.err && html`<div class="form-err" role="alert">${s.err}</div>`}
          <div style="flex:1;min-height:8px"></div>
          ${s.edit ? html`<div class="two-col">
              <button class="btn-soft" style=${'height:54px;' + (s.confirmDelete ? 'background:' + DELETE + ';color:#333' : '')} onClick=${() => this.deleteCard()}>${s.confirmDelete ? 'Tap again to delete' : 'Delete card'}</button>
              <button class="btn-ink d" style="height:54px;font-size:23px" onClick=${() => this.saveCard(true)}>Save</button>
            </div>`
            : html`<div class="two-col">
              <button class="btn-soft" style="height:54px" onClick=${() => this.saveCard(true)}>Done</button>
              <button class="btn-ink d" style="height:54px;font-size:23px" onClick=${() => this.saveCard(false)}>${s.saved ? 'Saved ' + s.saved + ' · next' : 'Save & next'}</button>
            </div>`}
        ` : html`
          <div style="display:flex;align-items:center;justify-content:space-between;gap:10px">
            <h1 class="d" style="margin:0;font-size:32px;line-height:1">Import cards</h1>
            ${this.deckChip()}
          </div>
          ${this.newDeckField()}
          <p style="margin:0;font-size:15px;font-weight:500;color:var(--muted);line-height:1.35">Paste one card per line: front, then back, separated by a tab, comma or semicolon.</p>
          <label class="field-label" for="ed-csv">Paste here
            <textarea id="ed-csv" class="field area mono" rows=${H < 820 ? 4 : 5} value=${s.csv} onInput=${(e) => this.setState({ csv: e.target.value })}></textarea>
          </label>
          <div style="display:flex;gap:8px;flex-wrap:wrap">
            <span class="tag">Separator: ${imp.sepName}</span>
            <span class="tag">${imp.rows.length} ${imp.rows.length === 1 ? 'card' : 'cards'}</span>
            ${imp.skipped > 0 && html`<span class="tag" style=${'background:' + PEACH + ';color:#333'}>${imp.skipped} ${imp.skipped === 1 ? 'line' : 'lines'} skipped</span>`}
          </div>
          <div role="table" aria-label="Preview" class="preview-table">
            <div role="row" class="pt-head"><span role="columnheader">Front</span><span role="columnheader">Back</span></div>
            ${imp.rows.slice(0, 3).map((r, i) => html`<div role="row" key=${i} class="pt-row"><span role="cell">${r.f}</span><span role="cell">${r.b}</span></div>`)}
            ${imp.rows.length > 3 && html`<div role="row" class="pt-row more"><span role="cell">+ ${imp.rows.length - 3} more</span><span role="cell"></span></div>`}
          </div>
          <div style="flex:1;min-height:8px"></div>
          <label class="btn-line" for="ed-file">Choose a .csv or .txt file…<input id="ed-file" type="file" accept=".csv,.txt,.tsv,text/plain,text/csv" style="display:none" onChange=${(e) => this.readFile(e)} /></label>
          <button class="btn-ink d" style="height:56px;font-size:24px" disabled=${!imp.rows.length} onClick=${() => this.doImport(imp.rows)}>Import ${imp.rows.length} ${imp.rows.length === 1 ? 'card' : 'cards'}</button>
        `}
        </div>
      </section>
    </div>`;
  }
}

// ---------- folder picker (move a deck, save a shop deck) ----------
export class FolderPicker extends Component {
  constructor(props) {
    super(props);
    this.state = { adding: false, name: '' };
  }
  render() {
    const { app, st, params, closing } = this.props;
    const exclude = params.exclude || [];
    const list = st.folders.filter((f) => !exclude.includes(f.id) && f.id !== 'f-archive');
    const add = () => {
      const name = this.state.name.trim();
      if (!name) return;
      let id;
      app.mut((s) => { id = 'f' + E.uid(''); s.folders.splice(Math.max(0, s.folders.length - 1), 0, { id, name, deckIds: [] }); });
      app.closeSub();
      params.onPick(id);
    };
    return html`<div class=${cx('sheet-wrap', closing && 'closing')} style="z-index:60">
      <div class="sheet-dim" onClick=${() => app.closeSub()}></div>
      <section class="sheet short" role="dialog" aria-label=${params.title}>
        <${Grip} />
        <h1 class="d" style="margin:2px 0 4px;font-size:30px;line-height:1">${params.title}</h1>
        ${params.subtitle && html`<p style="margin:0 0 6px;font-size:15px;font-weight:500;color:var(--muted)">${params.subtitle}</p>`}
        <div class="pick-list">
          ${list.map((f) => html`<button key=${f.id} class="pick-row" onClick=${() => { app.closeSub(); params.onPick(f.id); }}>
            <span class="d" style="font-size:22px">${f.name}</span><span class="muted">${f.deckIds.length} ${f.deckIds.length === 1 ? 'deck' : 'decks'} ›</span>
          </button>`)}
        </div>
        ${this.state.adding ? html`<div style="display:flex;gap:8px">
            <input class="field" style="flex:1;height:48px" aria-label="Folder name" placeholder="Folder name" value=${this.state.name} ref=${(el) => el && !this.focused && (this.focused = true, el.focus())}
              onInput=${(e) => this.setState({ name: e.target.value })} onKeyDown=${(e) => { if (e.key === 'Enter') add(); }} />
            <button class="btn-ink" style="height:48px;padding:0 18px;font-size:16px;font-weight:700" onClick=${add}>Add</button>
          </div>`
          : html`<button class="btn-line" onClick=${() => this.setState({ adding: true })}>+ New folder</button>`}
      </section>
    </div>`;
  }
}

// ---------- rename (folder) ----------
export class Rename extends Component {
  constructor(props) {
    super(props);
    this.state = { name: props.params.value || '' };
  }
  componentDidMount() {
    setTimeout(() => { if (this.el) { this.el.focus(); this.el.select(); } }, 260);
  }
  render() {
    const { app, params, closing } = this.props;
    const save = () => {
      const name = this.state.name.trim();
      if (!name) return;
      app.closeSub();
      params.onSave(name);
    };
    return html`<div class=${cx('sheet-wrap', closing && 'closing')} style="z-index:60">
      <div class="sheet-dim" onClick=${() => app.closeSub()}></div>
      <section class="sheet short" role="dialog" aria-label=${params.title}>
        <${Grip} />
        <h1 class="d" style="margin:2px 0 6px;font-size:30px;line-height:1">${params.title}</h1>
        <input class="field d" style="font-size:24px" aria-label="Name" ref=${(el) => (this.el = el)} value=${this.state.name}
          onInput=${(e) => this.setState({ name: e.target.value })} onKeyDown=${(e) => { if (e.key === 'Enter') save(); }} />
        <div class="two-col">
          <button class="btn-soft" style="height:52px" onClick=${() => app.closeSub()}>Cancel</button>
          <button class="btn-ink d" style="height:52px;font-size:22px" onClick=${save}>Save</button>
        </div>
      </section>
    </div>`;
  }
}

// ---------- choice sheet (shop sort, pace) ----------
export function Choice({ app, params, closing }) {
  return html`<div class=${cx('sheet-wrap', closing && 'closing')} style="z-index:60">
    <div class="sheet-dim" onClick=${() => app.closeSub()}></div>
    <section class="sheet short" role="dialog" aria-label=${params.title}>
      <${Grip} />
      <h1 class="d" style="margin:2px 0 6px;font-size:30px;line-height:1">${params.title}</h1>
      <div class="pick-list" role="radiogroup">
        ${params.options.map((o) => html`<button key=${o.value} role="radio" aria-checked=${o.value === params.value ? 'true' : 'false'} class=${cx('pick-row', o.value === params.value && 'on')}
          onClick=${() => { app.closeSub(); params.onPick(o.value); }}>
          <span style="text-align:left"><span style="display:block;font-size:17px;font-weight:700">${o.label}</span>${o.note && html`<span style="display:block;font-size:14px;font-weight:500;color:var(--muted)">${o.note}</span>`}</span>
          <span aria-hidden="true">${o.value === params.value ? '●' : '○'}</span>
        </button>`)}
      </div>
    </section>
  </div>`;
}

// ---------- the ⋮ menu ----------
export function Menu({ app, params, closing }) {
  return html`<div class=${cx('menu-wrap', closing && 'closing')} style="z-index:60">
    <div class="menu-dim" onClick=${() => app.closeSub()}></div>
    <div class="popover menu" role="menu" style=${'top:' + (params.top || 64) + 'px'}>
      ${params.items.map((it) => html`<button key=${it.label} role="menuitem" class=${cx('pop-item', it.strong && 'strong')} disabled=${it.disabled}
        onClick=${() => { app.closeSub(); it.act(); }}>${it.label}${it.hint && html`<span class="muted" style="float:right;font-weight:600">${it.hint}</span>`}</button>`)}
    </div>
  </div>`;
}
