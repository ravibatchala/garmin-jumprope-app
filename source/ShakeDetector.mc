import Toybox.Lang;
import Toybox.Math;
import Toybox.System;

// Detects a deliberate side-to-side wrist shake while the workout is resting.
//
// This detector is intentionally separate from JumpDetector. During rest the
// jump detector is not fed samples at all, so vibration and small arm motion
// cannot create false jumps. The shake detector removes the gravity vector and
// looks only at the remaining horizontal motion. Three peaks inside a two
// second window arm the next set.
class ShakeDetector {
    private var _gx as Float = 0.0f;
    private var _gy as Float = 0.0f;
    private var _gz as Float = 1000.0f;
    private var _hasGravity as Boolean = false;

    private var _inPeak as Boolean = false;
    private var _peakMax as Float = 0.0f;
    private var _peaks as Number = 0;
    private var _firstPeakTime as Number = 0;
    private var _lastPeakTime as Number = -1000000;
    private var _lastSample as Number = -1;
    private var _sampleRate as Number = AppConstants.SAMPLE_RATE;
    private var _gravityAlpha as Float = AppConstants.SHAKE_GRAVITY_ALPHA;

    private var _armed as Boolean = false;

    public function initialize() {
    }

    public function setSampleRate(rate as Number) as Void {
        if (rate < 1) {
            rate = 1;
        }
        if (rate > 200) {
            rate = 200;
        }
        _sampleRate = rate;
        var dt = 1000.0f / rate.toFloat();
        _gravityAlpha = dt / (AppConstants.SHAKE_GRAVITY_TAU_MS + dt);
    }

    public function reset() as Void {
        _gx = 0.0f;
        _gy = 0.0f;
        _gz = 1000.0f;
        _hasGravity = false;
        _inPeak = false;
        _peakMax = 0.0f;
        _peaks = 0;
        _firstPeakTime = 0;
        _lastPeakTime = -1000000;
        _lastSample = -1;
        _armed = false;
    }

    public function processSamples(xs as Array<Numeric>, ys as Array<Numeric>, zs as Array<Numeric>, timestamps as Array<Numeric>?) as Boolean {
        var n = xs.size();
        if (ys.size() < n) {
            n = ys.size();
        }
        if (zs.size() < n) {
            n = zs.size();
        }

        var interval = 1000 / _sampleRate;
        var fallbackStart = System.getTimer();
        for (var i = 0; i < n; i++) {
            var t;
            if (timestamps != null && i < timestamps.size()) {
                t = (timestamps[i] as Number);
            } else {
                t = fallbackStart + (i * interval);
            }

            processSample(
                (xs[i] as Numeric).toFloat(),
                (ys[i] as Numeric).toFloat(),
                (zs[i] as Numeric).toFloat(),
                t
            );
        }
        return _armed;
    }

    public function processSample(x as Float, y as Float, z as Float, timestamp as Number) as Boolean {
        if (_armed) {
            return true;
        }

        if (_lastSample >= 0 && timestamp <= _lastSample) {
            timestamp = _lastSample + (1000 / _sampleRate);
        }
        if (_lastSample >= 0 && timestamp > _lastSample + 1500) {
            // A gap in sensor data invalidates the current motion peak.
            _inPeak = false;
            _peakMax = 0.0f;
            _peaks = 0;
        }
        _lastSample = timestamp;

        if (!_hasGravity) {
            _gx = x;
            _gy = y;
            _gz = z;
            _hasGravity = true;
            return false;
        }

        // Track gravity slowly so a shake is not absorbed as gravity.
        var alpha = _gravityAlpha;
        _gx = _gx + ((x - _gx) * alpha);
        _gy = _gy + ((y - _gy) * alpha);
        _gz = _gz + ((z - _gz) * alpha);

        var gravitySq = (_gx * _gx) + (_gy * _gy) + (_gz * _gz);
        if (gravitySq < 1.0f) {
            gravitySq = 1.0f;
        }
        var dot = (x * _gx) + (y * _gy) + (z * _gz);
        var scale = dot / gravitySq;
        var hx = x - (_gx * scale);
        var hy = y - (_gy * scale);
        var hz = z - (_gz * scale);
        var horizontal = Math.sqrt((hx * hx) + (hy * hy) + (hz * hz)).toFloat();

        var threshold = AppConstants.SHAKE_HORIZONTAL_THRESHOLD;
        var release = threshold * AppConstants.SHAKE_RELEASE_RATIO;

        if (!_inPeak) {
            if (horizontal > threshold) {
                _inPeak = true;
                _peakMax = horizontal;
            }
            return false;
        }

        if (horizontal > _peakMax) {
            _peakMax = horizontal;
        }

        if (horizontal < release) {
            _inPeak = false;
            if (_peakMax >= threshold &&
                (timestamp - _lastPeakTime) >= AppConstants.SHAKE_PEAK_INTERVAL_MS) {
                _registerPeak(timestamp);
            }
            _peakMax = 0.0f;
        }
        return _armed;
    }

    public function isArmed() as Boolean {
        return _armed;
    }

    private function _registerPeak(timestamp as Number) as Void {
        if (_peaks > 0 && (timestamp - _lastPeakTime) > AppConstants.SHAKE_WINDOW_MS) {
            _peaks = 0;
        }
        if (_peaks == 0) {
            _firstPeakTime = timestamp;
        }
        _peaks++;
        _lastPeakTime = timestamp;
        if (_peaks >= AppConstants.SHAKE_PEAKS_REQUIRED &&
            (timestamp - _firstPeakTime) <= AppConstants.SHAKE_WINDOW_MS) {
            _armed = true;
        }
    }
}
