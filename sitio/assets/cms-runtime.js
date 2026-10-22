'use strict';
(() => {
  const binding = JSON.parse(document.getElementById('campus-bindings').textContent);
  const dataElement = document.getElementById('site-data');
  const originalData = JSON.parse(dataElement.textContent);
  const preview = new URLSearchParams(location.search).get('campusPreview') === '1' && window.parent !== window;
  let activeData = structuredClone(originalData);
  const targets = new Map();
  for (const area of binding.documents) for (const field of area.fields) {
    if (field.selector) {
      const node = document.querySelector(field.selector);
      if (node) targets.set(`${area.id}/${field.id}`, {node, textNode: field.textIndex === undefined ? null : node.childNodes[field.textIndex]});
    }
  }
  const safeUrl = (value, kind) => {
    if (typeof value !== 'string' || /[\u0000-\u0020\\]/.test(value)) return false;
    if (kind !== 'embed' && (/^\/(?!\/)/.test(value) || kind === 'url' && /^#/.test(value))) return true;
    try {
      const u = new URL(value);
      if (u.username || u.password) return false;
      if (kind === 'url' && ['tel:', 'mailto:'].includes(u.protocol)) return true;
      if (u.protocol !== 'https:') return false;
      return kind !== 'embed' || ['www.facebook.com', 'www.instagram.com', 'www.youtube.com', 'player.vimeo.com', 'www.tiktok.com'].includes(u.hostname);
    } catch { return false; }
  };
  function apply(records) {
    activeData = structuredClone(originalData);
    for (const area of binding.documents) for (const field of area.fields) {
      const record = records[area.id];
      const input = record?.templateId === binding.templateId ? record.values?.[field.id] : undefined;
      const value = typeof input === 'string' && input.length <= field.max && (field.kind === 'text' || safeUrl(input, field.kind)) ? input : field.value;
      if (field.dataPath) {
        let target = activeData;
        for (const part of field.dataPath.slice(0, -1)) target = target[part];
        target[field.dataPath.at(-1)] = value;
      } else {
        const target = targets.get(`${area.id}/${field.id}`);
        if (!target) continue;
        if (field.textIndex !== undefined && target.textNode?.nodeType === Node.TEXT_NODE) {
          if (target.textNode.nodeValue !== value) target.textNode.nodeValue = value;
        }
        else if (field.attribute) {
          const changed = target.node.getAttribute(field.attribute) !== value;
          if (changed) target.node.setAttribute(field.attribute, value);
          if (changed && target.node.tagName === 'SOURCE') target.node.parentElement.load();
          if (field.kind === 'image') {
            if (value !== field.value) target.node.removeAttribute('srcset');
            else if (target.node.dataset.cmsSrcset) target.node.setAttribute('srcset', target.node.dataset.cmsSrcset);
          }
        }
      }
    }
    // Contact links and draft forms must use the same configured destination.
    if (activeData.whatsapp !== originalData.whatsapp) document.querySelectorAll('a[href]').forEach(a => {
      if (a.getAttribute('href') === originalData.whatsapp) a.setAttribute('href', activeData.whatsapp);
    });
    const film = document.querySelector('.school-film');
    if (film && matchMedia('(max-width: 599px)').matches && activeData.filmMobile) film.setAttribute('src', activeData.filmMobile);
    dataElement.textContent = JSON.stringify(activeData);
    window.schoolSiteData = activeData;
    document.documentElement.dataset.cmsReady = 'true';
    window.dispatchEvent(new CustomEvent('campus-content-applied'));
  }
  document.querySelectorAll('img[srcset]').forEach(img => { img.dataset.cmsSrcset = img.getAttribute('srcset'); });
  window.schoolContentReady = (async () => {
    try {
      const configured = document.querySelector('meta[name="campus-content-endpoint"]')?.content;
      const endpoint = configured === 'https://us-central1-sistema-educativo-rl-prod.cloudfunctions.net/getCampusPublicContent' ? configured : '/sitio/content';
      const response = await fetch(`${endpoint}?page=${encodeURIComponent(binding.pageId)}`, {signal: AbortSignal.timeout(6000), credentials: 'omit'});
      if (!response.ok) throw new Error('Public content unavailable');
      const result = await response.json();
      apply(result.documents || {});
    } catch { apply({}); }
  })();
  if (preview) {
    const style = document.createElement('style');
    style.textContent = '[data-cms]:hover{outline:2px dashed #BF2F3C;outline-offset:3px;cursor:pointer}';
    document.head.append(style);
    document.addEventListener('click', event => {
      const node = event.target.closest('[data-cms]');
      event.preventDefault(); event.stopImmediatePropagation();
      if (!node) return;
      const candidates = binding.documents.flatMap(area => area.fields.filter(f => f.selector === `[data-cms="${node.dataset.cms}"]`).map(field => ({area: area.id, field: field.id, kind: field.kind})));
      const selected = candidates.find(item => item.kind === (node.tagName === 'IMG' ? 'image' : 'text')) || candidates[0];
      if (selected) parent.postMessage({type: 'campus-select', ...selected}, location.origin);
    }, true);
    window.addEventListener('message', async event => {
      if (event.origin !== location.origin || event.source !== parent || event.data?.type !== 'campus-preview') return;
      await window.schoolContentReady;
      apply(event.data.documents || {});
    });
    window.schoolContentReady.then(() => parent.postMessage({type: 'campus-preview-ready'}, location.origin));
  }
})();
