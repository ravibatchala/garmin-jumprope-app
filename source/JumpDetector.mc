import Toybox.Lang;
import Toybox.Math;
import Toybox.System;

// Detects vertical jumps from wrist accelerometer samples.
//
// The detector is deliberately split into small, testable stages:
//   1. Convert the 3-axis sample to an orientation-independent magnitude.
//   2. Remove gravity with a slow low-pass estimate.
//   3. Remove slow arm motion with a second low-pass stage (band-pass).
//   4. Smooth the remaining signal.
//   5. Detect a validated positive peak with an adaptive threshold and
//      a refractory period.
class JumpDetector {
    private var _threshold as Float;
    private var _gravity as Float = 1000.0f;
    private var _slow as Float = 0.0f;
    private var _prev1 as Float = 0.0f;
    private var _prev2 as Float = 0.0f;
    private var _noise as Float = 20.0f;
    private var _samples as Number = 0;
    private var _sampleRate as Number = AppConstants.SAMPLE_RATE;
    private var _warmupSamples as Number = 50;
    private var _gravityAlphaWarmup as Float = 0.08f;
    private var _gravityAlpha as Float = 0.015f;
    private var _slowAlpha as Float = 0.035f;
    private var _inPeak as Boolean = false;
    private var _peakStart as Number = 0;
    private var _peakMax as Float = 0.0f;
    private var _lastPeakMax as Float = 0.0f;
    private var _lastJump as Number = -1000000;
    private var _lastSample as Number = -1;
    private var _count as Number = 0;
    private var _streak as Number = 0;
    private var _bestStreak as Number = 0;
    private var _times as Array<Number>;
    private var _timeIndex as Number = 0;
    private var _signal as Float = 0.0f;
    private var _lastMagnitude as Float = 0.0f;
    private var _seedGravity as Boolean = false;

    public function initialize(threshold as Float) {
        _threshold = threshold;
        setSampleRate(AppConstants.SAMPLE_RATE);
        _times = new Array<Number>[40];
        for (var i = 0; i < _times.size(); i++) {
            _times[i] = -1000000;
        }
    }

    // Called with the real accelerometer rate before samples are processed.
    // The filter time constants are converted back to per-sample alpha values
    // so a 25 Hz device behaves like the tuned 50 Hz detector.
    public function setSampleRate(rate as Number) as Void {
        if (rate < 1) {
            rate = 1;
        }
        if (rate > 200) {
            rate = 200;
        }
        _sampleRate = rate;
        _warmupSamples = (rate.toFloat() * AppConstants.WARMUP_SECONDS).toNumber();
        var dt = 1000.0f / rate.toFloat();
        _gravityAlphaWarmup = dt / (AppConstants.GRAVITY_WARMUP_TAU_MS + dt);
        _gravityAlpha = dt / (AppConstants.GRAVITY_TAU_MS + dt);
        _slowAlpha = dt / (AppConstants.SLOW_TAU_MS + dt);
    }

    public function processSamples(xs as Array<Numeric>, ys as Array<Numeric>, zs as Array<Numeric>, timestamps as Array<Numeric>?) as Void {
        processSamplesFrom(xs, ys, zs, timestamps, 0);
    }

