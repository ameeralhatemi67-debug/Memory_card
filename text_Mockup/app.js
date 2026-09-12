/**
 * MEMORY CARD — LIVING DESIGN SYSTEM & INTERACTIVE GESTURE ENGINE
 * High-Fidelity Web Mockup & Gesture Simulation Lab
 */

// ==========================================================================
// 1. EMBEDDED 20 CUSTOM SVG GLYPHS (FROM ../icons/ DEFINITIONS)
// ==========================================================================
const AppIcons = {
  logoDarkMode: `<svg viewBox="0 0 11.21 14.18" width="22" height="22"><g transform="translate(-2960.94,-1288.69)"><g transform="translate(106.79,301.97)"><rect fill="#c0c0c0" width="6.93" height="11.21" x="2854.15" y="986.72" rx="0.53"/><rect fill="#d9d9d9" width="6.93" height="11.21" x="3014.99" y="213.75" rx="0.53" transform="rotate(15)"/><rect fill="#f1f1f1" width="6.93" height="11.21" x="2970.41" y="-574.21" rx="0.53" transform="rotate(30)"/></g></g></svg>`,
  logoLightMode: `<svg viewBox="0 0 11.21 14.18" width="22" height="22"><g transform="translate(-2960.94,-1288.69)"><g transform="translate(106.79,301.97)"><rect fill="#2a2a2a" width="6.93" height="11.21" x="2854.15" y="986.72" rx="0.53"/><rect fill="#454545" width="6.93" height="11.21" x="3014.99" y="213.75" rx="0.53" transform="rotate(15)"/><rect fill="#606060" width="6.93" height="11.21" x="2970.41" y="-574.21" rx="0.53" transform="rotate(30)"/></g></g></svg>`,
  folder: `<svg viewBox="0 0 12.72 9.07" width="22" height="22"><g transform="translate(-2995.1,-1321.98)"><path fill="currentColor" d="m 2996.09,1321.98 c -0.55,0 -0.99,0.44 -0.99,0.99 v 6.44 c 0,0.91 0.73,1.65 1.65,1.65 h 9.43 c 0.91,0 1.65,-0.74 1.65,-1.65 v -3.95 c 0,-0.91 -0.73,-1.65 -1.65,-1.65 h -2.08 c -0.49,0 -0.92,-0.66 -1.19,-1.05 -0.26,-0.38 -0.49,-0.77 -0.97,-0.77 z m 4.53,2.95 c 0.34,0 0.61,0.27 0.61,0.61 v 1.02 h 1.02 c 0.34,0 0.61,0.27 0.61,0.61 0,0.34 -0.27,0.61 -0.61,0.61 h -1.02 v 1.02 c 0,0.34 -0.27,0.61 -0.61,0.61 -0.34,0 -0.61,-0.27 -0.61,-0.61 v -1.02 h -1.02 c -0.34,0 -0.61,-0.27 -0.61,-0.61 0,-0.34 0.27,-0.61 0.61,-0.61 h 1.02 v -1.02 c 0,-0.34 0.27,-0.61 0.61,-0.61 z"/></g></svg>`,
  home: `<svg viewBox="0 0 11.32 11.32" width="22" height="22"><g transform="translate(-3015.35,-1319.9)"><g transform="matrix(0.7337,0,0,0.7337,2071.03,1201.78)"><path fill="currentColor" d="m 1294.78,160.99 c -0.35,0 -0.7,0.13 -0.97,0.4 l -4.25,4.25 c -0.03,0.02 -0.05,0.04 -0.07,0.07 l -2.18,2.18 c -0.33,0.33 -0.33,0.86 0,1.19 0.33,0.33 0.86,0.33 1.19,0 l 0.08,-0.08 2.1,-2.1 3.13,-3.13 c 0.54,-0.54 1.4,-0.54 1.93,0 l 3.14,3.13 1.95,1.95 0.23,0.23 c 0.33,0.33 0.86,0.33 1.19,0 0.33,-0.33 0.33,-0.86 0,-1.19 l -2.18,-2.18 c -0.02,-0.02 -0.05,-0.05 -0.08,-0.07 l -4.25,-4.25 c -0.27,-0.27 -0.62,-0.4 -0.97,-0.4 z"/><path fill="currentColor" d="m 1294.78,164.63 c -0.35,0 -0.7,0.13 -0.97,0.4 l -5.43,5.43 c -0.15,0.15 -0.24,0.36 -0.24,0.59 v 4.08 c 0,0.71 0.57,1.28 1.28,1.28 h 3.44 v -3.62 c 0,-0.18 0.14,-0.32 0.32,-0.32 h 3.22 c 0.18,0 0.32,0.14 0.32,0.32 v 3.62 h 3.45 c 0.71,0 1.28,-0.57 1.28,-1.28 v -4.08 c 0,-0.23 -0.09,-0.44 -0.24,-0.6 l -5.44,-5.44 c -0.27,-0.27 -0.62,-0.4 -0.97,-0.4 z"/></g></g></svg>`,
  shop: `<svg viewBox="0 0 11.32 9.79" width="22" height="22"><g transform="translate(-3035.29,-1321.98)"><g transform="matrix(0.523,0,0,0.523,2612.22,1252.04)"><path fill="currentColor" d="m 812.24,133.74 c -0.99,0 -1.79,0.8 -1.79,1.79 0,0.07 -1.49,2.96 -1.48,4.33 0,1.42 0.61,2.38 1.48,2.88 1.3,0.74 3.18,0.44 4.44,-0.96 1.57,1.76 3.21,1.75 4.91,0 1.52,1.7 3.17,1.7 4.95,0 1.02,1.26 3.01,1.58 4.39,0.82 0.87,-0.48 1.49,-1.37 1.49,-2.74 0,-1.19 -1.45,-4.23 -1.49,-4.33 0,-0.09 -0.01,-0.2 -0.02,-0.29 -0.12,-0.87 -0.86,-1.5 -1.77,-1.5 z"/><path fill="currentColor" d="m 819.79,143.18 c -1.7,1.76 -3.33,1.77 -4.91,0 -1.26,1.4 -3.13,1.7 -4.43,0.97 v 6.51 c 0,0.99 0.8,1.79 1.79,1.79 h 4.83 v -5.08 c 0,-0.25 0.2,-0.45 0.45,-0.45 h 4.52 c 0.25,0 0.45,0.2 0.45,0.45 v 5.08 h 4.84 c 0.99,0 1.79,-0.8 1.79,-1.79 v -6.66 c -1.38,0.76 -3.37,0.43 -4.39,-0.82 -1.77,1.69 -3.42,1.69 -4.95,0 z"/></g></g></svg>`,
  burggerDotes: `<svg viewBox="0 0 2.44 8.91" width="16" height="22"><g transform="translate(-2998.77,-1277.11)"><g transform="translate(-455.16,250.69)"><circle fill="currentColor" cx="3455.15" cy="1034.11" r="1.22"/><circle fill="currentColor" cx="3455.15" cy="1030.87" r="1.22"/><circle fill="currentColor" cx="3455.15" cy="1027.64" r="1.22"/></g></g></svg>`,
  settings: `<svg viewBox="0 0 9.9 11.12" width="22" height="22"><g transform="translate(-2996.82,-1340.0)"><path fill="currentColor" d="m 3001.77,1340.0 c -1.16,0 -0.96,1.56 -1.97,2.14 -1.01,0.58 -2.26,-0.37 -2.84,0.64 -0.58,1.01 0.87,1.61 0.87,2.78 0,1.16 -1.45,1.77 -0.87,2.78 0.58,1.01 1.83,0.06 2.84,0.64 1.01,0.58 0.81,2.14 1.97,2.14 1.16,0 0.96,-1.56 1.97,-2.14 1.01,-0.58 2.26,0.37 2.84,-0.64 0.58,-1.01 -0.87,-1.61 -0.87,-2.78 0,-1.16 1.45,-1.77 0.87,-2.78 -0.58,-1.01 -1.83,-0.06 -2.84,-0.64 -1.01,-0.58 -0.81,-2.14 -1.97,-2.14 z m 0,3.53 a 2.03,2.03 0 1 1 0,4.06 2.03,2.03 0 0 1 0,-4.06 z"/></g></svg>`,
  sun: `<svg viewBox="0 0 11.75 11.75" width="22" height="22"><g transform="translate(-3035.29,-1277.19)"><g transform="matrix(0.566,0,0,0.566,-819.51,2136.92)"><circle fill="currentColor" cx="6820.15" cy="-1508.37" r="6.35"/><rect fill="currentColor" width="2.85" height="3.04" x="6818.66" y="-1518.74" rx="1.05"/><rect fill="currentColor" width="2.85" height="3.04" x="6818.66" y="-1501.03" rx="1.05"/><rect fill="currentColor" width="2.85" height="3.04" x="5150.76" y="-4726.70" rx="1.05" transform="rotate(30)"/><rect fill="currentColor" width="2.85" height="3.04" x="2102.33" y="-6670.92" rx="1.05" transform="rotate(60)"/><rect fill="currentColor" width="2.85" height="3.04" x="-1509.79" y="-6830.46" rx="1.05" transform="rotate(90)"/><rect fill="currentColor" width="2.85" height="3.04" x="-4717.75" y="-5162.56" rx="1.05" transform="rotate(120)"/><rect fill="currentColor" width="2.85" height="3.04" x="-6661.98" y="-2114.13" rx="1.05" transform="rotate(150)"/></g></g></svg>`,
  search: `<svg viewBox="0 0 9.34 9.34" width="22" height="22"><g transform="translate(-2951.35,-1323.93)"><g transform="translate(2465.61,1035.85)"><path fill="currentColor" d="m 489.63,288.09 a 3.89,3.89 0 0 0 -3.89,3.89 3.89,3.89 0 0 0 3.89,3.89 3.89,3.89 0 0 0 1.84,-0.47 l 1.69,1.69 c 0.44,0.44 1.14,0.44 1.58,0 0.44,-0.44 0.44,-1.14 0,-1.58 l -1.69,-1.69 a 3.89,3.89 0 0 0 0.46,-1.84 3.89,3.89 0 0 0 -3.89,-3.89 z m 0,1 a 2.89,2.89 0 0 1 2.89,2.89 2.89,2.89 0 0 1 -0.22,1.09 l -1.58,1.58 a 2.89,2.89 0 0 1 -1.09,0.22 2.89,2.89 0 0 1 -2.89,-2.89 2.89,2.89 0 0 1 2.89,-2.89 z"/></g></g></svg>`,
  filter: `<svg viewBox="0 0 8.94 8.64" width="22" height="22"><g transform="translate(-2973.71,-1324.13)"><g transform="matrix(0.776,0,0,0.776,2696.49,1410.22)"><path fill="currentColor" d="m 360.63,-107.12 a 1.78,1.78 0 1 0 0,3.56 1.78,1.78 0 0 0 0,-3.56 z m 0,0.93 a 0.85,0.85 0 1 1 0,1.7 0.85,0.85 0 0 1 0,-1.7 z"/><path fill="currentColor" d="m 357.95,-109.94 c -0.42,0 -0.77,0.34 -0.77,0.77 v 0.09 c 0,0.42 0.34,0.77 0.77,0.77 h 5.77 a 0.85,0.85 0 0 1 0,-1.62 z m 6.3,0 a 0.85,0.85 0 0 1 0,1.62 h 3.69 c 0.42,0 0.77,-0.34 0.77,-0.77 v -0.09 c 0,-0.42 -0.34,-0.77 -0.77,-0.77 z"/><path fill="currentColor" d="m 357.95,-106.15 c -0.42,0 -0.77,0.34 -0.77,0.77 v 0.09 c 0,0.42 0.34,0.77 0.77,0.77 h 2.42 a 0.85,0.85 0 0 1 0,-1.62 z m 2.95,0 a 0.85,0.85 0 0 1 0,1.62 h 7.05 c 0.42,0 0.77,-0.34 0.77,-0.77 v -0.09 c 0,-0.42 -0.34,-0.77 -0.77,-0.77 z"/></g></g></svg>`,
  box: `<svg viewBox="0 0 10.26 10.4" width="22" height="22"><g transform="translate(-3016.42,-1338.58)"><path fill="currentColor" d="m 3018.61,1338.58 c -0.26,0 -0.5,0.18 -0.61,0.31 l -1.14,1.78 c -0.15,0.24 -0.24,0.53 -0.24,0.84 v 5.5 c 0,0.88 0.72,1.6 1.6,1.6 h 7.07 c 0.88,0 1.6,-0.72 1.6,-1.6 v -5.5 c 0,-0.24 -0.11,-0.44 -0.2,-0.64 l -1.13,-1.78 c -0.1,-0.14 -0.35,-0.31 -0.61,-0.31 z m 5.77,0.96 l 1.06,1.67 h -8.01 l 1.09,-1.69 z m -6.99,2.8 h 8.35 v 5.03 c 0,0.36 -0.28,0.64 -0.64,0.64 h -7.07 c -0.36,0 -0.64,-0.28 -0.64,-0.64 z"/></g></svg>`,
  done: `<svg viewBox="0 0 10.6 10.6" width="22" height="22"><g transform="translate(-2994.95,-1300.93)"><path fill="currentColor" d="m 3000.15,1300.93 c -1.46,0.03 -2.88,0.66 -3.89,1.81 -1.53,1.75 -1.74,4.31 -0.51,6.29 1.23,1.98 3.61,2.92 5.86,2.33 2.25,-0.6 3.85,-2.6 3.94,-4.92 a 0.59,0.59 0 0 0 -0.57,-0.61 0.59,0.59 0 0 0 -0.61,0.57 c -0.07,1.81 -1.31,3.36 -3.06,3.83 -1.75,0.46 -3.6,-0.27 -4.56,-1.81 -0.96,-1.54 -0.8,-3.52 0.4,-4.89 1.19,-1.37 3.13,-1.79 4.79,-1.05 a 0.59,0.59 0 0 0 0.78,-0.3 0.59,0.59 0 0 0 -0.3,-0.78 c -0.53,-0.24 -1.09,-0.38 -1.64,-0.44 z m 4.57,1.61 a 0.63,0.63 0 0 0 -0.35,0.18 l -4.08,4.08 -1.52,-1.52 a 0.63,0.63 0 0 0 -0.89,0 0.63,0.63 0 0 0 0,0.89 l 1.97,1.97 a 0.63,0.63 0 0 0 0.89,0 l 4.52,-4.52 a 0.63,0.63 0 0 0 0,-0.89 0.63,0.63 0 0 0 -0.54,-0.18 z"/></g></svg>`,
  delete: `<svg viewBox="0 0 6.16 6.16" width="22" height="22"><g transform="translate(-2974.28,-1343.35)"><g transform="translate(-1343.06,1236.63)"><rect fill="currentColor" width="2.07" height="7.86" x="3131.60" y="-2981.29" rx="1.03" transform="rotate(45)"/><rect fill="currentColor" width="2.07" height="7.86" x="-2978.39" y="-3136.57" rx="1.03" transform="rotate(135)"/></g></g></svg>`,
  archive: `<svg viewBox="0 0 7.24 7.86" width="22" height="22"><g transform="translate(-2956.06,-1341.44)"><g transform="translate(-3327.32,2617.03)"><rect fill="currentColor" width="2.07" height="7.86" x="-6288.03" y="1267.73" rx="1.03" transform="scale(-1)"/><rect fill="currentColor" width="2.07" height="5.05" x="-2045.75" y="6078.05" rx="1.03" transform="rotate(-120)"/><rect fill="currentColor" width="2.07" height="5.05" x="4241.25" y="-4811.35" rx="1.03" transform="matrix(0.5,-0.866,-0.866,-0.5,0,0)"/></g></g></svg>`,
  move: `<svg viewBox="0 0 8.84 6.26" width="22" height="22"><g transform="translate(-3036.62,-1343.82)"><g transform="translate(-2966.75,2649.77)"><rect fill="currentColor" width="2.07" height="5.03" x="-5172.8" y="3325.31" rx="1.03" transform="matrix(-0.707,0.707,0.707,0.707,0,0)"/><rect fill="currentColor" width="2.07" height="5.03" x="-3330.34" y="5167.78" rx="1.03" transform="rotate(-135)"/><rect fill="currentColor" width="2.07" height="5.03" x="-5169.5" y="3322.0" rx="1.03" transform="matrix(-0.707,0.707,0.707,0.707,0,0)"/><rect fill="currentColor" width="2.07" height="5.03" x="-3327.03" y="5164.47" rx="1.03" transform="rotate(-135)"/></g></g></svg>`,
  pin: `<svg viewBox="0 0 9.34 9.34" width="22" height="22"><g transform="translate(-3035.52,-1358.96)"><g transform="translate(-624.74,839.35)"><path fill="currentColor" d="m 3666.45,519.83 c -0.29,-0.29 -0.75,-0.29 -1.03,0 l -0.68,0.68 c -0.28,0.28 -0.29,0.74 -0.01,1.03 l -1.12,1.12 c -1.05,-0.39 -2.27,-0.2 -3.15,0.6 -0.07,0.12 -0.06,0.27 0.04,0.38 l 2.28,2.28 -2.41,2.41 c -0.14,0.14 -0.14,0.37 0,0.51 0.14,0.14 0.37,0.14 0.51,0 l 2.41,-2.41 2.28,2.28 c 0.1,0.1 0.26,0.12 0.38,0.04 0.79,-0.88 0.99,-2.1 0.6,-3.15 l 1.12,-1.12 c 0.29,0.28 0.74,0.28 1.03,-0.01 l 0.68,-0.68 c 0.29,-0.29 0.29,-0.75 0,-1.03 z"/></g></g></svg>`,
  share: `<svg viewBox="0 0 9.34 9.34" width="22" height="22"><g transform="translate(-3017.3,-1360.0)"><path fill="currentColor" d="m 3026.2,1360.43 c -1.05,-1.05 -3.19,0.09 -4.63,0.48 -1.44,0.39 -3.86,0.46 -4.25,1.9 -0.33,1.22 2.49,2.96 3.01,2.44 l 2.24,-2.03 c 0.3,-0.27 0.71,-0.33 0.94,-0.1 0.22,0.22 0.17,0.64 -0.1,0.94 l -2.03,2.24 c -0.58,0.58 1.23,3.34 2.44,3.01 1.44,-0.39 1.52,-2.81 1.9,-4.25 0.39,-1.44 1.53,-3.58 0.48,-4.63 z"/></g></svg>`,
  save: `<svg viewBox="0 0 6.7 9.34" width="22" height="22"><g transform="translate(-2998.22,-1359.62)"><path fill="currentColor" d="m 2998.81,1359.62 c -0.33,0 -0.6,0.27 -0.6,0.6 v 8.55 c 0,0.07 0.1,0.19 0.28,0.19 0.19,0.01 1.09,-0.74 1.6,-1.62 0.43,-0.74 0.06,-1.62 1.47,-1.62 1.27,0 1.13,1.03 1.47,1.62 0.51,0.88 1.34,1.63 1.61,1.62 0.24,0.01 0.27,-0.12 0.27,-0.18 v -8.55 c 0,-0.33 -0.27,-0.6 -0.6,-0.6 z"/></g></svg>`,
  apple: `<svg viewBox="0 0 11.04 13.56" width="22" height="22"><g transform="translate(-3034.59,-1297.81)"><path fill="currentColor" d="m 3045.28,1302.44 c -0.08,0.06 -1.47,0.84 -1.47,2.58 0,2.01 1.77,2.73 1.82,2.74 -0.01,0.04 -0.28,0.98 -0.93,1.93 -0.58,0.84 -1.19,1.67 -2.11,1.67 -0.92,0 -1.16,-0.54 -2.22,-0.54 -1.04,0 -1.41,0.55 -2.25,0.55 -0.84,0 -1.43,-0.77 -2.11,-1.72 -0.78,-1.12 -1.42,-2.85 -1.42,-4.49 0,-2.64 1.71,-4.04 3.4,-4.04 0.9,0 1.64,0.59 2.21,0.59 0.54,0 1.37,-0.62 2.39,-0.62 0.39,0 1.78,0.04 2.69,1.35 z m -3.17,-2.46 c 0.42,-0.5 0.72,-1.2 0.72,-1.89 0,-0.1 -0.01,-0.19 -0.03,-0.27 -0.69,0.03 -1.5,0.46 -2,1.03 -0.39,0.44 -0.75,1.13 -0.75,1.84 0,0.11 0.02,0.21 0.03,0.25 0.04,0.01 0.11,0.02 0.18,0.02 0.62,0 1.39,-0.41 1.84,-0.97 z"/></g></svg>`,
  google: `<svg viewBox="0 0 13.26 13.53" width="22" height="22"><g transform="translate(-3012.92,-1299.29)"><g transform="matrix(0.0518,0,0,0.0518,3012.92,1299.29)"><path d="m 255.88,133.45 c 0,-10.73 -0.87,-18.57 -2.76,-26.69 H 130.55 v 48.45 h 71.95 c -1.45,12.04 -9.28,30.17 -26.69,42.36 l 38.76,30.02 c 24.66,-22.77 38.88,-56.28 38.88,-96.03" fill="#4285f4"/><path d="m 130.55,261.1 c 35.25,0 64.84,-11.61 86.45,-31.62 l -41.2,-31.91 c -11.02,7.69 -25.82,13.06 -45.26,13.06 -34.52,0 -63.82,-22.77 -74.27,-54.25 l -40.3,31.19 c 21.46,42.48 65.56,71.78 114.58,71.78" fill="#34a853"/><path d="m 56.28,156.37 c -2.76,-8.12 -4.35,-16.83 -4.35,-25.82 0,-8.99 1.6,-17.7 4.21,-25.82 l -40.88,-33.42 C 5.08,89.64 0,109.52 0,130.55 c 0,21.03 5.08,40.91 13.93,58.6 l 42.35,-32.78" fill="#fbbc05"/><path d="m 130.55,50.48 c 24.51,0 41.05,10.59 50.48,19.44 L 217.87,33.94 C 195.25,12.91 165.8,0 130.55,0 79.49,0 35.39,29.3 13.93,71.95 L 56.14,104.73 C 66.73,73.25 96.03,50.48 130.55,50.48" fill="#eb4335"/></g></g></svg>`
};

