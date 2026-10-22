'use strict';
(() => {
  const $ = id => document.getElementById(id);
  let manifest;
  let published = {};
  let drafts = {};
  let current = 'page_inicio';
  let busy = false;
  let previewPath;
  const pending = new Map();
  function parentEvent(message) {
    // Same-origin DOM access and the exact frame element bind this bridge to
    // its Flutter host. Create the event in the parent's realm for Dart types.
    if (parent !== window && frameElement) frameElement.dispatchEvent(new parent.CustomEvent('campus-api', {detail: JSON.stringify(message)}));
  }
  const dirtyIds = () => Object.keys(drafts).filter(id => JSON.stringify(drafts[id].values) !== JSON.stringify(published[id]?.values || {}));
  function status(message, error = false) { $('status').textContent = message; $('status').classList.toggle('error', error); }
  function controls() {
    const dirty = dirtyIds().length;
    $('publish').disabled = busy || !dirty;
    $('publish').textContent = dirty ? `Publicar cambios (${dirty})` : 'Publicar cambios';
    $('discard').disabled = busy || !dirty;
    $('history').disabled = busy || !manifest;
    $('area').disabled = busy || !manifest;
    $('fields').querySelectorAll('button,input,textarea').forEach(node => { node.disabled = busy; });
    parentEvent({type: 'campus-dirty', dirty: dirty > 0});
  }
  // All privileged operations stay in the authenticated Flutter parent.
  // No token, password or credential is stored or placed in a URL.
  function api(operation, input = {}) {
    if (parent === window) return Promise.reject(new Error('Abre este editor desde el módulo Sitio web después de iniciar sesión.'));
    return new Promise((resolve, reject) => {
      const id = crypto.randomUUID();
      const timeout = setTimeout(() => { pending.delete(id); reject(new Error('La operación tardó demasiado. Comprueba tu sesión y vuelve a intentarlo.')); }, 90000);
      pending.set(id, {resolve, reject, timeout});
      parentEvent({type: 'campus-api', id, operation, input});
    });
  }
  function preview() {
    $('preview').contentWindow?.postMessage({type: 'campus-preview', documents: drafts}, location.origin);
  }
  function setValue(field, value) {
    if (value === field.value) delete drafts[current].values[field.id];
    else drafts[current].values[field.id] = value;
    controls(); preview();
    status('Vista previa actualizada. Los cambios aún no están publicados.');
  }
  function node(tag, content, attributes = {}) {
    const element = document.createElement(tag);
    if (content) element.textContent = content;
    for (const [key, value] of Object.entries(attributes)) element.setAttribute(key, value);
    return element;
  }
  async function upload(field, file) {
    if (!file) return;
    busy = true; controls(); status('Optimizando y subiendo la imagen…');
    try {
      if (!['image/jpeg', 'image/png', 'image/webp'].includes(file.type) || file.size > 10000000) throw new Error('Selecciona una imagen JPG, PNG o WebP de hasta 10 MB.');
      const bitmap = await createImageBitmap(file);
      const ratio = Math.min(1, 1920 / Math.max(bitmap.width, bitmap.height));
      const canvas = document.createElement('canvas');
      canvas.width = Math.max(1, Math.round(bitmap.width * ratio)); canvas.height = Math.max(1, Math.round(bitmap.height * ratio));
      canvas.getContext('2d').drawImage(bitmap, 0, 0, canvas.width, canvas.height); bitmap.close();
      const image = await new Promise(resolve => canvas.toBlob(resolve, 'image/webp', .88));
      if (!image || image.size > 6000000) throw new Error('No se pudo optimizar esta imagen. Selecciona otra.');
      const base64 = await new Promise((resolve, reject) => { const reader = new FileReader(); reader.onload = () => resolve(reader.result.split(',')[1]); reader.onerror = reject; reader.readAsDataURL(image); });
      const result = await api('uploadCampusImage', {base64});
      setValue(field, result.url); renderFields();
      status('Imagen cargada en la vista previa. Publica los cambios cuando estés conforme.');
    } catch (error) { status(error.message, true); }
    finally { busy = false; controls(); }
  }
  function renderFields(selected) {
    const area = manifest.documents[current];
    const query = $('filter').value.trim().toLocaleLowerCase('es');
    const fields = area.fields.filter(field => !query || [field.label, field.section, drafts[current].values[field.id] || field.value, field.kind === 'image' ? 'imagen foto' : ''].join(' ').toLocaleLowerCase('es').includes(query));
    $('fields').replaceChildren();
    for (const field of fields) {
      const wrapper = node('div', '', {class: 'field', id: `field-${field.id}`});
      wrapper.append(node('h3', field.section));
      const inputId = `input-${field.id}`;
      wrapper.append(node('label', field.label, {for: inputId}));
      const value = drafts[current].values[field.id] ?? field.value;
      if (field.kind === 'image') wrapper.append(node('img', '', {src: value, alt: field.label}));
      const input = node(field.kind === 'text' && (value.length > 95 || value.includes('\n')) ? 'textarea' : 'input', '', {id: inputId, maxlength: field.max});
      input.value = value;
      input.addEventListener('input', () => setValue(field, input.value));
      wrapper.append(input);
      const actions = node('div', '', {class: 'field-actions'});
      if (field.kind === 'image') {
        const button = node('button', 'Subir imagen');
        const picker = node('input', '', {type: 'file', accept: 'image/jpeg,image/png,image/webp', hidden: ''});
        button.addEventListener('click', () => picker.click());
        picker.addEventListener('change', () => upload(field, picker.files[0]));
        actions.append(button, picker);
      }
      const reset = node('button', 'Recuperar original');
      reset.addEventListener('click', () => { setValue(field, field.value); renderFields(field.id); });
      actions.append(reset); wrapper.append(actions); $('fields').append(wrapper);
    }
    if (!fields.length) $('fields').append(node('p', 'No se encontraron campos con esa búsqueda.'));
    controls();
    if (selected) {
      const field = $(`field-${selected}`);
      field?.classList.add('selected'); field?.scrollIntoView({block: 'center', behavior: 'instant'});
    }
  }
  function selectArea(id, selected) {
    if (!manifest.documents[id] || busy) return;
    current = id; $('area').value = id; $('filter').value = ''; renderFields(selected);
    const next = id.startsWith('page_') ? manifest.documents[id].path : previewPath || '/';
    if (next !== previewPath) {
      previewPath = next;
      $('preview').src = `${next}?campusPreview=1`;
      $('open-page').href = next;
    } else preview();
  }
  window.addEventListener('message', event => {
    if (event.origin !== location.origin) return;
    if (event.source === parent && event.data?.type === 'campus-api-result') {
      const request = pending.get(event.data.id);
      if (!request) return;
      pending.delete(event.data.id); clearTimeout(request.timeout);
      if (event.data.error) request.reject(new Error(event.data.error)); else request.resolve(event.data.result);
    }
    if (event.source === $('preview').contentWindow) {
      if (event.data?.type === 'campus-preview-ready') preview();
      if (event.data?.type === 'campus-select') selectArea(event.data.area, event.data.field);
    }
  });
  $('area').addEventListener('change', () => selectArea($('area').value));
  $('filter').addEventListener('input', () => renderFields());
  for (const mode of ['desktop', 'mobile']) $(mode).addEventListener('click', () => {
    document.querySelector('.preview-stage').classList.toggle('mobile', mode === 'mobile');
    for (const other of ['desktop', 'mobile']) $(other).setAttribute('aria-pressed', String(mode === other));
  });
  $('discard').addEventListener('click', () => {
    if (!confirm('¿Descartar todos los cambios sin publicar de esta sesión?')) return;
    drafts = structuredClone(published); renderFields(); preview(); status('Cambios descartados. Se conserva el contenido publicado.');
  });
  $('publish').addEventListener('click', async () => {
    const ids = dirtyIds();
    if (!ids.length || !confirm(`¿Publicar el contenido de ${ids.length} sección(es) en QA? El diseño no cambia.`)) return;
    busy = true; controls(); status('Publicando…');
    try {
      const result = await api('publishCampusContent', {templateId: manifest.templateId, changes: ids.map(id => ({id, expectedRevision: published[id].revision, values: drafts[id].values}))});
      Object.assign(published, result.documents); Object.assign(drafts, structuredClone(result.documents));
      preview(); status('Contenido publicado en QA. Las páginas lo mostrarán al abrirlas o recargarlas; la caché pública puede tardar hasta 30 segundos.');
    } catch (error) { status(error.message + ' Tus cambios permanecen en la vista previa.', true); }
    finally { busy = false; controls(); }
  });
  $('close-history').addEventListener('click', () => $('history-dialog').close());
  $('history').addEventListener('click', async () => {
    busy = true; controls();
    try {
      const result = await api('getCampusHistory', {id: current});
      $('revisions').replaceChildren();
      for (const revision of result.revisions) {
        const row = node('div', '', {class: 'revision'});
        row.append(node('span', `Revisión ${revision.revision} · ${revision.date ? new Date(revision.date).toLocaleString('es-CO') : ''}`));
        const restore = node('button', 'Recuperar');
        restore.addEventListener('click', async () => {
          if (busy || !confirm(`¿Recuperar la revisión ${revision.revision} de esta sección?`)) return;
          busy = true; controls(); restore.disabled = true;
          try {
            const response = await api('restoreCampusRevision', {id: current, expectedRevision: published[current].revision, revision: revision.revision, templateId: manifest.templateId});
            Object.assign(published, response.documents); Object.assign(drafts, structuredClone(response.documents));
            $('history-dialog').close(); renderFields(); preview(); status('Revisión recuperada y publicada en QA.');
          } catch (error) { status(error.message, true); }
          finally { busy = false; restore.disabled = false; controls(); }
        });
        row.append(restore); $('revisions').append(row);
      }
      if (!result.revisions.length) $('revisions').append(node('p', 'Aún no hay cambios publicados en esta sección.'));
      $('history-dialog').showModal();
    } catch (error) { status(error.message, true); }
    finally { busy = false; controls(); }
  });
  window.addEventListener('beforeunload', event => { if (dirtyIds().length) { event.preventDefault(); event.returnValue = ''; } });
  async function start() {
    try {
      const response = await fetch('/sitio/editor-manifest.json', {cache: 'no-store'});
      if (!response.ok) throw new Error('No se pudo cargar el diseño del sitio.');
      manifest = await response.json();
      const result = await api('getCampusEditor');
      published = result.documents;
      for (const id of Object.keys(manifest.documents)) if (published[id]?.templateId !== manifest.templateId) throw new Error('El diseño publicado y el editor no coinciden. Recarga y consulta con soporte si persiste.');
      drafts = structuredClone(published);
      for (const area of Object.values(manifest.documents)) $('area').append(node('option', area.label, {value: area.id}));
      selectArea(current); controls(); status('Elige una página. Puedes editar textos, fotos, enlaces y videos sin modificar su diseño.');
    } catch (error) { status(error.message, true); }
  }
  start();
})();
