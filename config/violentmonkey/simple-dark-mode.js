// ==UserScript==
// @name         Universal Dark Mode
// @namespace    vm.scripts
// @version      1.0
// @description  Injects a dark stylesheet into pages (change @match to limit to sites)
// @match        *://*/*
// @grant        none
// ==/UserScript==

(function() {
  'use strict';
  const css = `
    html, body { background: #0b0f12 !important; color: #dbe6ea !important; }
    img, video { filter: none !important; }
    a { color: #7cc5ff !important; }
    /* reduce strong white backgrounds */
    * { background-color: transparent !important; }
    /* optional: soften inputs */
    input, textarea, select, button { background: #111417 !important; color: #e6f0f3 !important; border: 1px solid #222 !important; }
  `;
  const s = document.createElement('style');
  s.textContent = css;
  document.head.appendChild(s);
})();