// ==========================================================================
// 2. STATE & GLOBAL CONFIGURATION
// ==========================================================================
const state = {
  activeTab: 'overview',
  theme: 'dark',
  audioEnabled: true,
  cardRevealMode: 'transform',
  isCardRevealed: false,
  cardIndex: 0,
  deleteFearMode: false,
  folders: [
    { id: 'f0', name: 'Languages', decks: 4, cards: 182, tabs: ['pill-blue', 'pill-yellow', 'pill-coral'] },
    { id: 'f1', name: 'German Words', decks: 3, cards: 95, tabs: ['pill-yellow', 'pill-coral', 'pill-blue'] },
    { id: 'f2', name: 'Coding Syntax', decks: 3, cards: 120, tabs: ['pill-coral', 'pill-blue', 'pill-yellow'] },
    { id: 'f3', name: 'Archive', decks: 2, cards: 64, tabs: ['pill-blue', 'pill-coral', 'pill-yellow'] },
    { id: 'f4', name: 'Medical Anatomy', decks: 5, cards: 210, tabs: ['pill-yellow', 'pill-blue', 'pill-coral'] },
    { id: 'f5', name: 'World History', decks: 4, cards: 140, tabs: ['pill-coral', 'pill-yellow', 'pill-blue'] },
    { id: 'f6', name: 'Law & Ethics', decks: 3, cards: 88, tabs: ['pill-blue', 'pill-coral', 'pill-yellow'] },
    { id: 'f7', name: 'Mathematics', decks: 6, cards: 310, tabs: ['pill-yellow', 'pill-coral', 'pill-blue'] },
    { id: 'f8', name: 'Philosophy', decks: 2, cards: 54, tabs: ['pill-coral', 'pill-blue', 'pill-yellow'] }
  ],
  // Track last 3 interacted folder IDs (starts with first 3 folders: f0, f1, f2)
  recentFolderIds: ['f0', 'f1', 'f2'],
  dragFolder: {
    isDragging: false,
    element: null,
    startIndex: -1,
    currentY: 0,
    pressTimer: null
  },
  gesture: {
    isDragging: false,
    startX: 0,
    startY: 0,
    currentX: 0,
    currentY: 0,
    cardWidth: 320,
    dragThreshold40: 128,
    commitThreshold60: 192,
  },
  sampleCards: [
    { front: "Das Eichhörnchen", meta: "[noun, neuter]", back: "The Squirrel", sentence: "Das Eichhörnchen klettert flink auf den Baum.", mnemonic: "Picture an oak horn on a squirrel." },
    { front: "Die Gemütlichkeit", meta: "[noun, feminine]", back: "Cozy warmth / Congeniality", sentence: "Ein Abend am Kamin voller Gemütlichkeit.", mnemonic: "Imagine relaxing in a warm mute-room with tea." },
    { front: "Fernweh", meta: "[noun, neuter]", back: "Longing for distant places (wanderlust)", sentence: "Er verspürte ein tiefes Fernweh nach den Bergen.", mnemonic: "Far-away yearning = Fern-weh." },
    { front: "Kummerspeck", meta: "[noun, masculine]", back: "Grief bacon (comfort-eating weight)", sentence: "Nach der Trennung bekam er etwas Kummerspeck.", mnemonic: "Kummer (grief) + Speck (bacon)." },
    { front: "Schadenfreude", meta: "[noun, feminine]", back: "Joy derived from another's misfortune", sentence: "Er konnte seine Schadenfreude nicht verbergen.", mnemonic: "Damage-joy." }
  ]
};

