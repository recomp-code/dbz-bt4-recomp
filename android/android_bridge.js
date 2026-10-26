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

  // The phone layout (android.css) moves a few elements; app.js finds them by id, so they work wherever they are.
  // Only text and elements of the launcher itself are touched, never anything that came from the network.
  function phoneLayout() {
    const $ = (id) => document.getElementById(id);
    // the page may go under a camera cutout: android.css keeps clear of it with env(safe-area-inset-*)
    const vp = document.querySelector('meta[name="viewport"]');
    if (vp && !/viewport-fit/.test(vp.content)) vp.content += ", viewport-fit=cover";

    // Biblioteca: the game's name and edition go to the play panel next to the art
    const pl = document.querySelector(".playline"), title = $("banner-title"), sub = $("banner-sub");
    if (pl && title && sub) {
      const head = document.createElement("div");
      head.className = "pl-head";
      head.append(title, sub);
      pl.prepend(head);
    }
    // no ISO chosen yet: "Seleccionar ISO" is the next step, so the panel shows it first (class need-iso)
    const play = $("btn-play"), iso = $("btn-iso"), line = $("iso-line");
    if (pl && play && iso) {
      const mark = () => pl.classList.toggle("need-iso",
        !iso.classList.contains("hidden") && play.disabled && play.textContent !== "Jugando");
      const watch = { attributes: true, attributeFilter: ["class", "disabled"], childList: true, characterData: true, subtree: true };
      for (const e of [play, iso]) new MutationObserver(mark).observe(e, watch);
      mark();
    }
    // the ISO is a content:// URI from the system's picker: show the file's name, not the URI
    if (line) {
      const tidy = () => {
        const t = line.textContent;
        if (!t.startsWith("content://")) return;
        let name = "";
        try { name = decodeURIComponent(t.split("/").pop() || ""); } catch (e) { name = ""; }
        name = name.split(/[/:]/).pop();
        line.textContent = /\.[a-z0-9]{2,4}$/i.test(name) ? name : "ISO elegida";
        line.title = t;
      };
      new MutationObserver(tidy).observe(line, { childList: true, characterData: true, subtree: true });
      tidy();
    }

    // En línea, signed out: the title and the pitch go into a card beside the form
    const login = $("login");
    if (login) {
      const intro = document.createElement("div");
      intro.className = "a-intro";
      const h = login.querySelector("h2"), p = login.querySelector("p");
      if (h) intro.append(h);
      if (p) intro.append(p);
      login.prepend(intro);
      const note = login.querySelector(":scope > small");
      if (note) note.textContent = "En este teléfono solo queda guardada tu sesión, en el almacenamiento privado de la app. La contraseña no.";
    }
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", phoneLayout);
  else phoneLayout();
})();
