// Arc Tracker iOS prototype shim.
// The tracker calls its backend with root-relative paths (/api/...). Inside the
// native shell those resolve to the shell's own origin, so send them to the live
// backend instead. NOTE: the Worker does not yet allow cross-origin calls from a
// Capacitor origin, so sync/verify fail until a CORS allowlist is added there
// (one small Worker change, needs owner approval).
(() => {
  const API_BASE = 'https://animemindset.com';
  const origFetch = window.fetch.bind(window);
  window.fetch = (input, init) => {
    if (typeof input === 'string' && input.startsWith('/api/')) {
      input = API_BASE + input;
    }
    return origFetch(input, init);
  };
})();
