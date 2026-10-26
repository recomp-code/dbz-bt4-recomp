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

    // Biblioteca: the art on top; over it a sheet with the game (edition, name, ISO, a few chips), the options
    // under it, and at its foot the action bar (JUGAR and the ISO button). Built from the page's own elements.
    const vplay = $("v-play"), pl = document.querySelector(".playline"), title = $("banner-title"), sub = $("banner-sub");
    const play = $("btn-play"), iso = $("btn-iso"), line = $("iso-line");
    let sheetBody = null;
    if (vplay && pl && title && sub && line && iso) {
      const div = (cls) => { const d = document.createElement("div"); d.className = cls; return d; };
      const sheet = div("a-sheet"), head = div("pl-head"), chips = div("a-chips");
      sheetBody = div("a-sheet-body");
      head.append(sub, title, line, chips);
      sheetBody.append(head);
      // the options (sections, rows, controls' text) follow the action bar in the page: they go into the sheet
      for (let n = pl.nextElementSibling; n; ) { const next = n.nextElementSibling; sheetBody.append(n); n = next; }
      pl.append(iso);
      sheet.append(sheetBody, pl);
      vplay.append(sheet);

      // the chips: the chosen quality and frame rate, and what the game is; text only, redrawn when it changes
      let shown = "";
      const drawChips = () => {
        const q = $("s-quality"), fps = $("go-fps60");
        const list = [];
        if (q && q.selectedOptions.length) list.push(q.selectedOptions[0].textContent);
        if (fps) list.push(fps.checked ? "60 fps" : "30 fps");
        list.push("En línea", "PS2 Recomp");
        const key = list.join("|");
        if (key === shown) return;
        shown = key;
        chips.replaceChildren(...list.map((t) => { const c = document.createElement("span"); c.className = "a-chip"; c.textContent = t; return c; }));
      };
      document.addEventListener("change", drawChips);
      setInterval(drawChips, 1000);   // app.js sets the values on every refresh without an event
      drawChips();
    }
    // no ISO chosen yet: "Seleccionar ISO" takes JUGAR's place (class need-iso on the view)
    if (vplay && play && iso) {
      const mark = () => vplay.classList.toggle("need-iso",
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

    // the launcher opens at the top: while the first state arrives and the page grows (and the system bars hide),
    // nothing may leave it scrolled down; the first touch hands the scroll to the player
    const main = document.querySelector("main");
    if (main) {
      // the header is see-through over Biblioteca's art; once the page scrolls under it, it turns solid (a-solid)
      const html = document.documentElement;
      const solid = () => html.classList.toggle("a-solid", main.scrollTop > 24);
      main.addEventListener("scroll", solid, { passive: true });
      if ("scrollRestoration" in history) history.scrollRestoration = "manual";
      let settle = true;
      const top = () => {
        for (const e of [main, sheetBody, document.scrollingElement]) if (e) e.scrollTop = 0;
      };
      const stop = () => { settle = false; };
      for (const ev of ["touchstart", "wheel", "keydown", "mousedown"]) window.addEventListener(ev, stop, { capture: true, passive: true, once: true });
      const until = Date.now() + 1500;
      const loop = () => { if (!settle || Date.now() > until) return; top(); requestAnimationFrame(loop); };
      top();
      requestAnimationFrame(loop);
      window.addEventListener("load", () => { if (settle) top(); solid(); });
      // a tab change starts the new view at the top
      document.querySelectorAll(".tab").forEach((t) => t.addEventListener("click", () => { main.scrollTop = 0; solid(); }));
    }

    // En línea, signed out: the title and the pitch go into a card above the form
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