// ==========================================================================
// 3. PROCEDURAL WEB AUDIO SYNTHESIZER
// ==========================================================================
class AudioSynthesizer {
  constructor() {
    this.ctx = null;
  }

  init() {
    if (!this.ctx) {
      const AudioContext = window.AudioContext || window.webkitAudioContext;
      this.ctx = new AudioContext();
    }
  }

  playTick(freq = 900) {
    if (!state.audioEnabled) return;
    this.init();
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = 'triangle';
    osc.frequency.setValueAtTime(freq, this.ctx.currentTime);
    osc.frequency.exponentialRampToValueAtTime(120, this.ctx.currentTime + 0.025);
    gain.gain.setValueAtTime(0.08, this.ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, this.ctx.currentTime + 0.025);
    osc.connect(gain);
    gain.connect(this.ctx.destination);
    osc.start();
    osc.stop(this.ctx.currentTime + 0.025);
  }

  playCommitThud() {
    if (!state.audioEnabled) return;
    this.init();
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(110, this.ctx.currentTime);
    osc.frequency.exponentialRampToValueAtTime(40, this.ctx.currentTime + 0.09);
    gain.gain.setValueAtTime(0.3, this.ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, this.ctx.currentTime + 0.09);
    osc.connect(gain);
    gain.connect(this.ctx.destination);
    osc.start();
    osc.stop(this.ctx.currentTime + 0.09);
  }

  playSuccessPop() {
    if (!state.audioEnabled) return;
    this.init();
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(520, this.ctx.currentTime);
    osc.frequency.exponentialRampToValueAtTime(1040, this.ctx.currentTime + 0.08);
    gain.gain.setValueAtTime(0.18, this.ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, this.ctx.currentTime + 0.08);
    osc.connect(gain);
    gain.connect(this.ctx.destination);
    osc.start();
    osc.stop(this.ctx.currentTime + 0.08);
  }

  playTriumphChimes() {
    if (!state.audioEnabled) return;
    this.init();
    const notes = [523.25, 659.25, 783.99, 1046.50];
    notes.forEach((freq, idx) => {
      setTimeout(() => {
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();
        osc.type = 'sine';
        osc.frequency.setValueAtTime(freq, this.ctx.currentTime);
        gain.gain.setValueAtTime(0.15, this.ctx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.001, this.ctx.currentTime + 0.35);
        osc.connect(gain);
        gain.connect(this.ctx.destination);
        osc.start();
        osc.stop(this.ctx.currentTime + 0.35);
      }, idx * 60);
    });
  }
}

const audio = new AudioSynthesizer();

// ==========================================================================
// 4. UI NAVIGATION & THEME ENGINE
// ==========================================================================
function initNavigation() {
  document.querySelectorAll('.nav-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      switchTab(btn.getAttribute('data-tab'));
    });
  });

  const audioToggle = document.getElementById('audioToggle');
  audioToggle.addEventListener('click', () => {
    state.audioEnabled = !state.audioEnabled;
    const statusText = audioToggle.querySelector('.toggle-status');
    if (state.audioEnabled) {
      statusText.textContent = 'FX ON';
      statusText.className = 'toggle-status on';
      audio.playTick(1200);
      toast('🔊 Procedural Audio FX: Enabled');
    } else {
      statusText.textContent = 'FX OFF';
      statusText.className = 'toggle-status';
      toast('🔇 Procedural Audio FX: Muted');
    }
  });

  document.querySelectorAll('.theme-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      setTheme(btn.getAttribute('data-theme-val'));
    });
  });
}

