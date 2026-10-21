// Memory Card prototype — shared UI: Preact + htm, icons (from icons/*.svg via the design canvas), sound, haptics.
export { html, render, Component, h } from 'https://unpkg.com/htm@3.1.1/preact/standalone.module.js';
import { html } from 'https://unpkg.com/htm@3.1.1/preact/standalone.module.js';

export const BLUE = '#80AEFF', PEACH = '#FFC680', RED = '#D35F5F', DELETE = '#FF8080', GREEN = '#8BD3A0';

// Theme-dependent lists that are easier in JS than in CSS variables.
export const TA = {
  light: {
    fanOn: ['#8F8F8F', '#A8A8A8', '#C2C2C2', '#DADADA', '#F1F1F1'], fanOff: '#454545',
    above: [['#C7C7C7', '#BCBCBC'], ['#D6D6D6', '#CDCDCD'], ['#E4E4E4', '#DEDEDE'], ['#EFEFEF', '#E9E9E9']], below: ['#666666', '#4E4E4E', '#3D3D3D'],
    heat: ['#474747', '#666666', '#8A8A8A', '#BDBDBD', '#F1F1F1'], heatEmpty: '#474747', folderShadow: 0.32
  },
  dark: {
    fanOn: ['#A3A3A3', '#888888', '#6E6E6E', '#525252', '#333333'], fanOff: '#DADADA',
    above: [['#5F5F5F', '#6E6E6E'], ['#4F4F4F', '#5B5B5B'], ['#434343', '#4B4B4B'], ['#373737', '#3F3F3F']], below: ['#D9D9D9', '#BDBDBD', '#A5A5A5'],
    heat: ['#DADADA', '#BDBDBD', '#8A8A8A', '#5E5E5E', '#333333'], heatEmpty: '#DADADA', folderShadow: 0.5
  }
};

export const cx = (...a) => a.filter(Boolean).join(' ');
export const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
export function polar(fn, n) {
  let d = '';
  for (let i = 0; i <= n; i++) {
    const a = (i / n) * Math.PI * 2;
    const r = fn(a);
    d += (i === 0 ? 'M' : 'L') + (Math.cos(a) * r).toFixed(2) + ' ' + (Math.sin(a) * r).toFixed(2);
  }
  return d + 'Z';
}
export function sealPath() {
  let d = '';
  for (let i = 0; i < 48; i++) {
    const a = (i / 48) * Math.PI * 2;
    const r = i % 2 === 0 ? 46 : 41;
    d += (i === 0 ? 'M' : 'L') + (Math.cos(a) * r).toFixed(2) + ' ' + (Math.sin(a) * r).toFixed(2);
  }
  return d + 'Z';
}
export const SEAL = sealPath();

