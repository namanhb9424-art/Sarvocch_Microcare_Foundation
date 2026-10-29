// Sarvocch Microcare Foundation front-end helpers: online/offline pill, service worker, offline report queue + auto-sync.
(function () {
  const pill = document.getElementById('netpill');
  function setNet() {
    if (!pill) return;
    pill.textContent = navigator.onLine ? 'Online' : 'Offline';
    pill.className = 'badge ms-auto me-3 ' + (navigator.onLine ? 'bg-success' : 'bg-warning text-dark');
  }
  window.addEventListener('online', () => { setNet(); flush(); });
  window.addEventListener('offline', setNet);
  setNet();

  if ('serviceWorker' in navigator) navigator.serviceWorker.register('/sw.js').then(() => {
    // Save the offline pages in advance, so they open even if this phone has never visited them without a network.
    if (navigator.onLine && document.querySelector('meta[name=uid]')) ['/sync', '/field'].forEach(u => fetch(u, { credentials: 'same-origin' }).catch(() => {}));
  }).catch(() => {});
  // On logout, wipe saved pages (a shared phone must not show the previous person's data).
  document.querySelectorAll('a[href="/logout"]').forEach(l => l.addEventListener('click', () => {
    if (navigator.serviceWorker && navigator.serviceWorker.controller) navigator.serviceWorker.controller.postMessage('clear');
  }));
  // "Install app" button (Chrome / Edge / Android). iPhone: Share > Add to Home Screen.
  let deferred = null; const ib = document.getElementById('installbtn');
  window.addEventListener('beforeinstallprompt', e => { e.preventDefault(); deferred = e; if (ib) ib.classList.remove('d-none'); });
  if (ib) ib.addEventListener('click', async () => { if (!deferred) return; deferred.prompt(); await deferred.userChoice; deferred = null; ib.classList.add('d-none'); });
  window.addEventListener('appinstalled', () => { if (ib) ib.classList.add('d-none'); });

  const UID = (document.querySelector('meta[name=uid]') || {}).content || '';
  const KEY = 'sarvocch_queue_v1';
  // The saved reports belong to the officer who wrote them: someone else logging in on the same phone never sees or sends them.
  const all = () => { try { return JSON.parse(localStorage.getItem(KEY) || '[]'); } catch (e) { return []; } };
  const load = () => all().filter(i => String(i.uid || '') === UID);
  const save = (q) => localStorage.setItem(KEY, JSON.stringify(all().filter(i => String(i.uid || '') !== UID).concat(q)));

  function render() {
    const ul = document.getElementById('queue'); if (!ul) return;
    const q = load();
    document.getElementById('qcount').textContent = q.length;
    ul.innerHTML = q.length ? q.map(i => '<li class="list-group-item">Visit #' + (i.task_id || '-') + ' · ₹' + (i.collected || 0) +
      ' · ' + (i.notes || '').slice(0, 40) + (i.photo ? ' · 📷' : '') + ' <span class="text-muted">(' + i.captured_at.slice(11, 16) + ')</span></li>').join('')
      : '<li class="list-group-item text-muted">All synced ✔</li>';
  }

  async function flush() {
    const q = load();
    if (!q.length || !navigator.onLine) { render(); return; }
    try {
      const r = await fetch('/api/sync', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ items: q }) });
      if (!r.ok) throw new Error('HTTP ' + r.status);
      const d = await r.json();
      const done = new Set([...(d.accepted || []), ...(d.duplicates || []), ...(d.rejected || [])]);
      save(q.filter(i => !done.has(i.uuid)));
      render();
      if ((d.accepted || []).length && document.getElementById('queue')) setTimeout(() => location.reload(), 800);
    } catch (e) { render(); }
  }

  function readPhoto(file) {
    return new Promise(res => {
      if (!file) return res(null);
      const img = new Image(), fr = new FileReader();
      fr.onload = () => { img.onload = () => {   // downscale to keep the queue small
        const s = Math.min(1, 800 / Math.max(img.width, img.height)), c = document.createElement('canvas');
        c.width = img.width * s; c.height = img.height * s; c.getContext('2d').drawImage(img, 0, 0, c.width, c.height);
        res(c.toDataURL('image/jpeg', 0.7)); }; img.onerror = () => res(null); img.src = fr.result; };
      fr.onerror = () => res(null); fr.readAsDataURL(file);
    });
  }

  const form = document.getElementById('rep');
  if (form) {
    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      const item = {
        uuid: (crypto.randomUUID ? crypto.randomUUID() : 'id-' + Date.now() + '-' + Math.random().toString(16).slice(2)),
        task_id: document.getElementById('task_id').value, collected: document.getElementById('collected').value || 0,
        notes: document.getElementById('notes').value, mark_done: document.getElementById('mark_done').checked,
        uid: UID, captured_at: new Date().toISOString(), photo: await readPhoto(document.getElementById('photo').files[0])
      };
      const finish = () => { const q = load(); q.push(item); try { save(q); } catch (err) { alert('Device storage is full - remove the photo and retry.'); return; } form.reset(); render(); flush(); };
      if (navigator.geolocation) navigator.geolocation.getCurrentPosition(p => { item.lat = p.coords.latitude; item.lng = p.coords.longitude; finish(); }, finish, { timeout: 3000 });
      else finish();
    });
    document.getElementById('syncnow').onclick = flush;
    render(); flush();
  }
})();
