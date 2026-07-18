using System;
using System.IO;
using System.Reflection;

namespace SecurityKeyLocker
{
    /// <summary>
    /// Loads settings from SecurityKeyLocker.ini placed next to the executable.
    /// Missing file or keys fall back to sensible defaults (matches any YubiKey).
    /// </summary>
    public sealed class AppConfig
    {
        // USB vendor id (hex, without the "0x"). 1050 = Yubico by default.
        public string VendorId = "1050";

        // Optional product id (hex). Empty = match any device from the vendor.
        public string ProductId = "";

        public static AppConfig Load()
        {
            var config = new AppConfig();
            try
            {
                string dir = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
                string path = Path.Combine(dir, "SecurityKeyLocker.ini");
                if (!File.Exists(path))
                {
                    return config;
                }

                foreach (string raw in File.ReadAllLines(path))
                {
                    string line = raw.Trim();
                    if (line.Length == 0 || line.StartsWith("#") || line.StartsWith(";"))
                    {
                        continue;
                    }

                    int eq = line.IndexOf('=');
                    if (eq <= 0) continue;

                    string key = line.Substring(0, eq).Trim();
                    string value = line.Substring(eq + 1).Trim();

                    if (key.Equals("VendorId", StringComparison.OrdinalIgnoreCase))
                    {
                        if (!string.IsNullOrEmpty(value)) config.VendorId = value;
                    }
                    else if (key.Equals("ProductId", StringComparison.OrdinalIgnoreCase))
                    {
                        config.ProductId = value;
                    }
                }
            }
            catch
            {
                // Any parse/IO error -> use defaults.
            }
            return config;
        }
    }
}
