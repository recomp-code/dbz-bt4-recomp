// DBZ BT4 launcher for macOS (the Mac twin of windows/launcher/DBZ_BT4.cs).
// Asks for the player's ISO once, copies the ELF and the small boot files out of it (they are not distributed), checks
// that it is the disc the game was recompiled from, and starts the recompiled runner with PCSX2's GS host (Metal).
// Everything the game writes lives in ~/Library/Application Support/DBZ_BT4: the app itself can stay read-only
// (macOS runs downloaded apps from a read-only copy until they are moved to Applications).
// Build: macos/build_launcher.sh (swiftc, Xcode command line tools).
import AppKit
import CryptoKit

// SHA-256 of SLUS_219.78 (BT4 Beta 14 Rev2): the game code in ps2EntryRunner was recompiled from exactly this ELF.
let elfSha256 = "224525c5639c00e01c2604c4685d307bc739c041000dcf8c69a4f884f465e8a4"
let elfName = "SLUS_219.78"

// MARK: - ISO 9660 (just enough to read the root directory and two subfolders)

final class Iso9660 {
    struct Entry { let name: String; let lba: UInt64; let size: UInt64; let isDir: Bool }
    private let fh: FileHandle
    private(set) var rootLba: UInt64 = 0
    private(set) var rootSize: UInt64 = 0

    init(path: String) throws {
        guard let h = FileHandle(forReadingAtPath: path) else { throw err("No pude abrir la ISO.") }
        fh = h
        let pvd = try read(16 * 2048, 2048)
        guard pvd.count == 2048, pvd[0] == 1, String(bytes: pvd[1..<6], encoding: .ascii) == "CD001" else {
            throw err("El archivo no es una imagen ISO 9660 (DVD de PS2).")
        }
        let root = pvd[156..<(156 + 34)]
        rootLba = UInt64(le32(root, 2))
        rootSize = UInt64(le32(root, 10))
    }
    deinit { try? fh.close() }

    func read(_ offset: UInt64, _ count: Int) throws -> Data {
        try fh.seek(toOffset: offset)
        return try fh.read(upToCount: count) ?? Data()
    }

    func list(_ lba: UInt64, _ size: UInt64) throws -> [Entry] {
        let d = try read(lba * 2048, Int(size))
        var out: [Entry] = []
        var sector = 0
        while sector < d.count {
            var p = sector
            while p < min(sector + 2048, d.count) {
                let len = Int(d[d.startIndex + p])
                if len == 0 { break }
                let nameLen = Int(d[d.startIndex + p + 32])
                let flags = d[d.startIndex + p + 25]
                let nameBytes = d[(d.startIndex + p + 33)..<(d.startIndex + p + 33 + nameLen)]
                if !(nameLen == 1 && (nameBytes.first == 0 || nameBytes.first == 1)) {
                    var name = String(bytes: nameBytes, encoding: .ascii) ?? ""
                    if let semi = name.firstIndex(of: ";") { name = String(name[..<semi]) }
                    if name.hasSuffix(".") { name.removeLast() }
                    out.append(Entry(name: name, lba: UInt64(le32(d, p + 2)), size: UInt64(le32(d, p + 10)),
                                     isDir: (flags & 2) != 0))
                }
                p += len
            }
            sector += 2048
        }
        return out
    }

    func readFile(_ e: Entry) throws -> Data { try read(e.lba * 2048, Int(e.size)) }

    private func le32(_ d: Data, _ o: Int) -> UInt32 {
        let b = d.startIndex + o
        return UInt32(d[b]) | UInt32(d[b + 1]) << 8 | UInt32(d[b + 2]) << 16 | UInt32(d[b + 3]) << 24
    }
}

func err(_ msg: String) -> NSError { NSError(domain: "DBZ", code: 1, userInfo: [NSLocalizedDescriptionKey: msg]) }

// MARK: - Paths

