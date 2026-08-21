import Toybox.Lang;
import Toybox.Activity;
import Toybox.System;

// Composes Lua rendering scripts for the Halo display from Activity.Info data.
// Produces a single Lua string that clears the screen and draws the full UI.
// Layout matches the mockups verified in tests/mockup_halo_ui.py.
class HaloDisplay {

    // Colors (0xRRGGBB)
    private static const COLOR_BG = 0x000000;
    private static const COLOR_RING_OUTER = 0x0050A0;
    private static const COLOR_RING_INNER = 0x002060;
    private static const COLOR_HR = 0xFF4444;
    private static const COLOR_PACE = 0xFFFFFF;
    private static const COLOR_PACE_LABEL = 0x808080;
    private static const COLOR_DISTANCE = 0x44FF44;
    private static const COLOR_TIME = 0xFFFFFF;
    private static const COLOR_NAV = 0xFFFF00;
    private static const COLOR_DIVIDER = 0x303030;

    // Font IDs
    private static const FONT_REGULAR = 0;
    private static const FONT_BOLD = 1;

    // Build the full Lua script for a running update (no navigation)
    public static function buildRunningScript(info as Activity.Info) as String {
        return buildRunningScriptFromValues(
            info.currentHeartRate,
            info.currentSpeed,
            info.elapsedDistance,
            info.timerTime
        );
    }

    // Build running script from raw values (used by unit tests)
    public static function buildRunningScriptFromValues(
        hr as Number or Null,
        speed as Float or Null,
        elapsedDistance as Float or Null,
        timerTime as Number or Null) as String {
        var s = "";

        s += "frame.display.clear(" + fmtHex(COLOR_BG) + ")";
        s += "frame.display.circle(128,128,125," + fmtHex(COLOR_RING_OUTER) + ",false)";
        s += "frame.display.circle(128,128,122," + fmtHex(COLOR_RING_INNER) + ",false)";

        // Heart rate (centered, top)
        s += "frame.display.set_font(0,16,1)";
        s += "frame.display.text(\"" + formatHR(hr) + "\",108,30," + fmtHex(COLOR_HR) + ")";
        s += "frame.display.circle(100,38,4," + fmtHex(COLOR_HR) + ",true)";

        // Pace (large, center)
        s += "frame.display.set_font(1,32,1)";
        s += "frame.display.text(\"" + formatPace(speed) + "\",78,90," + fmtHex(COLOR_PACE) + ")";

        // /km label
        s += "frame.display.set_font(0,16,1)";
        s += "frame.display.text(\"/km\",96,130," + fmtHex(COLOR_PACE_LABEL) + ")";

        // Distance + time (centered, below divider)
        s += "frame.display.text(\"" + formatDistance(elapsedDistance) + "\",96,165," + fmtHex(COLOR_DISTANCE) + ")";
        s += "frame.display.text(\"" + formatTime(timerTime) + "\",96,190," + fmtHex(COLOR_TIME) + ")";
        s += "frame.display.line(50,155,206,155," + fmtHex(COLOR_DIVIDER) + ")";

        return s;
    }

    // Build the full Lua script with navigation overlay
    public static function buildNavigationScript(info as Activity.Info) as String {
        return buildNavigationScriptFromValues(
            info.currentHeartRate,
            info.currentSpeed,
            info.elapsedDistance,
            info.timerTime,
            info.distanceToNextPoint
        );
    }

