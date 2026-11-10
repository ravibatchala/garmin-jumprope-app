import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

class DiagnosticsView extends WatchUi.View {
    private var _timer as Timer.Timer?;
    private var _logoWhite as BitmapResource?;
    private var _logoBlack as BitmapResource?;

    public function initialize() {
        View.initialize();
        _logoWhite = WatchUi.loadResource(Rez.Drawables.JumpRopeGlyphWhite) as BitmapResource;
        _logoBlack = WatchUi.loadResource(Rez.Drawables.JumpRopeGlyphBlack) as BitmapResource;
    }

    public function onShow() as Void {
        if (_timer == null) {
            _timer = new Timer.Timer();
            _timer.start(method(:onTick), 500, true);
        }
        WatchUi.requestUpdate();
    }

    public function onHide() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    public function onUpdate(dc as Dc) as Void {
        var app = Application.getApp() as JumpRopeApp;
        var session = app.getSession();
        var detector = session.getDetector();
        var dark = app.getSettings().darkMode;

        JumpUi.applyTheme(dc, dark);

        var w = dc.getWidth();
        var center = w / 2;

        // The Instinct E has a top-right circular window. Keep the header in
        // the main area to its left and put the logo inside the window.
        var inverted = session.isResting() || session.isPaused();
        var glyph = inverted ? (dark ? _logoWhite : _logoBlack) : (dark ? _logoBlack : _logoWhite);
        JumpUi.drawBadge(dc, dark, inverted, 0.0f, glyph);
        dc.drawText(32, 8, Graphics.FONT_XTINY, "DIAG", Graphics.TEXT_JUSTIFY_LEFT);

        var error = session.getSensorError();
        var stateText = _stateText(session.getState()) + " " + session.getSampleRate().toString() + "Hz";
        if (error != null) {
            stateText = error as String;
        }
        dc.drawText(32, 30, Graphics.FONT_XTINY, stateText, Graphics.TEXT_JUSTIFY_LEFT);

        if (detector == null) {
            dc.drawText(center, 78, Graphics.FONT_SMALL, "Start workout", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(center, 108, Graphics.FONT_XTINY, "for sensor data", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            _rowPair(dc, 64, "JMP " + detector.getCount().toString(),
                "SIG " + detector.getSignal().toNumber().toString());
            _rowPair(dc, 94, "THR " + detector.getThreshold().toNumber().toString(),
                "RAW " + detector.getMagnitude().toNumber().toString());
            _rowPair(dc, 124, "PEAK " + (detector.isPeaking() ? "Y" : "N"),
                "STRK " + detector.getStreak().toString());
        }
    }

    public function onTick() as Void {
        var app = Application.getApp() as JumpRopeApp;
        app.getSession().tick();
        WatchUi.requestUpdate();
    }

    private function _rowPair(dc as Dc, y as Number, left as String, right as String) as Void {
        // Stay inside the semioctagon corners at the bottom of the screen.
        dc.drawText(24, y, Graphics.FONT_XTINY, left, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(dc.getWidth() - 24, y, Graphics.FONT_XTINY, right, Graphics.TEXT_JUSTIFY_RIGHT);
    }

    private function _stateText(state as Number) as String {
        if (state == AppConstants.STATE_COUNTDOWN) {
            return "COUNT";
        } else if (state == AppConstants.STATE_RUNNING) {
            return "RUN";
        } else if (state == AppConstants.STATE_PAUSED) {
            return "PAUSE";
        } else if (state == AppConstants.STATE_STOPPED) {
            return "STOP";
        }
        return "IDLE";
    }
}

class DiagnosticsDelegate extends WatchUi.BehaviorDelegate {
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