struct Paths {
    let bundle = Bundle.main
    var macos: URL { bundle.executableURL!.deletingLastPathComponent() }
    var res: URL { bundle.resourceURL! }
    let support: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("DBZ_BT4", isDirectory: true)
    var runtime: URL { support.appendingPathComponent("runtime", isDirectory: true) }
    var data: URL { runtime.appendingPathComponent("data", isDirectory: true) }
    var gshost: URL { support.appendingPathComponent("gshost", isDirectory: true) }
    var logs: URL { support.appendingPathComponent("logs", isDirectory: true) }
    var elf: URL { data.appendingPathComponent("SLUS_216.78") }
}

// Quality presets: one ini each (like the Windows launcher), so what the in-game F1 menu changes is kept per quality.
struct Quality { let title: String; let ini: String }
let qualities = [
    Quality(title: "Máxima: 6x nativo (M Pro / Max / Ultra)", ini: "dbz.ini"),
    Quality(title: "Alta: 4x nativo", ini: "dbz_4x.ini"),
    Quality(title: "Equilibrada: 3x nativo", ini: "dbz_3x.ini"),
    Quality(title: "Apple MetalFX: 3x reescalado a tu pantalla (cualquier Mac)", ini: "dbz_metalfx.ini"),
]

func defaultQuality() -> Int {
    var size = 0
    sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
    var buf = [CChar](repeating: 0, count: max(size, 1))
    sysctlbyname("machdep.cpu.brand_string", &buf, &size, nil, 0)
    let chip = String(cString: buf)
    if chip.contains("Max") || chip.contains("Ultra") { return 0 }
    if chip.contains("Pro") { return 1 }
    return 3
}

// MARK: - Window

