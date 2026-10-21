// Profile & membership card (Profile.dc.html) and Settings (Settings.dc.html), computed from the store.
import { html, Component, Ico, Toggle, Seg, cx, polar } from './ui.js';
import * as E from './engine.js';

const SHAPES = {
  scallop: polar((a) => 34 + 3.4 * Math.cos(9 * a), 108),
  burst: polar((a) => 33.5 + 4.5 * Math.cos(12 * a), 144),
  squircle: polar((a) => 34 * Math.pow(Math.pow(Math.abs(Math.cos(a)), 4) + Math.pow(Math.abs(Math.sin(a)), 4), -0.25) + 2.4 * Math.sin(4 * a + 0.8), 108)
};
const pad4 = (n) => String(Math.max(0, Math.round(n))).padStart(4, '0').slice(-4);

export class Profile extends Component {
  constructor(props) {
    super(props);
    this.state = { flipped: false };
  }
  render() {
    const { app, st, dark, ta, H } = this.props;
    const at = E.now(st);
    const lib = E.libraryStats(st, at);
    const streak = E.liveStreak(st);
    const health = lib.health == null ? 0 : Math.round(lib.health * 100);
    const recentLog = st.log.slice(-200);
    const felt = recentLog.length ? Math.round((100 * recentLog.filter((r) => r.grade).length) / recentLog.length) : 74;
    const f = this.state.flipped;
    const todayIdx = E.dayIndex(st.today.day);
    const levels = (v) => (!v ? 0 : v < 15 ? 1 : v < 30 ? 2 : v < 55 ? 3 : 4);
    const heat = [];
    for (let i = 34; i >= 0; i--) {
      const key = E.keyOfIndex(todayIdx - i);
      const v = i === 0 ? st.today.done : st.profile.history[key] || 0;
      heat.push(ta.heat[levels(v)]);
    }
    const shift = H - 844;
    const y = (v) => v + Math.round(shift * 0.6);
    const tier = lib.good >= 1500 ? 'Gold tier' : lib.good >= 500 ? 'Silver tier' : 'Bronze tier';
    const tierBg = lib.good >= 1500 ? '#E3C46A' : lib.good >= 500 ? '#C9CED6' : '#D9A273';
    const accountTap = () => app.toast('Accounts come later · everything stays on this phone');
    return html`<div class="scr" id="screen-profile" data-screen="Profile" style="transition:background 250ms ease,color 250ms ease">
      <div aria-hidden="true" class="sash"></div>
      <div aria-hidden="true" class="sash-face"></div>
      <header class="hdr" style="padding-right:12px;gap:4px">
        <button class="ibtn" aria-label="Back to decks" onClick=${() => app.home()}><span style="width:28px;height:36px">${Ico.logo()}</span></button>
        <div style="flex:1"></div>
        <button class="ibtn" style="width:48px;height:48px" aria-label=${dark ? 'Switch to light mode' : 'Switch to dark mode'} onClick=${() => app.setTheme(dark ? 'Light' : 'Dark')}><span style="width:36px;height:36px">${Ico.sun()}</span></button>
      </header>
      <div style=${'position:absolute;left:14px;right:14px;top:' + y(312) + 'px;height:244px;perspective:1200px'}>
        <button class="mcard" onClick=${() => this.setState({ flipped: !f })} style=${'transform:rotateY(' + (f ? 180 : 0) + 'deg)'}
          aria-label=${f ? 'Membership card, back: activity and streak. Tap to flip to the front' : 'Membership card. Tap to flip and see your activity'}>
          <span class="mface">
            <span style="display:flex;justify-content:space-between;align-items:flex-start">
              <span class="tier" style=${'background:' + tierBg}>${tier}</span>
              <span style="display:block;width:34px;height:44px;color:var(--on-ink)">${Ico.logo()}</span>
            </span>
            <span style="position:absolute;left:22px;right:22px;bottom:18px;display:block">
              <span class="d" style="display:block;font-size:36px;line-height:1">Guest Learner</span>
              <span style="margin-top:10px;display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:6px">
                ${[[pad4(lib.good), 'mastered'], [pad4(streak), 'streak'], [pad4(health), 'health %'], [String(st.profile.since), 'since']].map(([v, l]) => html`<span key=${l} style="display:block">
                  <span class="d" style="display:block;font-size:32px;line-height:1;letter-spacing:1px;color:var(--digits)">${v}</span>
                  <span class="mlabel">${l}</span>
                </span>`)}
              </span>
            </span>
          </span>
          <span class="mface mback">
            <span class="stripe"></span>
            <span style="position:absolute;left:20px;top:66px;display:block">
              <span class="mlabel" style="margin:0">Last 5 weeks</span>
              <span role="img" aria-label="Study activity over the last 35 days" style="margin-top:8px;display:grid;grid-template-columns:repeat(7,14px);gap:4px">
                ${heat.map((bg, i) => html`<span key=${i} style=${'display:block;width:14px;height:14px;border-radius:4px;background:' + bg + (i === 34 ? ';outline:2px solid ' + '#D35F5F' + ';outline-offset:-2px' : '')}></span>`)}
              </span>
            </span>
            <span style="position:absolute;left:172px;right:18px;top:64px;display:block">
              <span style="display:flex;align-items:center;gap:8px">${Ico.flame(18, 21)}<span class="d" style="font-size:24px;line-height:1">${streak}-day streak</span></span>
              <span style="margin-top:6px;display:flex;align-items:center;gap:4px;font-size:12px;font-weight:600;color:var(--muted-on-ink)">
                ${[0, 1].map((i) => html`<span key=${i}>${Ico.shield(13, 15, i >= st.profile.shields)}</span>`)} ${st.profile.shields} ${st.profile.shields === 1 ? 'shield' : 'shields'} left
              </span>
              <span style="margin-top:12px;display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:6px">
                ${[[lib.good, 'cards mastered'], [health + '%', 'memory health'], [felt + '%', 'felt success']].map(([v, l]) => html`<span key=${l} style="display:block">
                  <span class="d" style="display:block;font-size:24px;line-height:1">${v}</span>
                  <span style="display:block;margin-top:2px;font-size:11px;font-weight:600;line-height:1.15;color:var(--muted-on-ink)">${l}</span>
                </span>`)}
              </span>
            </span>
            <span style="position:absolute;right:18px;bottom:14px;display:block;font-size:11px;font-weight:600;color:var(--muted-on-ink)">Member since ${st.profile.since}</span>
          </span>
        </button>
      </div>
      <p class="center-note" style=${'top:' + y(568) + 'px'}>${f ? 'Tap the card to flip it back' : 'Tap the card to see your activity'}</p>
      <p class="center-note d" style=${'top:' + y(614) + 'px;font-size:17px'}>Back up your progress? <button class="link d" onClick=${() => app.go('settings')}>Sign in</button></p>
      <div style=${'position:absolute;left:0;right:0;top:' + y(650) + 'px;display:flex;justify-content:center;gap:30px'}>
        <button class="badge84" aria-label="Sign in with Google" onClick=${accountTap}>
          <svg width="84" height="84" viewBox="-40 -40 80 80" aria-hidden="true" style="position:absolute;inset:0;filter:var(--badge-shadow)"><path d=${SHAPES.scallop} fill="var(--badge)"/></svg>
          <span style="position:absolute;left:25px;top:25px;width:34px;height:34px">${Ico.google()}</span>
        </button>
        <button class="badge84" aria-label="Create a Memory Card account" onClick=${accountTap}>
          <svg width="84" height="84" viewBox="-40 -40 80 80" aria-hidden="true" style="position:absolute;inset:0;filter:var(--badge-shadow)"><path d=${SHAPES.burst} fill="var(--badge)"/></svg>
          <span style="position:absolute;left:27px;top:25px;width:27px;height:34px;color:var(--badge-ink)">${Ico.logo()}</span>
        </button>
        <button class="badge84" aria-label="Sign in with Apple" onClick=${accountTap}>
          <svg width="84" height="84" viewBox="-40 -40 80 80" aria-hidden="true" style="position:absolute;inset:0;filter:var(--badge-shadow)"><path d=${SHAPES.squircle} fill="var(--badge)"/></svg>
          <span style="position:absolute;left:28px;top:25px;width:28px;height:34px;color:var(--badge-ink)">${Ico.apple()}</span>
        </button>
      </div>
      <p class="center-note" style=${'top:' + y(750) + 'px;left:30px;right:30px;font-weight:500'}>Optional. Everything works offline without an account.</p>
    </div>`;
  }
}

