import Toybox.Attention;
import Toybox.Lang;
import Toybox.Sensor;
import Toybox.System;
import Toybox.WatchUi;

class SessionManager {
    private var _settings as Settings?;
    private var _detector as JumpDetector?;
    private var _recorder as FitRecorder?;
    private var _state as Number = AppConstants.STATE_IDLE;
    private var _startedAt as Number = 0;
    private var _elapsedBefore as Number = 0;
    private var _heartRate as Number = 0;
    private var _hrSum as Number = 0;
    private var _hrCount as Number = 0;
    private var _hrMax as Number = 0;
    private var _hrMin as Number = 0;
    private var _peakCadence as Number = 0;
    private var _nextMilestone as Number = 0;
    private var _targetReached as Boolean = false;
    private var _saveActivity as Boolean = false;
    private var _sets as Number = 0;
    private var _inRest as Boolean = false;
    private var _setArmed as Boolean = false;
    private var _shakeDetector as ShakeDetector?;
    private var _shakeIgnoreUntil as Number = 0;
    private var _jumpIgnoreUntil as Number = 0;
    private var _lastJumpTime as Number = 0;
    private var _pausedAt as Number = 0;
    private var _sensorsOn as Boolean = false;
    private var _sensorError as String? = null;
    private var _saved as Boolean = false;

    // Rest, set and active-time tracking.
    private var _restTotalMs as Number = 0;
    private var _restStartedAt as Number = 0;
    private var _restBaseMs as Number = 0;
    private var _restCount as Number = 0;
    private var _setStartCount as Number = 0;
    private var _setStartedAt as Number = 0;
    private var _lastSetCount as Number = 0;
    private var _lastSetDurationMs as Number = 0;
    private var _setCounts as Array<Number>;
    private var _setDurations as Array<Number>;

    // UI state and sensor-rate tracking.
    private var _targetFlashUntil as Number = 0;
    private var _cadenceTrend as Number = 0;
    private var _lastTrendCadence as Number = 0;
    private var _countdownEndsAt as Number = 0;
    private var _countdownLast as Number = 0;
    private var _sampleRate as Number = AppConstants.SAMPLE_RATE;
    private var _previousBestTotal as Number = 0;
    private var _previousBestStreak as Number = 0;

    public function initialize() {
        _setCounts = new Array<Number>[0];
        _setDurations = new Array<Number>[0];
    }

    public function start(settings as Settings) as Boolean {
        if (_state != AppConstants.STATE_IDLE) {
            return false;
        }

        _settings = settings;
        _sampleRate = _getAccelSampleRate();
        _detector = new JumpDetector(settings.getThreshold());
        _detector.setSampleRate(_sampleRate);
        _shakeDetector = new ShakeDetector();
        _shakeDetector.setSampleRate(_sampleRate);

        _elapsedBefore = 0;
        _heartRate = 0;
        _hrSum = 0;
        _hrCount = 0;
        _hrMax = 0;
        _hrMin = 0;
        _peakCadence = 0;
        _targetReached = false;
        _targetFlashUntil = 0;
        _cadenceTrend = 0;
        _lastTrendCadence = 0;
        _saveActivity = settings.saveActivity;
        _sets = 0;
        _inRest = false;
        _setArmed = false;
        _shakeIgnoreUntil = 0;
        _jumpIgnoreUntil = 0;
        _lastJumpTime = 0;
        _pausedAt = 0;
        _sensorError = null;
        _saved = false;
        _nextMilestone = settings.vibeEvery;

        _restTotalMs = 0;
        _restStartedAt = 0;
        _restBaseMs = 0;
        _restCount = 0;
        _setStartCount = 0;
        _setStartedAt = 0;
        _lastSetCount = 0;
        _lastSetDurationMs = 0;
        _setCounts = new Array<Number>[0];
        _setDurations = new Array<Number>[0];

        _previousBestTotal = settings.bestTotal;
        _previousBestStreak = settings.bestStreak;

        if (settings.countdownSeconds > 0) {
            _state = AppConstants.STATE_COUNTDOWN;
            _countdownEndsAt = System.getTimer() + (settings.countdownSeconds * 1000);
            _countdownLast = settings.countdownSeconds;
            _recorder = null;
            _vibrate(70);
            WatchUi.requestUpdate();
            return true;
        }

        _beginRunning();
        return true;
    }