// ---------- icons ----------
export const Ico = {
  logo: () => html`<svg width="100%" height="100%" viewBox="0 0 11.211 14.182" fill="currentColor" aria-hidden="true"><g transform="translate(-3014.7719,-1275.9218)"><g transform="translate(-69.860379)"><rect x="3084.633" y="1275.922" width="6.926" height="11.206" ry="0.534" fill-opacity=".55"/><rect x="3312.468" y="433.451" width="6.926" height="11.206" ry="0.534" transform="rotate(15)" fill-opacity=".78"/><rect x="3314.619" y="-438.992" width="6.926" height="11.206" ry="0.534" transform="rotate(30)"/></g></g></svg>`,
  dots: () => html`<svg width="100%" height="100%" viewBox="0 0 2.444 8.911" fill="currentColor" aria-hidden="true"><g transform="translate(-2998.7693,-1277.1094)"><g transform="translate(-455.15531,250.69204)"><circle cx="3455.146" cy="1034.107" r="1.222"/><circle cx="3455.146" cy="1030.873" r="1.222"/><circle cx="3455.146" cy="1027.639" r="1.222"/></g></g></svg>`,
  home: () => html`<svg width="100%" height="100%" viewBox="0 0 11.321 11.322" fill="currentColor" aria-hidden="true"><g transform="translate(-3015.3506,-1319.8992)"><g transform="matrix(0.73369523,0,0,0.73369523,2071.0345,1201.7805)"><path d="m 1294.783,160.991 c -0.349,0 -0.699,0.134 -0.966,0.402 l -4.247,4.247 c -0.026,0.02 -0.051,0.042 -0.074,0.066 l -2.181,2.181 c -0.329,0.329 -0.329,0.858 0,1.187 0.329,0.329 0.858,0.329 1.187,0 l 0.076,-0.076 0,-0 2.104,-2.104 3.135,-3.135 c 0.535,-0.535 1.397,-0.535 1.933,-0 l 3.135,3.135 1.951,1.951 0.229,0.229 c 0.329,0.329 0.858,0.329 1.187,0 0.329,-0.329 0.329,-0.858 -0,-1.187 l -2.181,-2.181 c -0.024,-0.024 -0.05,-0.046 -0.076,-0.066 l -4.246,-4.246 c -0.268,-0.268 -0.617,-0.402 -0.966,-0.402 z"/><path d="m 1294.784,164.627 c -0.349,0 -0.699,0.134 -0.966,0.402 l -5.431,5.432 -0.021,0.021 c -0.148,0.153 -0.24,0.361 -0.24,0.591 h 0.001 v 2.893 1.182 c 0,0.707 0.569,1.276 1.276,1.276 h 1.182 2.262 v -3.618 c 0,-0.178 0.143,-0.321 0.321,-0.321 h 3.224 c 0.178,0 0.321,0.143 0.321,0.321 v 3.618 h 2.272 1.18 c 0.707,0 1.276,-0.569 1.276,-1.276 v -1.181 -2.894 h -0.001 c 0,-0.233 -0.093,-0.443 -0.244,-0.597 l -0.01,-0.01 -5.436,-5.436 c -0.268,-0.268 -0.617,-0.402 -0.966,-0.402 z"/></g></g></svg>`,
  shop: () => html`<svg width="100%" height="100%" viewBox="0 0 11.322 9.794" fill="currentColor" aria-hidden="true"><g transform="translate(-3035.2904,-1321.978)"><g transform="matrix(0.52297311,0,0,0.52297311,2612.2188,1252.0369)"><path d="m 812.241,133.738 c -0.992,0 -1.791,0.799 -1.791,1.791 -0.034,0.069 -1.488,2.963 -1.475,4.327 -0.005,1.418 0.607,2.381 1.475,2.877 1.3,0.742 3.178,0.437 4.436,-0.963 1.573,1.755 3.209,1.752 4.907,-0.011 1.524,1.701 3.173,1.704 4.946,0.011 1.023,1.257 3.009,1.581 4.389,0.824 0.866,-0.475 1.494,-1.374 1.494,-2.738 0,-1.193 -1.448,-4.229 -1.494,-4.327 0,-0.086 -0.009,-0.203 -0.021,-0.286 -0.123,-0.871 -0.864,-1.504 -1.769,-1.504 z"/><path d="m 819.793,143.182 c -1.698,1.763 -3.333,1.766 -4.907,0.011 -1.255,1.396 -3.127,1.703 -4.427,0.967 v 6.513 c 0,0.992 0.799,1.79 1.791,1.79 h 4.831 v -5.076 c 0,-0.25 0.201,-0.451 0.451,-0.451 h 4.522 c 0.25,0 0.451,0.201 0.451,0.451 v 5.076 h 4.843 c 0.992,0 1.791,-0.798 1.791,-1.79 v -6.663 c -0.003,0.002 -0.006,0.004 -0.01,0.006 -1.38,0.757 -3.366,0.434 -4.389,-0.824 -1.773,1.693 -3.422,1.689 -4.946,-0.011 z"/></g></g></svg>`,
  x: () => html`<svg width="100%" height="100%" viewBox="0 0 6.163 6.163" fill="currentColor" aria-hidden="true"><g transform="translate(-2974.2755,-1343.3503)"><g transform="translate(-1343.0628,1236.6336)"><rect x="3131.604" y="-2981.288" width="2.068" height="7.857" ry="1.034" transform="rotate(45)"/><rect x="-2978.393" y="-3136.566" width="2.068" height="7.857" ry="1.034" transform="rotate(135)"/></g></g></svg>`,
  archive: () => html`<svg width="100%" height="100%" viewBox="0 0 7.238 7.857" fill="currentColor" aria-hidden="true"><g transform="translate(-2956.0603,-1341.437)"><g transform="translate(-3327.3161,2617.0253)"><rect x="-6288.029" y="1267.731" width="2.068" height="7.857" ry="1.034" transform="scale(-1)"/><rect x="-2045.748" y="6078.048" width="2.068" height="5.051" ry="1.034" transform="rotate(-120)"/><rect x="4241.247" y="-4811.348" width="2.068" height="5.051" ry="1.034" transform="matrix(0.5,-0.8660254,-0.8660254,-0.5,0,0)"/></g></g></svg>`,
  move: () => html`<svg width="100%" height="100%" viewBox="0 0 8.839 6.255" fill="currentColor" aria-hidden="true"><g transform="translate(-3036.6173,-1343.8233)"><g transform="translate(-2966.7452,2649.7719)"><rect x="-5172.804" y="3325.31" width="2.068" height="5.027" ry="1.034" transform="matrix(-0.70710678,0.70710678,0.70710678,0.70710678,0,0)"/><rect x="-3330.337" y="5167.777" width="2.068" height="5.027" ry="1.034" transform="rotate(-135)"/><rect x="-5169.497" y="3322.003" width="2.068" height="5.027" ry="1.034" transform="matrix(-0.70710678,0.70710678,0.70710678,0.70710678,0,0)"/><rect x="-3327.03" y="5164.47" width="2.068" height="5.027" ry="1.034" transform="rotate(-135)"/></g></g></svg>`,
  pin: () => html`<svg width="100%" height="100%" viewBox="0 0 9.339 9.339" fill="currentColor" aria-hidden="true"><g transform="translate(-3035.5152,-1358.9588)"><g transform="translate(-624.73788,839.34861)"><path d="m 3666.454,519.825 c -0.287,-0.287 -0.748,-0.287 -1.035,0 l -0.678,0.678 c -0.285,0.285 -0.286,0.742 -0.01,1.029 l -1.124,1.124 c 0,0.004 -0.01,0.007 -0.011,0.011 -1.051,-0.395 -2.27,-0.195 -3.152,0.596 -0.074,0.118 -0.06,0.274 0.043,0.376 l 2.282,2.282 -2.41,2.41 c -0.142,0.142 -0.142,0.37 0,0.512 0.142,0.142 0.37,0.142 0.511,0 l 2.41,-2.41 2.282,2.282 c 0.102,0.103 0.258,0.116 0.376,0.043 0.791,-0.882 0.991,-2.101 0.596,-3.152 0,-0.004 0.01,-0.007 0.011,-0.011 l 1.124,-1.124 c 0.287,0.281 0.744,0.279 1.029,-0.006 l 0.678,-0.678 c 0.287,-0.287 0.287,-0.748 0,-1.035 z"/></g></g></svg>`,
  again: () => html`<svg width="100%" height="100%" viewBox="0 0 10.26 10.395" fill="currentColor" aria-hidden="true"><g transform="translate(-3016.4154,-1338.5752)"><path d="m 3018.609,1338.575 c -0.257,0 -0.504,0.177 -0.606,0.314 -0.102,0.136 -0.14,0.233 -0.171,0.281 l -1.143,1.783 a 0.478,0.478 0 0 0 -0.01,0.01 c -0.011,0.017 -0.013,0.037 -0.022,0.055 0,0 -0,0.01 0,0.01 -0.151,0.243 -0.242,0.534 -0.242,0.843 v 5.503 c 0,0.876 0.72,1.596 1.596,1.596 h 7.069 c 0.876,0 1.596,-0.72 1.596,-1.596 v -5.503 c 0,-0.238 -0.109,-0.439 -0.203,-0.643 v -0.01 a 0.478,0.478 0 0 0 -0.074,-0.256 l -1.131,-1.782 c -0.031,-0.049 -0.07,-0.147 -0.172,-0.284 -0.102,-0.137 -0.349,-0.313 -0.606,-0.313 z m 5.768,0.956 c 0.02,0.037 0.035,0.065 0.09,0.152 l 1.055,1.665 v -0.133 a 0.478,0.478 0 0 0 0.033,0.165 h -8.004 l 1.086,-1.692 c 0.056,-0.087 0.07,-0.116 0.09,-0.154 z m -6.999,2.805 h 8.347 v 5.026 c 0,0.363 -0.277,0.639 -0.64,0.639 h -7.068 c -0.363,0 -0.639,-0.276 -0.639,-0.639 z m 4.176,0.977 a 0.478,0.478 0 0 0 -0.478,0.478 v 1.606 l -0.506,-0.506 a 0.478,0.478 0 0 0 -0.676,0 0.478,0.478 0 0 0 0,0.676 l 1.323,1.323 a 0.478,0.478 0 0 0 0.013,0.01 0.478,0.478 0 0 0 0.075,0.057 0.478,0.478 0 0 0 0.018,0.012 0.478,0.478 0 0 0 0.098,0.04 0.478,0.478 0 0 0 0.014,0.01 0.478,0.478 0 0 0 0.12,0.017 0.478,0.478 0 0 0 0.352,-0.154 l 1.307,-1.306 a 0.478,0.478 0 0 0 0,-0.676 0.478,0.478 0 0 0 -0.676,0 l -0.506,0.506 v -1.606 a 0.478,0.478 0 0 0 -0.478,-0.478 z"/></g></svg>`,
  done: () => html`<svg width="100%" height="100%" viewBox="0 0 10.6 10.604" fill="currentColor" aria-hidden="true"><g transform="translate(-2994.9515,-1300.9293)"><path d="m 3000.15,1300.93 c -1.461,0.029 -2.885,0.661 -3.89,1.812 -1.533,1.753 -1.74,4.309 -0.512,6.287 1.229,1.978 3.61,2.924 5.861,2.328 2.251,-0.596 3.853,-2.597 3.941,-4.924 a 0.59,0.59 0 0 0 -0.566,-0.613 0.59,0.59 0 0 0 -0.611,0.568 c -0.069,1.814 -1.31,3.364 -3.064,3.828 -1.754,0.465 -3.601,-0.269 -4.558,-1.811 -0.958,-1.542 -0.796,-3.52 0.398,-4.887 1.194,-1.367 3.135,-1.792 4.791,-1.049 a 0.59,0.59 0 0 0 0.779,-0.297 0.59,0.59 0 0 0 -0.297,-0.779 c -0.531,-0.238 -1.087,-0.385 -1.644,-0.44 -0.209,-0.021 -0.419,-0.028 -0.627,-0.024 z m 4.571,1.611 a 0.632,0.632 0 0 0 -0.348,0.177 l -4.076,4.076 -1.521,-1.521 a 0.632,0.632 0 0 0 -0.894,0 0.632,0.632 0 0 0 0,0.895 l 1.969,1.969 a 0.633,0.633 0 0 0 0.895,0 l 4.523,-4.524 a 0.632,0.632 0 0 0 0,-0.894 0.632,0.632 0 0 0 -0.546,-0.177 z"/></g></svg>`,
  gear: () => html`<svg width="100%" height="100%" viewBox="0 0 9.904 11.118" fill="currentColor" aria-hidden="true"><g transform="translate(-2996.8187,-1339.9974)"><path d="m 3001.771,1339.997 c -1.165,0 -0.965,1.558 -1.973,2.141 -1.009,0.582 -2.258,-0.37 -2.841,0.638 -0.582,1.009 0.867,1.615 0.867,2.779 0,1.165 -1.45,1.771 -0.867,2.779 0.582,1.009 1.832,0.056 2.841,0.638 1.009,0.582 0.809,2.141 1.973,2.141 1.165,0 0.965,-1.558 1.973,-2.141 1.009,-0.582 2.258,0.37 2.841,-0.638 0.582,-1.009 -0.867,-1.615 -0.867,-2.779 0,-1.165 1.45,-1.771 0.867,-2.779 -0.582,-1.009 -1.832,-0.056 -2.841,-0.638 -1.009,-0.582 -0.809,-2.141 -1.973,-2.141 z m 0,3.528 a 2.03,2.03 0 0 1 2.03,2.03 2.03,2.03 0 0 1 -2.03,2.03 2.03,2.03 0 0 1 -2.03,-2.03 2.03,2.03 0 0 1 2.03,-2.03 z"/></g></svg>`,
  search: () => html`<svg width="100%" height="100%" viewBox="0 0 9.34 9.339" fill="currentColor" aria-hidden="true"><g transform="translate(-2951.3477,-1323.9333)"><g transform="translate(2465.6093,1035.8454)"><path d="m 489.632,288.088 a 3.893,3.893 0 0 0 -3.893,3.893 3.893,3.893 0 0 0 3.893,3.893 3.893,3.893 0 0 0 1.845,-0.465 l 1.69,1.69 c 0.439,0.439 1.145,0.439 1.584,0 0.439,-0.439 0.439,-1.145 0,-1.584 l -1.69,-1.69 a 3.893,3.893 0 0 0 0.465,-1.845 3.893,3.893 0 0 0 -3.893,-3.893 z m 0,1.002 a 2.891,2.891 0 0 1 2.891,2.891 2.891,2.891 0 0 1 -0.215,1.092 l -0.004,-0.004 a 2.891,2.891 0 0 1 -1.584,1.584 l 0.004,0.004 a 2.891,2.891 0 0 1 -1.092,0.216 2.891,2.891 0 0 1 -2.891,-2.891 2.891,2.891 0 0 1 2.891,-2.891 z m -1.922,2.681 a 0.367,0.367 0 0 0 -0.391,0.34 c -0.04,0.595 0.181,1.181 0.605,1.601 0.424,0.42 1.01,0.635 1.605,0.59 a 0.367,0.367 0 0 0 0.338,-0.393 0.367,0.367 0 0 0 -0.395,-0.338 c -0.383,0.029 -0.759,-0.109 -1.032,-0.38 -0.273,-0.271 -0.414,-0.647 -0.388,-1.031 a 0.367,0.367 0 0 0 -0.341,-0.389 z"/></g></g></svg>`,
  filter: () => html`<svg width="100%" height="100%" viewBox="0 0 8.945 8.642" fill="currentColor" aria-hidden="true"><g transform="translate(-2973.7149,-1324.1336)"><g transform="matrix(0.77615351,0,0,0.77615351,2696.4867,1410.2158)"><path d="m 360.629,-107.12 a 1.779,1.779 0 0 0 -1.778,1.778 1.779,1.779 0 0 0 1.778,1.779 1.779,1.779 0 0 0 1.779,-1.779 1.779,1.779 0 0 0 -1.779,-1.778 z m 0,0.926 a 0.852,0.852 0 0 1 0.853,0.852 0.852,0.852 0 0 1 -0.853,0.853 0.852,0.852 0 0 1 -0.852,-0.853 0.852,0.852 0 0 1 0.852,-0.852 z"/><path d="m 357.948,-109.94 c -0.424,0 -0.766,0.341 -0.766,0.765 v 0.089 c 0,0.424 0.342,0.765 0.766,0.765 h 5.775 a 0.852,0.852 0 0 1 -0.59,-0.81 0.852,0.852 0 0 1 0.591,-0.81 z m 6.303,0 a 0.852,0.852 0 0 1 0.587,0.81 0.852,0.852 0 0 1 -0.59,0.81 h 3.693 c 0.424,0 0.765,-0.341 0.765,-0.765 v -0.089 c 0,-0.424 -0.341,-0.765 -0.765,-0.765 z"/><path d="m 357.948,-106.151 c -0.424,0 -0.766,0.342 -0.766,0.766 v 0.088 c 0,0.424 0.342,0.765 0.766,0.765 h 2.419 a 0.852,0.852 0 0 1 -0.59,-0.81 0.852,0.852 0 0 1 0.592,-0.81 z m 2.946,0 a 0.852,0.852 0 0 1 0.588,0.81 0.852,0.852 0 0 1 -0.59,0.81 h 7.05 c 0.424,0 0.765,-0.341 0.765,-0.765 v -0.088 c 0,-0.424 -0.341,-0.766 -0.765,-0.766 z"/><path d="m 357.948,-102.363 c -0.424,0 -0.766,0.341 -0.766,0.765 v 0.088 c 0,0.424 0.342,0.766 0.766,0.766 h 7.237 a 0.852,0.852 0 0 1 -0.592,-0.81 0.852,0.852 0 0 1 0.59,-0.81 z m 7.765,0 a 0.852,0.852 0 0 1 0.586,0.81 0.852,0.852 0 0 1 -0.592,0.81 h 2.234 c 0.424,0 0.765,-0.342 0.765,-0.766 v -0.088 c 0,-0.424 -0.341,-0.765 -0.765,-0.765 z"/><path d="m 363.985,-110.909 a 1.779,1.779 0 0 0 -1.779,1.779 1.779,1.779 0 0 0 1.779,1.779 1.779,1.779 0 0 0 1.779,-1.779 1.779,1.779 0 0 0 -1.779,-1.779 z m 0,0.926 a 0.852,0.852 0 0 1 0.853,0.853 0.852,0.852 0 0 1 -0.853,0.853 0.852,0.852 0 0 1 -0.853,-0.853 0.852,0.852 0 0 1 0.853,-0.853 z"/><path d="m 365.446,-103.331 a 1.779,1.779 0 0 0 -1.779,1.779 1.779,1.779 0 0 0 1.779,1.778 1.779,1.779 0 0 0 1.779,-1.778 1.779,1.779 0 0 0 -1.779,-1.779 z m 0,0.926 a 0.852,0.852 0 0 1 0.853,0.853 0.852,0.852 0 0 1 -0.853,0.852 0.852,0.852 0 0 1 -0.853,-0.852 0.852,0.852 0 0 1 0.853,-0.853 z"/></g></g></svg>`,
  share: () => html`<svg width="100%" height="100%" viewBox="0 0 9.339 9.34" fill="currentColor" aria-hidden="true"><g transform="translate(-3017.3021,-1359.9964)"><path d="m 3026.205,1360.431 c -1.053,-1.053 -3.191,0.091 -4.629,0.477 -1.438,0.385 -3.862,0.463 -4.247,1.901 -0.327,1.219 2.494,2.964 3.013,2.445 l 2.237,-2.028 c 0.302,-0.274 0.713,-0.329 0.938,-0.105 0.217,0.217 0.17,0.635 -0.105,0.938 l -2.028,2.237 c -0.577,0.577 1.226,3.34 2.445,3.013 1.438,-0.385 1.516,-2.809 1.901,-4.247 0.386,-1.438 1.53,-3.576 0.477,-4.629 z"/></g></svg>`,
  save: () => html`<svg width="100%" height="100%" viewBox="0 0 6.702 9.335" fill="currentColor" aria-hidden="true"><g transform="translate(-2998.2159,-1359.6182)"><path d="m 2998.815,1359.618 c -0.332,0 -0.598,0.267 -0.598,0.598 v 8.551 c 0,0.065 0.098,0.19 0.282,0.185 0.185,0.01 1.089,-0.742 1.598,-1.624 0.43,-0.745 0.057,-1.622 1.471,-1.622 1.266,0 1.129,1.029 1.471,1.622 0.509,0.882 1.342,1.629 1.61,1.624 0.238,0.01 0.269,-0.12 0.27,-0.185 v -8.551 c 0,-0.331 -0.266,-0.598 -0.598,-0.598 z"/></g></svg>`,
  sun: () => html`<svg width="100%" height="100%" viewBox="0 0 11.748 11.747" fill="currentColor" aria-hidden="true"><g transform="translate(-3035.2857,-1277.1944)"><g transform="matrix(0.56607437,0,0,0.56607437,-819.51472,2136.9158)"><circle cx="6820.145" cy="-1508.367" r="6.35"/><rect x="6818.657" y="-1518.743" width="2.853" height="3.044" ry="1.052"/><rect x="6818.657" y="-1501.034" width="2.853" height="3.044" ry="1.052"/><rect x="5150.755" y="-4726.702" width="2.853" height="3.044" ry="1.052" transform="rotate(30)"/><rect x="5150.755" y="-4708.993" width="2.853" height="3.044" ry="1.052" transform="rotate(30)"/><rect x="2102.331" y="-6670.925" width="2.853" height="3.044" ry="1.052" transform="rotate(60)"/><rect x="2102.331" y="-6653.216" width="2.853" height="3.044" ry="1.052" transform="rotate(60)"/><rect x="-1509.793" y="-6830.459" width="2.853" height="3.044" ry="1.052" transform="rotate(90)"/><rect x="-1509.793" y="-6812.751" width="2.853" height="3.044" ry="1.052" transform="rotate(90)"/><rect x="-4717.752" y="-5162.558" width="2.853" height="3.044" ry="1.052" transform="rotate(120)"/><rect x="-4717.752" y="-5144.85" width="2.853" height="3.044" ry="1.052" transform="rotate(120)"/><rect x="-6661.975" y="-2114.134" width="2.853" height="3.044" ry="1.052" transform="rotate(150)"/><rect x="-6661.975" y="-2096.425" width="2.853" height="3.044" ry="1.052" transform="rotate(150)"/></g></g></svg>`,
  newFolder: () => html`<svg width="76" height="56" viewBox="0 0 12.718 9.075" fill="currentColor" aria-hidden="true"><g transform="translate(-2995.1018,-1321.9776)"><path d="m 2996.095,1321.978 c -0.55,0 -0.993,0.443 -0.993,0.993 v 2.482 3.384 0.571 c 0,0.912 0.734,1.645 1.645,1.645 h 9.426 c 0.912,0 1.646,-0.734 1.646,-1.645 v -3.955 c 0,-0.912 -0.734,-1.645 -1.646,-1.645 h -2.085 c -0.494,0 -0.92,-0.662 -1.189,-1.055 -0.257,-0.376 -0.494,-0.775 -0.969,-0.775 z m 4.533,2.949 c 0.336,0 0.607,0.271 0.607,0.607 v 1.019 h 1.019 c 0.336,0 0.607,0.271 0.607,0.607 0,0.336 -0.271,0.607 -0.607,0.607 h -1.019 v 1.019 c 0,0.336 -0.271,0.607 -0.607,0.607 -0.336,0 -0.607,-0.271 -0.607,-0.607 v -1.019 h -1.02 c -0.336,0 -0.606,-0.271 -0.606,-0.607 0,-0.336 0.27,-0.607 0.606,-0.607 h 1.02 v -1.019 c 0,-0.336 0.271,-0.607 0.607,-0.607 z"/></g></svg>`,
  google: () => html`<svg width="100%" height="100%" viewBox="0 0 13.258 13.529" aria-hidden="true"><g transform="translate(-3012.921,-1299.2855)"><g transform="matrix(0.05181444,0,0,0.05181444,3012.9209,1299.2854)"><path d="m 255.878,133.451 c 0,-10.734 -0.871,-18.567 -2.756,-26.69 H 130.55 v 48.448 h 71.947 c -1.45,12.04 -9.283,30.172 -26.69,42.356 l -0.244,1.622 38.755,30.023 2.685,0.268 c 24.659,-22.774 38.875,-56.282 38.875,-96.027" fill="#4285f4"/><path d="m 130.55,261.1 c 35.248,0 64.839,-11.605 86.453,-31.622 l -41.196,-31.913 c -11.024,7.688 -25.82,13.055 -45.257,13.055 -34.523,0 -63.824,-22.773 -74.269,-54.25 l -1.531,0.13 -40.298,31.187 -0.527,1.465 C 35.393,231.798 79.49,261.1 130.55,261.1" fill="#34a853"/><path d="m 56.281,156.37 c -2.756,-8.123 -4.351,-16.827 -4.351,-25.82 0,-8.994 1.595,-17.697 4.206,-25.82 L 56.063,103 15.26,71.312 13.925,71.947 C 5.077,89.644 0,109.517 0,130.55 c 0,21.033 5.077,40.905 13.925,58.602 L 56.281,156.37" fill="#fbbc05"/><path d="m 130.55,50.479 c 24.514,0 41.05,10.589 50.479,19.438 L 217.873,33.943 C 195.245,12.91 165.798,0 130.55,0 79.49,0 35.393,29.301 13.925,71.947 L 56.136,104.73 C 66.726,73.253 96.027,50.479 130.55,50.479" fill="#eb4335"/></g></g></svg>`,
  apple: () => html`<svg width="100%" height="100%" viewBox="0 0 11.044 13.564" fill="currentColor" aria-hidden="true"><g transform="translate(-3034.5918,-1297.8149)"><path d="m 3045.282,1302.439 c -0.079,0.061 -1.468,0.844 -1.468,2.584 0,2.013 1.767,2.725 1.82,2.743 -0.01,0.043 -0.281,0.975 -0.932,1.925 -0.581,0.836 -1.187,1.67 -2.109,1.67 -0.922,0 -1.16,-0.536 -2.225,-0.536 -1.038,0 -1.407,0.553 -2.251,0.553 -0.844,0 -1.433,-0.773 -2.109,-1.723 -0.784,-1.115 -1.417,-2.847 -1.417,-4.492 0,-2.637 1.715,-4.036 3.402,-4.036 0.897,0 1.644,0.589 2.207,0.589 0.536,0 1.371,-0.624 2.392,-0.624 0.387,0 1.776,0.035 2.69,1.346 z m -3.174,-2.462 c 0.422,-0.501 0.72,-1.195 0.72,-1.89 0,-0.096 -0.01,-0.194 -0.025,-0.273 -0.686,0.026 -1.503,0.457 -1.996,1.028 -0.387,0.44 -0.748,1.134 -0.748,1.838 0,0.106 0.017,0.212 0.025,0.246 0.044,0.01 0.114,0.018 0.184,0.018 0.616,0 1.391,-0.412 1.838,-0.967 z"/></g></svg>`,
  flame: (w = 14, h = 16) => html`<svg width=${w} height=${h} viewBox="0 0 24 24" fill="#D35F5F" aria-hidden="true"><path d="M12 2c1.2 4 6 6.2 6 11.5A6 6 0 0 1 6 13.5c0-2.6 1.2-4.3 2.6-5.6.3 1.9 1.4 3 2.6 3.3C11 8.6 10.6 5.4 12 2z"/></svg>`,
  shield: (w = 22, h = 26, used = false) => html`<svg width=${w} height=${h} viewBox="0 0 24 28" aria-hidden="true"><path d="M12 1 22 5v8c0 6.5-4.3 11.3-10 14C6.3 24.3 2 19.5 2 13V5z" fill=${used ? 'none' : '#80AEFF'} stroke="#80AEFF" stroke-width=${used ? 2 : 0}/></svg>`,
  plus: (s = 30, sw = 3.2) => html`<svg width=${s} height=${s} viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width=${sw} stroke-linecap="round" aria-hidden="true"><path d="M12 4.5v15M4.5 12h15"/></svg>`,
  speaker: () => html`<svg width="30" height="30" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 9.5v5h3.5L12 18.5v-13L7.5 9.5H4z" fill="currentColor"/><path d="M15.5 9a4.2 4.2 0 0 1 0 6"/><path d="M18 6.5a7.8 7.8 0 0 1 0 11"/></svg>`,
  undo: () => html`<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M9 14 4 9l5-5"/><path d="M4 9h10.5a5.5 5.5 0 0 1 0 11H11"/></svg>`,
  back: () => html`<svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M15 18 9 12l6-6"/></svg>`,
  eye: () => html`<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/></svg>`,
  note: () => html`<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 5h16v11H9l-5 4z"/><path d="M8 9.5h8M8 12.5h5"/></svg>`
};