const PACE_NOTES = {
  Relaxed: 'New cards join only while you remember about 80% — calm, steady sessions.',
  Balanced: 'New cards join while you remember about 75%. The default.',
  Intense: 'Every card is in the stack from day one. Covers most ground, fails more often.'
};
export class Settings extends Component {
  constructor(props) {
    super(props);
    this.state = { confirmRestore: null };
  }
  async exportBackup() {
    const { app, st } = this.props;
    const data = JSON.stringify(st, null, 1);
    const name = 'memory-card-backup-' + st.today.day + '.json';
    const dl = await app.capability('downloads');
    if (dl) {
      try {
        await dl.save({ filename: name, data });
        app.toast('Backup saved');
      } catch (e) {
        if (e && e.code === 'declined') app.toast('Backup not saved');
        else app.toast('Saving files is not available here');
      }
    } else {
      app.toast('Saving files works on the published page');
    }
  }
  restore(e) {
    const { app } = this.props;
    const file = e.target.files && e.target.files[0];
    e.target.value = '';
    if (!file) return;
    const fr = new FileReader();
    fr.onload = () => {
      try {
        const obj = JSON.parse(String(fr.result));
        if (!E.validBackup(obj)) throw new Error('bad');
        app.replaceStore(obj);
        app.toast('Backup restored');
      } catch (err) {
        app.toast('That file is not a Memory Card backup');
      }
    };
    fr.readAsText(file);
  }
  render() {
    const { app, st } = this.props;
    const set = st.settings;
    const pick = (key) => (v) => app.setSetting(key, v);
    const at = E.now(st);
    let worst = null;
    for (const f of st.folders) {
      if (f.id === 'f-archive') continue;
      for (const id of f.deckIds) {
        const s = E.deckStats(st, st.decks[id], at);
        if (!worst || s.slip > worst.slip) worst = { slip: s.slip, name: st.decks[id].name };
      }
    }
    const toggles = [['sounds', 'Sounds', 'Soft clicks and a finish fanfare'], ['haptics', 'Haptics', 'A tick when a swipe locks in (Android)'], ['reduced', 'Reduced motion', 'Slides and fades instead of tilts']];
    return html`<div class="scr" id="screen-settings" data-screen="Settings">
      <header class="hdr" style="padding-left:10px;gap:6px">
        <button class="ibtn" aria-label="Back" onClick=${() => app.back()}>${Ico.back()}</button>
        <h1 class="d" style="margin:0;font-size:34px;line-height:1">Settings</h1>
      </header>
      <div class="scroll settings" style="top:76px;bottom:0">
        <section aria-label="Study">
          <h2 class="eyebrow">Study</h2>
          <div class="group pad">
            <div>
              <div class="row-title">Reveal the answer by</div>
              <${Seg} label="Reveal the answer by" options=${['Tap card', 'Tap icon', 'Flip', 'Front only']} value=${set.reveal} onPick=${pick('reveal')} cls="well sm" />
            </div>
            <div>
              <div class="row-title">Pace</div>
              <${Seg} label="Pace" options=${['Relaxed', 'Balanced', 'Intense']} value=${set.pace} onPick=${pick('pace')} cls="well" />
              <div class="row-note" style="margin-top:6px">${PACE_NOTES[set.pace]}</div>
            </div>
            <div class="row-between">
              <div><div class="row-title" style="margin:0">Daily goal</div><div class="row-note">Swipes before the celebration</div></div>
              <div style="display:flex;align-items:center;gap:6px">
                <button class="step-btn" aria-label="Lower daily goal" onClick=${() => app.setSetting('goal', Math.max(10, set.goal - 10))}>−</button>
                <span aria-live="polite" class="d" style="min-width:40px;text-align:center;font-size:26px">${set.goal}</span>
                <button class="step-btn" aria-label="Raise daily goal" onClick=${() => app.setSetting('goal', Math.min(200, set.goal + 10))}>+</button>
              </div>
            </div>
          </div>
        </section>
        <section aria-label="Feel">
          <h2 class="eyebrow">Feel</h2>
          <div class="group" style="padding:4px 14px">
            ${toggles.map(([key, name, note], i) => html`<div key=${key} class="row-between" style=${'min-height:58px;' + (i < toggles.length - 1 ? 'border-bottom:1px solid var(--line)' : '')}>
              <div><div class="row-title" style="margin:0">${name}</div><div class="row-note">${note}</div></div>
              <${Toggle} on=${set[key]} label=${name} onFlip=${() => app.setSetting(key, !set[key])} />
            </div>`)}
          </div>
        </section>
        <section aria-label="Appearance">
          <h2 class="eyebrow">Appearance</h2>
          <${Seg} label="Theme" options=${['Light', 'Dark', 'System']} value=${set.theme} onPick=${(v) => app.setTheme(v)} cls="soft-group" />
        </section>
        <section aria-label="Reminders">
          <h2 class="eyebrow">Reminders</h2>
          <div class="group pad" style="gap:10px">
            <div class="row-between">
              <label class="row-title" style="margin:0" for="remind-time">Daily at</label>
              <input id="remind-time" type="time" class="time d" value=${set.remind} onInput=${(e) => app.setSetting('remind', e.target.value)} />
            </div>
            <div class="remind-preview">
              <span style="display:block;flex:none;width:22px;height:28px;color:var(--ink)">${Ico.logo()}</span>
              <span style="font-size:15px;font-weight:600;line-height:1.3">${worst && worst.slip ? worst.slip + ' cards are slipping in ' + worst.name + '. Two minutes saves them.' : 'Everything is fresh. A short session keeps it that way.'}</span>
            </div>
          </div>
        </section>
        <section aria-label="Your data">
          <h2 class="eyebrow">Your data</h2>
          <div class="group" style="overflow:hidden">
            <button class="list-row" onClick=${() => app.create({ mode: 'import' })}>Import cards from CSV <span aria-hidden="true">›</span></button>
            <button class="list-row" onClick=${() => this.exportBackup()}>Export backup (.json) <span aria-hidden="true">›</span></button>
            <label class="list-row last" for="restore-file">Restore a backup <span aria-hidden="true">›</span><input id="restore-file" type="file" accept=".json,application/json" style="display:none" onChange=${(e) => this.restore(e)} /></label>
          </div>
          <div class="row-note" style="margin-top:8px">Everything lives on this phone. Back it up now and then.</div>
        </section>
        <div class="row-between" style="font-size:14px;font-weight:600;color:var(--muted);padding-bottom:24px">
          <button class="link" style="height:44px;font-size:16px" onClick=${(e) => app.note(e.currentTarget.closest('.scr'))}>Send feedback</button>
          <span>Memory Card 0.1.0 · prototype</span>
        </div>
      </div>
    </div>`;
  }
}
