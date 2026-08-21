import Toybox.Lang;
import Toybox.Application;
import Toybox.BluetoothLowEnergy;
import Toybox.System;
import Toybox.WatchUi;

// Data field app entry point. The actual running logic is in HaloDataField.compute().
class HaloApp extends Application.AppBase {

    public static var s_delegate as HaloDelegate or Null = null;

    public function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [new HaloDataField()];
    }

    function onStart(state as Dictionary or Null) as Void {
        s_delegate = new HaloDelegate();
        BluetoothLowEnergy.setDelegate(s_delegate);
        System.println("Halo Bridge data field started");
    }

    function onStop(state as Dictionary or Null) as Void {
        if (s_delegate != null) {
            s_delegate.disconnect();
        }
        System.println("Halo Bridge data field stopped");
    }
}