function switchTab(tabId) {
  state.activeTab = tabId;
  document.querySelectorAll('.nav-btn').forEach(btn => {
    btn.classList.toggle('active', btn.getAttribute('data-tab') === tabId);
  });
  document.querySelectorAll('.tab-pane').forEach(pane => {
    pane.classList.toggle('active', pane.id === `tab-${tabId}`);
  });
  audio.playTick(750);
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

function setTheme(theme) {
  state.theme = theme;
  document.body.className = `theme-${theme}`;
  document.documentElement.setAttribute('data-theme', theme);
  document.querySelectorAll('.theme-btn').forEach(btn => {
    btn.classList.toggle('active', btn.getAttribute('data-theme-val') === theme);
  });

  const logoSlot = document.getElementById('headerBrandLogoSlot');
  if (logoSlot) {
    logoSlot.innerHTML = theme === 'dark' ? AppIcons.logoDarkMode : AppIcons.logoLightMode;
  }

  renderFolderStack();
  renderMobileDrawerStack();
  toast(`Theme switched to: ${theme.toUpperCase()}`);
}

function toast(msg) {
  const container = document.getElementById('toastContainer');
  const toastEl = document.createElement('div');
  toastEl.className = 'toast';
  toastEl.textContent = msg;
  container.appendChild(toastEl);
  setTimeout(() => {
    toastEl.style.opacity = '0';
    setTimeout(() => toastEl.remove(), 300);
  }, 2400);
}

// ==========================================================================
// 5. 20 CUSTOM SVG ICONS MATRIX POPULATION (INLINE GUARANTEED)
// ==========================================================================
function populateIconsMatrix() {
  const container = document.getElementById('iconsMatrix');
  if (!container) return;
  container.innerHTML = '';

  Object.keys(AppIcons).forEach(name => {
    const card = document.createElement('div');
    card.className = 'icon-item';
    card.innerHTML = `
      <div class="icon-svg-slot">${AppIcons[name]}</div>
      <span>${name}</span>
    `;
    card.addEventListener('click', () => {
      navigator.clipboard.writeText(`AppIcons.${name}`);
      toast(`Copied: AppIcons.${name}`);
      audio.playTick(1100);
    });
    container.appendChild(card);
  });

  // Populate UI Icon Slots
  const headerLogo = document.getElementById('headerBrandLogoSlot');
  if (headerLogo) headerLogo.innerHTML = AppIcons.logoDarkMode;

  const deleteBtnSlot = document.getElementById('deleteBtnIconSlot');
  if (deleteBtnSlot) deleteBtnSlot.innerHTML = AppIcons.delete;

  const actionDelete = document.getElementById('actionIconDelete');
  if (actionDelete) actionDelete.innerHTML = AppIcons.delete;

  const actionArchive = document.getElementById('actionIconArchive');
  if (actionArchive) actionArchive.innerHTML = AppIcons.archive;

  const actionMove = document.getElementById('actionIconMove');
  if (actionMove) actionMove.innerHTML = AppIcons.move;

  const actionDone = document.getElementById('actionIconDone');
  if (actionDone) actionDone.innerHTML = AppIcons.done;

  const badgeBox = document.getElementById('badgeBoxSlot');
  if (badgeBox) badgeBox.innerHTML = AppIcons.box;

  const badgeDone = document.getElementById('badgeDoneSlot');
  if (badgeDone) badgeDone.innerHTML = AppIcons.done;
}

// ==========================================================================
// 6. LIVING CONSCIOUS FOLDER ENGINE (DYNAMIC HEAD, GRADIENTS & EXTENDED PILLS)
// ==========================================================================
function calculateDynamicTabWidth(name) {
  // Font: Bernard MT Condensed (~11.2px per char + 36px padding)
  const charWidth = 11.2;
  const rawTextWidth = name.length * charWidth;
  const tabWidth = Math.min(230, Math.max(92, rawTextWidth + 36));
  return tabWidth;
}

function generateDynamicFolderSilhouette(W, H, tabWidth, stepHeight = 30, stepSpan = 36, r = 28, alpha = 0.45) {
  const p0x = tabWidth;
  const p1x = tabWidth + (alpha * stepSpan);
  const p2x = tabWidth + ((1.0 - alpha) * stepSpan);
  const p3x = tabWidth + stepSpan;

  return `M ${r} 0 
          L ${p0x} 0 
          C ${p1x} 0, ${p2x} ${stepHeight}, ${p3x} ${stepHeight} 
          L ${W - r} ${stepHeight} 
          A ${r} ${r} 0 0 1 ${W} ${stepHeight + r} 
          L ${W} ${H - r} 
          A ${r} ${r} 0 0 1 ${W - r} ${H} 
          L ${r} ${H} 
          A ${r} ${r} 0 0 1 0 ${H - r} 
          L 0 ${r} 
          A ${r} ${r} 0 0 1 ${r} 0 Z`;
}

function getFolderGradientStops(index, total) {
  if (state.theme === 'dark') {
    // Dark Mode: Starts at 95% Lightness, decreases by 5% each folder
    const startL = Math.max(10, 95 - (index * 5));
    const endL = Math.max(5, startL - 5);
    return {
      start: `hsl(0, 0%, ${startL}%)`,
      end: `hsl(0, 0%, ${endL}%)`
    };
  } else {
    // Light Mode: Starts at 20% Lightness, increases by 5% each folder
    const startL = Math.min(90, 20 + (index * 5));
    const endL = Math.max(10, startL - 5);
    return {
      start: `hsl(0, 0%, ${startL}%)`,
      end: `hsl(0, 0%, ${endL}%)`
    };
  }
}

function getFolderTextColor(index) {
  if (state.theme === 'dark') {
    // Lightness starts at 95% and goes down to 55%. Dark text for lightness > 65%, white text for lower
    const lightness = 95 - (index * 5);
    return lightness >= 65 ? '#1E1E1E' : '#FFFFFF';
  } else {
    // Lightness starts at 20% and goes up to 60%. White text for lightness < 45%, dark text for higher
    const lightness = 20 + (index * 5);
    return lightness < 45 ? '#FFFFFF' : '#1E1E1E';
  }
}

function renderFolderStack() {
  const container = document.getElementById('interactiveFolderStack');
  if (!container) return;
  container.innerHTML = '';

  if (state.folders.length === 0) {
    container.innerHTML = `
      <div class="empty-state-box" style="text-align:center; padding: 2rem; color: var(--text-secondary);">
        <div style="font-size: 2.5rem; margin-bottom: 0.5rem;">🧠 ???</div>
        <h4 style="font-family: var(--font-display); font-size: 1.3rem;">Empty Mind</h4>
        <p style="font-size: 0.85rem;">No folders remaining. Click "Reset Folders" to restore.</p>
      </div>
    `;
    return;
  }

  const W = 420;
  const H = 175; // Extended bottom for deeper 3D overlapping layers
  const stepSpan = 36;
  const stepHeight = 45; // 8px taller head plateau above the pills resting at Y=8px

  state.folders.forEach((folder, idx) => {
    const isBottomFolder = (idx === state.folders.length - 1);
    const card = document.createElement('div');
    card.className = `living-folder-card ${state.deleteFearMode ? 'fear-mode-active' : ''} ${isBottomFolder ? 'bottom-folder-fade' : ''}`;
    card.setAttribute('data-id', folder.id);
    card.setAttribute('data-index', idx);
    card.style.zIndex = idx + 1;

    const tabWidth = calculateDynamicTabWidth(folder.name);
    const svgPath = generateDynamicFolderSilhouette(W, H, tabWidth, stepHeight, stepSpan);
    const grad = getFolderGradientStops(idx, state.folders.length);
    const gradId = `folderGrad_${folder.id}_${idx}`;
    const textColor = getFolderTextColor(idx);
    const pillStartLeft = tabWidth + stepSpan - 16;

    // Determine if this folder is among the last 3 interacted folders
    const isPillVisible = state.recentFolderIds.includes(folder.id);

    card.innerHTML = `
      <svg class="folder-svg-shape" viewBox="0 0 ${W} ${H}" preserveAspectRatio="none">
        <defs>
          <linearGradient id="${gradId}" x1="0%" y1="0%" x2="0%" y2="100%">
            <stop offset="0%" stop-color="${grad.start}" />
            <stop offset="100%" stop-color="${grad.end}" />
          </linearGradient>
        </defs>
        <path class="folder-path-geometry" fill="url(#${gradId})" d="${svgPath}"/>
      </svg>
      <div class="folder-inner-overlay">
        <!-- Title on Top Plateau (8px Taller than files, Fits Dynamic Name Width) -->
        <div class="folder-tab-title" style="color: ${textColor}; width: ${tabWidth}px;">
          ${folder.name}
        </div>
        <!-- 3 Overlapping Deck File Pills (Only shown for the last 3 interacted folders) -->
        <div class="folder-deck-files ${isPillVisible ? '' : 'pills-hidden'}" id="deckFiles_${folder.id}" style="left: ${pillStartLeft}px;">
          ${folder.tabs.map((t, tabIdx) => `<div class="deck-file-pill ${t}" style="z-index: ${tabIdx + 1};" title="Deck File ${tabIdx + 1}"></div>`).join('')}
        </div>
      </div>
      <!-- Bottom Fade Gradient Layer for the last folder -->
      ${isBottomFolder ? `<div class="bottom-folder-gradient-overlay"></div>` : ''}
      ${state.deleteFearMode ? `<div class="delete-target-cross" title="Delete Folder">✖</div>` : ''}
    `;

    // Interaction 1: Tap -> Select Folder, Update Recent 3, Animate Pills In/Out
    card.addEventListener('click', () => {
      if (state.deleteFearMode) {
        card.classList.add('recoil-panic');
        audio.playCommitThud();
        setTimeout(() => {
          state.folders.splice(idx, 1);
          state.recentFolderIds = state.recentFolderIds.filter(id => id !== folder.id);
          renderFolderStack();
          renderMobileDrawerStack();
          toast(`Deleted Folder: ${folder.name}`);
        }, 380);
        return;
      }

      handleFolderInteraction(folder.id, card);
    });

    // Interaction 2: Long Press for +3% Pulsing Floating Drag
    card.addEventListener('mousedown', (e) => startFolderPress(e, card, idx));
    card.addEventListener('touchstart', (e) => startFolderPress(e, card, idx), { passive: true });

    container.appendChild(card);
  });
}

function handleFolderInteraction(folderId, cardElement) {
  const currentRecents = [...state.recentFolderIds];
  const isAlreadyFirst = currentRecents[0] === folderId;

  // If already at the top of recents, just trigger excitement pop animation
  if (isAlreadyFirst) {
    const targetEl = document.getElementById(`deckFiles_${folderId}`);
    if (targetEl) {
      targetEl.classList.remove('pills-hidden', 'pills-exiting');
      targetEl.classList.remove('pills-entering');
      void targetEl.offsetWidth;
      targetEl.classList.add('pills-entering');
    }
    audio.playSuccessPop();
    const folder = state.folders.find(f => f.id === folderId);
    toast(`📂 Selected "${folder ? folder.name : ''}": Deck tabs active!`);
    return;
  }

  // Calculate new recent list (folderId is now at index 0)
  const filtered = currentRecents.filter(id => id !== folderId);
  const newRecents = [folderId, ...filtered];
  let droppedFolderId = null;

  if (newRecents.length > 3) {
    droppedFolderId = newRecents.pop();
  }

  state.recentFolderIds = newRecents;
  const folder = state.folders.find(f => f.id === folderId);

  // 1. If a folder was bumped out of the top 3, animate its pills down & hide them
  if (droppedFolderId) {
    const droppedEl = document.getElementById(`deckFiles_${droppedFolderId}`);
    if (droppedEl) {
      droppedEl.classList.remove('pills-hidden', 'pills-entering');
      droppedEl.classList.add('pills-exiting');
      setTimeout(() => {
        if (!state.recentFolderIds.includes(droppedFolderId)) {
          droppedEl.classList.add('pills-hidden');
          droppedEl.classList.remove('pills-exiting');
        }
      }, 500);
    }
  }

  // 2. Animate newly entered/promoted folder's pills up with overshoot
  const targetEl = document.getElementById(`deckFiles_${folderId}`);
  if (targetEl) {
    targetEl.classList.remove('pills-hidden', 'pills-exiting');
    targetEl.classList.remove('pills-entering');
    void targetEl.offsetWidth;
    targetEl.classList.add('pills-entering');
    setTimeout(() => {
      targetEl.classList.remove('pills-entering');
    }, 500);
  }

  audio.playSuccessPop();
  const droppedObj = droppedFolderId ? state.folders.find(f => f.id === droppedFolderId) : null;
  if (droppedObj) {
    toast(`📂 Selected "${folder.name}"! "${droppedObj.name}" tabs tucked away.`);
  } else {
    toast(`📂 Selected "${folder.name}": 3 Deck Tabs Extended Smoothly!`);
  }
}

function startFolderPress(e, card, index) {
  if (state.deleteFearMode) return;

  clearTimeout(state.dragFolder.pressTimer);
  state.dragFolder.pressTimer = setTimeout(() => {
    state.dragFolder.isDragging = true;
    state.dragFolder.element = card;
    state.dragFolder.startIndex = index;
    card.classList.add('floating-active');
    audio.playTick(1400);
    toast(`⏱️ Floating Mode: Breathing Pulse (+3%) "${state.folders[index].name}"! Drag to reorder.`);
  }, 350);

  const cancelPress = () => {
    clearTimeout(state.dragFolder.pressTimer);
    window.removeEventListener('mouseup', cancelPress);
    window.removeEventListener('touchend', cancelPress);
  };
  window.addEventListener('mouseup', cancelPress);
  window.addEventListener('touchend', cancelPress);
}

window.addEventListener('mousemove', handleFolderDrag);
window.addEventListener('touchmove', handleFolderDrag, { passive: false });

function handleFolderDrag(e) {
  if (!state.dragFolder.isDragging || !state.dragFolder.element) return;
  const clientY = e.clientY || (e.touches && e.touches[0].clientY);
  const container = document.getElementById('interactiveFolderStack');
  if (!container) return;

  const rect = container.getBoundingClientRect();
  const relativeY = clientY - rect.top;
  const slotHeight = 68;
  const targetIndex = Math.max(0, Math.min(state.folders.length - 1, Math.floor(relativeY / slotHeight)));

  if (targetIndex !== state.dragFolder.startIndex && targetIndex >= 0 && targetIndex < state.folders.length) {
    const item = state.folders.splice(state.dragFolder.startIndex, 1)[0];
    state.folders.splice(targetIndex, 0, item);
    state.dragFolder.startIndex = targetIndex;
    audio.playTick(800 + (targetIndex * 150));
    renderFolderStack();
    const newCard = container.querySelector(`[data-index="${targetIndex}"]`);
    if (newCard) {
      newCard.classList.add('floating-active');
      state.dragFolder.element = newCard;
    }
  }
}

window.addEventListener('mouseup', endFolderDrag);
window.addEventListener('touchend', endFolderDrag);

function endFolderDrag() {
  if (state.dragFolder.isDragging && state.dragFolder.element) {
    state.dragFolder.isDragging = false;
    state.dragFolder.element.classList.remove('floating-active');
    audio.playCommitThud();
    renderFolderStack();
    renderMobileDrawerStack();
    toast('✓ Folder reorder committed!');
  }
}

function initFolderStageControls() {
  const deleteBtn = document.getElementById('folderDeleteModeBtn');
  const deleteLabel = document.getElementById('deleteBtnLabel');
  const resetBtn = document.getElementById('folderResetBtn');

  deleteBtn.addEventListener('click', () => {
    state.deleteFearMode = !state.deleteFearMode;
    deleteBtn.classList.toggle('active', state.deleteFearMode);
    deleteLabel.textContent = state.deleteFearMode ? 'Exit Fear Mode' : 'Delete Mode';
    renderFolderStack();

    if (state.deleteFearMode) {
      audio.playTick(1600);
      toast('😱 Fear of Deletion Mode: 6Hz Nervous Shiver (±4°) Active.');
    } else {
      toast('Delete mode deactivated.');
    }
  });

  resetBtn.addEventListener('click', () => {
    state.folders = [
      { id: 'f0', name: 'Languages', decks: 4, cards: 182, tabs: ['pill-blue', 'pill-yellow', 'pill-coral'] },
      { id: 'f1', name: 'German Words', decks: 3, cards: 95, tabs: ['pill-yellow', 'pill-coral', 'pill-blue'] },
      { id: 'f2', name: 'Coding Syntax', decks: 3, cards: 120, tabs: ['pill-coral', 'pill-blue', 'pill-yellow'] },
      { id: 'f3', name: 'Archive', decks: 2, cards: 64, tabs: ['pill-blue', 'pill-coral', 'pill-yellow'] },
      { id: 'f4', name: 'Medical Anatomy', decks: 5, cards: 210, tabs: ['pill-yellow', 'pill-blue', 'pill-coral'] },
      { id: 'f5', name: 'World History', decks: 4, cards: 140, tabs: ['pill-coral', 'pill-yellow', 'pill-blue'] },
      { id: 'f6', name: 'Law & Ethics', decks: 3, cards: 88, tabs: ['pill-blue', 'pill-coral', 'pill-yellow'] },
      { id: 'f7', name: 'Mathematics', decks: 6, cards: 310, tabs: ['pill-yellow', 'pill-coral', 'pill-blue'] },
      { id: 'f8', name: 'Philosophy', decks: 2, cards: 54, tabs: ['pill-coral', 'pill-blue', 'pill-yellow'] }
    ];
    state.recentFolderIds = ['f0', 'f1', 'f2'];
    state.deleteFearMode = false;
    deleteBtn.classList.remove('active');
    deleteLabel.textContent = 'Delete Mode';
    renderFolderStack();
    renderMobileDrawerStack();
    audio.playTriumphChimes();
    toast('↺ Folders successfully restored!');
  });
}

function renderMobileDrawerStack() {
  const container = document.getElementById('mobileDrawerFolderStack');
  if (!container) return;
  container.innerHTML = '';

  state.folders.forEach((f, idx) => {
    const card = document.createElement('div');
    card.className = `drawer-folder-card f-${idx % 4}`;
    card.innerHTML = `
      <div class="drawer-folder-header">
        <span class="df-title">${f.name}</span>
        <div class="df-tabs">
          ${f.tabs.map(t => `<span class="mini-pill ${t}"></span>`).join('')}
        </div>
      </div>
      <div class="df-meta">${f.decks} Decks • ${f.cards} Cards</div>
    `;
    card.addEventListener('click', () => toast(`Opened Folder: ${f.name}`));
    container.appendChild(card);
  });
}

// ==========================================================================
// 7. INTERACTIVE 6-LAYER 3D SWIPE STACK CONTROLLER
// ==========================================================================
function initCardStackGesture() {
  const card = document.getElementById('topActiveCard');
  if (!card) return;

  const badgeLeft = document.getElementById('badgeLeft');
  const badgeRight = document.getElementById('badgeRight');
  const telDeltaX = document.getElementById('telDeltaX');
  const telScale = document.getElementById('telScale');
  const telRotation = document.getElementById('telRotation');
  const telThreshold = document.getElementById('telThreshold');

  const onPointerDown = (e) => {
    state.gesture.isDragging = true;
    state.gesture.startX = e.clientX || (e.touches && e.touches[0].clientX);
    state.gesture.startY = e.clientY || (e.touches && e.touches[0].clientY);
    card.style.transition = 'none';
  };

  const onPointerMove = (e) => {
    if (!state.gesture.isDragging) return;
    const clientX = e.clientX || (e.touches && e.touches[0].clientX);
    const clientY = e.clientY || (e.touches && e.touches[0].clientY);

    const deltaX = clientX - state.gesture.startX;
    const deltaY = clientY - state.gesture.startY;
    state.gesture.currentX = deltaX;
    state.gesture.currentY = deltaY;

    const u = deltaX / state.gesture.cardWidth;
    const clampedU = Math.max(-1, Math.min(1, u));
    const rotation = clampedU * 45;
    const scale = 1.0 - (0.25 * Math.abs(clampedU));
    const driftY = deltaY + (0.15 * Math.abs(deltaX));

    card.style.transform = `translate3d(${deltaX}px, ${driftY}px, 0) rotate(${rotation}deg) scale(${scale})`;

    const absDeltaX = Math.abs(deltaX);
    if (deltaX < -state.gesture.dragThreshold40) {
      badgeLeft.classList.add('visible');
      badgeRight.classList.remove('visible');
    } else if (deltaX > state.gesture.dragThreshold40) {
      badgeRight.classList.add('visible');
      badgeLeft.classList.remove('visible');
    } else {
      badgeLeft.classList.remove('visible');
      badgeRight.classList.remove('visible');
    }

    const pct = Math.round((absDeltaX / state.gesture.cardWidth) * 100);
    telDeltaX.textContent = `${Math.round(deltaX)} px`;
    telScale.textContent = scale.toFixed(3);
    telRotation.textContent = `${rotation.toFixed(1)}°`;
    telThreshold.textContent = `${pct}% ${pct >= 60 ? '(COMMIT READY)' : '(Sub-60%)'}`;
  };

  const onPointerUp = () => {
    if (!state.gesture.isDragging) return;
    state.gesture.isDragging = false;

    const deltaX = state.gesture.currentX;
    const absDeltaX = Math.abs(deltaX);

    card.style.transition = 'all 0.35s cubic-bezier(0.175, 0.885, 0.32, 1.275)';
    badgeLeft.classList.remove('visible');
    badgeRight.classList.remove('visible');

    if (absDeltaX >= state.gesture.commitThreshold60) {
      const exitDir = deltaX > 0 ? 1 : -1;
      card.style.transform = `translate3d(${exitDir * 600}px, 120px, 0) rotate(${exitDir * 60}deg) scale(0.6)`;

      if (exitDir > 0) {
        audio.playSuccessPop();
        toast('✓ Swiped Right: Card Mastered (FSRS)');
      } else {
        audio.playCommitThud();
        toast('🗃️ Swiped Left: Re-inserted into Active Queue (+N)');
      }

      setTimeout(advanceCardStack, 350);
    } else {
      card.style.transform = 'translate3d(0, 0, 0) rotate(0deg) scale(1)';
      audio.playTick(600);
      telDeltaX.textContent = '0 px';
      telScale.textContent = '1.000';
      telRotation.textContent = '0.0°';
      telThreshold.textContent = '0%';
    }
  };

  card.addEventListener('mousedown', onPointerDown);
  window.addEventListener('mousemove', onPointerMove);
  window.addEventListener('mouseup', onPointerUp);

  card.addEventListener('touchstart', onPointerDown, { passive: true });
  window.addEventListener('touchmove', onPointerMove, { passive: true });
  window.addEventListener('touchend', onPointerUp);

  document.getElementById('btnSimulateLeft').addEventListener('click', () => {
    card.style.transition = 'all 0.35s ease';
    card.style.transform = 'translate3d(-600px, 100px, 0) rotate(-45deg) scale(0.6)';
    audio.playCommitThud();
    setTimeout(advanceCardStack, 350);
  });

  document.getElementById('btnSimulateRight').addEventListener('click', () => {
    card.style.transition = 'all 0.35s ease';
    card.style.transform = 'translate3d(600px, 100px, 0) rotate(45deg) scale(0.6)';
    audio.playSuccessPop();
    setTimeout(advanceCardStack, 350);
  });

  document.getElementById('btnSimulateFlip').addEventListener('click', toggleCardReveal);
  document.getElementById('manualRevealBtn').addEventListener('click', (e) => {
    e.stopPropagation();
    toggleCardReveal();
  });

  document.getElementById('btnResetStack').addEventListener('click', () => {
    state.cardIndex = 0;
    renderCurrentCard();
    resetCardTransform();
    toast('Stack Reset to Initial State');
  });

  document.getElementById('cardRevealMode').addEventListener('change', (e) => {
    state.cardRevealMode = e.target.value;
    resetCardTransform();
    toast(`Card Reveal Mode set to: ${state.cardRevealMode.toUpperCase()}`);
  });
}

function toggleCardReveal() {
  const card = document.getElementById('topActiveCard');
  if (!card) return;
  state.isCardRevealed = !state.isCardRevealed;
  audio.playTick(1100);

  if (state.cardRevealMode === 'flip') {
    card.style.transition = 'transform 0.4s cubic-bezier(0.2, 0.8, 0.2, 1)';
    card.style.transform = state.isCardRevealed ? 'rotateY(180deg)' : 'rotateY(0deg)';
  } else if (state.cardRevealMode === 'transform') {
    card.classList.toggle('mode-revealed', state.isCardRevealed);
    const frontText = document.getElementById('cardFrontText');
    const cur = state.sampleCards[state.cardIndex % state.sampleCards.length];
    if (state.isCardRevealed) {
      frontText.innerHTML = `${cur.front} <br><span style="font-size: 1.25rem; color: var(--pill-yellow);">${cur.back}</span>`;
    } else {
      frontText.textContent = cur.front;
    }
  } else {
    toast('Mode C (No Flip): Direct Assessment Mode');
  }
}

function advanceCardStack() {
  state.cardIndex++;
  state.isCardRevealed = false;
  renderCurrentCard();
  resetCardTransform();
}

function renderCurrentCard() {
  const cur = state.sampleCards[state.cardIndex % state.sampleCards.length];
  document.getElementById('cardFrontText').textContent = cur.front;
  document.getElementById('cardBackText').textContent = cur.back;
  document.getElementById('cardCounter').textContent = `${(state.cardIndex % 45) + 1}/45`;
  document.getElementById('topActiveCard').classList.remove('mode-revealed');
}

function resetCardTransform() {
  const card = document.getElementById('topActiveCard');
  if (card) {
    card.style.transition = 'none';
    card.style.transform = 'translate3d(0, 0, 0) rotate(0deg) scale(1)';
  }
}

// ==========================================================================
// 8. MOBILE SCREEN WALKTHROUGHS
// ==========================================================================
function initMobileScreenWalkthrough() {
  document.querySelectorAll('.screen-tab-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      switchMobileScreen(btn.getAttribute('data-screen'));
    });
  });

  // Inject Mobile Icons
  const drawerHeaderIcon = document.getElementById('drawerHeaderIconSlot');
  if (drawerHeaderIcon) drawerHeaderIcon.innerHTML = AppIcons.folder;

  const drawerSettings = document.getElementById('drawerSettingsSlot');
  if (drawerSettings) drawerSettings.innerHTML = AppIcons.settings;

  const newFolderBtnSlot = document.getElementById('newFolderBtnIconSlot');
  if (newFolderBtnSlot) newFolderBtnSlot.innerHTML = AppIcons.folder;

  const deckNavMenu = document.getElementById('deckNavMenuSlot');
  if (deckNavMenu) deckNavMenu.innerHTML = AppIcons.logoDarkMode;

  const deckNavMore = document.getElementById('deckNavMoreSlot');
  if (deckNavMore) deckNavMore.innerHTML = AppIcons.burggerDotes;

  const deckActionMove = document.getElementById('deckActionMoveSlot');
  if (deckActionMove) deckActionMove.innerHTML = AppIcons.move;

  const deckActionDelete = document.getElementById('deckActionDeleteSlot');
  if (deckActionDelete) deckActionDelete.innerHTML = AppIcons.delete;

  const bottomNavHome = document.getElementById('bottomNavHomeSlot');
  if (bottomNavHome) bottomNavHome.innerHTML = AppIcons.home;

  const bottomNavShop = document.getElementById('bottomNavShopSlot');
  if (bottomNavShop) bottomNavShop.innerHTML = AppIcons.shop;

  const shopFilter = document.getElementById('shopFilterSlot');
  if (shopFilter) shopFilter.innerHTML = AppIcons.filter;

  const searchBarIcon = document.getElementById('searchBarIconSlot');
  if (searchBarIcon) searchBarIcon.innerHTML = AppIcons.search;

  const fabPin = document.getElementById('fabPinSlot');
  if (fabPin) fabPin.innerHTML = AppIcons.pin;

  const fabShare = document.getElementById('fabShareSlot');
  if (fabShare) fabShare.innerHTML = AppIcons.share;

  const fabSearch = document.getElementById('fabSearchSlot');
  if (fabSearch) fabSearch.innerHTML = AppIcons.search;

  const fabSave = document.getElementById('fabSaveSlot');
  if (fabSave) fabSave.innerHTML = AppIcons.save;

  const profileSettings = document.getElementById('profileSettingsSlot');
  if (profileSettings) profileSettings.innerHTML = AppIcons.settings;
}