    // Processes a batch starting at startIndex. Used right after arming to
    // skip the samples that arrived before the arm point, so the button press
    // and the last moments of rest cannot be counted as jumps.
    public function processSamplesFrom(xs as Array<Numeric>, ys as Array<Numeric>, zs as Array<Numeric>, timestamps as Array<Numeric>?, startIndex as Number) as Void {
        var n = xs.size();
        if (ys.size() < n) {
            n = ys.size();
        }
        if (zs.size() < n) {
            n = zs.size();
        }

        if (startIndex < 0) {
            startIndex = 0;
        }
        if (startIndex > n) {
            startIndex = n;
        }

        var interval = 1000 / _sampleRate;
        var fallbackStart = System.getTimer();
        for (var i = startIndex; i < n; i++) {
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
    }

    public function processSample(x as Float, y as Float, z as Float, timestamp as Number) as Boolean {
        if (_lastSample >= 0 && timestamp <= _lastSample) {
            // Keep time monotonic even if a sensor batch has a duplicate stamp.
            timestamp = _lastSample + (1000 / _sampleRate);
        }
        if (_lastSample >= 0 && timestamp > _lastSample + 1500) {
            // A gap in sensor data should not be mistaken for a long peak.
            _inPeak = false;
        }
        _lastSample = timestamp;

        var magnitudeSq = (x * x) + (y * y) + (z * z);
        var magnitude = Math.sqrt(magnitudeSq).toFloat();
        _lastMagnitude = magnitude;

        if (_seedGravity) {
            // Start a new set without a one second warm-up. The first sample
            // establishes gravity, then the next sample can be detected.
            _gravity = magnitude;
            _slow = 0.0f;
            _prev1 = 0.0f;
            _prev2 = 0.0f;
            _noise = 20.0f;
            _samples = _warmupSamples;
            _signal = 0.0f;
            _seedGravity = false;
            return false;
        }

        if (_samples == 0) {
            _gravity = magnitude;
        }

        var gravityAlpha = _gravityAlphaWarmup;
        if (_samples >= _warmupSamples) {
            gravityAlpha = _gravityAlpha;
        }
        _gravity = _gravity + ((magnitude - _gravity) * gravityAlpha);

        var dynamic = magnitude - _gravity;
        _slow = _slow + ((dynamic - _slow) * _slowAlpha);

        var filtered = dynamic - _slow;
        _prev2 = _prev1;
        _prev1 = filtered;
        var smooth = (_prev2 + _prev1 + filtered) / 3.0f;
        _signal = smooth;
        _samples++;

        if (_samples < _warmupSamples) {
            _noise = (_noise * 0.95f) + (_abs(smooth) * 0.05f);
            return false;
        }

        var activeThreshold = _threshold;
        var adaptive = _noise * 2.2f;
        if (adaptive > activeThreshold) {
            activeThreshold = adaptive;
        }
        if (activeThreshold > 450.0f) {
            activeThreshold = 450.0f;
        }

        if (!_inPeak) {
            _noise = (_noise * 0.999f) + (_abs(smooth) * 0.001f);
            if (smooth > activeThreshold) {
                _inPeak = true;
                _peakStart = timestamp;
                _peakMax = smooth;
            }
            return false;
        }

        if (smooth > _peakMax) {
            _peakMax = smooth;
        }

        var width = timestamp - _peakStart;
        if (smooth < (activeThreshold * 0.55f)) {
            _inPeak = false;
            if (width >= 20 && width <= AppConstants.PEAK_MAX_WIDTH_MS &&
                _peakMax >= activeThreshold &&
                (timestamp - _lastJump) >= AppConstants.MIN_JUMP_INTERVAL_MS) {
                _registerJump(timestamp);
                return true;
            }
        } else if (width > 600) {
            _inPeak = false;
        }
        return false;
    }

    public function setThreshold(threshold as Float) as Void {
        _threshold = threshold;
    }

    // Clear only the filter state. Count, streak, and cadence history survive
    // so a pause or a trip through the background does not erase the workout.
    public function resetFilters() as Void {
        _gravity = 1000.0f;
        _slow = 0.0f;
        _prev1 = 0.0f;
        _prev2 = 0.0f;
        _noise = 20.0f;
        _samples = 0;
        _inPeak = false;
        _peakStart = 0;
        _peakMax = 0.0f;
        _signal = 0.0f;
        _lastSample = -1;
        _seedGravity = false;
    }

    // Reset the filters for a new set, but seed gravity from the first sample
    // instead of discarding a full warm-up second. Count/history are preserved.
    public function rebase() as Void {
        resetFilters();
        _seedGravity = true;
    }

    public function getCount() as Number {
        return _count;
    }

    public function getStreak() as Number {
        return _streak;
    }

    public function getBestStreak() as Number {
        return _bestStreak;
    }

    public function getCadence(now as Number) as Number {
        if (_lastJump < 0 || (now - _lastJump) > 2500) {
            return 0;
        }

        var cutoff = now - AppConstants.CADENCE_WINDOW_MS;
        var recent = 0;
        var oldest = now;
        var newest = 0;
        for (var i = 0; i < _times.size(); i++) {
            var stamp = _times[i];
            if (stamp >= cutoff && stamp > 0) {
                recent++;
                if (stamp < oldest) {
                    oldest = stamp;
                }
                if (stamp > newest) {
                    newest = stamp;
                }
            }
        }
        if (recent < 2) {
            return 0;
        }

        var span = newest - oldest;
        if (span <= 0) {
            return 0;
        }
        var cadence = ((recent - 1) * 60000) / span;
        if (cadence > 300) {
            cadence = 300;
        }
        return cadence;
    }

    public function getCadenceNow() as Number {
        if (_lastSample < 0) {
            return 0;
        }
        return getCadence(_lastSample);
    }

    public function getLastTimestamp() as Number {
        return _lastSample;
    }

    public function getSignal() as Float {
        return _signal;
    }

    public function getLastPeakMax() as Float {
        return _lastPeakMax;
    }

    public function getMagnitude() as Float {
        return _lastMagnitude;
    }

    public function getThreshold() as Float {
        var adaptive = _noise * 2.2f;
        if (adaptive > _threshold) {
            if (adaptive > 450.0f) {
                return 450.0f;
            }
            return adaptive;
        }
        return _threshold;
    }

    public function isPeaking() as Boolean {
        return _inPeak;
    }

    private function _registerJump(timestamp as Number) as Void {
        if ((timestamp - _lastJump) > AppConstants.JUMP_GAP_MS) {
            _streak = 0;
            for (var i = 0; i < _times.size(); i++) {
                _times[i] = -1000000;
            }
            _timeIndex = 0;
        }
        _lastJump = timestamp;
        _lastPeakMax = _peakMax;
        _count++;
        _streak++;
        if (_streak > _bestStreak) {
            _bestStreak = _streak;
        }
        _times[_timeIndex] = timestamp;
        _timeIndex = (_timeIndex + 1) % _times.size();
    }

    private function _abs(value as Float) as Float {
        if (value < 0.0f) {
            return -value;
        }
        return value;
    }
}
