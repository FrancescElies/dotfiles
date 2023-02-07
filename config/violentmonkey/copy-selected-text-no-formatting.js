// ==UserScript==
// @name         Copy Selection as Plain Text (Ctrl+Shift+C)
// @namespace    vm.scripts
// @version      1.0
// @description  Copies selected text to clipboard without formatting
// @match        *://*/*
// @grant        none
// ==/UserScript==

(function () {
  "use strict";
  document.addEventListener("keydown", async (e) => {
    if (e.ctrlKey && e.shiftKey && e.code === "KeyC") {
      const sel = window.getSelection().toString();
      if (!sel) return;
      try {
        await navigator.clipboard.writeText(sel);
        // small user feedback
        const el = document.createElement("div");
        el.textContent = "Copied as plain text";
        Object.assign(el.style, {
          position: "fixed",
          top: "10px",
          right: "10px",
          background: "#222",
          color: "#fff",
          padding: "6px 10px",
          zIndex: 99999,
          borderRadius: "6px",
        });
        document.body.appendChild(el);
        setTimeout(() => el.remove(), 1200);
      } catch (err) {
        console.error("Clipboard failed", err);
      }
    }
  });
})();