function switchMobileScreen(screenId) {
  document.querySelectorAll('.screen-tab-btn').forEach(b => {
    b.classList.toggle('active', b.getAttribute('data-screen') === screenId);
  });
  document.querySelectorAll('.device-screen').forEach(s => {
    s.classList.toggle('active', s.id === screenId);
  });
  audio.playTick(800);
}

function openShopFAB(tile, event) {
  const fab = document.getElementById('shopRadialFAB');
  if (!fab) return;
  fab.classList.toggle('active');
  audio.playSuccessPop();
  toast('Living Radial FAB: Pinned & Filter Actions Revealed');
}

function updateProfileTier(tier) {
  const card = document.getElementById('memberProfileCard');
  const badge = document.getElementById('memberTierBadge');
  const cms = document.getElementById('memberCmsVal');
  if (!card) return;

  const tiers = {
    bronze: { bg: 'linear-gradient(135deg, #2a1f18 0%, #1e1e1e 100%)', border: '#CD7F32', badge: 'BRONZE TIER', pts: '450 PTS' },
    silver: { bg: 'linear-gradient(135deg, #24282c 0%, #1e1e1e 100%)', border: '#E0E0E0', badge: 'SILVER TIER', pts: '2,840 PTS' },
    gold: { bg: 'linear-gradient(135deg, #302612 0%, #1e1e1e 100%)', border: '#FFD700', badge: 'GOLD TIER', pts: '8,920 PTS' },
    emerald: { bg: 'linear-gradient(135deg, #132a1e 0%, #1e1e1e 100%)', border: '#50C878', badge: 'EMERALD TIER', pts: '22,400 PTS' },
    diamond: { bg: 'linear-gradient(135deg, #142a38 0%, #1e1e1e 100%)', border: '#B9F2FF', badge: 'DIAMOND TIER', pts: '52,100 PTS' },
    obsidian: { bg: 'linear-gradient(135deg, #09090b 0%, #18181b 100%)', border: '#7928ca', badge: 'OBSIDIAN BLACK', pts: '84,290 PTS' }
  };

  const t = tiers[tier];
  card.style.background = t.bg;
  card.style.borderColor = t.border;
  badge.textContent = t.badge;
  cms.textContent = t.pts;

  document.querySelectorAll('.ts-btn').forEach(b => {
    b.classList.toggle('active', b.textContent.toLowerCase().includes(tier));
  });

  audio.playSuccessPop();
  toast(`Profile Card updated to ${tier.toUpperCase()}`);
}

