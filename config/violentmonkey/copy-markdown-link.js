// ==UserScript==
// @name         Copy Page Title as Markdown Link
// @namespace    http://tampermonkey.net/
// @version      1.0
// @description  Copies the page title and URL as a Markdown link to the clipboard
// @author       You
// @match        *://*/*
// @grant        GM_registerMenuCommand
// @grant        GM_setClipboard
// ==/UserScript==

(function () {
  "use strict";

  function showToast(message, duration = 2000) {
    const toast = document.createElement("div");
    toast.textContent = message;

    Object.assign(toast.style, {
      position: "fixed",
      bottom: "20px",
      right: "20px",
      backgroundColor: "#333",
      color: "#fff",
      padding: "10px 15px",
      borderRadius: "5px",
      fontSize: "14px",
      fontFamily: "sans-serif",
      zIndex: 9999,
      opacity: "0",
      transition: "opacity 0.3s ease",
      pointerEvents: "none",
    });

    document.body.appendChild(toast);
    requestAnimationFrame(() => {
      toast.style.opacity = "1";
    });

    setTimeout(() => {
      toast.style.opacity = "0";
      toast.addEventListener("transitionend", () => toast.remove());
    }, duration);
  }
  function copyMarkdownLink() {
    const title = document.title;
    const url = window.location.href;
    const markdown = `[${title}](${url})`;

    // Copies to clipboard
    GM_setClipboard(markdown);

    showToast("Copied link as Markdown");
  }

  GM_registerMenuCommand("Copy Markdown Link", copyMarkdownLink);

  showToast("<C-S-Z>: Copy Markdown link");

  document.addEventListener("keydown", function (e) {
    if (e.ctrlKey && e.shiftKey && e.key === "Z") {
      // <C-S-Z>
      e.preventDefault(); // prevent default browser behavior
      copyMarkdownLink();
    }
  });
})();
