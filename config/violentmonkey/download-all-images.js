// ==UserScript==
// @name         Download All Images (simple)
// @namespace    vm.scripts
// @version      1.0
// @description  Adds a button to open all images in new tabs (then use browser save)
// @match        *://*/*
// @grant        none
// ==/UserScript==

(function () {
  "use strict";
  const btn = document.createElement("button");
  btn.textContent = "Download images";
  Object.assign(btn.style, {
    position: "fixed",
    bottom: "12px",
    right: "12px",
    zIndex: 99999,
    padding: "8px 12px",
    background: "#222",
    color: "#fff",
    borderRadius: "6px",
    border: "none",
    cursor: "pointer",
  });
  btn.addEventListener("click", () => {
    const imgs = Array.from(document.images)
      .map((i) => i.src)
      .filter(Boolean);
    if (!imgs.length) {
      alert("No images found");
      return;
    }
    imgs.forEach((src, i) => {
      // open in new tab; user browser will prompt save or display
      window.open(src, `_img_${i}`);
    });
  });
  document.body.appendChild(btn);
})();
