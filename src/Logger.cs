using System;
using System.Diagnostics;

namespace WindowsLocker
{
    /// <summary>
    /// Minimal logger that writes to the Windows Application event log (source
    /// created by the installer) and, when interactive, to the console.
    /// </summary>
    internal static class Logger
    {
        private const string Source = "WindowsLocker";

        public static void Info(string message)
        {
            Write(message, EventLogEntryType.Information);
        }

        public static void Error(string message)
        {
            Write(message, EventLogEntryType.Error);
        }

        private static void Write(string message, EventLogEntryType type)
        {
            try
            {
                if (EventLog.SourceExists(Source))
                {
                    EventLog.WriteEntry(Source, message, type);
                }
            }
            catch
            {
                // Never let logging crash the service.
            }

            if (Environment.UserInteractive)
            {
                Console.WriteLine("[" + type + "] " + DateTime.Now.ToString("HH:mm:ss") + " " + message);
            }
        }
    }
}