    public function pause() as Void {
        if (_state != AppConstants.STATE_RUNNING) {
            return;
        }
        var now = System.getTimer();
        if (_inRest && _restStartedAt > 0) {
            _restTotalMs += now - _restStartedAt;
            _restStartedAt = 0;
        }
        _elapsedBefore = getElapsedMs();
        _state = AppConstants.STATE_PAUSED;
        _pausedAt = now;
        _stopSensors();
        if (_recorder != null) {
            _recorder.pause();
        }
        WatchUi.requestUpdate();
    }

    public function resume() as Void {
        if (_state != AppConstants.STATE_PAUSED) {
            return;
        }
        var now = System.getTimer();
        var pausedFor = 0;
        if (_pausedAt > 0) {
            pausedFor = now - _pausedAt;
        }
        if (_inRest) {
            // Paused during a rest: resume the rest clock from now.
            _restStartedAt = now;
        } else if (_sets > 0 && _pausedAt > 0 &&
                   pausedFor >= _getRestDelayMs()) {
            // Finalize the set at the moment of the pause, not when the user
            // resumes, so the per-set time excludes the pause itself.
            _finalizeCurrentSet(_pausedAt);
            _enterRest(now, true);
        }

        _pausedAt = 0;
        _startedAt = now;
        _state = AppConstants.STATE_RUNNING;

        // A short pause keeps the same set alive, but its per-set duration
        // must not include the paused time.
        if (!_inRest && _setStartedAt > 0 && pausedFor > 0) {
            _setStartedAt += pausedFor;
        }

        if (_inRest) {
            _setArmed = false;
            _shakeIgnoreUntil = now + AppConstants.SHAKE_BLANK_MS;
            if (_shakeDetector != null) {
                _shakeDetector.reset();
            }
        } else {
            _lastJumpTime = now;
            if (_detector != null) {
                if (_setArmed) {
                    _detector.rebase();
                } else {
                    _detector.resetFilters();
                }
            }
        }

        _startSensors();
        if (_recorder != null) {
            _recorder.resume();
        }
        WatchUi.requestUpdate();
    }

    // Arm the next set after a rest. Called by a deliberate shake or by DOWN.
    public function armNewSet() as Boolean {
        if (_state != AppConstants.STATE_RUNNING || !_inRest || _sets == 0) {
            return false;
        }

        var now = System.getTimer();
        _endRest(now);
        _inRest = false;
        _setArmed = true;
        // With the current-set hero, READY should show 0 until the first real
        // jump of the new set arrives.
        _setStartCount = getJumpCount();
        _lastJumpTime = now;
        if (_detector != null) {
            _detector.rebase();
        }
        if (_shakeDetector != null) {
            _shakeDetector.reset();
        }
        _shakeIgnoreUntil = 0;
        _jumpIgnoreUntil = now + AppConstants.ARM_BLANK_MS;
        _vibrate(120);
        WatchUi.requestUpdate();
        return true;
    }

    public function stop() as Void {
        if (_state != AppConstants.STATE_RUNNING && _state != AppConstants.STATE_PAUSED) {
            return;
        }

        var now = System.getTimer();
        var stopAt = now;
        if (_state == AppConstants.STATE_PAUSED && _pausedAt > 0) {
            stopAt = _pausedAt;
        }
        if (_state == AppConstants.STATE_RUNNING) {
            _elapsedBefore = getElapsedMs();
        }
        if (_inRest && _restStartedAt > 0) {
            _restTotalMs += now - _restStartedAt;
            _restStartedAt = 0;
        }

        _finalizeCurrentSet(stopAt);
        _inRest = false;
        _setArmed = false;
        _state = AppConstants.STATE_STOPPED;
        _stopSensors();
        if (_recorder != null) {
            _recorder.stop();
        }
        WatchUi.requestUpdate();
    }

    public function cancelCountdown() as Void {
        if (_state == AppConstants.STATE_COUNTDOWN) {
            reset();
        }
    }

