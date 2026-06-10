// ==UserScript==
// @name         Highlight Dev Keywords Colorized
// @namespace    https://example.local/
// @version      1.2
// @description  Highlight TODO, FIXME, HACK, NOTE, WAIT with different colors
// @match        *://*/*
// @grant        none
// ==/UserScript==

(function () {
  'use strict';

  const HIGHLIGHT_BASE = 'vm-highlight-keyword';
  const KEYWORDS = {
    TODO: '#00a5c5',   // user-specified
    FIXME: '#ff5252',
    HACK: '#ff9800',
    NOTE: '#7baf7b',
    WAIT: '#ddbe0b'
  };
  const WORDS = Object.keys(KEYWORDS);
  const RE = new RegExp('\\b(' + WORDS.join('|') + ')\\b', 'gi');

  // inject stylesheet with per-keyword classes
  const style = document.createElement('style');
  let css = '';
  Object.entries(KEYWORDS).forEach(([k, color]) => {
    const cls = `${HIGHLIGHT_BASE}-${k.toLowerCase()}`;
    css += `
      .${cls} {
        background: ${color} !important;
        color: #fff !important;
        padding: 0 4px;
        border-radius: 3px;
        font-weight: 600;
      }
    `;
  });
  // ensure base class exists for easy selection
  css += `
    .${HIGHLIGHT_BASE} { display: inline; }
  `;
  style.textContent = css;
  document.head.appendChild(style);

  const SKIP_TAGS = new Set(['SCRIPT', 'STYLE', 'NOSCRIPT', 'IFRAME', 'OBJECT', 'CODE', 'PRE', 'TEXTAREA', 'INPUT']);

  function makeSpan(text, keyword) {
    const span = document.createElement('span');
    span.className = `${HIGHLIGHT_BASE} ${HIGHLIGHT_BASE}-${keyword.toLowerCase()}`;
    span.textContent = text;
    return span;
  }

  function highlightTextNode(node) {
    if (!node || node.nodeType !== Node.TEXT_NODE) return;
    const text = node.nodeValue;
    if (!text || !RE.test(text)) return;

    const frag = document.createDocumentFragment();
    let lastIndex = 0;
    RE.lastIndex = 0;
    let m;
    while ((m = RE.exec(text)) !== null) {
      const before = text.slice(lastIndex, m.index);
      if (before) frag.appendChild(document.createTextNode(before));
      const matched = m[0];
      const key = matched.toUpperCase();
      frag.appendChild(makeSpan(matched, key));
      lastIndex = RE.lastIndex;
    }
    const after = text.slice(lastIndex);
    if (after) frag.appendChild(document.createTextNode(after));
    node.parentNode.replaceChild(frag, node);
  }

  function walkAndHighlight(root) {
    const walker = document.createTreeWalker(
      root,
      NodeFilter.SHOW_TEXT,
      {
        acceptNode(node) {
          if (!node.nodeValue || !node.nodeValue.trim()) return NodeFilter.FILTER_REJECT;
          const parent = node.parentNode;
          if (!parent || SKIP_TAGS.has(parent.nodeName)) return NodeFilter.FILTER_REJECT;
          if (parent.closest && parent.closest('.' + HIGHLIGHT_BASE)) return NodeFilter.FILTER_REJECT;
          return NodeFilter.FILTER_ACCEPT;
        }
      },
      false
    );

    const nodes = [];
    let cur;
    while ((cur = walker.nextNode())) nodes.push(cur);
    nodes.forEach(highlightTextNode);
  }

  if (document.body) walkAndHighlight(document.body);
  else document.addEventListener('DOMContentLoaded', () => walkAndHighlight(document.body));

  const observer = new MutationObserver((mutations) => {
    for (const m of mutations) {
      if (m.type === 'childList') {
        m.addedNodes.forEach((n) => {
          if (n.nodeType === Node.TEXT_NODE) highlightTextNode(n);
          else if (n.nodeType === Node.ELEMENT_NODE && !SKIP_TAGS.has(n.tagName)) walkAndHighlight(n);
        });
      } else if (m.type === 'characterData') {
        highlightTextNode(m.target);
      }
    }
  });

  observer.observe(document.documentElement || document.body, {
    childList: true,
    subtree: true,
    characterData: true
  });

})();