    // Build navigation script from raw values (used by unit tests)
    public static function buildNavigationScriptFromValues(
        hr as Number or Null,
        speed as Float or Null,
        elapsedDistance as Float or Null,
        timerTime as Number or Null,
        distToNext as Float or Null) as String {
        var s = "";

        s += "frame.display.clear(" + fmtHex(COLOR_BG) + ")";
        s += "frame.display.circle(128,128,125," + fmtHex(COLOR_RING_OUTER) + ",false)";
        s += "frame.display.circle(128,128,122," + fmtHex(COLOR_RING_INNER) + ",false)";

        // Navigation arrow + distance (same line, centered as a pair)
        s += "frame.display.polygon({108,28,100,46,116,46}," + fmtHex(COLOR_NAV) + ")";
        s += "frame.display.set_font(0,16,1)";
        s += "frame.display.text(\"" + formatDistToNext(distToNext) + "\",122,32," + fmtHex(COLOR_NAV) + ")";

        // Heart rate (centered, between nav and pace)
        s += "frame.display.text(\"" + formatHR(hr) + "\",108,70," + fmtHex(COLOR_HR) + ")";
        s += "frame.display.circle(100,78,4," + fmtHex(COLOR_HR) + ",true)";

        // Pace (large, center, shifted down slightly)
        s += "frame.display.set_font(1,32,1)";
        s += "frame.display.text(\"" + formatPace(speed) + "\",78,110," + fmtHex(COLOR_PACE) + ")";

        // /km, distance, time (centered, below)
        s += "frame.display.set_font(0,16,1)";
        s += "frame.display.text(\"/km\",96,150," + fmtHex(COLOR_PACE_LABEL) + ")";
        s += "frame.display.text(\"" + formatDistance(elapsedDistance) + "\",96,180," + fmtHex(COLOR_DISTANCE) + ")";
        s += "frame.display.text(\"" + formatTime(timerTime) + "\",96,205," + fmtHex(COLOR_TIME) + ")";
        s += "frame.display.line(50,170,206,170," + fmtHex(COLOR_DIVIDER) + ")";

        return s;
    }

    // Decide which script to build based on navigation state
    public static function buildScript(info as Activity.Info) as String {
        if (info != null && info.distanceToNextPoint != null) {
            return buildNavigationScript(info);
        } else {
            return buildRunningScript(info);
        }
    }

    // Build a connection status screen (shown when not in activity or searching)
    public static function buildStatusScript(statusText as String) as String {
        var s = "";
        s += "frame.display.clear(" + fmtHex(COLOR_BG) + ")";
        s += "frame.display.circle(128,128,125," + fmtHex(COLOR_RING_OUTER) + ",false)";
        s += "frame.display.set_font(0,16,1)";
        s += "frame.display.text(\"" + statusText + "\",96,120," + fmtHex(COLOR_PACE) + ")";
        return s;
    }

    // --- Formatting helpers ---

    private static function fmtHex(color as Number) as String {
        return "0x" + color.format("%06x");
    }

    private static function formatHR(hr as Number or Null) as String {
        if (hr == null) {
            return "--";
        }
        return hr.toString();
    }

    private static function formatPace(speed as Float or Null) as String {
        if (speed == null || speed <= 0) {
            return "--:--";
        }
        var paceSecPerKm = 1000.0 / speed;
        var min = (paceSecPerKm / 60.0).toNumber();
        var sec = (paceSecPerKm - (min * 60)).toNumber();
        if (sec < 10) {
            return min.toString() + ":0" + sec.toString();
        }
        return min.toString() + ":" + sec.toString();
    }

    private static function formatDistance(dist as Float or Null) as String {
        if (dist == null) {
            return "0.0km";
        }
        var km = dist / 1000.0;
        return km.format("%.1f") + "km";
    }

    private static function formatTime(elapsed as Number or Null) as String {
        if (elapsed == null) {
            return "0:00";
        }
        var totalSec = (elapsed / 1000.0).toNumber();
        var h = (totalSec / 3600).toNumber();
        var m = ((totalSec % 3600) / 60).toNumber();
        var s = (totalSec % 60).toNumber();
        if (h > 0) {
            if (m < 10) {
                return h.toString() + ":0" + m.toString();
            }
            return h.toString() + ":" + m.toString();
        }
        if (s < 10) {
            return m.toString() + ":0" + s.toString();
        }
        return m.toString() + ":" + s.toString();
    }

    private static function formatDistToNext(dist as Float or Null) as String {
        if (dist == null) {
            return "---m";
        }
        if (dist >= 1000) {
            var km = dist / 1000.0;
            return km.format("%.1f") + "km";
        }
        return dist.toNumber().toString() + "m";
    }
}
