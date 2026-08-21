import Toybox.Lang;
import Toybox.BluetoothLowEnergy;

class HaloConstants {

    // Halo Lua Service UUID
    public static const SERVICE_UUID = "7A230001-5475-A6A4-654C-8431F6AD49C4";

    // LUA RX Characteristic (Garmin writes Lua commands here)
    public static const LUA_RX_UUID = "7A230002-5475-A6A4-654C-8431F6AD49C4";

    // LUA TX Characteristic (Halo sends print() output via notifications)
    public static const LUA_TX_UUID = "7A230003-5475-A6A4-654C-8431F6AD49C4";

    // Control codes sent on LUA RX
    public static const CTRL_BREAK = 0x03;  // Interrupt running script
    public static const CTRL_RESET = 0x04;  // Restart Lua runtime

    // Binary data marker (first byte of binary payloads on TX)
    public static const DATA_MARKER = 0x01;

    // Max bytes per BLE write (Garmin API limit)
    public static const MAX_WRITE_SIZE = 20;

    // CCCD value to enable notifications (little-endian 0x0001)
    public static const CCCD_NOTIFY_ENABLED = [0x01, 0x00]b;
}
