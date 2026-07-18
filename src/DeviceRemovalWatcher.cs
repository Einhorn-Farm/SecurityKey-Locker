using System;
using System.Management;

namespace WindowsLocker
{
    /// <summary>
    /// Subscribes to WMI PnP device-deletion events and raises a callback when a
    /// device matching the configured vendor/product id is removed.
    /// </summary>
    public sealed class DeviceRemovalWatcher : IDisposable
    {
        private readonly Action<string> _onRemoved;
        private readonly string _match;
        private ManagementEventWatcher _watcher;

        public DeviceRemovalWatcher(AppConfig config, Action<string> onRemoved)
        {
            if (config == null) throw new ArgumentNullException("config");
            _onRemoved = onRemoved ?? throw new ArgumentNullException("onRemoved");

            _match = "VID_" + config.VendorId.ToUpperInvariant();
            if (!string.IsNullOrEmpty(config.ProductId))
            {
                _match += "&PID_" + config.ProductId.ToUpperInvariant();
            }
        }

        public void Start()
        {
            // Poll the PnP tree once per second for deleted entities. WMI runs in
            // its own service, so events are delivered regardless of session.
            var query = new WqlEventQuery(
                "__InstanceDeletionEvent",
                TimeSpan.FromSeconds(1),
                "TargetInstance ISA 'Win32_PnPEntity'");

            _watcher = new ManagementEventWatcher(query);
            _watcher.EventArrived += OnEventArrived;
            _watcher.Start();
        }

        private void OnEventArrived(object sender, EventArrivedEventArgs e)
        {
            try
            {
                var target = e.NewEvent["TargetInstance"] as ManagementBaseObject;
                if (target == null) return;

                string deviceId = Convert.ToString(SafeGet(target, "DeviceID"));
                if (string.IsNullOrEmpty(deviceId))
                {
                    deviceId = Convert.ToString(SafeGet(target, "PNPDeviceID"));
                }
                if (string.IsNullOrEmpty(deviceId)) return;

                if (deviceId.ToUpperInvariant().Contains(_match))
                {
                    _onRemoved(deviceId);
                }
            }
            catch (Exception ex)
            {
                Logger.Error("Error processing device event: " + ex);
            }
        }

        private static object SafeGet(ManagementBaseObject obj, string property)
        {
            try { return obj[property]; }
            catch { return null; }
        }

        public void Dispose()
        {
            if (_watcher != null)
            {
                try { _watcher.Stop(); }
                catch { /* ignore */ }

                _watcher.EventArrived -= OnEventArrived;
                _watcher.Dispose();
                _watcher = null;
            }
        }
    }
}
