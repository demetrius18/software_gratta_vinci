/* Compatibilità GitHub Pages: window.storage persistente tramite localStorage.
   Mantiene le chiavi gv_* già presenti nello stesso browser/origine. */
(function () {
  'use strict';
  if (window.storage && typeof window.storage.get === 'function') return;
  window.storage = {
    async get(key) { const value = localStorage.getItem(key); return value === null ? null : { key, value }; },
    async set(key, value) { localStorage.setItem(key, String(value)); return { key, value: String(value) }; },
    async delete(key) { localStorage.removeItem(key); return { key, deleted: true }; },
    async list(prefix) { const keys = Object.keys(localStorage).filter(k => !prefix || k.startsWith(prefix)); return { keys }; }
  };
})();