final class Launcher: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let paths = Paths()
    var window: NSWindow!
    let status = NSTextField(wrappingLabelWithString: "")
    let pick = NSButton(title: "Seleccionar ISO…", target: nil, action: nil)
    let play = NSButton(title: "JUGAR", target: nil, action: nil)
    let quality = NSPopUpButton(frame: .zero, pullsDown: false)
    let fps60 = NSButton(checkboxWithTitle: "Peleas a 60 fps (la PS2 iba a 30)", target: nil, action: nil)
    let fullscreen = NSButton(checkboxWithTitle: "Pantalla completa (F11 o Alt+Enter cambia durante el juego)",
                              target: nil, action: nil)
    var isoPath = ""
    var direct = false
    var game: Process?
    let prefs = UserDefaults.standard

    func applicationDidFinishLaunching(_ n: Notification) {
        let args = CommandLine.arguments
        direct = args.contains("--jugar")
        buildWindow()
        loadConfig()
        if let i = args.firstIndex(of: "--iso"), i + 1 < args.count { useIso(args[i + 1]) }
        refreshState()
        if direct && gameReady() {
            startGame()
        } else {
            direct = false
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { game == nil }

    func applicationShouldTerminate(_ s: NSApplication) -> NSApplication.TerminateReply {
        if let g = game, g.isRunning { g.terminate() }
        return .terminateNow
    }

    func label(_ text: String, size: CGFloat = 13, bold: Bool = false) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = bold ? .boldSystemFont(ofSize: size) : .systemFont(ofSize: size)
        return l
    }

    func buildWindow() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 430),
                          styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Dragon Ball Z Budokai Tenkaichi 4 (mod Beta 14 Rev2) - Mac"
        window.delegate = self
        window.center()
        let v = window.contentView!

        let title = label("Dragon Ball Z Budokai Tenkaichi 4", size: 22, bold: true)
        let sub = label("Mod de Team BT4 (Beta 14 Rev2) recompilado para Mac - necesitas tu ISO SLUS-219.78", size: 12)
        sub.textColor = .secondaryLabelColor

        pick.target = self; pick.action = #selector(pickIso)
        play.target = self; play.action = #selector(startGame)
        play.font = .boldSystemFont(ofSize: 18)
        play.bezelStyle = .rounded
        play.keyEquivalent = "\r"
        status.maximumNumberOfLines = 3

        for q in qualities { quality.addItem(withTitle: q.title) }
        quality.target = self; quality.action = #selector(saveConfig)
        fps60.target = self; fps60.action = #selector(saveConfig)
        fullscreen.target = self; fullscreen.action = #selector(saveConfig)

        let help = label("Mando (Xbox, PlayStation o MFi) o teclado: flechas = cruceta, WASD = stick,\n" +
                         "Z/X/C/V = Cuadrado/Cruz/Círculo/Triángulo, Q/E = L1/R1, 1/3 = L2/R2, Enter = START.\n" +
                         "F1 (o mantener START 1,5 s) = menú: resolución, MetalFX, 60 fps, FPS... Se guarda.", size: 11)
        help.textColor = .secondaryLabelColor
        let folder = NSButton(title: "Partidas y registros…", target: self, action: #selector(openSupport))
        folder.bezelStyle = .rounded
        let team = NSButton(title: "Team BT4 (creadores del mod)", target: self, action: #selector(openTeam))
        team.bezelStyle = .inline

        let place: [(NSView, NSRect)] = [
            (title, NSRect(x: 20, y: 380, width: 560, height: 32)),
            (sub, NSRect(x: 22, y: 358, width: 560, height: 18)),
            (status, NSRect(x: 22, y: 300, width: 400, height: 48)),
            (pick, NSRect(x: 430, y: 312, width: 150, height: 32)),
            (label("Calidad:"), NSRect(x: 22, y: 262, width: 70, height: 20)),
            (quality, NSRect(x: 90, y: 256, width: 490, height: 28)),
            (fps60, NSRect(x: 22, y: 226, width: 520, height: 20)),
            (fullscreen, NSRect(x: 22, y: 200, width: 520, height: 20)),
            (help, NSRect(x: 22, y: 120, width: 560, height: 60)),
            (folder, NSRect(x: 18, y: 70, width: 190, height: 30)),
            (team, NSRect(x: 22, y: 30, width: 220, height: 24)),
            (play, NSRect(x: 420, y: 22, width: 160, height: 56)),
        ]
        for (view, frame) in place { view.frame = frame; v.addSubview(view) }
    }

    // MARK: config

    func loadConfig() {
        isoPath = prefs.string(forKey: "iso") ?? ""
        let q = prefs.object(forKey: "quality") as? Int ?? defaultQuality()
        quality.selectItem(at: (0..<qualities.count).contains(q) ? q : defaultQuality())
        fps60.state = (prefs.object(forKey: "fps60") as? Bool ?? true) ? .on : .off
        fullscreen.state = (prefs.object(forKey: "fullscreen") as? Bool ?? true) ? .on : .off
    }

    @objc func saveConfig() {
        prefs.set(isoPath, forKey: "iso")
        prefs.set(quality.indexOfSelectedItem, forKey: "quality")
        prefs.set(fps60.state == .on, forKey: "fps60")
        prefs.set(fullscreen.state == .on, forKey: "fullscreen")
    }

    func gameReady() -> Bool {
        !isoPath.isEmpty && FileManager.default.fileExists(atPath: isoPath)
            && FileManager.default.fileExists(atPath: paths.elf.path)
    }

    func refreshState() {
        if gameReady() {
            status.stringValue = "Listo. ISO: " + isoPath
        } else if !isoPath.isEmpty && !FileManager.default.fileExists(atPath: isoPath) {
            status.stringValue = "No encuentro la ISO (\(isoPath)). Selecciónala otra vez."
        } else {
            status.stringValue = "Primero selecciona tu ISO de DBZ BT4 Beta 14 Rev2 (SLUS-219.78)."
        }
        play.isEnabled = gameReady()
    }

    // MARK: ISO

    // Copies the ELF and the small boot files (SYSTEM.CNF, IRX/, BIN/) into runtime/data. The big AFS archives stay in
    // the ISO: the runtime reads them from the image (PS2X_CD_IMAGE).
    func prepare(_ iso: String) throws {
        let img = try Iso9660(path: iso)
        let top = try img.list(img.rootLba, img.rootSize)
        func find(_ name: String) -> Iso9660.Entry? { top.first { $0.name.caseInsensitiveCompare(name) == .orderedSame } }
        guard let elf = find(elfName) else {
            throw err("Esta ISO no es DBZ BT4 (no tiene \(elfName)). Hace falta el mod Beta 14 Rev2 de Team BT4.")
        }
        let elfData = try img.readFile(elf)
        let sum = SHA256.hash(data: elfData).map { String(format: "%02x", $0) }.joined()
        guard sum == elfSha256 else {
            throw err("Esta ISO es otra versión del mod: el juego está recompilado para la Beta 14 Rev2 (SLUS-219.78).")
        }
        let fm = FileManager.default
        try fm.createDirectory(at: paths.data, withIntermediateDirectories: true)
        try elfData.write(to: paths.elf)
        try elfData.write(to: paths.data.appendingPathComponent(elfName))
        if let cnf = find("SYSTEM.CNF") { try img.readFile(cnf).write(to: paths.data.appendingPathComponent("SYSTEM.CNF")) }
        for sub in ["IRX", "BIN"] {
            guard let d = find(sub), d.isDir else { continue }
            let outDir = paths.data.appendingPathComponent(sub, isDirectory: true)
            try fm.createDirectory(at: outDir, withIntermediateDirectories: true)
            for f in try img.list(d.lba, d.size) where !f.isDir && f.size < (64 << 20) {
                try img.readFile(f).write(to: outDir.appendingPathComponent(f.name))
            }
        }
    }

    func useIso(_ path: String) {
        do {
            try prepare(path)
            isoPath = path
            saveConfig()
        } catch {
            alert("ISO no válida", error.localizedDescription)
        }
        refreshState()
    }

    @objc func pickIso() {
        let dlg = NSOpenPanel()
        dlg.title = "Elige tu ISO de DBZ BT4 (SLUS-219.78)"
        dlg.allowedContentTypes = []
        dlg.allowsOtherFileTypes = true
        if !isoPath.isEmpty { dlg.directoryURL = URL(fileURLWithPath: isoPath).deletingLastPathComponent() }
        dlg.beginSheetModal(for: window) { r in
            if r == .OK, let u = dlg.url { self.useIso(u.path) }
        }
    }

    // MARK: play

    // The writable runtime folder: data/ (from the ISO), savedata/ (memory card + settings), mods/, and assets/ linked
    // to the app's copy (re-linked on every start: the app may have moved).
    func setupRuntime() throws {
        let fm = FileManager.default
        for d in [paths.runtime, paths.data, paths.runtime.appendingPathComponent("savedata"),
                  paths.runtime.appendingPathComponent("mods"), paths.gshost, paths.logs] {
            try fm.createDirectory(at: d, withIntermediateDirectories: true)
        }
        let assets = paths.runtime.appendingPathComponent("assets")
        try? fm.removeItem(at: assets)
        try fm.createSymbolicLink(at: assets, withDestinationURL: paths.res.appendingPathComponent("runtime/assets"))
        let settings = paths.runtime.appendingPathComponent("savedata/settings.toml")
        if !fm.fileExists(atPath: settings.path) {
            try copyWritable(paths.res.appendingPathComponent("runtime/settings.toml"), settings)
        }
    }

    // the app's files may be read-only (a downloaded app runs from a read-only copy): copy the bytes, not the permissions
    func copyWritable(_ src: URL, _ dst: URL) throws {
        try Data(contentsOf: src).write(to: dst)
    }

    func iniValue(_ ini: URL, _ key: String) -> String? {
        guard let text = try? String(contentsOf: ini, encoding: .utf8) else { return nil }
        for line in text.split(separator: "\n") {
            let l = line.replacingOccurrences(of: " ", with: "")
            if l.lowercased().hasPrefix(key.lowercased() + "=") { return String(l.dropFirst(key.count + 1)) }
        }
        return nil
    }

    @objc func startGame() {
        guard gameReady() else { refreshState(); return }
        saveConfig()
        let q = qualities[quality.indexOfSelectedItem]
        let ini = paths.gshost.appendingPathComponent(q.ini)
        do {
            try setupRuntime()
            if !FileManager.default.fileExists(atPath: ini.path) {
                try copyWritable(paths.res.appendingPathComponent("presets/" + q.ini), ini)
            }
        } catch {
            alert("No pude preparar el juego", error.localizedDescription)
            return
        }
        // window mode: 16:9, up to 1920x1080 points and 85% of the screen
        let vf = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        var ww = min(1920, Int(vf.width * 0.85)), wh = ww * 9 / 16
        if CGFloat(wh) > vf.height * 0.85 { wh = Int(vf.height * 0.85); ww = wh * 16 / 9 }

        let p = Process()
        p.executableURL = paths.macos.appendingPathComponent("ps2EntryRunner")
        p.arguments = [paths.elf.path]
        p.currentDirectoryURL = paths.runtime
        var env = ProcessInfo.processInfo.environment
        env["PS2X_EXEDIR"] = paths.runtime.path
        env["PS2X_CD_IMAGE"] = isoPath
        env["PS2X_GS_LIVE"] = "1"
        env["PS2X_GSHOST"] = paths.macos.appendingPathComponent("pcsx2-gsrunner").path
        env["PS2X_GSHOST_ARGS"] = "-ini \"\(ini.path)\"" + (fullscreen.state == .on ? " -fullscreen" : "")
        env["PS2X_LIVE_SERIAL"] = "SLUS-21978"
        env["PS2X_LIVE_TITLE"] = "Dragon Ball Z Budokai Tenkaichi 4"
        env["PS2X_HOST_WINDOW"] = "\(ww)x\(wh)"
        // the fps60 rules file goes along in both cases: the in-game menu can switch 60 fps on at any time
        env["PS2X_HALFSTEP"] = paths.res.appendingPathComponent("runtime/fps60_sites.txt").path
        env["PS2X_FPS60"] = fps60.state == .on ? "1" : "0"
        p.environment = env
        let log = paths.logs.appendingPathComponent("juego.log")
        FileManager.default.createFile(atPath: log.path, contents: nil)
        if let h = try? FileHandle(forWritingTo: log) { p.standardOutput = h; p.standardError = h }
        let started = Date()
        p.terminationHandler = { proc in
            DispatchQueue.main.async { self.gameEnded(proc, ini: ini, log: log, seconds: Date().timeIntervalSince(started)) }
        }
        do { try p.run() } catch {
            alert("No pude arrancar el juego", error.localizedDescription)
            return
        }
        game = p
        window.orderOut(nil)
    }

    func gameEnded(_ p: Process, ini: URL, log: URL, seconds: TimeInterval) {
        game = nil
        // the in-game menu saves "DbzFps60 = true/false" in its ini: that becomes the next start's default
        if let v = iniValue(ini, "DbzFps60") { fps60.state = v.lowercased() == "true" ? .on : .off; saveConfig() }
        let code = p.terminationStatus
        let failed = code != 0 && p.terminationReason == .exit || p.terminationReason == .uncaughtSignal
        if direct && !failed { NSApp.terminate(nil); return }
        direct = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        if failed {
            let how = p.terminationReason == .uncaughtSignal ? "por la señal \(code)" : "con el código \(code)"
            alert("DBZ BT4", "El juego se cerró \(how) a los \(Int(seconds)) s.\nRegistro: \(log.path)")
        }
    }

    // MARK: misc

    @objc func openSupport() {
        try? FileManager.default.createDirectory(at: paths.support, withIntermediateDirectories: true)
        NSWorkspace.shared.open(paths.support)
    }

    @objc func openTeam() { NSWorkspace.shared.open(URL(string: "https://teambt4.wixsite.com/teambt4projects")!) }

    func alert(_ title: String, _ text: String) {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = text
        if window.isVisible { a.beginSheetModal(for: window) } else { a.runModal() }
    }

    // an ISO dropped on the window
    func application(_ app: NSApplication, open urls: [URL]) {
        if let u = urls.first(where: { $0.pathExtension.lowercased() == "iso" }) { useIso(u.path) }
    }
}

let app = NSApplication.shared
let delegate = Launcher()
app.delegate = delegate
app.setActivationPolicy(.regular)
// menu bar: About / Quit (Cmd+Q)
let mainMenu = NSMenu()
let appItem = NSMenuItem()
mainMenu.addItem(appItem)
let appMenu = NSMenu()
appMenu.addItem(withTitle: "Salir de DBZ BT4", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
appItem.submenu = appMenu
app.mainMenu = mainMenu
app.run()
