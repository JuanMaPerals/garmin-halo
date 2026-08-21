import Toybox.Lang;
import Toybox.BluetoothLowEnergy;
import Toybox.System;

// BLE delegate handling all async BLE callbacks for Halo communication.
// No callbacks to the view — the view can poll isConnected() / isScanning().
// Scanning starts automatically when the delegate is created.
class HaloDelegate extends BluetoothLowEnergy.BleDelegate {

    private var _comm as HaloComm or Null;
    private var _rxChar as BluetoothLowEnergy.Characteristic or Null;
    private var _txChar as BluetoothLowEnergy.Characteristic or Null;
    private var _connectedDevice as BluetoothLowEnergy.Device or Null;
    private var _isConnected as Boolean = false;
    private var _isScanning as Boolean = false;

    public function initialize() {
        BleDelegate.initialize();

        // Register the Halo Lua service profile (only once per app lifetime)
        try {
            BluetoothLowEnergy.registerProfile({
                :uuid => BluetoothLowEnergy.stringToUuid(HaloConstants.SERVICE_UUID),
                :characteristics => [{
                    :uuid => BluetoothLowEnergy.stringToUuid(HaloConstants.LUA_RX_UUID),
                    :descriptors => []
                }, {
                    :uuid => BluetoothLowEnergy.stringToUuid(HaloConstants.LUA_TX_UUID),
                    :descriptors => [BluetoothLowEnergy.cccdUuid()]
                }]
            });
        } catch (e instanceof Lang.Exception) {
            System.println("Profile already registered: " + e.getErrorMessage());
        }

        // Start scanning for Halo automatically
        _isScanning = true;
        BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_SCANNING);
    }

    // --- Scan callbacks ---

    public function onScanResults(scanResults as Iterator) as Void {
        var result = scanResults.next();
        while (result != null) {
            if (result instanceof ScanResult) {
                if (containsHaloService(result)) {
                    System.println("Halo found, stopping scan and pairing");
                    _isScanning = false;
                    BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_OFF);
                    BluetoothLowEnergy.pairDevice(result);
                    break;
                }
            }
            result = scanResults.next();
        }
    }

    public function onScanStateChange(scanState as ScanState, status as Status) as Void {
        if (status != BluetoothLowEnergy.STATUS_SUCCESS) {
            System.println("Scan error: " + status);
        }
    }

    // --- Profile registration ---

    public function onProfileRegister(uuid as Uuid, status as Status) as Void {
        if (status == BluetoothLowEnergy.STATUS_SUCCESS) {
            System.println("Halo profile registered successfully");
        } else {
            System.println("Profile registration failed: " + status);
        }
    }

    // --- Connection callbacks ---

    public function onConnectedStateChanged(device as Device, state as BluetoothLowEnergy.ConnectionState) as Void {
        if (state == BluetoothLowEnergy.CONNECTION_STATE_CONNECTED) {
            System.println("Connected to Halo");
            _connectedDevice = device;
            _isConnected = true;
            _isScanning = false;
            onDeviceConnected(device);
        } else if (state == BluetoothLowEnergy.CONNECTION_STATE_DISCONNECTED) {
            System.println("Disconnected from Halo");
            _connectedDevice = null;
            _isConnected = false;
            _rxChar = null;
            _txChar = null;
            if (_comm != null) {
                _comm.setCharacteristic(null);
            }
            // If the data field is still active, attempt to reconnect
            _isScanning = true;
            BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_SCANNING);
        }
    }

    // Called after successful connection — discover service and characteristics
    private function onDeviceConnected(device as Device) as Void {
        var service = device.getService(BluetoothLowEnergy.stringToUuid(HaloConstants.SERVICE_UUID));
        if (service == null) {
            System.println("Halo service not found");
            return;
        }

        _rxChar = service.getCharacteristic(BluetoothLowEnergy.stringToUuid(HaloConstants.LUA_RX_UUID));
        _txChar = service.getCharacteristic(BluetoothLowEnergy.stringToUuid(HaloConstants.LUA_TX_UUID));

        if (_rxChar == null || _txChar == null) {
            System.println("Halo characteristics not found");
            return;
        }

        var rxChar = _rxChar;
        var txChar = _txChar;

        // Initialize the comm queue with the RX characteristic
        if (_comm == null) {
            _comm = new HaloComm(rxChar, null);
        } else {
            _comm.setCharacteristic(rxChar);
        }

        // Enable notifications on the TX characteristic by writing CCCD
        var cccd = txChar.getDescriptor(BluetoothLowEnergy.cccdUuid());
        if (cccd != null) {
            cccd.requestWrite(HaloConstants.CCCD_NOTIFY_ENABLED);
            System.println("Enabling notifications on TX characteristic");
        } else {
            System.println("CCCD not found on TX characteristic");
        }
    }

    // --- Characteristic write callback ---

    public function onCharacteristicWrite(characteristic as Characteristic, status as Status) as Void {
        if (_comm != null) {
            _comm.onWriteComplete(status);
        }
        if (status != BluetoothLowEnergy.STATUS_SUCCESS) {
            System.println("Write failed: " + status);
        }
    }

    // --- Descriptor write callback (CCCD) ---

    public function onDescriptorWrite(descriptor as Descriptor, status as Status) as Void {
        if (status == BluetoothLowEnergy.STATUS_SUCCESS) {
            System.println("Descriptor write success (notifications enabled)");
            // Send break to ensure Halo is in REPL mode
            if (_comm != null) {
                _comm.sendBreak();
            }
        } else {
            System.println("Descriptor write failed: " + status);
        }
    }

    // --- Notification callback (Halo -> Garmin data) ---

    public function onCharacteristicChanged(characteristic as Characteristic, value as ByteArray) as Void {
        if (value == null || value.size() == 0) {
            return;
        }

        // Check if this is the TX characteristic
        var txUuid = BluetoothLowEnergy.stringToUuid(HaloConstants.LUA_TX_UUID);
        if (!characteristic.getUuid().equals(txUuid)) {
            return;
        }

        // Check for binary data marker (0x01 prefix)
        if (value[0] == HaloConstants.DATA_MARKER) {
            // Binary data — strip marker and handle (not needed for MVP, just log)
            System.println("Received binary data from Halo (" + (value.size() - 1) + " bytes)");
        } else {
            // Text output from print() or error
            var text = value.toString();
            System.println("Halo response: " + text);
        }
    }

    // --- Public accessors ---

    public function getComm() as HaloComm or Null {
        return _comm;
    }

    public function isConnected() as Boolean {
        return _isConnected;
    }

    public function isScanning() as Boolean {
        return _isScanning;
    }

    public function disconnect() as Void {
        if (_connectedDevice != null) {
            BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_OFF);
        }
        _isConnected = false;
        _isScanning = false;
        if (_comm != null) {
            _comm.clear();
        }
    }

    // --- Helpers ---

    private function containsHaloService(result as ScanResult) as Boolean {
        var serviceUuids = result.getServiceUuids();
        if (serviceUuids == null) {
            return false;
        }
        var haloUuid = BluetoothLowEnergy.stringToUuid(HaloConstants.SERVICE_UUID);
        for (var uuid = serviceUuids.next(); uuid != null; uuid = serviceUuids.next()) {
            if (uuid instanceof Uuid) {
                if ((uuid as Uuid).equals(haloUuid)) {
                    return true;
                }
            }
        }
        return false;
    }
}