// ---------- sound (procedural, Web Audio) and haptics ----------
export const fx = {
  ctx: null,
  on: true,
  haptic: true,
  ensure() {
    if (!this.ctx) {
      try { this.ctx = new (window.AudioContext || window.webkitAudioContext)(); } catch (e) { this.ctx = null; }
    }
    if (this.ctx && this.ctx.state === 'suspended') this.ctx.resume();
    return this.ctx;
  },
  tone(freq, dur, type, vol, when, glideTo) {
    const c = this.ensure();
    if (!c) return;
    const t = c.currentTime + (when || 0);
    const o = c.createOscillator();
    const g = c.createGain();
    o.type = type || 'sine';
    o.frequency.setValueAtTime(freq, t);
    if (glideTo) o.frequency.exponentialRampToValueAtTime(glideTo, t + dur);
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(vol || 0.12, t + 0.008);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    o.connect(g).connect(c.destination);
    o.start(t);
    o.stop(t + dur + 0.02);
  },
  click() { if (this.on) this.tone(1180, 0.05, 'triangle', 0.07); },
  good() { if (this.on) { this.tone(660, 0.09, 'triangle', 0.09); this.tone(990, 0.12, 'triangle', 0.07, 0.06); } },
  thud() { if (this.on) this.tone(190, 0.18, 'sine', 0.16, 0, 90); },
  pop() { if (this.on) this.tone(520, 0.07, 'sine', 0.08, 0, 780); },
  fanfare() {
    if (!this.on) return;
    [523.25, 659.25, 783.99, 1046.5].forEach((f, i) => this.tone(f, 0.32, 'triangle', 0.09, i * 0.11));
    this.tone(1318.5, 0.6, 'sine', 0.05, 0.48);
  },
  buzz(ms) {
    if (!this.haptic) return;
    try { navigator.vibrate && navigator.vibrate(ms); } catch (e) {}
  }
};

