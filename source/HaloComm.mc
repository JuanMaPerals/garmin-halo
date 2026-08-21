import Toybox.Lang;
import Toybox.BluetoothLowEnergy;

// Handles queued BLE writes with 20-byte chunking for the Garmin API limit.
// Only one write is outstanding at a time; the next chunk is sent after
// onCharacteristicWrite() fires via the onWriteComplete callback.
class HaloComm {

    private var _characteristic as BluetoothLowEnergy.Characteristic or Null;
    private var _queue as Array<ByteArray>;
    private var _queueIndex as Number;
    private var _isWriting as Boolean;

    public function initialize(char as BluetoothLowEnergy.Characteristic, callback as Object or Null) {
        _characteristic = char;
        _queue = [] as Array<ByteArray>;
        _queueIndex = 0;
        _isWriting = false;
    }

    // Set or update the target characteristic (after connection/discovery)
    public function setCharacteristic(char as BluetoothLowEnergy.Characteristic or Null) as Void {
        _characteristic = char;
    }

    // Enqueue a Lua command string for sending (auto-chunked to 20 bytes)
    public function sendLua(code as String) as Void {
        var utf8 = code.toUtf8Array();
        var ba = new ByteArray();
        for (var i = 0; i < utf8.size(); i++) {
            ba.add(utf8[i]);
        }
        enqueue(ba);
    }

    // Enqueue raw bytes for sending (auto-chunked to 20 bytes)
    public function enqueue(data as ByteArray) as Void {
        var offset = 0;
        while (offset < data.size()) {
            var remaining = data.size() - offset;
            var chunkSize = remaining < HaloConstants.MAX_WRITE_SIZE ? remaining : HaloConstants.MAX_WRITE_SIZE;
            var chunk = new ByteArray();
            for (var i = 0; i < chunkSize; i++) {
                chunk.add(data[offset + i]);
            }
            _queue.add(chunk);
            offset += chunkSize;
        }
        sendNext();
    }

    // Send a single control code byte
    public function sendControl(code as Number) as Void {
        var data = new ByteArray();
        data.add(code);
        _queue.add(data);
        sendNext();
    }

    // Convenience: send break (0x03)
    public function sendBreak() as Void {
        sendControl(HaloConstants.CTRL_BREAK);
    }

    // Attempt to send the next chunk in the queue
    public function sendNext() as Void {
        if (_isWriting || _characteristic == null) {
            return;
        }
        if (_queueIndex >= _queue.size()) {
            _queue = [] as Array<ByteArray>;
            _queueIndex = 0;
            return;
        }
        var chunk = _queue[_queueIndex];
        _queueIndex += 1;
        _isWriting = true;
        _characteristic.requestWrite(chunk, { :writeType => BluetoothLowEnergy.WRITE_TYPE_DEFAULT });
    }

    // Called by the BleDelegate when a write completes
    public function onWriteComplete(status as BluetoothLowEnergy.Status) as Void {
        _isWriting = false;
        if (status != BluetoothLowEnergy.STATUS_SUCCESS) {
            _queue = [] as Array<ByteArray>;
            _queueIndex = 0;
        }
        sendNext();
    }

    // Check if there are pending writes
    public function hasPendingWrites() as Boolean {
        return _queueIndex < _queue.size() || _isWriting;
    }

    // Clear the write queue
    public function clear() as Void {
        _queue = [] as Array<ByteArray>;
        _queueIndex = 0;
        _isWriting = false;
    }
}
