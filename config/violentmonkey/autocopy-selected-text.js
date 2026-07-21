// ==UserScript==
// @name         Auto-Copy Selected Text
// @namespace    http://tampermonkey.net/
// @version      1.0
// @description  Automatically copies selected text to clipboard
// @author       You
// @match        *://*/*
// @grant        none
// ==/UserScript==

(function() {
    'use strict';

    let debounceTimer;

    document.addEventListener('mouseup', handleSelection);
    document.addEventListener('keyup', handleSelection); // catches keyboard-based selection (shift+arrows, etc.)

    function handleSelection() {
        clearTimeout(debounceTimer);
        debounceTimer = setTimeout(() => {
            const text = window.getSelection().toString();
            if (text.length > 0) {
                navigator.clipboard.writeText(text).catch(err => {
                    console.warn('Auto-copy failed:', err);
                });
            }
        }, 100); // small debounce so it doesn't fire on every pixel of drag
    }
})();