    public function save() as Boolean {
        _finalizeCurrentSet(System.getTimer());

        if (_recorder == null) {
            _saved = true;
            _recordBest();
            return true;
        }

        var ok = _recorder.finish(
            getJumpCount(),
            getBestStreak(),
            getAverageCadence(),
            getSets(),
            getAverageHeartRate(),
            getMaxHeartRate()
        );
        if (ok) {
            _saved = true;
            _recorder = null;
            _recordBest();
        }
        return ok;
    }

    public function discard() as Void {
        if (_recorder != null) {
            _recorder.discard();
            _recorder = null;
        }
        _saved = false;
    }

    public function reset() as Void {
        _stopSensors();
        if (_recorder != null) {
            _recorder.discard();
            _recorder = null;
        }
        _detector = null;
        _shakeDetector = null;
        _settings = null;
        _state = AppConstants.STATE_IDLE;
        _startedAt = 0;
        _elapsedBefore = 0;
        _heartRate = 0;
        _hrSum = 0;
        _hrCount = 0;
        _hrMax = 0;
        _hrMin = 0;
        _peakCadence = 0;
        _nextMilestone = 0;
        _targetReached = false;
        _targetFlashUntil = 0;
        _cadenceTrend = 0;
        _lastTrendCadence = 0;
        _saveActivity = false;
        _sets = 0;
        _inRest = false;
        _setArmed = false;
        _shakeIgnoreUntil = 0;
        _jumpIgnoreUntil = 0;
        _lastJumpTime = 0;
        _pausedAt = 0;
        _sensorError = null;
        _saved = false;
        _restTotalMs = 0;
        _restStartedAt = 0;
        _restBaseMs = 0;
        _restCount = 0;
        _setStartCount = 0;
        _setStartedAt = 0;
        _lastSetCount = 0;
        _lastSetDurationMs = 0;
        _setCounts = new Array<Number>[0];
        _setDurations = new Array<Number>[0];
        _countdownEndsAt = 0;
        _countdownLast = 0;
        _previousBestTotal = 0;
        _previousBestStreak = 0;
    }

    public function finalizeOnExit() as Void {
        if (_state == AppConstants.STATE_COUNTDOWN) {
            reset();
            return;
        }
        if (_state == AppConstants.STATE_RUNNING || _state == AppConstants.STATE_PAUSED) {
            stop();
        }
        if (_recorder != null || getJumpCount() > 0) {
            if (getJumpCount() > 0) {
                save();
            } else {
                discard();
            }
        }
        reset();
    }

    public function tick() as Void {
        if (_state == AppConstants.STATE_COUNTDOWN) {
            _tickCountdown();
            return;
        }
        if (_state != AppConstants.STATE_RUNNING || _detector == null) {
            return;
        }

        try {
            var info = Sensor.getInfo();
            if (info != null && info.heartRate != null) {
                _updateHeartRate(info.heartRate as Number);
            }
        } catch (e) {
            System.println("Sensor info failed: " + e.getErrorMessage());
        }

        _checkRestTimeout();
        var cadence = getCadence();
        if (cadence > _peakCadence) {
            _peakCadence = cadence;
        }
        _updateCadenceTrend(cadence);
        _updateRecorderRecord();
    }

    public function onAccel(sensorData as Sensor.SensorData) as Void {
        var detector = _detector;
        if (_state != AppConstants.STATE_RUNNING || detector == null) {
            return;
        }
        if (!(sensorData has :accelerometerData)) {
            return;
        }

        var accel = sensorData.accelerometerData;
        if (accel == null || accel.x == null || accel.y == null || accel.z == null) {
            return;
        }

        var xs = accel.x as Array<Numeric>;
        var ys = accel.y as Array<Numeric>;
        var zs = accel.z as Array<Numeric>;
        var timestamps = accel.timestamp as Array<Numeric>?;

        if (_inRest) {
            // Never feed the jump detector while resting. The rest vibration
            // and small arm movements must not create jumps or start/stop
            // cycles. Only a deliberate shake can arm the next set here; DOWN
            // is handled by the input delegate.
            var shake = _shakeDetector;
            if (shake != null && System.getTimer() >= _shakeIgnoreUntil) {
                if (shake.processSamples(xs, ys, zs, timestamps)) {
                    armNewSet();
                }
            }
            return;
        }

        if (System.getTimer() < _jumpIgnoreUntil) {
            return;
        }

        var before = detector.getCount();
        detector.processSamples(xs, ys, zs, timestamps);
        var after = detector.getCount();
        if (after > before) {
            _onJumpDetected(after, before);
        }
    }

