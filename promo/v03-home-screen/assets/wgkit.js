// The widgets as the launcher composes them (app/android/.../widgets/SceneWidget.kt › SceneViews.build): the face,
// the moving pieces that sit behind the drawing (wg_scene_fxb.xml: seal, badges, flames), the drawing itself, then
// the pieces in front (wg_scene_fxf.xml: pulse rings, sheens). Sizes are dp (CSS px inside the phone's screen).
// Faces, drawings and piece places come from assets/widgets.js (tools/build_widgets.py); the motion is the
// launcher's own: res/drawable/wg_fx_*.xml, res/animator/wg_fx_*.xml and the durations in wg_scene_fxb.xml.
window.MC_WGKIT = (function () {
  const NS = "http://www.w3.org/2000/svg";
  const SEAL = "96,50 90.65,55.35 94.43,61.91 87.88,65.69 89.84,73 82.53,74.96 82.53,82.53 74.96,82.53 73,89.84 65.69,87.88 61.91,94.43 55.35,90.65 50,96 44.65,90.65 38.09,94.43 34.31,87.88 27,89.84 25.04,82.53 17.47,82.53 17.47,74.96 10.16,73 12.12,65.69 5.57,61.91 9.35,55.35 4,50 9.35,44.65 5.57,38.09 12.12,34.31 10.16,27 17.47,25.04 17.47,17.47 25.04,17.47 27,10.16 34.31,12.12 38.09,5.57 44.65,9.35 50,4 55.35,9.35 61.91,5.57 65.69,12.12 73,10.16 74.96,17.47 82.53,17.47 82.53,25.04 89.84,27 87.88,34.31 94.43,38.09 90.65,44.65";
  const FLAME = "M12,2c1.2,4 6,6.2 6,11.5A6,6 0,0 1,6 13.5c0,-2.6 1.2,-4.3 2.6,-5.6 0.3,1.9 1.4,3 2.6,3.3C11,8.6 10.6,5.4 12,2z";
  // The turning speeds of the ProgressBar slots, by slot (wg_scene_fxb.xml).
  const SEAL_SECONDS = [32, 27, 36, 30];
  const BADGE_SECONDS = [22, 28, 25, 31];
  const BEHIND = { SEAL: 1, BADGE: 1, FLAME: 1, FLAME_OUTLINE: 1 };

  const rgba = (argb) => {
    const n = parseInt(argb.slice(1), 16);
    const a = ((n >>> 24) & 255) / 255, r = (n >>> 16) & 255, g = (n >>> 8) & 255, b = n & 255;
    return `rgba(${r},${g},${b},${a.toFixed(3)})`;
  };
  const svg = (tag, attrs, parent) => {
    const e = document.createElementNS(NS, tag);
    for (const k in attrs) e.setAttribute(k, attrs[k]);
    if (parent) parent.appendChild(e);
    return e;
  };

  function piece(p) {
    const box = document.createElement("div");
    box.className = "wg-piece wg-" + p.fx.toLowerCase();
    Object.assign(box.style, { position: "absolute", left: p.x + "px", top: p.y + "px", width: p.w + "px", height: p.h + "px" });
    const color = rgba(p.color);
    let s, moving, origin = null;
    if (p.fx === "SEAL") {
      s = svg("svg", { viewBox: "0 0 100 100", width: "100%", height: "100%", preserveAspectRatio: "none" });
      moving = svg("polygon", { points: SEAL, fill: color }, s);
      origin = "50 50";
    } else if (p.fx === "FLAME" || p.fx === "FLAME_OUTLINE") {
      s = svg("svg", { viewBox: "0 0 24 24", width: "100%", height: "100%", preserveAspectRatio: "none", overflow: "visible" });
      moving = svg("g", {}, s);
      origin = "12 21";
      svg("path", p.fx === "FLAME" ? { d: FLAME, fill: color } : { d: FLAME, fill: "none", stroke: color, "stroke-width": 1.8, "stroke-linejoin": "round" }, moving);
    } else if (p.fx === "PULSE") {
      s = svg("svg", { viewBox: "0 0 24 24", width: "100%", height: "100%", overflow: "visible" });
      moving = svg("circle", { cx: 12, cy: 12, r: 9, fill: "none", stroke: color, "stroke-width": 2.4 }, s);
      origin = "12 12";
    } else if (p.fx === "SHEEN" || p.fx === "SHEEN_WIDE") {
      const wide = p.fx === "SHEEN_WIDE";
      s = svg("svg", { viewBox: wide ? "0 0 500 100" : "0 0 214 100", width: "100%", height: "100%", preserveAspectRatio: "none" });
      box.style.overflow = "hidden";
      moving = svg("g", {}, s);
      if (wide) {
        svg("path", { d: "M34,0 L62,0 L28,100 L0,100 Z", fill: "rgba(255,255,255,0.30)" }, moving);
        svg("path", { d: "M70,0 L80,0 L46,100 L36,100 Z", fill: "rgba(255,255,255,0.16)" }, moving);
      } else {
        svg("path", { d: "M30,0 L52,0 L22,100 L0,100 Z", fill: "rgba(255,255,255,0.35)" }, moving);
        svg("path", { d: "M58,0 L66,0 L36,100 L28,100 Z", fill: "rgba(255,255,255,0.20)" }, moving);
      }
    } else {
      s = svg("svg", { viewBox: "0 0 100 100", width: "100%", height: "100%" });
      moving = svg("polygon", { points: SEAL, fill: color }, s);
      origin = "50 50";
    }
    box.appendChild(s);
    // Each piece turns about the pivot its drawable names (in the drawable's own units).
    if (origin) gsap.set(moving, { svgOrigin: origin });
    return { fx: p.fx, box, moving };
  }

  /** Builds widget [key] inside [el] (positioned by the caller). Returns its moving pieces. */
  function mount(el, key) {
    const m = window.MC_WIDGETS[key];
    if (!m) throw new Error("no widget render " + key);
    el.style.width = m.w + "px";
    el.style.height = m.h + "px";
    if (getComputedStyle(el).position === "static") el.style.position = "absolute";
    if (m.face) {
      const face = document.createElement("div");
      const r = m.face.radius >= 999 ? Math.min(m.w, m.h) / 2 : m.face.radius;
      Object.assign(face.style, { position: "absolute", inset: "0", background: rgba(m.face.color), borderRadius: r + "px" });
      face.className = "wg-face";
      el.appendChild(face);
    }
    const pieces = m.pieces.map(piece);
    pieces.filter((p) => BEHIND[p.fx]).forEach((p) => el.appendChild(p.box));
    const ink = document.createElement("img");
    ink.src = m.ink;
    ink.alt = "";
    Object.assign(ink.style, { position: "absolute", left: "0", top: "0", width: m.w + "px", height: m.h + "px" });
    ink.className = "wg-ink";
    el.appendChild(ink);
    pieces.filter((p) => !BEHIND[p.fx]).forEach((p) => el.appendChild(p.box));
    el.dataset.wg = key;
    return pieces;
  }

  /**
   * Runs the launcher's motion of [pieces] on [tl] from [t0] to [t1] seconds (finite repeats, so any frame can be
   * seeked). [age] is how long the widget has already been on the home screen at t0 (its loops are mid-way).
   */
  function animate(tl, pieces, t0, t1, age = 0) {
    const FOSI = CustomEase.create("mcFosi", "M0,0 C0.4,0 0.2,1 1,1"); // fast_out_slow_in
    const span = Math.max(0.01, t1 - t0);
    const count = {};
    pieces.forEach((p) => {
      const slot = (count[p.fx] = (count[p.fx] || 0) + 1) - 1;
      const m = p.moving;
      if (p.fx === "SEAL" || p.fx === "BADGE") {
        const secs = (p.fx === "SEAL" ? SEAL_SECONDS : BADGE_SECONDS)[slot % 4];
        const a0 = (age / secs) * 360;
        tl.fromTo(m, { rotation: a0 }, { rotation: a0 + (span / secs) * 360, duration: span, ease: "none" }, t0);
      } else if (p.fx === "FLAME" || p.fx === "FLAME_OUTLINE") {
        // wg_fx_flicker.xml: three out-of-step wobbles, each reversing (accelerate_decelerate).
        const wobble = (prop, from, to, half) => {
          const n = Math.max(0, Math.floor(span / half) - 1);
          tl.fromTo(m, { [prop]: from }, { [prop]: to, duration: half, ease: "sine.inOut", repeat: n, yoyo: true }, t0);
        };
        wobble("scaleY", 1, 1.13, 0.43);
        wobble("scaleX", 1, 0.9, 0.59);
        wobble("rotation", -4, 4, 0.81);
      } else if (p.fx === "PULSE") {
        // wg_fx_ring_grow.xml + wg_fx_ring_fade.xml: swells 0.6 -> 1.06 and fades 0.95 -> 0 every 1.9 s.
        const n = Math.max(0, Math.floor(span / 1.9) - 1);
        tl.fromTo(m, { scale: 0.6 }, { scale: 1.06, duration: 1.9, ease: FOSI, repeat: n }, t0);
        tl.fromTo(m, { opacity: 0.95 }, { opacity: 0, duration: 1.9, ease: "none", repeat: n }, t0);
      } else if (p.fx === "SHEEN" || p.fx === "SHEEN_WIDE") {
        // wg_fx_sweep*.xml: the band crosses in the first fifth of the loop, then rests off the card.
        const wide = p.fx === "SHEEN_WIDE";
        const loop = wide ? [7, 8.3, 9.6][slot % 3] : 7;
        const cross = wide ? [0.2, 0.17, 0.15][slot % 3] : 0.22;
        const from = wide ? -90 : -80, to = wide ? 560 : 290;
        const n = Math.max(0, Math.floor(span / loop) - 1);
        const sweep = gsap.timeline({ repeat: n });
        sweep.fromTo(m, { x: from }, { x: to, duration: loop * cross, ease: FOSI, immediateRender: false }, 0);
        sweep.to({}, { duration: loop * (1 - cross) }, loop * cross);
        gsap.set(m, { x: from });
        tl.add(sweep, t0 + 0.25 + slot * 0.6);
      }
    });
  }

  return { mount, animate };
})();