function copySnippet(elementId) {
  const codeEl = document.getElementById(elementId);
  if (!codeEl) return;
  navigator.clipboard.writeText(codeEl.innerText);
  toast('📋 Dart Source Code copied to clipboard!');
  audio.playTick(1200);
}

// ==========================================================================
// 8. DECK LIST MULTI-STEPPED SWIPE ACTIONS & INWARD GRAVITY (RES-02 & RES-03)
// ==========================================================================
const initialDeckData = [
  { id: 'deck-1', title: 'To Remember', creator: 'by AmirOb', cards: 45, pinned: false },
  { id: 'deck-2', title: 'Research', creator: 'by LanguagePro', cards: 120, pinned: false },
  { id: 'deck-3', title: 'Medical Terms', creator: 'by DrSmith', cards: 85, pinned: false },
  { id: 'deck-4', title: 'World Capitals', creator: 'by GeoMaster', cards: 195, pinned: false },
  { id: 'deck-5', title: 'JavaScript ES6+', creator: 'by CodeNinja', cards: 62, pinned: false },
  { id: 'deck-6', title: 'Python Data', creator: 'by PyDev', cards: 40, pinned: false },
  { id: 'deck-7', title: 'Art History', creator: 'by ArtScholar', cards: 35, pinned: false },
  { id: 'deck-8', title: 'Music Theory', creator: 'by MozartFan', cards: 50, pinned: false },
  { id: 'deck-9', title: 'General Trivia', creator: 'by QuizMaster', cards: 300, pinned: false }
];

