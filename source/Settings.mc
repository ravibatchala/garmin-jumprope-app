import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.UserProfile;

class Settings {
    public var sensitivity as Number = 3;
    public var vibeEvery as Number = 100;
    public var heartRateEnabled as Boolean = true;
    public var saveActivity as Boolean = true;
    public var weightKg as Number = 70;
    public var target as Number = 0;
    public var restDelayMs as Number = 6000;
    public var bigNumberCurrent as Boolean = false;
    public var countdownSeconds as Number = 0;
    public var customThreshold as Number = 0;
    public var bestTotal as Number = 0;
    public var bestStreak as Number = 0;
    public var darkMode as Boolean = false;

    public function initialize() {
        load();
    }

    public function load() as Void {
        sensitivity = _readNumber(AppConstants.STORAGE_SENSITIVITY, 3);
        if (sensitivity < 1 || sensitivity > 5) {
            sensitivity = 3;
        }

        vibeEvery = _readNumber(AppConstants.STORAGE_VIBE_EVERY, 100);
        if (!_isVibeValue(vibeEvery)) {
            vibeEvery = 100;
        }

        heartRateEnabled = _readBool(AppConstants.STORAGE_HEART_RATE, true);
        saveActivity = _readBool(AppConstants.STORAGE_SAVE_ACTIVITY, true);

        weightKg = _readNumber(AppConstants.STORAGE_WEIGHT, _profileWeightKg());
        if (weightKg < AppConstants.WEIGHT_MIN_KG || weightKg > AppConstants.WEIGHT_MAX_KG) {
            weightKg = 70;
        }

        target = _readNumber(AppConstants.STORAGE_TARGET, 0);
        if (!_isTargetValue(target)) {
            target = 0;
        }

        restDelayMs = _readNumber(AppConstants.STORAGE_REST_DELAY, 6000);
        if (!_isRestDelayValue(restDelayMs)) {
            restDelayMs = 6000;
        }

        bigNumberCurrent = _readBool(AppConstants.STORAGE_BIG_NUMBER, false);
        countdownSeconds = _readNumber(AppConstants.STORAGE_COUNTDOWN, 0);
        if (!_isCountdownValue(countdownSeconds)) {
            countdownSeconds = 0;
        }

        customThreshold = _readNumber(AppConstants.STORAGE_CUSTOM_THRESHOLD, 0);
        if (customThreshold < 80 || customThreshold > 400) {
            customThreshold = 0;
        }

        bestTotal = _readNumber(AppConstants.STORAGE_BEST_TOTAL, 0);
        if (bestTotal < 0) {
            bestTotal = 0;
        }
        bestStreak = _readNumber(AppConstants.STORAGE_BEST_STREAK, 0);
        if (bestStreak < 0) {
            bestStreak = 0;
        }

        darkMode = _readBool(AppConstants.STORAGE_THEME, false);
    }

    public function save() as Void {
        Application.Storage.setValue(AppConstants.STORAGE_SENSITIVITY, sensitivity);
        Application.Storage.setValue(AppConstants.STORAGE_VIBE_EVERY, vibeEvery);
        Application.Storage.setValue(AppConstants.STORAGE_HEART_RATE, heartRateEnabled);
        Application.Storage.setValue(AppConstants.STORAGE_SAVE_ACTIVITY, saveActivity);
        Application.Storage.setValue(AppConstants.STORAGE_WEIGHT, weightKg);
        Application.Storage.setValue(AppConstants.STORAGE_TARGET, target);
        Application.Storage.setValue(AppConstants.STORAGE_REST_DELAY, restDelayMs);
        Application.Storage.setValue(AppConstants.STORAGE_BIG_NUMBER, bigNumberCurrent);
        Application.Storage.setValue(AppConstants.STORAGE_COUNTDOWN, countdownSeconds);
        Application.Storage.setValue(AppConstants.STORAGE_CUSTOM_THRESHOLD, customThreshold);
        Application.Storage.setValue(AppConstants.STORAGE_BEST_TOTAL, bestTotal);
        Application.Storage.setValue(AppConstants.STORAGE_BEST_STREAK, bestStreak);
        Application.Storage.setValue(AppConstants.STORAGE_THEME, darkMode);
    }

    public function cycleSensitivity() as Void {
        sensitivity++;
        if (sensitivity > 5) {
            sensitivity = 1;
        }
        // A manual sensitivity choice replaces the previous auto-calibration.
        customThreshold = 0;
        save();
    }

    public function cycleVibeEvery() as Void {
        var values = [0, 50, 100, 200, 500] as Array<Number>;
        var index = values.indexOf(vibeEvery);
        if (index < 0) {
            index = 2;
        } else {
            index = (index + 1) % values.size();
        }
        vibeEvery = values[index];
        save();
    }

    public function toggleHeartRate() as Void {
        heartRateEnabled = !heartRateEnabled;
        save();
    }

