// Launcher de DBZ Budokai Tenkaichi 4 (mod de BT3, Beta 14 Rev2) para Windows.
// Pide la ISO del jugador una vez, saca de ella el ELF y los modulos (no se distribuyen), comprueba que es el disco
// para el que se recompilo el juego y lanza runtime\ps2EntryRunner.exe con el GS de PCSX2 (gshost\).
// Compilar: tools\build_launcher.ps1 (csc de .NET Framework 4, viene con Windows).
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Windows.Forms;

[assembly: System.Reflection.AssemblyTitle("DBZ Budokai Tenkaichi 4 - Windows")]
[assembly: System.Reflection.AssemblyProduct("dbz-bt4-recomp")]
[assembly: System.Reflection.AssemblyVersion("1.0.0.0")]

namespace DbzBt4
{
    // Minimal ISO 9660 reader: enough to find and copy a few files by path.
    class Iso9660 : IDisposable
    {
        const int Sector = 2048;
        readonly FileStream fs;
        readonly long rootLba;
        readonly long rootSize;

        public Iso9660(string path)
        {
            fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read);
            byte[] pvd = Read(16L * Sector, Sector);
            if (pvd[0] != 1 || Encoding.ASCII.GetString(pvd, 1, 5) != "CD001")
                throw new InvalidDataException("no es una imagen ISO 9660");
            rootLba = BitConverter.ToUInt32(pvd, 156 + 2);
            rootSize = BitConverter.ToUInt32(pvd, 156 + 10);
        }

        byte[] Read(long offset, int count)
        {
            byte[] b = new byte[count];
            fs.Position = offset;
            int got = 0;
            while (got < count)
            {
                int n = fs.Read(b, got, count - got);
                if (n <= 0) throw new EndOfStreamException("la ISO esta incompleta");
                got += n;
            }
            return b;
        }

        public class Entry { public string Name; public long Lba; public long Size; public bool Dir; }

        public List<Entry> List(long lba, long size)
        {
            List<Entry> list = new List<Entry>();
            byte[] d = Read(lba * Sector, (int)size);
            int p = 0;
            while (p < d.Length)
            {
                int len = d[p];
                if (len == 0) { p = (p / Sector + 1) * Sector; continue; }
                int nameLen = d[p + 32];
                string name = Encoding.ASCII.GetString(d, p + 33, nameLen);
                bool special = nameLen == 1 && (d[p + 33] == 0 || d[p + 33] == 1);
                if (!special)
                {
                    int semi = name.IndexOf(';');
                    if (semi >= 0) name = name.Substring(0, semi);
                    Entry e = new Entry();
                    e.Name = name.TrimEnd('.');
                    e.Lba = BitConverter.ToUInt32(d, p + 2);
                    e.Size = BitConverter.ToUInt32(d, p + 10);
                    e.Dir = (d[p + 25] & 2) != 0;
                    list.Add(e);
                }
                p += len;
            }
            return list;
        }

        public List<Entry> Root() { return List(rootLba, rootSize); }

        public Entry Find(List<Entry> dir, string name)
        {
            foreach (Entry e in dir)
                if (string.Equals(e.Name, name, StringComparison.OrdinalIgnoreCase)) return e;
            return null;
        }

        public byte[] ReadFile(Entry e) { return Read(e.Lba * Sector, (int)e.Size); }