    public function onSensorInfo(info as Sensor.Info) as Void {
        if (_state != AppConstants.STATE_RUNNING) {
            return;
        }
        if (info != null && info.heartRate != null) {
            _updateHeartRate(info.heartRate as Number);
        }
    }

    public function getState() as Number {
        return _state;
    }

    public function isIdle() as Boolean {
        return _state == AppConstants.STATE_IDLE;
    }

    public function isRunning() as Boolean {
        return _state == AppConstants.STATE_RUNNING;
    }

    public function isPaused() as Boolean {
        return _state == AppConstants.STATE_PAUSED;
    }

    public function isStopped() as Boolean {
        return _state == AppConstants.STATE_STOPPED;
    }

    public function isCountdown() as Boolean {
        return _state == AppConstants.STATE_COUNTDOWN;
    }

    public function getJumpCount() as Number {
        if (_detector == null) {
            return 0;
        }
        return _detector.getCount();
    }

    public function getStreak() as Number {
        if (_detector == null) {
            return 0;
        }
        return _detector.getStreak();
    }

    public function getBestStreak() as Number {
        if (_detector == null) {
            return 0;
        }
        return _detector.getBestStreak();
    }

    public function getSets() as Number {
        return _sets;
    }

    public function getCurrentSetJumps() as Number {
        if (_detector == null || _sets == 0) {
            return 0;
        }
        var count = _detector.getCount() - _setStartCount;
        if (count < 0) {
            count = 0;
        }
        return count;
    }

    public function getLastSetCount() as Number {
        return _lastSetCount;
    }

    public function getLastSetDurationMs() as Number {
        return _lastSetDurationMs;
    }

    public function getSetCount() as Number {
        return _setCounts.size();
    }

    public function getSetJumps(index as Number) as Number {
        if (index < 0 || index >= _setCounts.size()) {
            return 0;
        }
        return _setCounts[index];
    }

    public function getSetDurationMs(index as Number) as Number {
        if (index < 0 || index >= _setDurations.size()) {
            return 0;
        }
        return _setDurations[index];
    }

    public function isResting() as Boolean {
        return _inRest;
    }

    public function isSetArmed() as Boolean {
        return _setArmed;
    }

    public function getRestCount() as Number {
        return _restCount;
    }

    public function getRestElapsedMs() as Number {
        var total = _restTotalMs;
        if (_inRest && _restStartedAt > 0 && _state == AppConstants.STATE_RUNNING) {
            total += System.getTimer() - _restStartedAt;
        }
        return total;
    }

    // Elapsed time for the current rest, not the accumulated rest time used by
    // the active-time calculation. The timer is paused with the workout.
    public function getCurrentRestElapsedMs() as Number {
        if (!_inRest) {
            return 0;
        }
        var total = _restTotalMs;
        if (_restStartedAt > 0 && _state == AppConstants.STATE_RUNNING) {
            total += System.getTimer() - _restStartedAt;
        }
        var current = total - _restBaseMs;
        if (current < 0) {
            current = 0;
        }
        return current;
    }

    public function getCadence() as Number {
        if (_detector == null || _state != AppConstants.STATE_RUNNING || _inRest) {
            return 0;
        }
        return _detector.getCadenceNow();
    }

    public function getCadenceTrend() as Number {
        return _cadenceTrend;
    }

    public function getPeakCadence() as Number {
        return _peakCadence;
    }

    public function getAverageCadence() as Number {
        var active = getActiveMs();
        if (active < 1000 || _detector == null) {
            return 0;
        }
        var minutes = active.toFloat() / 60000.0f;
        if (minutes <= 0.0f) {
            return 0;
        }
        return (_detector.getCount().toFloat() / minutes).toNumber();
    }

    // Cadence of the set that just ended, shown while resting so the JPM
    // column does not drop to a misleading zero.
    public function getLastSetAverageCadence() as Number {
        if (_lastSetCount <= 0 || _lastSetDurationMs < 1000) {
            return 0;
        }
        var minutes = _lastSetDurationMs.toFloat() / 60000.0f;
        if (minutes <= 0.0f) {
            return 0;
        }
        return (_lastSetCount.toFloat() / minutes).toNumber();
    }

