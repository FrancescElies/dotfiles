// ==UserScript==
// @name         Auto Dismiss Cookie/Overlay
// @namespace    vm.scripts
// @version      1.1
// @description  Attempts to close common cookie and consent overlays automatically
// @match        *://*/*
// @grant        none
// ==/UserScript==

(function () {
  "use strict";
  const trySelectors = [
    '[id*="consent"] button',
    '[class*="consent"] button',
    '[id*="cookie"] button',
    '[class*="cookie"] button',
    'button[aria-label*="accept"]',
    'button[aria-label*="Close"]',
    'button[title*="Accept"]',
    ".cc-accept",
    ".consent-accept",
  ];

  function clickIfExists() {
    for (const sel of trySelectors) {
      const el = document.querySelector(sel);
      if (el) {
        el.click();
        return true;
      }
    }
    // fallback: hide big modal-looking elements
    const modals = Array.from(document.querySelectorAll("div")).filter((d) => {
      const s = getComputedStyle(d);
      return (
        (s.position === "fixed" || s.position === "sticky") &&
        s.zIndex !== "auto" &&
        d.clientHeight > 50
      );
    });
    modals.forEach((m) => {
      m.style.display = "none";
    });
    return false;
  }

  // try on load and a few times after (some consent widgets load later)
  clickIfExists();
  const i = setInterval(clickIfExists, 700);
  setTimeout(() => clearInterval(i), 5000);
})();