export function speak(text, lang, onEnd) {
  try {
    const s = window.speechSynthesis;
    if (!s || !lang) { setTimeout(onEnd, 700); return; }
    s.cancel();
    const u = new SpeechSynthesisUtterance(text.replace(/\s·\s.*$/, ''));
    u.lang = lang;
    u.rate = 0.9;
    const voice = s.getVoices().find((v) => v.lang && v.lang.toLowerCase().startsWith(lang.slice(0, 2).toLowerCase()));
    if (voice) u.voice = voice;
    u.onend = onEnd;
    u.onerror = onEnd;
    s.speak(u);
    setTimeout(onEnd, 4000);
  } catch (e) {
    setTimeout(onEnd, 700);
  }
}

// ---------- shared pieces ----------
export function Nav({ app, current }) {
  return html`<nav class="nav" aria-label="Main">
    <button class="nav-btn" aria-label="Home" aria-current=${current === 'home' ? 'page' : null} onClick=${() => app.home()}><span style="width:44px;height:44px">${Ico.home()}</span></button>
    <button class="nav-plus" aria-label="Create a card" onClick=${() => app.create()}><span class="diamond"></span><span class="plus">${Ico.plus()}</span></button>
    <button class="nav-btn" aria-label="Shop" aria-current=${current === 'shop' ? 'page' : null} onClick=${() => app.go('shop')}><span style="width:48px;height:42px">${Ico.shop()}</span></button>
  </nav>`;
}

export function Toggle({ on, label, onFlip }) {
  return html`<button type="button" class=${cx('switch', on && 'on')} role="switch" aria-checked=${on ? 'true' : 'false'} aria-label=${label} onClick=${onFlip}><span class="knob"></span></button>`;
}

export function Seg({ options, value, onPick, label, cls }) {
  return html`<div class=${cx('seg', cls)} role="radiogroup" aria-label=${label} style=${'grid-template-columns:repeat(' + options.length + ',minmax(0,1fr))'}>
    ${options.map((o) => html`<button type="button" key=${o} role="radio" aria-checked=${o === value ? 'true' : 'false'} class=${o === value ? 'on' : ''} onClick=${() => onPick(o)}>${o}</button>`)}
  </div>`;
}

export function Grip() {
  return html`<div class="grip" aria-hidden="true"></div>`;
}
