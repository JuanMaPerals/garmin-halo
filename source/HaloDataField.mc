import Toybox.Lang;
import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Time;
import Toybox.WatchUi;

// Data field that mirrors running and navigation data to Halo glasses.
// Extends SimpleDataField, so compute() is called by the system on each
// Activity.Info update. The returned value is not displayed; we draw a
// status indicator and push the rendered UI to Halo via BLE.
class HaloDataField extends WatchUi.SimpleDataField {

    private var _lastUpdateSec as Number = -1;

    public function initialize() {
        SimpleDataField.initialize();
        label = "Halo";
    }

    // Called by the system when the activity info updates.
    // Send a Lua rendering script to Halo at most once per second.
    function compute(info as Activity.Info) as Numeric or Duration or String or Null {
        if (info == null) {
            return null;
        }

        // Throttle to once per second to avoid flooding BLE
        var timerTime = info.timerTime;
        var elapsedSec = timerTime != null ? (timerTime / 1000.0).toNumber() : -1;
        if (elapsedSec == _lastUpdateSec) {
            return null;
        }
        _lastUpdateSec = elapsedSec;

        var delegate = HaloApp.s_delegate;
        if (delegate != null && delegate.isConnected()) {
            var lua = HaloDisplay.buildScript(info);
            var comm = delegate.getComm();
            if (comm != null) {
                comm.sendLua(lua);
            }
        }

        return null;
    }

    // Render a minimal Halo status indicator on the watch data field.
    // Green = connected to Halo, yellow = scanning/connecting, red = not connected.
    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();

        var delegate = HaloApp.s_delegate;
        var statusColor = Graphics.COLOR_RED;
        if (delegate != null) {
            if (delegate.isConnected()) {
                statusColor = Graphics.COLOR_GREEN;
            } else if (delegate.isScanning()) {
                statusColor = Graphics.COLOR_YELLOW;
            }
        }

        // Outer dark ring
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(width / 2, height / 2 - 10, 15);

        // Inner status dot
        dc.setColor(statusColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(width / 2, height / 2 - 10, 8);

        // Label below
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height / 2 + 10, Graphics.FONT_TINY, label, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
