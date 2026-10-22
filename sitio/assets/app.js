'use strict';
(async () => {
  await window.schoolContentReady;
  const data = new Proxy({}, {get: (_, key) => (window.schoolSiteData || JSON.parse(document.getElementById('site-data').textContent))[key]});
  const film = document.querySelector('.school-film');
  if (film && matchMedia('(max-width: 599px)').matches) {
    film.src = data.filmMobile || '/sitio/assets/liceo-en-movimiento-vertical.mp4';
  }
  const menu = document.querySelector('.menu-toggle');
  const nav = document.getElementById('site-nav');
  if (menu) menu.addEventListener('click', () => {
    const open = menu.getAttribute('aria-expanded') !== 'true';
    menu.setAttribute('aria-expanded', String(open));
    menu.setAttribute('aria-label', open ? 'Cerrar menú' : 'Abrir menú');
    nav.classList.toggle('open', open);
  });
  document.addEventListener('keydown', event => {
    if (event.key === 'Escape') document.querySelectorAll('.submenu-toggle[aria-expanded="true"]').forEach(button => { button.click(); button.focus(); });
    if (event.key === 'Escape' && menu?.getAttribute('aria-expanded') === 'true') {
      menu.click(); menu.focus();
    }
  });

  function closeSubmenus(except) {
    document.querySelectorAll('.submenu-toggle').forEach(button => {
      if (button === except) return;
      button.setAttribute('aria-expanded', 'false');
      document.getElementById(button.getAttribute('aria-controls')).hidden = true;
    });
  }
  document.querySelectorAll('.submenu-toggle').forEach(button => button.addEventListener('click', () => {
    const open = button.getAttribute('aria-expanded') !== 'true';
    closeSubmenus(button);
    button.setAttribute('aria-expanded', String(open));
    document.getElementById(button.getAttribute('aria-controls')).hidden = !open;
  }));
  document.addEventListener('click', event => { if (!event.target.closest('.nav-group')) closeSubmenus(); });
  document.addEventListener('focusin', event => { if (!event.target.closest('.nav-group')) closeSubmenus(); });
  document.querySelectorAll('[data-carousel]').forEach(carousel => {
    const track = carousel.querySelector('.photo-track');
    const move = direction => track.scrollBy({left: direction * (track.firstElementChild.getBoundingClientRect().width + parseFloat(getComputedStyle(track).gap)), behavior: matchMedia('(prefers-reduced-motion: reduce)').matches ? 'instant' : 'smooth'});
    carousel.querySelector('[data-previous]').addEventListener('click', () => move(-1));
    carousel.querySelector('[data-next]').addEventListener('click', () => move(1));
    const update = () => {
      carousel.querySelector('[data-previous]').disabled = track.scrollLeft < 2;
      carousel.querySelector('[data-next]').disabled = track.scrollLeft + track.clientWidth >= track.scrollWidth - 2;
    };
    track.addEventListener('scroll', update, {passive: true});
    new ResizeObserver(update).observe(track);
    update();
  });

  const mediaDialog = document.getElementById('media-dialog');
  const content = document.getElementById('media-content');
  const footer = document.getElementById('media-footer');
  const title = document.getElementById('media-title');
  let opener;
  let galleryIndex = 0;
  function element(tag, props, text) {
    const node = document.createElement(tag);
    for (const [key, value] of Object.entries(props || {})) node.setAttribute(key, value);
    if (text) node.textContent = text;
    return node;
  }
  function openDialog(trigger) {
    opener = trigger;
    if (!mediaDialog.open) mediaDialog.showModal();
    document.body.classList.add('dialog-open');
  }
  function finishMedia() {
    // Removing the frame stops playback when the dialog closes.
    content.replaceChildren(); footer.replaceChildren();
    document.body.classList.remove('dialog-open');
    opener?.focus();
  }
  mediaDialog?.addEventListener('close', finishMedia);
  document.querySelector('[data-dialog-close]')?.addEventListener('click', () => mediaDialog.close());
  mediaDialog?.addEventListener('click', event => { if (event.target === mediaDialog) mediaDialog.close(); });

  function openVideo(id, trigger) {
    const item = data.media.find(item => item.id === id);
    if (!item) return;
    content.replaceChildren(); footer.replaceChildren();
    title.textContent = item.title;
    if (item.embed) {
      const area = element('div', {class: `embed-area ${item.platform}`});
      area.append(element('iframe', {src: item.embed, title: item.title,
        allow: 'autoplay; fullscreen; encrypted-media; picture-in-picture',
        allowfullscreen: '', referrerpolicy: 'strict-origin-when-cross-origin', loading: 'eager'}));
      content.append(area);
    } else {
      const area = element('div', {class: 'social-profile-card'});
      area.append(element('img', {src: `/sitio/assets/${item.platform}.svg`, alt: ''}));
      area.append(element('p', {}, item.description));
      area.append(element('a', {class: 'button', href: item.url, target: '_blank', rel: 'noopener noreferrer'}, 'Abrir perfil oficial'));
      content.append(area);
    }
    const note = element('div', {class: 'media-note'});
    note.append(element('p', {}, 'Contenido de la red oficial del colegio. Si el reproductor no está disponible o solicita una sesión, abre la publicación original.'));
    note.append(element('a', {href: item.url, target: '_blank', rel: 'noopener noreferrer'}, item.embed ? 'Abrir publicación original ↗' : 'Visitar perfil oficial ↗'));
    footer.append(note);
    openDialog(trigger);
  }
  document.querySelectorAll('[data-video]').forEach(trigger => trigger.addEventListener('click', () => openVideo(trigger.dataset.video, trigger)));

  function showGallery(index) {
    const visible = [...document.querySelectorAll('[data-gallery]:not([hidden])')].map(button => Number(button.dataset.gallery));
    galleryIndex = index;
    const original = data.gallery[index];
    const tile = document.querySelector(`[data-gallery="${index}"]`);
    const item = {...original, title: tile?.querySelector('strong')?.textContent || original.title, category: tile?.querySelector('small')?.textContent || original.category};
    title.textContent = item.title;
    content.replaceChildren(element('img', {class: 'gallery-full', src: tile?.querySelector('img')?.src || `/school-home/${item.image}.webp`, alt: tile?.querySelector('img')?.alt || item.alt}));
    footer.replaceChildren();
    const controls = element('div', {class: 'gallery-controls'});
    for (const [label, direction] of [['Fotografía anterior', -1], ['Fotografía siguiente', 1]]) {
      const button = element('button', {class: 'icon-button', type: 'button', 'aria-label': label}, direction === -1 ? '←' : '→');
      button.addEventListener('click', () => {
        const position = visible.indexOf(galleryIndex);
        showGallery(visible[(position + direction + visible.length) % visible.length]);
      });
      controls.append(button);
      if (direction === -1) controls.append(element('span', {'aria-live': 'polite'}, item.category));
    }
    footer.append(controls);
  }
  document.querySelectorAll('[data-gallery]').forEach(trigger => trigger.addEventListener('click', () => {
    showGallery(Number(trigger.dataset.gallery)); openDialog(trigger);
  }));
  mediaDialog?.addEventListener('keydown', event => {
    if (!content.querySelector('.gallery-full')) return;
    if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') {
      event.preventDefault();
      footer.querySelectorAll('button')[event.key === 'ArrowLeft' ? 0 : 1]?.click();
    }
  });
  document.querySelectorAll('[data-filter]').forEach(trigger => trigger.addEventListener('click', () => {
    document.querySelectorAll('[data-filter]').forEach(button => {
      const selected = button === trigger;
      button.classList.toggle('active', selected); button.setAttribute('aria-pressed', String(selected));
    });
    document.querySelectorAll('[data-gallery]').forEach(item => {
      item.hidden = trigger.dataset.filter !== 'Todos' && item.dataset.category !== trigger.dataset.filter;
    });
  }));

  const tabs = [...document.querySelectorAll('[role="tab"]')];
  function selectTab(tab, focus = false) {
    for (const button of tabs) {
      const selected = tab === button;
      button.setAttribute('aria-selected', String(selected));
      button.tabIndex = selected ? 0 : -1;
      document.getElementById(button.getAttribute('aria-controls')).hidden = !selected;
    }
    if (focus) tab.focus();
  }
  tabs.forEach((tab, index) => {
    tab.addEventListener('click', () => selectTab(tab));
    tab.addEventListener('keydown', event => {
      let next;
      if (event.key === 'ArrowRight') next = (index + 1) % tabs.length;
      if (event.key === 'ArrowLeft') next = (index - 1 + tabs.length) % tabs.length;
      if (event.key === 'Home') next = 0;
      if (event.key === 'End') next = tabs.length - 1;
      if (next !== undefined) { event.preventDefault(); selectTab(tabs[next], true); }
    });
  });
  const hashTab = tabs.find(tab => `#${tab.getAttribute('aria-controls')}` === location.hash);
  if (hashTab) selectTab(hashTab);
  window.addEventListener('hashchange', () => {
    const current = tabs.find(tab => `#${tab.getAttribute('aria-controls')}` === location.hash);
    if (current) selectTab(current);
  });

  document.querySelectorAll('.conversation-form').forEach(form => form.addEventListener('submit', event => {
    event.preventDefault();
    if (!form.reportValidity()) return;
    const values = new FormData(form);
    const name = String(values.get('name') || '').trim();
    const message = String(values.get('message') || '').trim();
    if (!name || !message) return;
    const target = new URL(data.whatsapp);
    target.searchParams.set('text', `Hola, soy ${name}. Me interesa: ${values.get('interest')}.\n${message}`);
    const status = form.querySelector('.form-status');
    status.replaceChildren(element('a', {href: target.href, target: '_blank', rel: 'noopener noreferrer'}, 'Abrir mi consulta en WhatsApp ↗'));
    // A real user click opens only a draft conversation; nothing is sent here.
    window.open(target.href, '_blank', 'noopener,noreferrer');
  }));

  const searchDialog = document.getElementById('search-dialog');
  const searchInput = document.getElementById('site-search');
  const results = document.getElementById('search-results');
  const normalize = value => value.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
  function search() {
    const query = normalize(searchInput.value.trim());
    const targets = [...data.routes, {label: 'Plataforma de familias · Iniciar sesión', url: '/login'}];
    const matches = targets.filter(target => normalize(target.label).includes(query));
    results.replaceChildren(...matches.map(item => element('a', {href: item.url}, `${item.label} →`)));
    if (!matches.length) results.append(element('p', {}, 'No encontramos esa sección. Puedes consultar al equipo desde Contacto.'));
  }
  document.querySelectorAll('[data-search-open]').forEach(button => button.addEventListener('click', () => {
    searchInput.value = ''; search(); searchDialog.showModal(); document.body.classList.add('dialog-open'); searchInput.focus();
  }));
  searchInput?.addEventListener('input', search);
  document.querySelector('[data-search-close]')?.addEventListener('click', () => searchDialog.close());
  searchDialog?.addEventListener('close', () => document.body.classList.remove('dialog-open'));
  searchDialog?.addEventListener('click', event => { if (event.target === searchDialog) searchDialog.close(); });
})();