    public function toggleSaveActivity() as Void {
        saveActivity = !saveActivity;
        save();
    }

    public function getTargetValues() as Array<Number> {
        return [
            0, 50, 100, 200, 300, 500, 750, 1000,
            1500, 2000, 2500, 3000, 4000, 5000, 7500, 10000
        ] as Array<Number>;
    }

    public function cycleRestDelay() as Void {
        var values = [3000, 6000, 10000, 15000] as Array<Number>;
        var index = values.indexOf(restDelayMs);
        if (index < 0) {
            index = 1;
        } else {
            index = (index + 1) % values.size();
        }
        restDelayMs = values[index];
        save();
    }

    public function toggleBigNumber() as Void {
        bigNumberCurrent = !bigNumberCurrent;
        save();
    }

    public function toggleTheme() as Void {
        darkMode = !darkMode;
        save();
    }

    public function cycleCountdown() as Void {
        var values = [0, 3, 5] as Array<Number>;
        var index = values.indexOf(countdownSeconds);
        if (index < 0) {
            index = 0;
        } else {
            index = (index + 1) % values.size();
        }
        countdownSeconds = values[index];
        save();
    }

    public function setCustomThreshold(value as Number) as Void {
        if (value < 80) {
            value = 80;
        }
        if (value > 400) {
            value = 400;
        }
        customThreshold = value;
        save();
    }

    public function clearCustomThreshold() as Void {
        customThreshold = 0;
        save();
    }

    public function recordBest(total as Number, streak as Number) as Boolean {
        var improved = false;
        if (total > bestTotal) {
            bestTotal = total;
            improved = true;
        }
        if (streak > bestStreak) {
            bestStreak = streak;
            improved = true;
        }
        if (improved) {
            save();
        }
        return improved;
    }

    public function getThreshold() as Float {
        if (customThreshold > 0) {
            return customThreshold.toFloat();
        }
        // Higher sensitivity means a lower detection threshold.
        return (300 - (sensitivity * 34)).toFloat();
    }

    public function getSensitivityLabel() as String {
        if (sensitivity == 1) {
            return "1 - low";
        } else if (sensitivity == 2) {
            return "2";
        } else if (sensitivity == 3) {
            return "3 - medium";
        } else if (sensitivity == 4) {
            return "4";
        }
        return "5 - high";
    }

    public function getVibeLabel() as String {
        if (vibeEvery == 0) {
            return "off";
        }
        return vibeEvery.toString() + " jumps";
    }

    public function getHeartRateLabel() as String {
        if (heartRateEnabled) {
            return "on";
        }
        return "off";
    }

    public function getSaveLabel() as String {
        if (saveActivity) {
            return "on";
        }
        return "off";
    }

    public function getWeightLabel() as String {
        return weightKg.toString() + " kg";
    }

    public function getTargetLabel() as String {
        if (target == 0) {
            return "off";
        }
        return target.toString() + " jumps";
    }

    public function getRestDelayLabel() as String {
        return (restDelayMs / 1000).toString() + " s";
    }

    public function getBigNumberLabel() as String {
        if (bigNumberCurrent) {
            return "current set";
        }
        return "total";
    }

    public function getThemeLabel() as String {
        if (darkMode) {
            return "dark";
        }
        return "light";
    }

    public function getCountdownLabel() as String {
        if (countdownSeconds == 0) {
            return "off";
        }
        return countdownSeconds.toString() + " s";
    }

    public function getCalibrationLabel() as String {
        if (customThreshold > 0) {
            return "custom " + customThreshold.toString();
        }
        return "not set";
    }

    private function _readNumber(key as String, defaultValue as Number) as Number {
        var value = Application.Storage.getValue(key);
        if (value instanceof Number) {
            return value as Number;
        }
        return defaultValue;
    }

    private function _readBool(key as String, defaultValue as Boolean) as Boolean {
        var value = Application.Storage.getValue(key);
        if (value instanceof Boolean) {
            return value as Boolean;
        }
        return defaultValue;
    }

    private function _isVibeValue(value as Number) as Boolean {
        return value == 0 || value == 50 || value == 100 || value == 200 || value == 500;
    }

    private function _isTargetValue(value as Number) as Boolean {
        return getTargetValues().indexOf(value) >= 0;
    }

    private function _isRestDelayValue(value as Number) as Boolean {
        return value == 3000 || value == 6000 || value == 10000 || value == 15000;
    }

    private function _isCountdownValue(value as Number) as Boolean {
        return value == 0 || value == 3 || value == 5;
    }

    private function _profileWeightKg() as Number {
        try {
            var profile = UserProfile.getProfile();
            if (profile != null && profile.weight != null) {
                var weight = profile.weight as Number;
                if (weight > 300) {
                    // The profile reports weight in grams.
                    return (weight / 1000).toNumber();
                }
                return weight;
            }
        } catch (e) {
            System.println("Profile weight unavailable: " + e.getErrorMessage());
        }
        return 70;
    }
}