    public function getElapsedMs() as Number {
        if (_state == AppConstants.STATE_RUNNING) {
            return _elapsedBefore + (System.getTimer() - _startedAt);
        }
        return _elapsedBefore;
    }

    public function getActiveMs() as Number {
        var active = getElapsedMs() - getRestElapsedMs();
        if (active < 0) {
            active = 0;
        }
        return active;
    }

    public function getHeartRate() as Number {
        return _heartRate;
    }

    public function isHeartRateEnabled() as Boolean {
        if (_settings != null) {
            return _settings.heartRateEnabled;
        }
        return true;
    }

    public function getAverageHeartRate() as Number {
        if (_hrCount == 0) {
            return 0;
        }
        return (_hrSum.toFloat() / _hrCount.toFloat()).toNumber();
    }

    public function getMaxHeartRate() as Number {
        return _hrMax;
    }

    public function getMinHeartRate() as Number {
        return _hrMin;
    }

    public function getCalories() as Number {
        var weight = 70;
        if (_settings != null) {
            weight = _settings.weightKg;
        }
        var active = getActiveMs();
        if (active <= 0) {
            return 0;
        }

        // Use the compendium ranges only as an estimate. The activity is still
        // an estimate, but it now follows the actual jump rate and excludes rest.
        var met = AppConstants.CALORIE_MET;
        var cadence = getAverageCadence();
        if (cadence > 0) {
            if (cadence < 100) {
                met = AppConstants.CALORIE_MET_LOW;
            } else if (cadence <= 120) {
                met = AppConstants.CALORIE_MET_MID;
            } else {
                met = AppConstants.CALORIE_MET_HIGH;
            }
        }

        var hours = active.toFloat() / 3600000.0f;
        var kcal = met * weight.toFloat() * hours;
        return kcal.toNumber();
    }

    public function getTarget() as Number {
        if (_settings == null) {
            return 0;
        }
        return _settings.target;
    }

    public function getTargetProgress() as Float {
        var target = getTarget();
        if (target <= 0) {
            return 0.0f;
        }
        var progress = getJumpCount().toFloat() / target.toFloat();
        if (progress > 1.0f) {
            progress = 1.0f;
        }
        if (progress < 0.0f) {
            progress = 0.0f;
        }
        return progress;
    }

    public function isTargetReached() as Boolean {
        return _targetReached;
    }

    public function isTargetFlashing() as Boolean {
        return _targetFlashUntil > 0 && System.getTimer() < _targetFlashUntil;
    }

    public function getSampleRate() as Number {
        return _sampleRate;
    }

    public function getPreviousBestTotal() as Number {
        return _previousBestTotal;
    }

    public function getPreviousBestStreak() as Number {
        return _previousBestStreak;
    }

    public function isNewBestTotal() as Boolean {
        return getJumpCount() > 0 && getJumpCount() > _previousBestTotal;
    }

    public function isNewBestStreak() as Boolean {
        return getBestStreak() > 0 && getBestStreak() > _previousBestStreak;
    }

    public function getCountdownRemaining() as Number {
        if (_state != AppConstants.STATE_COUNTDOWN) {
            return 0;
        }
        var remaining = ((_countdownEndsAt - System.getTimer() + 999) / 1000).toNumber();
        if (remaining < 0) {
            remaining = 0;
        }
        return remaining;
    }

    public function getSensorError() as String? {
        return _sensorError;
    }

    public function applySettings() as Void {
        var detector = _detector;
        var settings = _settings;
        if (detector != null && settings != null) {
            detector.setThreshold(settings.getThreshold());
            if (settings.target == 0 || getJumpCount() < settings.target) {
                _targetReached = false;
            } else {
                _targetReached = true;
            }
            if (settings.vibeEvery > 0) {
                _nextMilestone = ((getJumpCount() / settings.vibeEvery) + 1) * settings.vibeEvery;
            } else {
                _nextMilestone = 0;
            }
        }
    }

    public function getSettings() as Settings? {
        return _settings;
    }

    public function getDetector() as JumpDetector? {
        return _detector;
    }

    public function isSavingActivity() as Boolean {
        return _saveActivity;
    }

    public function isSaved() as Boolean {
        return _saved;
    }

