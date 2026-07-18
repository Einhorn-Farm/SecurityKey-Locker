using System;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;

namespace WindowsLocker
{
    /// <summary>
    /// Locks the interactive (console) desktop from a Session 0 service by
    /// launching rundll32 user32.dll,LockWorkStation inside the logged-on
    /// user's session using their token.
    /// </summary>
    internal static class SessionLocker
    {
        public static void LockActiveSession()
        {
            uint sessionId = NativeMethods.WTSGetActiveConsoleSessionId();
            if (sessionId == 0xFFFFFFFF)
            {
                Logger.Info("No active console session; nothing to lock.");
                return;
            }

            IntPtr userToken = IntPtr.Zero;
            IntPtr dupToken = IntPtr.Zero;
            IntPtr envBlock = IntPtr.Zero;

            try
            {
                if (!NativeMethods.WTSQueryUserToken(sessionId, out userToken))
                {
                    int err = Marshal.GetLastWin32Error();
                    // 1008 = no token (no interactive user logged on in that session)
                    Logger.Info("No user token for session " + sessionId +
                                " (Win32 error " + err + "); skipping lock.");
                    return;
                }

                var sa = new NativeMethods.SECURITY_ATTRIBUTES();
                sa.nLength = Marshal.SizeOf(typeof(NativeMethods.SECURITY_ATTRIBUTES));

                if (!NativeMethods.DuplicateTokenEx(
                        userToken,
                        NativeMethods.MAXIMUM_ALLOWED,
                        ref sa,
                        NativeMethods.SECURITY_IMPERSONATION_LEVEL.SecurityImpersonation,
                        NativeMethods.TOKEN_TYPE.TokenPrimary,
                        out dupToken))
                {
                    throw new Win32Exception(Marshal.GetLastWin32Error(), "DuplicateTokenEx failed");
                }

                // Best-effort environment block; lock works without it too.
                NativeMethods.CreateEnvironmentBlock(out envBlock, dupToken, false);

                string rundll = Path.Combine(Environment.SystemDirectory, "rundll32.exe");
                string commandLine = "\"" + rundll + "\" user32.dll,LockWorkStation";

                var si = new NativeMethods.STARTUPINFO();
                si.cb = Marshal.SizeOf(typeof(NativeMethods.STARTUPINFO));
                si.lpDesktop = @"winsta0\default";

                NativeMethods.PROCESS_INFORMATION pi;
                bool created = NativeMethods.CreateProcessAsUser(
                    dupToken,
                    null,
                    commandLine,
                    IntPtr.Zero,
                    IntPtr.Zero,
                    false,
                    NativeMethods.CREATE_UNICODE_ENVIRONMENT | NativeMethods.CREATE_NO_WINDOW,
                    envBlock,
                    null,
                    ref si,
                    out pi);

                if (!created)
                {
                    throw new Win32Exception(Marshal.GetLastWin32Error(), "CreateProcessAsUser failed");
                }

                NativeMethods.CloseHandle(pi.hThread);
                NativeMethods.CloseHandle(pi.hProcess);
            }
            finally
            {
                if (envBlock != IntPtr.Zero) NativeMethods.DestroyEnvironmentBlock(envBlock);
                if (dupToken != IntPtr.Zero) NativeMethods.CloseHandle(dupToken);
                if (userToken != IntPtr.Zero) NativeMethods.CloseHandle(userToken);
            }
        }
    }
}
