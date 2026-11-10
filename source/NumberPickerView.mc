import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Reusable custom picker for settings that need deliberate up/down changes.
// UP/DOWN move one value, SELECT saves, BACK cancels. Native Menu2 has no
// left/right event, so this view gives weight and target two-way adjustment.
class NumberPickerView extends WatchUi.View {
    private var _settings as Settings;
    private var _isWeight as Boolean;
    private var _values as Array<Number>;
    private var _index as Number = 0;
    private var _title as String;
    private var _unit as String;

    public function initialize(settings as Settings, isWeight as Boolean) {
        View.initialize();
        _settings = settings;
        _isWeight = isWeight;

        if (_isWeight) {
            _title = "WEIGHT";
            _unit = "KG";
            _values = new Array<Number>[0];
            var value = AppConstants.WEIGHT_MIN_KG;
            while (value <= AppConstants.WEIGHT_MAX_KG) {
                _values.add(value);
                value += AppConstants.WEIGHT_STEP_KG;
            }
            _index = _values.indexOf(settings.weightKg);
        } else {
            _title = "TARGET";
            _unit = "JUMPS";
            _values = settings.getTargetValues();
            _index = _values.indexOf(settings.target);
        }

        if (_index < 0) {
            _index = 0;
        }
    }

    public function onShow() as Void {
        WatchUi.requestUpdate();
    }

    public function onUpdate(dc as Dc) as Void {
        JumpUi.applyTheme(dc, _settings.darkMode);

        var w = dc.getWidth();
        var center = w / 2;

        dc.drawText(center, 6, Graphics.FONT_XTINY, _title, Graphics.TEXT_JUSTIFY_CENTER);

        var value = _values[_index];
        var valueText = value.toString();
        var unitText = _unit;
        if (!_isWeight && value == 0) {
            valueText = "OFF";
            unitText = "TARGET";
        }

        var valueFont = Graphics.FONT_NUMBER_HOT;
        var maxWidth = w - 24;
        if (dc.getTextWidthInPixels(valueText, valueFont) > maxWidth) {
            valueFont = Graphics.FONT_NUMBER_MEDIUM;
        }
        if (dc.getTextWidthInPixels(valueText, valueFont) > maxWidth) {
            valueFont = Graphics.FONT_NUMBER_MILD;
        }
        if (dc.getTextWidthInPixels(valueText, valueFont) > maxWidth) {
            valueFont = Graphics.FONT_LARGE;
        }
        if (dc.getTextWidthInPixels(valueText, valueFont) > maxWidth) {
            valueFont = Graphics.FONT_SMALL;
        }
        dc.drawText(center, 30, valueFont, valueText, Graphics.TEXT_JUSTIFY_CENTER);

        dc.drawText(center, 82, Graphics.FONT_XTINY, unitText, Graphics.TEXT_JUSTIFY_CENTER);

        var stepHint = _isWeight ? "UP/DOWN 1 KG" : "UP/DOWN PRESET";
        dc.drawText(center, 116, Graphics.FONT_XTINY, stepHint, Graphics.TEXT_JUSTIFY_CENTER);

        var saveHint = "SELECT SAVE  BACK CANCEL";
        if (dc.getTextWidthInPixels(saveHint, Graphics.FONT_XTINY) > (w - 12)) {
            saveHint = "SELECT SAVE";
        }
        dc.drawText(center, 140, Graphics.FONT_XTINY, saveHint, Graphics.TEXT_JUSTIFY_CENTER);
    }

    public function increment() as Void {
        if (_index < (_values.size() - 1)) {
            _index++;
            WatchUi.requestUpdate();
        }
    }

    public function decrement() as Void {
        if (_index > 0) {
            _index--;
            WatchUi.requestUpdate();
        }
    }

    public function save() as Void {
        var value = _values[_index];
        if (_isWeight) {
            _settings.weightKg = value;
        } else {
            _settings.target = value;
        }
        _settings.save();
    }

    public function getMenuLabel() as String {
        if (_isWeight) {
            return _settings.getWeightLabel();
        }
        return _settings.getTargetLabel();
    }
}

class NumberPickerDelegate extends WatchUi.BehaviorDelegate {
    private var _picker as NumberPickerView;
    private var _item as WatchUi.MenuItem?;

    public function initialize(picker as NumberPickerView, item as WatchUi.MenuItem?) {
        BehaviorDelegate.initialize();
        _picker = picker;
        _item = item;
    }

    public function onPreviousPage() as Boolean {
        _picker.decrement();
        return true;
    }

    public function onNextPage() as Boolean {
        _picker.increment();
        return true;
    }

    public function onSelect() as Boolean {
        _picker.save();
        var item = _item;
        if (item != null) {
            item.setSubLabel(_picker.getMenuLabel());
        }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    public function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