    public function isFallbackSport() as Boolean {
        if (_recorder == null) {
            return false;
        }
        return _recorder.isFallbackSport();
    }

    public function onActive() as Void {
        if (_state == AppConstants.STATE_COUNTDOWN) {
            WatchUi.requestUpdate();
            return;
        }
        if (_state == AppConstants.STATE_RUNNING) {
            if (_inRest) {
                _setArmed = false;
                _shakeIgnoreUntil = System.getTimer() + AppConstants.SHAKE_BLANK_MS;
                if (_shakeDetector != null) {
                    _shakeDetector.reset();
                }
            } else {
                _lastJumpTime = System.getTimer();
                if (_detector != null) {
                    if (_setArmed) {
                        _detector.rebase();
                    } else {
                        _detector.resetFilters();
                    }
                }
            }
        }
        WatchUi.requestUpdate();
    }

    public function onInactive() as Void {
        // Sensor listeners are re-enabled automatically by the system.
    }

    private function _beginRunning() as Void {
        _state = AppConstants.STATE_RUNNING;
        _startedAt = System.getTimer();
        _elapsedBefore = 0;

        if (_saveActivity) {
            _recorder = new FitRecorder();
            if (!_recorder.start()) {
                _recorder = null;
                _saveActivity = false;
                _sensorError = "FIT ERR";
            }
        } else {
            _recorder = null;
        }

        _startSensors();
        WatchUi.requestUpdate();
    }

    private function _tickCountdown() as Void {
        var now = System.getTimer();
        var remaining = ((_countdownEndsAt - now + 999) / 1000).toNumber();
        if (remaining < 0) {
            remaining = 0;
        }
        if (remaining != _countdownLast) {
            if (remaining > 0) {
                _vibrate(70);
            }
            _countdownLast = remaining;
        }
        if (now >= _countdownEndsAt) {
            _countdownEndsAt = 0;
            _beginRunning();
        }
    }

    private function _getAccelSampleRate() as Number {
        var rate = AppConstants.SAMPLE_RATE;
        try {
            var maxRate = Sensor.getMaxSampleRateForSensorType(:accelerometer);
            if (maxRate > 0 && maxRate < rate) {
                rate = maxRate;
            }
        } catch (e) {
            System.println("Sample rate query failed: " + e.getErrorMessage());
        }
        return rate;
    }

    private function _startSensors() as Void {
        if (_sensorsOn) {
            return;
        }

        try {
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
            _sensorError = "SENSOR ERR";
            System.println("Accelerometer failed: " + e.getErrorMessage());
        }

        var settings = _settings;
        if (settings != null && settings.heartRateEnabled) {
            try {
                Sensor.enableSensorType(Sensor.SENSOR_ONBOARD_HEARTRATE);
                Sensor.enableSensorEvents(method(:onSensorInfo));
                _sensorsOn = true;
            } catch (e) {
                System.println("Heart rate failed: " + e.getErrorMessage());
            }
        }
    }

    private function _stopSensors() as Void {
        if (!_sensorsOn) {
            return;
        }
        try {
            Sensor.unregisterSensorDataListener();
        } catch (e) {
            System.println("Accelerometer stop failed: " + e.getErrorMessage());
        }
        try {
            Sensor.enableSensorEvents(null);
        } catch (e) {
            System.println("HR events stop failed: " + e.getErrorMessage());
        }
        try {
            Sensor.disableSensorType(Sensor.SENSOR_ONBOARD_HEARTRATE);
        } catch (e) {
            System.println("HR stop failed: " + e.getErrorMessage());
        }
        _sensorsOn = false;
    }

    private function _updateHeartRate(hr as Number) as Void {
        var settings = _settings;
        if (settings == null || !settings.heartRateEnabled) {
            return;
        }
        if (hr <= 0 || hr > 240) {
            return;
        }
        _heartRate = hr;
        if (_hrCount == 0 || hr < _hrMin) {
            _hrMin = hr;
        }
        if (hr > _hrMax) {
            _hrMax = hr;
        }
        _hrSum += hr;
        _hrCount++;
    }