let activeDecksState = [...initialDeckData];

// Geometry Constants
const STEP_1_TARGET = 65; // 58px for single option
const STEP_2_TARGET = 125; // 108px for overlapping 2-option state (58 + 50)
const STEP_2_SPAN = STEP_2_TARGET - STEP_1_TARGET; // 50px

function initDeckSwipeGestures() {
  const container = document.getElementById('deckListInteractiveContainer');
  if (!container) return;

  const resetBtn = document.getElementById('btnResetDeckList');
  if (resetBtn) {
    resetBtn.addEventListener('click', () => {
      activeDecksState = initialDeckData.map(d => ({ ...d }));
      renderInteractiveDeckList();
      audio.playTriumphChimes();
      toast('↺ All 9 Decks successfully restored!');
      updatePhysicsTelemetry('Resting (0%)', 0, 'None');
      const scrollSlider = document.getElementById('deckVerticalScrollSlider');
      if (scrollSlider) scrollSlider.value = 0;
      const scrollPosText = document.getElementById('deckScrollPosText');
      if (scrollPosText) scrollPosText.textContent = '0%';
      container.scrollTop = 0;
    });
  }

  // Two-way sync for Vertical Scroll / Swipe Down Slider
  const scrollSlider = document.getElementById('deckVerticalScrollSlider');
  const scrollPosText = document.getElementById('deckScrollPosText');
  if (scrollSlider) {
    scrollSlider.addEventListener('input', (e) => {
      const pct = parseFloat(e.target.value) / 100;
      const maxScroll = container.scrollHeight - container.clientHeight;
      container.scrollTop = pct * maxScroll;
      if (scrollPosText) scrollPosText.textContent = `${Math.round(pct * 100)}%`;
    });

    container.addEventListener('scroll', () => {
      const maxScroll = container.scrollHeight - container.clientHeight;
      if (maxScroll > 0) {
        const pct = container.scrollTop / maxScroll;
        scrollSlider.value = pct * 100;
        if (scrollPosText) scrollPosText.textContent = `${Math.round(pct * 100)}%`;
      }
    });
  }

  renderInteractiveDeckList();
}

function updatePhysicsTelemetry(stage, disp, target) {
  const stageEl = document.getElementById('deckStepStageText');
  const dispEl = document.getElementById('deckStepDispText');
  const targetEl = document.getElementById('deckStepTargetText');
  if (stageEl) stageEl.textContent = stage;
  if (dispEl) dispEl.textContent = `${Math.round(disp)} px`;
  if (targetEl) targetEl.textContent = target;
}

function renderInteractiveDeckList() {
  const container = document.getElementById('deckListInteractiveContainer');
  if (!container) return;

  container.innerHTML = '';

  activeDecksState.forEach(deck => {
    const track = document.createElement('div');
    track.className = `deck-swipe-track ${deck.pinned ? 'pinned' : ''}`;
    track.setAttribute('data-deck-id', deck.id);

    track.innerHTML = `
      <!-- Left Side Options Layer (Swipe Right: Move & Pin) -->
      <div class="deck-action-layer layer-left">
        <!-- Option 1: Move (Blue, wide base underneath) -->
        <button class="action-layer-btn btn-opt-1 btn-action-move" data-action="move" title="Move to Folder">
          <div class="btn-glyph-wrap">${AppIcons.folder}</div>
        </button>
        <!-- Option 2: Pin (Green, overlapping layer on left edge) -->
        <button class="action-layer-btn btn-opt-2 btn-action-pin" data-action="pin" title="Pin Deck">
          <div class="btn-glyph-wrap">${deck.pinned ? '⭐' : AppIcons.pin}</div>
        </button>
      </div>

      <!-- Center Foreground Deck Card -->
      <div class="deck-list-item">
        <div class="deck-item-content">
          <span class="deck-item-title">${deck.pinned ? '📌 ' : ''}${deck.title}</span>
          <span class="deck-item-creator">${deck.creator} • ${deck.cards} Cards</span>
        </div>
        <!-- 3D Fan Card Silhouette Graphic -->
        <div class="deck-fan-silhouette">
          <svg viewBox="0 0 100 60" class="fan-svg">
            <path d="M5 58 Q 20 20, 50 25 Q 75 30, 95 58 Z" fill="#2a2a2a" opacity="0.35" />
            <path d="M15 58 Q 30 14, 60 18 Q 82 24, 96 58 Z" fill="#383838" opacity="0.55" />
            <path d="M25 58 Q 42 8, 70 12 Q 88 18, 97 58 Z" fill="#4a4a4a" opacity="0.75" />
            <path d="M38 58 Q 55 2, 82 5 Q 94 10, 98 58 Z" fill="#5c5c5c" opacity="0.9" />
            <path d="M52 58 Q 68 -2, 90 0 Q 98 4, 100 58 Z" fill="#707070" opacity="1.0" />
          </svg>
        </div>
      </div>

      <!-- Right Side Options Layer (Swipe Left: Delete & Archive) -->
      <div class="deck-action-layer layer-right">
        <!-- Option 1: Delete (Red Coral, wide base underneath) -->
        <button class="action-layer-btn btn-opt-1 btn-action-delete" data-action="delete" title="Delete Deck">
          <div class="btn-glyph-wrap">${AppIcons.delete}</div>
        </button>
        <!-- Option 2: Archive (Yellow/Amber, overlapping layer on right edge) -->
        <button class="action-layer-btn btn-opt-2 btn-action-archive" data-action="archive" title="Archive Deck">
          <div class="btn-glyph-wrap">${AppIcons.archive}</div>
        </button>
      </div>
    `;

    attachSteppedSwipePhysics(track, deck);
    container.appendChild(track);
  });
}

