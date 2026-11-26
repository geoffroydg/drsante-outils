// DrSante-Installation.exe : telecharge la derniere version de Installer.ps1
// depuis GitHub et la lance. Compile automatiquement par GitHub Actions
// (.github/workflows/installeur.yml) ; l'exe n'a donc jamais besoin d'etre
// refait a la main : il prend toujours l'installateur le plus recent.
using System;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Reflection;
using System.Windows.Forms;

[assembly: AssemblyTitle("Installation Dr Sante outils")]
[assembly: AssemblyProduct("Dr Sante outils")]
[assembly: AssemblyDescription("Installe les outils Heidi vers Dr Sante")]
[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyFileVersion("1.0.0.0")]

static class Programme
{
    const string Url = "https://raw.githubusercontent.com/geoffroydg/drsante-outils/main/Installer.ps1";
    const string Titre = "Dr Sante outils - installation";

    [STAThread]
    static int Main()
    {
        try
        {
            // TLS 1.2 (obligatoire pour GitHub)
            ServicePointManager.SecurityProtocol |= (SecurityProtocolType)3072;

            string dossier = Path.Combine(Path.GetTempPath(), "DrSanteInstallation");
            Directory.CreateDirectory(dossier);
            string script = Path.Combine(dossier, "Installer.ps1");

            using (WebClient wc = new WebClient())
            {
                wc.Headers.Add("User-Agent", "DrSanteOutils");
                wc.DownloadFile(Url, script);
            }

            ProcessStartInfo psi = new ProcessStartInfo("powershell.exe",
                "-NoProfile -ExecutionPolicy Bypass -File \"" + script + "\"");
            psi.UseShellExecute = false;
            Process.Start(psi);
            return 0;
        }
        catch (Exception e)
        {
            MessageBox.Show(
                "Impossible de lancer l'installation :\n\n" + e.Message +
                "\n\nVerifiez la connexion internet puis reessayez.",
                Titre, MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
    }
}