    private function _updateCadenceTrend(cadence as Number) as Void {
        if (cadence == _lastTrendCadence) {
            return;
        }
        if (cadence > _lastTrendCadence + 2) {
            _cadenceTrend = 1;
        } else if (cadence + 2 < _lastTrendCadence) {
            _cadenceTrend = -1;
        } else {
            _cadenceTrend = 0;
        }
        _lastTrendCadence = cadence;
    }

    private function _getRestDelayMs() as Number {
        if (_settings != null && _settings.restDelayMs > 0) {
            return _settings.restDelayMs;
        }
        return AppConstants.REST_TIMEOUT_MS;
    }

    private function _checkRestTimeout() as Void {
        if (_inRest || _sets == 0 || _lastJumpTime <= 0) {
            return;
        }

        var now = System.getTimer();
        if ((now - _lastJumpTime) < _getRestDelayMs()) {
            return;
        }

        _enterRest(now, true);
    }

    private function _enterRest(now as Number, vibrate as Boolean) as Void {
        if (_inRest) {
            return;
        }

        _finalizeCurrentSet(now);
        _inRest = true;
        _setArmed = false;
        _restBaseMs = _restTotalMs;
        _restStartedAt = now;
        _restCount++;
        _shakeIgnoreUntil = now + AppConstants.SHAKE_BLANK_MS;
        if (_shakeDetector != null) {
            _shakeDetector.reset();
        }
        if (vibrate) {
            _vibrateRestStart();
        }
        WatchUi.requestUpdate();
    }

    private function _endRest(now as Number) as Void {
        if (_restStartedAt > 0) {
            _restTotalMs += now - _restStartedAt;
            _restStartedAt = 0;
        }
    }

    private function _finalizeCurrentSet(now as Number) as Void {
        if (_sets == 0 || _setStartedAt <= 0) {
            return;
        }
        var count = getJumpCount() - _setStartCount;
        if (count > 0) {
            var duration = now - _setStartedAt;
            if (duration < 0) {
                duration = 0;
            }
            _setCounts.add(count);
            _setDurations.add(duration);
            _lastSetCount = count;
            _lastSetDurationMs = duration;
        }
        _setStartedAt = 0;
    }

    private function _onJumpDetected(count as Number, firstNewCount as Number) as Void {
        var now = System.getTimer();
        if (_sets == 0) {
            _sets = 1;
            _setArmed = false;
            // A sensor batch can contain more than one jump. Anchor the set
            // before the whole batch so every detected jump is included.
            _setStartCount = firstNewCount;
            _setStartedAt = now;
        } else if (_setArmed) {
            _setArmed = false;
            _sets++;
            _setStartCount = firstNewCount;
            _setStartedAt = now;
            _vibrate(120);
        }

        _lastJumpTime = now;
        _handleJumps(count);
        var cadence = getCadence();
        if (cadence > _peakCadence) {
            _peakCadence = cadence;
        }
        _updateCadenceTrend(cadence);
        _updateRecorderRecord();
        WatchUi.requestUpdate();
    }

    private function _handleJumps(count as Number) as Void {
        var settings = _settings;
        if (settings == null) {
            return;
        }

        if (settings.vibeEvery > 0 && count >= _nextMilestone) {
            // Milestones are deliberately longer than the short transition taps.
            _vibrate(350);
            _nextMilestone = ((count / settings.vibeEvery) + 1) * settings.vibeEvery;
        }

        if (!_targetReached && settings.target > 0 && count >= settings.target) {
            _targetReached = true;
            _targetFlashUntil = System.getTimer() + AppConstants.TARGET_FLASH_MS;
            _vibrateTarget();
        }
    }

    private function _updateRecorderRecord() as Void {
        var recorder = _recorder;
        if (recorder == null) {
            return;
        }
        recorder.updateRecord(getCadence());
    }

    private function _recordBest() as Void {
        var settings = _settings;
        if (settings != null) {
            settings.recordBest(getJumpCount(), getBestStreak());
        }
    }

    private function _vibrate(durationMs as Number) as Void {
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(75, durationMs)]);
        }
    }

    private function _vibrateRestStart() as Void {
        if (Attention has :vibrate) {
            Attention.vibrate([
                new Attention.VibeProfile(75, 80),
                new Attention.VibeProfile(0, 120),
                new Attention.VibeProfile(75, 80)
            ]);
        }
    }

    private function _vibrateTarget() as Void {
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