function attachSteppedSwipePhysics(track, deck) {
  const card = track.querySelector('.deck-list-item');
  const layerLeft = track.querySelector('.layer-left');
  const layerRight = track.querySelector('.layer-right');
  const btnPin = track.querySelector('.btn-action-pin');
  const btnMove = track.querySelector('.btn-action-move');
  const btnDelete = track.querySelector('.btn-action-delete');
  const btnArchive = track.querySelector('.btn-action-archive');

  let isDragging = false;
  let startX = 0;
  let currentRawDisp = 0;
  let settledDisplacement = 0; // 0, -58, -108, 58, 108
  let currentDirection = 0; // -1 for Left Swipe, +1 for Right Swipe
  let animFrameId = null;

  // Threshold tick state
  let hasTriggeredStep1Tick = false;
  let hasTriggeredStep2Tick = false;

  // Evaluates effective displacement with 4-phase gravity curves
  function calculateGravityDisplacement(rawD) {
    const absD = Math.abs(rawD);

    if (absD <= STEP_1_TARGET) {
      const p = absD / STEP_1_TARGET; // 0.0 to 1.0
      if (p < 0.10) {
        // 0 - 10%: Inward gravity (resisting pulling away from 0)
        return absD * 0.35;
      } else if (p < 0.90) {
        // 10 - 90%: Normal slide
        return absD;
      } else {
        // 90 - 100%: Inward gravity pulling towards Step 1 detent
        return STEP_1_TARGET - ((STEP_1_TARGET - absD) * 0.35);
      }
    } else {
      const d2 = absD - STEP_1_TARGET;
      const p2 = Math.min(1.0, d2 / STEP_2_SPAN);

      if (p2 < 0.10) {
        // 0 - 10% of Step 2: Inward gravity holding at Step 1
        return STEP_1_TARGET + (d2 * 0.35);
      } else if (p2 < 0.90) {
        // 10 - 90% of Step 2: Normal slide towards Step 2
        return STEP_1_TARGET + d2;
      } else if (p2 <= 1.00) {
        // 90 - 100% of Step 2: Inward gravity pulling towards Step 2 detent
        return STEP_2_TARGET - ((STEP_2_TARGET - (STEP_1_TARGET + d2)) * 0.35);
      } else {
        // Past Step 2: Elastic rubberband squash tension (allows lively stretch)
        const excess = absD - STEP_2_TARGET;
        return STEP_2_TARGET + Math.min(22, excess * 0.22);
      }
    }
  }

  // Renders visual width of overlapping action layers and card displacement
  function renderDisplacement(effD, dir) {
    if (effD === 0 || dir === 0) {
      layerLeft.style.width = '0px';
      layerRight.style.width = '0px';
      btnMove.style.width = '0px';
      btnPin.style.width = '0px';
      btnDelete.style.width = '0px';
      btnArchive.style.width = '0px';
      card.style.transform = 'translate3d(0, 0, 0)';
      
      // Reset sinking effect
      track.style.setProperty('--sink-left-opacity', 0);
      track.style.setProperty('--sink-right-opacity', 0);
      return;
    }

    const GAP = 10; // 10px empty space gap between deck and options
    const cardDisplacement = effD + GAP;

    // Calculate Adaptive Sinking Progress (0.0 to ~1.86 for Step 2)
    const progress = effD / STEP_1_TARGET; 
    const sinkOpacity = Math.min(1, progress * 1.5); // Fades in quickly, then maxes out

    const excess = Math.max(0, effD - STEP_2_TARGET);

    if (dir < 0) {
      // Swiping Left (Sinks on the Left)
      track.style.setProperty('--sink-left-progress', progress);
      track.style.setProperty('--sink-left-opacity', sinkOpacity);
      track.style.setProperty('--sink-right-opacity', 0);

      layerLeft.style.width = '0px';
      btnMove.style.width = '0px';
      btnPin.style.width = '0px';

      layerRight.style.width = `${effD}px`;
      btnDelete.style.width = `${effD}px`; // Option 1 (Red Coral) wide base

      if (effD <= STEP_1_TARGET) {
        btnArchive.style.width = '0px';
      } else {
        // Option 2 (Yellow/Amber) emerges on top at the right boundary & squashes with excess
        const opt2Base = Math.min(65, effD - STEP_1_TARGET);
        const opt2W = opt2Base + (excess * 0.45);
        btnArchive.style.width = `${opt2W}px`;
      }

      // Deck displacement with 10px empty space gap
      card.style.transform = `translate3d(-${cardDisplacement}px, 0, 0)`;
    } else {
      // Swiping Right (Sinks on the Right)
      track.style.setProperty('--sink-right-progress', progress);
      track.style.setProperty('--sink-right-opacity', sinkOpacity);
      track.style.setProperty('--sink-left-opacity', 0);

      layerRight.style.width = '0px';
      btnDelete.style.width = '0px';
      btnArchive.style.width = '0px';

      layerLeft.style.width = `${effD}px`;
      btnMove.style.width = `${effD}px`; // Option 1 (Blue) wide base

      if (effD <= STEP_1_TARGET) {
        btnPin.style.width = '0px';
      } else {
        // Option 2 (Green) emerges on top at the left boundary & squashes with excess
        const opt2Base = Math.min(65, effD - STEP_1_TARGET);
        const opt2W = opt2Base + (excess * 0.45);
        btnPin.style.width = `${opt2W}px`;
      }

      // Deck displacement with 10px empty space gap
      card.style.transform = `translate3d(${cardDisplacement}px, 0, 0)`;
    }
  }

  // Spring animation engine with added overshoot and squash rebound
  function animateTo(targetD, dir, withOvershoot, callback) {
    if (animFrameId) cancelAnimationFrame(animFrameId);

    // Live position at moment of release
    const liveDisp = calculateGravityDisplacement(currentRawDisp);
    let startD = liveDisp > 0 ? liveDisp : (settledDisplacement !== 0 ? Math.abs(settledDisplacement) : 0);
    let overshootD = targetD;

    if (withOvershoot) {
      if (targetD > startD) {
        overshootD = targetD + 12; // +12px opening overshoot extension
      } else if (startD > targetD + 1) {
        overshootD = targetD - 9;  // -9px elastic squash compression rebound
      }
    }

    let currentVal = startD;
    let velocity = 0;
    const springK = 0.16; // Elastic spring stiffness (~380ms duration)
    const damping = 0.74; // Smooth fluid damping for visible squash cycle
    let phase = withOvershoot && Math.abs(overshootD - targetD) > 1 ? 'overshoot' : 'settle';

    function step() {
      const dest = phase === 'overshoot' ? overshootD : targetD;
      const force = (dest - currentVal) * springK;
      velocity = (velocity + force) * damping;
      currentVal += velocity;

      renderDisplacement(currentVal, dir);

      if (phase === 'overshoot' && Math.abs(currentVal - overshootD) < 1.2) {
        phase = 'settle';
      } else if (phase === 'settle' && Math.abs(currentVal - targetD) < 0.3 && Math.abs(velocity) < 0.15) {
        currentVal = targetD;
        renderDisplacement(currentVal, dir);
        settledDisplacement = dir * targetD;
        currentRawDisp = targetD;
        if (callback) callback();
        return;
      }

      animFrameId = requestAnimationFrame(step);
    }

    step();
  }

  const onPointerDown = (e) => {
    if (e.target.closest('.action-layer-btn')) return;
    if (animFrameId) cancelAnimationFrame(animFrameId);

    isDragging = true;
    startX = (e.clientX || (e.touches && e.touches[0].clientX)) - (settledDisplacement || 0);
    card.classList.add('dragging');
    hasTriggeredStep1Tick = false;
    hasTriggeredStep2Tick = false;
  };

  const onPointerMove = (e) => {
    if (!isDragging) return;
    const clientX = e.clientX || (e.touches && e.touches[0].clientX);
    const deltaX = clientX - startX;
    currentDirection = deltaX < 0 ? -1 : 1;
    currentRawDisp = Math.abs(deltaX);

    const effD = calculateGravityDisplacement(currentRawDisp);
    renderDisplacement(effD, currentDirection);

    // Telemetry & Stage Classification
    if (effD <= STEP_1_TARGET) {
      const p = effD / STEP_1_TARGET;
      if (p < 0.10) {
        updatePhysicsTelemetry('0-10% Inward Gravity (Pulling Back)', effD, 'Resting (0px)');
      } else if (p < 0.50) {
        updatePhysicsTelemetry('10-50% Sliding Normally (Returns on Lift)', effD, `Option 1 (${STEP_1_TARGET}px)`);
      } else if (p < 0.55) {
        updatePhysicsTelemetry('50-55% THRESHOLD (Snaps & Overshoots!)', effD, `Option 1 (${STEP_1_TARGET}px)`);
        if (!hasTriggeredStep1Tick) {
          audio.playTick(950);
          hasTriggeredStep1Tick = true;
        }
      } else if (p < 0.90) {
        updatePhysicsTelemetry('55-90% Opening Option 1', effD, `Option 1 (${STEP_1_TARGET}px)`);
      } else {
        updatePhysicsTelemetry('90-100% Inward Gravity (Step 1 Detent)', effD, `Option 1 (${STEP_1_TARGET}px)`);
      }
    } else {
      const d2 = effD - STEP_1_TARGET;
      const p2 = Math.min(1.0, d2 / STEP_2_SPAN);
      if (p2 < 0.10) {
        updatePhysicsTelemetry('Step 2: 0-10% Gravity Hold', effD, `Option 2 (${STEP_2_TARGET}px)`);
      } else if (p2 < 0.50) {
        updatePhysicsTelemetry('Step 2: 10-50% Sliding (Returns to Step 1)', effD, `Option 2 (${STEP_2_TARGET}px)`);
      } else if (p2 < 0.55) {
        updatePhysicsTelemetry('Step 2: 50-55% THRESHOLD (Snaps & Overshoots!)', effD, `Option 2 (${STEP_2_TARGET}px)`);
        if (!hasTriggeredStep2Tick) {
          audio.playTick(1300);
          hasTriggeredStep2Tick = true;
        }
      } else if (p2 < 0.90) {
        updatePhysicsTelemetry('Step 2: 55-90% Opening Option 2', effD, `Option 2 (${STEP_2_TARGET}px)`);
      } else {
        updatePhysicsTelemetry('Step 2: 90-100% Inward Gravity (Fully Armed)', effD, `Option 2 (${STEP_2_TARGET}px)`);
      }
    }
  };

  const onPointerUp = () => {
    if (!isDragging) return;
    isDragging = false;
    card.classList.remove('dragging');

    const rawD = currentRawDisp;
    const dir = currentDirection;

    if (rawD <= STEP_1_TARGET) {
      const p = rawD / STEP_1_TARGET;
      if (p < 0.50) {
        // < 50%: Goes back to 0px
        animateTo(0, dir, false, () => {
          settledDisplacement = 0;
          updatePhysicsTelemetry('Resting (0%)', 0, 'None');
        });
        audio.playTick(600);
      } else {
        // >= 50%: Detection threshold triggered -> Continues opening with added overshoot!
        animateTo(STEP_1_TARGET, dir, true, () => {
          settledDisplacement = dir * STEP_1_TARGET;
          updatePhysicsTelemetry(`Step 1 Locked (${dir < 0 ? 'Delete' : 'Move'})`, STEP_1_TARGET, 'Option 1 Active');
        });
        audio.playSuccessPop();
        toast(`${dir < 0 ? '🗑️ Step 1: Delete option ready' : '📁 Step 1: Move option ready'} (Swipe deeper for Option 2)`);
      }
    } else {
      const d2 = rawD - STEP_1_TARGET;
      const p2 = d2 / STEP_2_SPAN;

      if (p2 < 0.50) {
        // < 50% of Step 2: Snaps back to Step 1 (58px)
        animateTo(STEP_1_TARGET, dir, false, () => {
          settledDisplacement = dir * STEP_1_TARGET;
          updatePhysicsTelemetry(`Step 1 Locked (${dir < 0 ? 'Delete' : 'Move'})`, STEP_1_TARGET, 'Option 1 Active');
        });
        audio.playTick(750);
      } else {
        // >= 50% of Step 2: Detection threshold triggered -> Continues opening to Step 2 with added overshoot!
        animateTo(STEP_2_TARGET, dir, true, () => {
          settledDisplacement = dir * STEP_2_TARGET;
          updatePhysicsTelemetry(`Step 2 Locked (${dir < 0 ? 'Delete + Archive' : 'Move + Pin'})`, STEP_2_TARGET, 'Both Options Active');
        });
        audio.playCommitThud();
        toast(`${dir < 0 ? '📦 Step 2: Delete & Archive ready' : '📌 Step 2: Move & Pin ready'}!`);
      }
    }
  };

  card.addEventListener('mousedown', onPointerDown);
  window.addEventListener('mousemove', onPointerMove);
  window.addEventListener('mouseup', onPointerUp);

  card.addEventListener('touchstart', onPointerDown, { passive: true });
  window.addEventListener('touchmove', onPointerMove, { passive: true });
  window.addEventListener('touchend', onPointerUp);

  // Wire Action Buttons
  btnDelete.addEventListener('click', (e) => {
    e.stopPropagation();
    track.classList.add('deleted');
    audio.playCommitThud();
    toast(`🗑️ Deleted deck: "${deck.title}"`);
    setTimeout(() => {
      activeDecksState = activeDecksState.filter(d => d.id !== deck.id);
    }, 380);
  });

  btnArchive.addEventListener('click', (e) => {
    e.stopPropagation();
    track.classList.add('archived');
    audio.playCommitThud();
    toast(`📦 Archived deck: "${deck.title}"`);
    setTimeout(() => {
      activeDecksState = activeDecksState.filter(d => d.id !== deck.id);
    }, 400);
  });

  btnPin.addEventListener('click', (e) => {
    e.stopPropagation();
    deck.pinned = !deck.pinned;
    audio.playSuccessPop();
    toast(`📌 "${deck.title}" ${deck.pinned ? 'Pinned to top' : 'Unpinned'}`);
    renderInteractiveDeckList();
  });

  btnMove.addEventListener('click', (e) => {
    e.stopPropagation();
    animateTo(0, 1, false);
    audio.playSuccessPop();
    toast(`📁 Select target folder for "${deck.title}"...`);
  });
}

// ==========================================================================
// 9. INITIALIZATION RUNNER
// ==========================================================================
document.addEventListener('DOMContentLoaded', () => {
  initNavigation();
  populateIconsMatrix();
  renderFolderStack();
  initFolderStageControls();
  initDeckSwipeGestures();
  initCardStackGesture();
  initMobileScreenWalkthrough();

  document.querySelectorAll('[data-copy]').forEach(el => {
    el.addEventListener('click', () => {
      const val = el.getAttribute('data-copy');
      navigator.clipboard.writeText(val);
      toast(`Copied: ${val}`);
      audio.playTick(1100);
    });
  });
});


