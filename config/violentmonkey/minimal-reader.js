// ==UserScript==
// @name         Minimal Reader Mode
// @namespace    vm.scripts
// @version      1.0
// @description  Extracts main article text and shows it in a clean reader overlay
// @match        *://*/*
// @grant        none
// ==/UserScript==

(function() {
  'use strict';
  function createReader(text) {
    const overlay = document.createElement('div');
    Object.assign(overlay.style, {
      position:'fixed', top:0, left:0, right:0, bottom:0, background:'#fff', color:'#111', zIndex:999999, overflow:'auto', padding:'28px'
    });
    const close = document.createElement('button');
    close.textContent = 'Close';
    Object.assign(close.style, {position:'fixed', right:'20px', top:'20px', padding:'8px'});
    close.onclick = () => overlay.remove();
    overlay.appendChild(close);

    const p = document.createElement('div');
    p.style.maxWidth = '900px';
    p.style.margin = '0 auto';
    p.style.fontSize = '18px';
    p.innerHTML = text;
    overlay.appendChild(p);
    document.body.appendChild(overlay);
  }

  // very simple main content guess: largest <article> or largest text container
  function guessContent() {
    let best = document.querySelector('article');
    if (!best) {
      const candidates = Array.from(document.querySelectorAll('div, main')).map(el => ({el, score: (el.innerText||'').length}));
      candidates.sort((a,b) => b.score - a.score);
      best = candidates[0] && candidates[0].el;
    }
    return best ? best.innerHTML : document.body.innerText;
  }

  const btn = document.createElement('button');
  btn.textContent = 'Reader';
  Object.assign(btn.style, {position:'fixed', left:'12px', bottom:'12px', zIndex:99999, padding:'8px 10px'});
  btn.onclick = () => createReader(guessContent());
  document.body.appendChild(btn);
})();
