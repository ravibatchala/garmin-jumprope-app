import Toybox.Attention;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Sensor;
import Toybox.System;
import Toybox.WatchUi;

// "Jump 10 times" calibration. This is only offered from an idle session, so
// it never competes with the workout sensor listener.
class CalibrationView extends WatchUi.View {
    private var _settings as Settings;
    private var _detector as JumpDetector?;
    private var _jumps as Number = 0;
    private var _peakSum as Float = 0.0f;
    private var _done as Boolean = false;
    private var _error as String? = null;
    private var _sensorsOn as Boolean = false;
    private var _sampleRate as Number = AppConstants.SAMPLE_RATE;

    public function initialize(settings as Settings) {
        View.initialize();
        _settings = settings;
    }

    public function onShow() as Void {
        _startSensors();
        WatchUi.requestUpdate();
    }

    public function onHide() as Void {
        _stopSensors();
    }

    public function onUpdate(dc as Dc) as Void {
        JumpUi.applyTheme(dc, _settings.darkMode);

        var w = dc.getWidth();
        var center = w / 2;

        dc.drawText(center, 8, Graphics.FONT_XTINY, "CALIBRATE", Graphics.TEXT_JUSTIFY_CENTER);

        if (_error != null) {
            dc.drawText(center, 58, Graphics.FONT_SMALL, "SENSOR ERR", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(center, 92, Graphics.FONT_XTINY, "BACK TO EXIT", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        if (_done) {
            dc.drawText(center, 46, Graphics.FONT_SMALL, "SAVED", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(center, 82, Graphics.FONT_XTINY, "THRESHOLD", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(center, 106, Graphics.FONT_MEDIUM, _settings.customThreshold.toString(), Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(center, 140, Graphics.FONT_XTINY, "BACK TO EXIT", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        dc.drawText(center, 40, Graphics.FONT_XTINY, "JUMP 10 TIMES", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(center, 64, Graphics.FONT_NUMBER_MILD, _jumps.toString(), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(center, 104, Graphics.FONT_XTINY, "OF 10  STEADY JUMPS", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(center, 140, Graphics.FONT_XTINY, "BACK TO CANCEL", Graphics.TEXT_JUSTIFY_CENTER);
    }

    public function isDone() as Boolean {
        return _done;
    }

    public function onAccel(sensorData as Sensor.SensorData) as Void {
        if (_done) {
            return;
        }
        var detector = _detector;
        if (detector == null) {
            return;
        }
        if (!(sensorData has :accelerometerData)) {
            return;
        }
        var accel = sensorData.accelerometerData;
        if (accel == null || accel.x == null || accel.y == null || accel.z == null) {
            return;
        }

        var before = detector.getCount();
        detector.processSamples(
            accel.x as Array<Numeric>,
            accel.y as Array<Numeric>,
            accel.z as Array<Numeric>,
            accel.timestamp as Array<Numeric>?
        );
        if (detector.getCount() > before) {
            _jumps++;
            _peakSum += detector.getLastPeakMax();
            if (_jumps >= 10) {
                var average = _peakSum / 10.0f;
                var threshold = (average * 0.55f).toNumber();
                if (threshold < 120) {
                    threshold = 120;
                }
                if (threshold > 320) {
                    threshold = 320;
                }
                _settings.setCustomThreshold(threshold);
                _done = true;
                _stopSensors();
                _vibrateDone();
            }
            WatchUi.requestUpdate();
        }
    }

    private function _startSensors() as Void {
        if (_sensorsOn) {
            return;
        }
        _sampleRate = AppConstants.SAMPLE_RATE;
        try {
            var maxRate = Sensor.getMaxSampleRateForSensorType(:accelerometer);
            if (maxRate > 0 && maxRate < _sampleRate) {
                _sampleRate = maxRate;
            }
        } catch (e) {
            System.println("Calibration sample-rate query failed: " + e.getErrorMessage());
        }

        try {
            var detector = new JumpDetector(120.0f);
            detector.setSampleRate(_sampleRate);
            _detector = detector;

            var options = {
                :period => AppConstants.ACCEL_PERIOD,
                :accelerometer => {
                    :enabled => true,
                    :sampleRate => _sampleRate,
                    :includeTimestamps => true
                }
            };
            Sensor.registerSensorDataListener(method(:onAccel), options);
            _sensorsOn = true;
        } catch (e) {
            _error = "SENSOR ERR";
            System.println("Calibration sensor failed: " + e.getErrorMessage());
        }
    }

    private function _stopSensors() as Void {
        if (!_sensorsOn) {
            return;
        }
        try {
            Sensor.unregisterSensorDataListener();
        } catch (e) {
            System.println("Calibration stop failed: " + e.getErrorMessage());
        }
        _sensorsOn = false;
    }

    private function _vibrateDone() as Void {
        if (Attention has :vibrate) {
            Attention.vibrate([
                new Attention.VibeProfile(75, 60),
                new Attention.VibeProfile(0, 80),
                new Attention.VibeProfile(75, 60),
                new Attention.VibeProfile(0, 80),
                new Attention.VibeProfile(75, 60)
            ]);
        }
    }
}

class CalibrationDelegate extends WatchUi.BehaviorDelegate {
    public function initialize() {
        BehaviorDelegate.initialize();
    }

    public function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    public function onSelect() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
