import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

module SettingsMenu {
    public function create(settings as Settings, allowCalibration as Boolean) as WatchUi.Menu2 {
        var menu = new WatchUi.Menu2({:title => "Settings"});
        menu.addItem(new WatchUi.MenuItem("Theme", settings.getThemeLabel(), :theme, null));
        menu.addItem(new WatchUi.MenuItem("Sensitivity", settings.getSensitivityLabel(), :sensitivity, null));
        menu.addItem(new WatchUi.MenuItem("Rest delay", settings.getRestDelayLabel(), :restDelay, null));
        menu.addItem(new WatchUi.MenuItem("Big number", settings.getBigNumberLabel(), :bigNumber, null));
        menu.addItem(new WatchUi.MenuItem("Start countdown", settings.getCountdownLabel(), :countdown, null));
        menu.addItem(new WatchUi.MenuItem("Vibrate every", settings.getVibeLabel(), :vibe, null));
        menu.addItem(new WatchUi.MenuItem("Heart rate", settings.getHeartRateLabel(), :heartRate, null));
        menu.addItem(new WatchUi.MenuItem("Save activity", settings.getSaveLabel(), :saveActivity, null));
        menu.addItem(new WatchUi.MenuItem("Weight", settings.getWeightLabel(), :weight, null));
        menu.addItem(new WatchUi.MenuItem("Target jumps", settings.getTargetLabel(), :target, null));
        if (allowCalibration) {
            menu.addItem(new WatchUi.MenuItem("Calibrate jumps", settings.getCalibrationLabel(), :calibrate, null));
        }
        if (settings.customThreshold > 0) {
            menu.addItem(new WatchUi.MenuItem("Clear calibration", null, :clearCalibration, null));
        }
        return menu;
    }
}

class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _settings as Settings;

    public function initialize(settings as Settings) {
        Menu2InputDelegate.initialize();
        _settings = settings;
    }

    public function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();

        if (id == :theme) {
            _settings.toggleTheme();
            item.setSubLabel(_settings.getThemeLabel());
        } else if (id == :sensitivity) {
            _settings.cycleSensitivity();
            item.setSubLabel(_settings.getSensitivityLabel());
        } else if (id == :restDelay) {
            _settings.cycleRestDelay();
            item.setSubLabel(_settings.getRestDelayLabel());
        } else if (id == :bigNumber) {
            _settings.toggleBigNumber();
            item.setSubLabel(_settings.getBigNumberLabel());
        } else if (id == :countdown) {
            _settings.cycleCountdown();
            item.setSubLabel(_settings.getCountdownLabel());
        } else if (id == :vibe) {
            _settings.cycleVibeEvery();
            item.setSubLabel(_settings.getVibeLabel());
        } else if (id == :heartRate) {
            _settings.toggleHeartRate();
            item.setSubLabel(_settings.getHeartRateLabel());
        } else if (id == :saveActivity) {
            _settings.toggleSaveActivity();
            item.setSubLabel(_settings.getSaveLabel());
        } else if (id == :weight) {
            var weightPicker = new NumberPickerView(_settings, true);
            WatchUi.pushView(weightPicker, new NumberPickerDelegate(weightPicker, item), WatchUi.SLIDE_UP);
        } else if (id == :target) {
            var targetPicker = new NumberPickerView(_settings, false);
            WatchUi.pushView(targetPicker, new NumberPickerDelegate(targetPicker, item), WatchUi.SLIDE_UP);
        } else if (id == :calibrate) {
            WatchUi.pushView(new CalibrationView(_settings), new CalibrationDelegate(), WatchUi.SLIDE_UP);
        } else if (id == :clearCalibration) {
            _settings.clearCustomThreshold();
            item.setSubLabel(_settings.getCalibrationLabel());
        }

        WatchUi.requestUpdate();
    }

    public function onBack() as Void {
        _settings.save();
        var app = Application.getApp() as JumpRopeApp;
        app.getSession().applySettings();
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