        public void Dispose() { fs.Dispose(); }
    }

    class Launcher : Form
    {
        // SHA-256 of SLUS_219.78 (BT4 Beta 14 Rev2): the game code in ps2EntryRunner.exe was recompiled from exactly this ELF.
        const string ElfSha256 = "224525C5639C00E01C2604C4685D307BC739C041000DCF8C69A4F884F465E8A4";
        const string ElfName = "SLUS_219.78";

        readonly string root, runtimeDir, dataDir, gshostDir, cfgPath, dlssDir;
        readonly Label dlssInfo;
        string isoPath = "";
        readonly Label status;
        readonly Button pick, play;
        readonly ComboBox quality;
        readonly CheckBox fps60, fullscreen;

        static readonly string[] QualityIni = { "dbz.ini", "dbz_3x.ini", "dbz_dlss.ini", "dbz_dlss_dx12.ini" };
        const int QualityDlss = 2, QualityDlss5 = 3;

        Launcher()
        {
            root = AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\');
            runtimeDir = Path.Combine(root, "runtime");
            dataDir = Path.Combine(runtimeDir, "data");
            gshostDir = Path.Combine(root, "gshost");
            cfgPath = Path.Combine(root, "DBZ_BT4.cfg");
            dlssDir = Path.Combine(root, "DLSS");

            Text = "Dragon Ball Z Budokai Tenkaichi 4 (mod Beta 14 Rev2) - Windows";
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            StartPosition = FormStartPosition.CenterScreen;
            ClientSize = new Size(560, 430);
            Font = new Font("Segoe UI", 9.5f);
            try { Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath); } catch { }

            Label title = new Label();
            title.Text = "Dragon Ball Z Budokai Tenkaichi 4";
            title.Font = new Font("Segoe UI", 16f, FontStyle.Bold);
            title.SetBounds(16, 12, 530, 34);
            Controls.Add(title);

            Label sub = new Label();
            sub.Text = "Mod de Team BT4 (Beta 14 Rev2) recompilado para Windows - necesitas tu ISO SLUS-219.78";
            sub.SetBounds(18, 46, 530, 20);
            Controls.Add(sub);

            status = new Label();
            status.SetBounds(18, 78, 420, 44);
            Controls.Add(status);

            pick = new Button();
            pick.Text = "Seleccionar ISO...";
            pick.SetBounds(440, 80, 104, 30);
            pick.Click += delegate { PickIso(); };
            Controls.Add(pick);

            GroupBox opts = new GroupBox();
            opts.Text = "Opciones";
            opts.SetBounds(16, 128, 528, 160);
            Controls.Add(opts);

            Label ql = new Label();
            ql.Text = "Calidad:";
            ql.SetBounds(12, 28, 70, 22);
            opts.Controls.Add(ql);
            quality = new ComboBox();
            quality.DropDownStyle = ComboBoxStyle.DropDownList;
            quality.Items.Add("Maxima - 6x nativo (GPU potente: RTX 3070 / RX 6800 o mejor)");
            quality.Items.Add("Equilibrada - 3x nativo");
            quality.Items.Add("DLSS / FSR - 2x reescalado a tu pantalla (NVIDIA RTX: DLSS; otras: FSR)");
            quality.Items.Add(Dlss5Parts() != null
                ? "DLSS 5 - DLSS + pase neural de NVIDIA (experimental, RTX)"
                : "DLSS 5 - necesita DLSS 5 Swapper instalado (RTX)");
            quality.SetBounds(86, 25, 428, 24);
            opts.Controls.Add(quality);

            fps60 = new CheckBox();
            fps60.Text = "Peleas a 60 fps (la PS2 iba a 30)";
            fps60.SetBounds(14, 60, 300, 24);
            opts.Controls.Add(fps60);

            fullscreen = new CheckBox();
            fullscreen.Text = "Pantalla completa (Alt+Enter o F11 cambia durante el juego)";
            fullscreen.SetBounds(14, 90, 500, 24);
            opts.Controls.Add(fullscreen);

            // Your own DLSS: drop nvngx_dlss.dll (or the DLSS 5 files) into DLSS\ or onto this window
            dlssInfo = new Label();
            dlssInfo.SetBounds(14, 122, 360, 30);
            opts.Controls.Add(dlssInfo);
            Button dlssBtn = new Button();
            dlssBtn.Text = "Carpeta DLSS...";
            dlssBtn.SetBounds(384, 120, 130, 28);
            dlssBtn.Click += delegate
            {
                try { Directory.CreateDirectory(dlssDir); Process.Start("explorer.exe", "\"" + dlssDir + "\""); } catch { }
            };
            opts.Controls.Add(dlssBtn);
            AllowDrop = true;
            DragEnter += delegate(object s, DragEventArgs e)
            {
                e.Effect = e.Data.GetDataPresent(DataFormats.FileDrop) ? DragDropEffects.Copy : DragDropEffects.None;
            };
            DragDrop += delegate(object s, DragEventArgs e) { AddDlssFiles((string[])e.Data.GetData(DataFormats.FileDrop)); };

            Label help = new Label();
            help.Text = "Mando XInput (Xbox): A=Cruz, B=Circulo, X=Cuadrado, Y=Triangulo.  Teclado: flechas, WASD = stick,\n" +
                        "Z/X/C/V = Cuadrado/Cruz/Circulo/Triangulo, Q/E = L1/R1, 1/3 = L2/R2, Enter = START.\n" +
                        "Mantener START 1,5 s (o F1) = menu: resolucion, DLSS/FSR, 60 fps, nitidez... Se guarda.";
            help.SetBounds(18, 296, 530, 56);
            Controls.Add(help);

            LinkLabel links = new LinkLabel();
            links.Text = "Team BT4 (creadores del mod)   -   github.com/recomp-code/dbz-bt4-recomp";
            links.Links.Add(0, 8, "https://teambt4.wixsite.com/teambt4projects");
            int gh = links.Text.IndexOf("github");
            links.Links.Add(gh, links.Text.Length - gh, "https://github.com/recomp-code/dbz-bt4-recomp");
            links.LinkClicked += delegate(object s, LinkLabelLinkClickedEventArgs e)
            {
                try { Process.Start((string)e.Link.LinkData); } catch { }
            };
            links.SetBounds(18, 360, 400, 20);
            Controls.Add(links);

            play = new Button();
            play.Text = "JUGAR";
            play.Font = new Font("Segoe UI", 14f, FontStyle.Bold);
            play.SetBounds(400, 376, 144, 44);
            play.Click += delegate { Play(); };
            Controls.Add(play);
            AcceptButton = play;

            LoadConfig();
            RefreshState();
            RefreshDlss();
        }

        // ---- DLSS files ----
        // DLSS\ next to the launcher (any subfolder, any file name): the files are recognised by their version info, and
        // the newest of each kind wins. Kinds: NVIDIA DLSS super resolution (nvngx_dlss.dll), NVIDIA DLSSNR (DLSS 5's neural
        // pass), ReShade 64-bit and the RenoDX DLSS 5 add-on. What DLSS\ lacks comes from the zip (DLSS) or from DLSS 5 Swapper.
        enum DlssKind { None, SuperRes, Neural, ReShade, Addon }

        static DlssKind KindOf(string path)
        {
            try
            {
                string name = Path.GetFileName(path).ToLowerInvariant();
                if (name.EndsWith(".addon64")) return name.Contains("dlss5") ? DlssKind.Addon : DlssKind.None;
                if (!name.EndsWith(".dll") || !IsX64(path)) return DlssKind.None;
                FileVersionInfo v = FileVersionInfo.GetVersionInfo(path);
                string prod = v.ProductName ?? "", desc = v.FileDescription ?? "";
                if (prod.IndexOf("Deep Learning SuperSampling", StringComparison.OrdinalIgnoreCase) >= 0) return DlssKind.SuperRes;
                if (prod.Equals("NVIDIA DLSSNR", StringComparison.OrdinalIgnoreCase)) return DlssKind.Neural;
                if (prod.Equals("ReShade", StringComparison.OrdinalIgnoreCase) && desc.IndexOf("64-bit", StringComparison.OrdinalIgnoreCase) >= 0)
                    return DlssKind.ReShade;
            }
            catch { }
            return DlssKind.None;
        }

        // PE machine type x64 (0x8664): the DLSS SDK also has ARM64 / ARM64EC builds of the same DLLs, which would not load.
        static bool IsX64(string path)
        {
            try
            {
                using (FileStream fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read))
                using (BinaryReader r = new BinaryReader(fs))
                {
                    fs.Position = 0x3C;
                    fs.Position = r.ReadInt32() + 4;
                    return r.ReadUInt16() == 0x8664;
                }
            }
            catch { return false; }
        }

        static Version VersionOf(string path)
        {
            try
            {
                FileVersionInfo v = FileVersionInfo.GetVersionInfo(path);
                return new Version(v.FileMajorPart, v.FileMinorPart, v.FileBuildPart, v.FilePrivatePart);
            }
            catch { return new Version(0, 0); }
        }

        static string VersionText(string path)
        {
            Version v = VersionOf(path);
            return v.Revision > 0 ? v.ToString(4) : v.ToString(3);
        }

        // The newest file of that kind in DLSS\, or null.
        string UserDlss(DlssKind kind)
        {
            string best = null;
            if (!Directory.Exists(dlssDir)) return null;
            try
            {
                foreach (string f in Directory.GetFiles(dlssDir, "*.*", SearchOption.AllDirectories))
                    if (KindOf(f) == kind && (best == null || VersionOf(f) > VersionOf(best)))
                        best = f;
            }
            catch { }
            return best;
        }

        static string SwapperFile(string rel)
        {
            string p = Path.Combine(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                                                 @"Programs\DLSS 5 Swapper\resources\payload"), rel);
            return File.Exists(p) ? p : null;
        }

        // ReShade, the RenoDX DLSS 5 add-on and nvngx_dlssnr.dll (DLSS\ first, then DLSS 5 Swapper), or null if one is missing.
        string[] Dlss5Parts()
        {
            string reshade = UserDlss(DlssKind.ReShade) ?? SwapperFile(@"reshade-vulkan\ReShade64.dll");
            string addon = UserDlss(DlssKind.Addon) ?? SwapperFile("renodx-dlss5.addon64");
            string neural = UserDlss(DlssKind.Neural) ?? SwapperFile(@"streamline\nvngx_dlssnr.dll");
            return reshade != null && addon != null && neural != null ? new string[] { reshade, addon, neural } : null;
        }

        // The DLSS the game will use: DLSS\'s newest nvngx_dlss.dll, else the one that came with the zip.
        string SuperResDll()
        {
            string user = UserDlss(DlssKind.SuperRes);
            if (user != null) return user;
            string orig = Path.Combine(Path.Combine(gshostDir, "presets"), "nvngx_dlss.dll");
            return File.Exists(orig) ? orig : Path.Combine(gshostDir, "nvngx_dlss.dll");
        }

        void AddDlssFiles(string[] files)
        {
            if (files == null) return;
            int added = 0;
            List<string> skipped = new List<string>();
            foreach (string f in files)
            {
                if (KindOf(f) == DlssKind.None) { skipped.Add(Path.GetFileName(f)); continue; }
                try
                {
                    Directory.CreateDirectory(dlssDir);
                    File.Copy(f, Path.Combine(dlssDir, Path.GetFileName(f)), true);
                    added++;
                }
                catch (Exception ex) { skipped.Add(Path.GetFileName(f) + " (" + ex.Message + ")"); }
            }
            RefreshDlss();
            if (skipped.Count > 0)
                MessageBox.Show(this, "No es un archivo de DLSS que el juego use:\n" + string.Join("\n", skipped.ToArray()) +
                                "\n\nSirven: nvngx_dlss.dll (DLSS) y, para DLSS 5, nvngx_dlssnr.dll, ReShade64.dll y renodx-dlss5.addon64.",
                                "DLSS", MessageBoxButtons.OK, MessageBoxIcon.Information);
            else if (added > 0)
                MessageBox.Show(this, "Listo. " + dlssInfo.Text, "DLSS", MessageBoxButtons.OK, MessageBoxIcon.Information);
        }

        void RefreshDlss()
        {
            string sr = SuperResDll();
            bool mine = UserDlss(DlssKind.SuperRes) != null;
            string[] d5 = Dlss5Parts();
            dlssInfo.Text = "DLSS " + VersionText(sr) + (mine ? " (tuyo, carpeta DLSS)" : " (incluido)") +
                            "   DLSS 5: " + (d5 == null ? "no disponible" : "listo (DLSSNR " + VersionText(d5[2]) + ")") +
                            "\nArrastra aqui tus DLL de DLSS para usarlas.";
            if (quality.Items.Count > QualityDlss5)
                quality.Items[QualityDlss5] = d5 != null ? "DLSS 5 - DLSS + pase neural de NVIDIA (experimental, RTX)"
                                                         : "DLSS 5 - necesita DLSS 5 Swapper o sus archivos en DLSS (RTX)";
        }

        // Puts the chosen nvngx_dlss.dll next to the normal host (gshost_dlss5\ copies it from there).
        void ApplySuperResDll()
        {
            string sr = SuperResDll(), dst = Path.Combine(gshostDir, "nvngx_dlss.dll");
            if (!string.Equals(Path.GetFullPath(sr), Path.GetFullPath(dst), StringComparison.OrdinalIgnoreCase))
                CopyIfChanged(sr, dst);
        }
        // First start: everything on. NVIDIA RTX -> DLSS 5 (with DLSS 5 Swapper) or DLSS; other GPUs -> 3x native.
        int DefaultQuality()
        {
            string gpu = "";
            try
            {
                using (System.Management.ManagementObjectSearcher q =
                       new System.Management.ManagementObjectSearcher("SELECT Name FROM Win32_VideoController"))
                    foreach (System.Management.ManagementObject o in q.Get())
                        gpu += " " + o["Name"];
            }
            catch { }
            if (gpu.IndexOf("RTX", StringComparison.OrdinalIgnoreCase) >= 0)
                return Dlss5Parts() != null ? QualityDlss5 : QualityDlss;
            return 1;
        }

        void LoadConfig()
        {
            quality.SelectedIndex = DefaultQuality();
            fullscreen.Checked = true;
            fps60.Checked = true;
            if (!File.Exists(cfgPath)) return;
            foreach (string line in File.ReadAllLines(cfgPath, Encoding.UTF8))
            {
                int eq = line.IndexOf('=');
                if (eq <= 0) continue;
                string k = line.Substring(0, eq).Trim(), v = line.Substring(eq + 1).Trim();
                int n;
                if (k == "iso") isoPath = v;
                else if (k == "quality" && int.TryParse(v, out n) && n >= 0 && n < QualityIni.Length) quality.SelectedIndex = n;
                else if (k == "fps60") fps60.Checked = v == "1";
                else if (k == "fullscreen") fullscreen.Checked = v == "1";
            }
        }

        void SaveConfig()
        {
            try
            {
                File.WriteAllLines(cfgPath, new string[] {
                    "iso=" + isoPath,
                    "quality=" + quality.SelectedIndex,
                    "fps60=" + (fps60.Checked ? "1" : "0"),
                    "fullscreen=" + (fullscreen.Checked ? "1" : "0") }, Encoding.UTF8);
            }
            catch { }
        }

        bool GameReady()
        {
            return isoPath.Length > 0 && File.Exists(isoPath) && File.Exists(Path.Combine(dataDir, "SLUS_216.78"));
        }

        void RefreshState()
        {
            if (GameReady())
                status.Text = "Listo. ISO: " + isoPath;
            else if (isoPath.Length > 0 && !File.Exists(isoPath))
                status.Text = "No encuentro la ISO (" + isoPath + "). Seleccionala otra vez.";
            else
                status.Text = "Primero selecciona tu ISO de DBZ BT4 Beta 14 Rev2 (SLUS-219.78).";
            play.Enabled = GameReady();
        }

        static string Sha256(byte[] data)
        {
            using (SHA256 h = SHA256.Create())
                return BitConverter.ToString(h.ComputeHash(data)).Replace("-", "");
        }

        // Copies the ELF and the small boot files (SYSTEM.CNF, IRX\, BIN\) into runtime\data. The big AFS archives stay
        // in the ISO: the runtime reads them from the image (PS2X_CD_IMAGE).
        string Prepare(string iso)
        {
            using (Iso9660 img = new Iso9660(iso))
            {
                List<Iso9660.Entry> top = img.Root();
                Iso9660.Entry elf = img.Find(top, ElfName);
                if (elf == null)
                    return "Esta ISO no es DBZ BT4 (no tiene " + ElfName + "). Hace falta el mod Beta 14 Rev2 de Team BT4.";
                byte[] elfData = img.ReadFile(elf);
                if (Sha256(elfData) != ElfSha256)
                    return "Esta ISO es otra version del mod: el juego esta recompilado para la Beta 14 Rev2 (SLUS-219.78).";
                Directory.CreateDirectory(dataDir);
                File.WriteAllBytes(Path.Combine(dataDir, "SLUS_216.78"), elfData);
                File.WriteAllBytes(Path.Combine(dataDir, ElfName), elfData);
                Iso9660.Entry cnf = img.Find(top, "SYSTEM.CNF");
                if (cnf != null) File.WriteAllBytes(Path.Combine(dataDir, "SYSTEM.CNF"), img.ReadFile(cnf));
                foreach (string sub in new string[] { "IRX", "BIN" })
                {
                    Iso9660.Entry d = img.Find(top, sub);
                    if (d == null || !d.Dir) continue;
                    string outDir = Path.Combine(dataDir, sub);
                    Directory.CreateDirectory(outDir);
                    foreach (Iso9660.Entry f in img.List(d.Lba, d.Size))
                        if (!f.Dir && f.Size < (64 << 20))
                            File.WriteAllBytes(Path.Combine(outDir, f.Name), img.ReadFile(f));
                }
            }
            return null;
        }

        void PickIso()
        {
            using (OpenFileDialog dlg = new OpenFileDialog())
            {
                dlg.Title = "Selecciona la ISO de DBZ Budokai Tenkaichi 4 (Beta 14 Rev2)";
                dlg.Filter = "Imagen de disco PS2 (*.iso)|*.iso|Todos los archivos|*.*";
                if (isoPath.Length > 0)
                    try { dlg.InitialDirectory = Path.GetDirectoryName(isoPath); } catch { }
                if (dlg.ShowDialog(this) != DialogResult.OK) return;
                Cursor = Cursors.WaitCursor;
                string err;
                try { err = Prepare(dlg.FileName); }
                catch (Exception ex) { err = "No pude leer la ISO: " + ex.Message; }
                Cursor = Cursors.Default;
                if (err != null)
                {
                    MessageBox.Show(this, err, "ISO no valida", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                    return;
                }
                isoPath = dlg.FileName;
                SaveConfig();
                RefreshState();
            }
        }

        static void CopyIfChanged(string src, string dst)
        {
            FileInfo a = new FileInfo(src), b = new FileInfo(dst);
            if (!b.Exists || a.Length != b.Length || a.LastWriteTimeUtc != b.LastWriteTimeUtc)
                File.Copy(src, dst, true);
        }

        static void CopyTree(string src, string dst)
        {
            Directory.CreateDirectory(dst);
            foreach (string f in Directory.GetFiles(src))
                CopyIfChanged(f, Path.Combine(dst, Path.GetFileName(f)));
            foreach (string d in Directory.GetDirectories(src))
                CopyTree(d, Path.Combine(dst, Path.GetFileName(d)));
        }

        // DLSS 5: a copy of gshost\ with ReShade (as dxgi.dll), the RenoDX DLSS 5 add-on and NVIDIA's nvngx_dlssnr.dll from
        // DLSS 5 Swapper, so the normal host never loads ReShade. Kept up to date on every start (only changed files copy).
        string PrepareDlss5Host()
        {
            string[] parts = Dlss5Parts();
            if (parts == null) return null;
            string dir = Path.Combine(root, "gshost_dlss5");
            Directory.CreateDirectory(dir);
            foreach (string f in Directory.GetFiles(gshostDir))
            {
                string ext = Path.GetExtension(f).ToLowerInvariant();
                if (ext == ".exe" || ext == ".dll")
                    CopyIfChanged(f, Path.Combine(dir, Path.GetFileName(f)));
            }
            CopyTree(Path.Combine(gshostDir, "resources"), Path.Combine(dir, "resources"));
            if (!File.Exists(Path.Combine(dir, "portable.ini"))) File.WriteAllText(Path.Combine(dir, "portable.ini"), "");
            CopyIfChanged(parts[0], Path.Combine(dir, "dxgi.dll"));
            CopyIfChanged(parts[1], Path.Combine(dir, "renodx-dlss5.addon64"));
            CopyIfChanged(parts[2], Path.Combine(dir, "nvngx_dlssnr.dll"));
            string presets = Path.Combine(gshostDir, "presets");
            foreach (string n in new string[] { "dbz_dlss_dx12.ini", "ReShade.ini" })
                if (!File.Exists(Path.Combine(dir, n)) && File.Exists(Path.Combine(presets, n)))
                    File.Copy(Path.Combine(presets, n), Path.Combine(dir, n));
            return dir;
        }

        // The menu inside the game saves "DbzFps60 = true/false" in its ini: that becomes the next start's default.
        void ReadBackFps60(string iniPath)
        {
            try
            {
                foreach (string line in File.ReadAllLines(iniPath))
                {
                    string l = line.Replace(" ", "");
                    if (l.StartsWith("DbzFps60=", StringComparison.OrdinalIgnoreCase))
                    {
                        fps60.Checked = l.EndsWith("true", StringComparison.OrdinalIgnoreCase);
                        SaveConfig();
                    }
                }
            }
            catch { }
        }

        void Play()
        {
            if (!GameReady()) { RefreshState(); return; }
            int q = quality.SelectedIndex;
            try { ApplySuperResDll(); }
            catch (Exception ex) { MessageBox.Show(this, "No pude poner tu DLL de DLSS: " + ex.Message, "DLSS"); }
            string hostDir = gshostDir;
            if (q == QualityDlss5)
            {
                try { hostDir = PrepareDlss5Host(); }
                catch (Exception ex) { hostDir = null; MessageBox.Show(this, "No pude preparar DLSS 5: " + ex.Message, "DLSS 5"); }
                if (hostDir == null)
                {
                    MessageBox.Show(this, "DLSS 5 necesita una NVIDIA RTX y DLSS 5 Swapper instalado (o ReShade64.dll, renodx-dlss5.addon64 y nvngx_dlssnr.dll en la carpeta DLSS). Juego con DLSS normal.", "DLSS 5",
                                    MessageBoxButtons.OK, MessageBoxIcon.Information);
                    q = QualityDlss;
                    hostDir = gshostDir;
                }
            }
            SaveConfig();
            string runner = Path.Combine(runtimeDir, "ps2EntryRunner.exe");
            string ini = QualityIni[q];
            string iniPath = Path.Combine(hostDir, ini);
            string preset = Path.Combine(Path.Combine(gshostDir, "presets"), ini);
            if (!File.Exists(iniPath) && File.Exists(preset)) File.Copy(preset, iniPath);
            string logs = Path.Combine(root, "logs");
            Directory.CreateDirectory(logs);
            // window mode: 16:9, up to 1920x1080 and 90% of the screen (DLSS only runs while the window is larger than
            // the 2x image, 1024x896)
            Rectangle wa = Screen.PrimaryScreen.WorkingArea;
            int ww = Math.Min(1920, wa.Width * 9 / 10), wh = ww * 9 / 16;
            if (wh > wa.Height * 9 / 10) { wh = wa.Height * 9 / 10; ww = wh * 16 / 9; }

            ProcessStartInfo si = new ProcessStartInfo(runner, "\"" + Path.Combine(dataDir, "SLUS_216.78") + "\"");
            si.UseShellExecute = false;
            si.WorkingDirectory = runtimeDir;
            si.EnvironmentVariables["PS2X_CD_IMAGE"] = isoPath;
            si.EnvironmentVariables["PS2X_GS_LIVE"] = "1";
            // without PS2X_GSHOST the runtime finds ..\gshost\pcsx2-gsrunner.exe; the ini is relative to the host's directory
            if (hostDir != gshostDir)
                si.EnvironmentVariables["PS2X_GSHOST"] = Path.Combine(hostDir, "pcsx2-gsrunner.exe");
            si.EnvironmentVariables["PS2X_GSHOST_ARGS"] = (q == QualityDlss5 ? "-renderer dx12" : "-renderer vulkan") + " -ini " + ini +
                                                          (fullscreen.Checked ? " -fullscreen" : "");
            si.EnvironmentVariables["PS2X_LIVE_SERIAL"] = "SLUS-21978";
            si.EnvironmentVariables["PS2X_LIVE_TITLE"] = "Dragon Ball Z Budokai Tenkaichi 4";
            si.EnvironmentVariables["PS2X_HOST_WINDOW"] = ww + "x" + wh;
            si.EnvironmentVariables["PS2X_LOGFILE"] = Path.Combine(logs, "juego.log");
            // the fps60 rules file goes along in both cases: the in-game menu can switch 60 fps on at any time
            si.EnvironmentVariables["PS2X_HALFSTEP"] = Path.Combine(runtimeDir, "fps60_sites.txt");
            si.EnvironmentVariables["PS2X_FPS60"] = fps60.Checked ? "1" : "0";

            Process p;
            try { p = Process.Start(si); }
            catch (Exception ex)
            {
                MessageBox.Show(this, "No pude arrancar el juego: " + ex.Message, "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }
            Hide();
            Thread t = new Thread(delegate()
            {
                p.WaitForExit();
                int code = p.ExitCode;
                BeginInvoke((MethodInvoker)delegate
                {
                    ReadBackFps60(iniPath);
                    if (direct && code == 0) { Close(); return; }
                    direct = false;
                    Show();
                    Activate();
                    if (code != 0)
                        MessageBox.Show(this, "El juego se cerro con el codigo " + code + ".\nRegistro: " + Path.Combine(logs, "juego.log") +
                                        "\nRegistro del GS: " + Path.Combine(hostDir, "logs\\emulog.txt") +
                                        "\n\nSi la ventana no llego a abrir: actualiza el driver de la tarjeta grafica (hace falta Vulkan).",
                                        "DBZ BT4", MessageBoxButtons.OK, MessageBoxIcon.Information);
                });
            });
            t.IsBackground = true;
            t.Start();
        }
        // DBZ_BT4.exe --jugar: starts the game straight away with the saved options (for a desktop shortcut) and exits
        // with it; the window only shows up when the ISO still has to be chosen or the game failed.
        bool direct;

        protected override void SetVisibleCore(bool value)
        {
            if (direct && !IsHandleCreated && GameReady())
            {
                CreateHandle();
                value = false;
                BeginInvoke((MethodInvoker)delegate { Play(); });
            }
            base.SetVisibleCore(value);
        }

        [STAThread]
        static void Main(string[] args)
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Launcher f = new Launcher();
            f.direct = Array.IndexOf(args, "--jugar") >= 0;
            // DBZ_BT4.exe --iso <path>: same as "Seleccionar ISO..." without the dialog
            int i = Array.IndexOf(args, "--iso");
            if (i >= 0 && i + 1 < args.Length)
            {
                string err;
                try { err = f.Prepare(args[i + 1]); }
                catch (Exception ex) { err = "No pude leer la ISO: " + ex.Message; }
                if (err != null) MessageBox.Show(err, "ISO no valida", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                else { f.isoPath = args[i + 1]; f.SaveConfig(); f.RefreshState(); }
            }
            Application.Run(f);
        }
    }
}
