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

        readonly string root, runtimeDir, dataDir, gshostDir, cfgPath;
        string isoPath = "";
        readonly Label status;
        readonly Button pick, play;
        readonly ComboBox quality;
        readonly CheckBox fps60, fullscreen;

        static readonly string[] QualityIni = { "dbz.ini", "dbz_3x.ini", "dbz_dlss.ini" };

        Launcher()
        {
            root = AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\');
            runtimeDir = Path.Combine(root, "runtime");
            dataDir = Path.Combine(runtimeDir, "data");
            gshostDir = Path.Combine(root, "gshost");
            cfgPath = Path.Combine(root, "DBZ_BT4.cfg");

            Text = "Dragon Ball Z Budokai Tenkaichi 4 (mod Beta 14 Rev2) - Windows";
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            StartPosition = FormStartPosition.CenterScreen;
            ClientSize = new Size(560, 400);
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
            opts.SetBounds(16, 128, 528, 130);
            Controls.Add(opts);

            Label ql = new Label();
            ql.Text = "Calidad:";
            ql.SetBounds(12, 28, 70, 22);
            opts.Controls.Add(ql);
            quality = new ComboBox();
            quality.DropDownStyle = ComboBoxStyle.DropDownList;
            quality.Items.Add("Maxima - 6x nativo (GPU potente: RTX 3070 / RX 6800 o mejor)");
            quality.Items.Add("Equilibrada - 3x nativo");
            quality.Items.Add("DLSS / FSR - 2x reescalado a tu pantalla (GPU modesta)");
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

            Label help = new Label();
            help.Text = "Mando XInput (Xbox): A=Cruz, B=Circulo, X=Cuadrado, Y=Triangulo.  Teclado: flechas, WASD = stick,\n" +
                        "Z/X/C/V = Cuadrado/Cruz/Circulo/Triangulo, Q/E = L1/R1, 1/3 = L2/R2, Enter = START.\n" +
                        "F1 = opciones graficas (resolucion, DLSS/FSR, nitidez). Cerrar la ventana = salir.";
            help.SetBounds(18, 266, 530, 56);
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
            links.SetBounds(18, 330, 400, 20);
            Controls.Add(links);

            play = new Button();
            play.Text = "JUGAR";
            play.Font = new Font("Segoe UI", 14f, FontStyle.Bold);
            play.SetBounds(400, 346, 144, 44);
            play.Click += delegate { Play(); };
            Controls.Add(play);
            AcceptButton = play;

            LoadConfig();
            RefreshState();
        }

        void LoadConfig()
        {
            quality.SelectedIndex = 0;
            fullscreen.Checked = true;
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

        void Play()
        {
            if (!GameReady()) { RefreshState(); return; }
            SaveConfig();
            string runner = Path.Combine(runtimeDir, "ps2EntryRunner.exe");
            string ini = QualityIni[quality.SelectedIndex];
            string iniPath = Path.Combine(gshostDir, ini);
            string preset = Path.Combine(Path.Combine(gshostDir, "presets"), ini);
            if (!File.Exists(iniPath) && File.Exists(preset)) File.Copy(preset, iniPath);
            string logs = Path.Combine(root, "logs");
            Directory.CreateDirectory(logs);

            ProcessStartInfo si = new ProcessStartInfo(runner, "\"" + Path.Combine(dataDir, "SLUS_216.78") + "\"");
            si.UseShellExecute = false;
            si.WorkingDirectory = runtimeDir;
            si.EnvironmentVariables["PS2X_CD_IMAGE"] = isoPath;
            si.EnvironmentVariables["PS2X_GS_LIVE"] = "1";
            // the runtime finds ..\gshost\pcsx2-gsrunner.exe by itself; the ini is relative to gshost\ (the host's directory)
            si.EnvironmentVariables["PS2X_GSHOST_ARGS"] = "-renderer vulkan -ini " + ini + (fullscreen.Checked ? " -fullscreen" : "");
            si.EnvironmentVariables["PS2X_LIVE_SERIAL"] = "SLUS-21978";
            si.EnvironmentVariables["PS2X_LIVE_TITLE"] = "Dragon Ball Z Budokai Tenkaichi 4";
            si.EnvironmentVariables["PS2X_HOST_WINDOW"] = "1280x720";
            si.EnvironmentVariables["PS2X_LOGFILE"] = Path.Combine(logs, "juego.log");
            if (fps60.Checked)
            {
                si.EnvironmentVariables["PS2X_FPS60"] = "1";
                si.EnvironmentVariables["PS2X_HALFSTEP"] = Path.Combine(runtimeDir, "fps60_sites.txt");
            }
            else
                si.EnvironmentVariables["PS2X_FPS60"] = "0";

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
                    if (direct && code == 0) { Close(); return; }
                    direct = false;
                    Show();
                    Activate();
                    if (code != 0)
                        MessageBox.Show(this, "El juego se cerro con el codigo " + code + ".\nRegistro: " + Path.Combine(logs, "juego.log") +
                                        "\nRegistro del GS: " + Path.Combine(gshostDir, "logs\\emulog.txt") +
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
