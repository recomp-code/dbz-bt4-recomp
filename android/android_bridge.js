"use strict";
// [android] The launcher frontend's Wails runtime on Android: window.go.main.App.<Method>(...) and window.runtime, backed
// by the app's RecompAndroid interface (LauncherActivity.Js) and the Go launcher behind it (RecompBridge). Calls are
// asynchronous like Wails' (a Promise; a Go error rejects it); events arrive through __recompEmit.
(function () {
  const pending = new Map();
  const listeners = Object.create(null);
  let seq = 0;
  // non-ASCII as \u escapes: the JSON crosses JNI as modified UTF-8
  const ascii = (s) => s.replace(/[\u0080-￿]/g, (c) => "\\u" + c.charCodeAt(0).toString(16).padStart(4, "0"));
  window.__recompResolve = (id, r) => {
    const p = pending.get(id);
    if (!p) return;
    pending.delete(id);
    if (r && r.e) p.reject(r.e); else p.resolve(r ? r.r : undefined);
  };
  window.__recompEmit = (name, data) => {
    for (const cb of (listeners[name] || []).slice()) {
      try { cb(data); } catch (e) { console.error(e); }
    }
  };
  const App = new Proxy({}, {
    get: (_, method) => (...args) => new Promise((resolve, reject) => {
      const id = ++seq;
      pending.set(id, { resolve, reject });
      RecompAndroid.call(id, String(method), ascii(JSON.stringify(args)));
    }),
  });
  window.go = { main: { App } };
  window.runtime = {
    EventsOn: (name, cb) => {
      (listeners[name] = listeners[name] || []).push(cb);
      return () => { listeners[name] = (listeners[name] || []).filter((x) => x !== cb); };
    },
    EventsOff: (name) => { delete listeners[name]; },
    WindowMinimise: () => RecompAndroid.minimise(),
    Quit: () => RecompAndroid.quit(),
    BrowserOpenURL: (u) => RecompAndroid.openUrl(u),
    OnFileDrop: () => {},
  };
  document.documentElement.classList.add("android");
})();
