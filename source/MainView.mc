import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

class MainView extends WatchUi.View {
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
        var settings = app.getSettings();
        var state = session.getState();

        var dark = settings.darkMode;
        JumpUi.applyTheme(dc, dark);

        var w = dc.getWidth();
        var center = w / 2;

        var inverted = session.isResting() || session.isPaused() || session.isTargetFlashing();
        var glyph = inverted ? (dark ? _logoWhite : _logoBlack) : (dark ? _logoBlack : _logoWhite);
        JumpUi.drawBadge(dc, dark, inverted, session.getTargetProgress(), glyph);
        JumpUi.drawDivider(dc, dark);

        var countText = session.getJumpCount().toString();
        if (state == AppConstants.STATE_COUNTDOWN) {
            countText = session.getCountdownRemaining().toString();
        } else if (settings.bigNumberCurrent && session.getSets() > 0) {
            countText = session.getCurrentSetJumps().toString();
        }

        var countFont = Graphics.FONT_NUMBER_HOT;
        var countMaxWidth = 88;
        if (dc.getTextWidthInPixels(countText, countFont) > countMaxWidth) {
            countFont = Graphics.FONT_NUMBER_MEDIUM;
        }
        if (dc.getTextWidthInPixels(countText, countFont) > countMaxWidth) {
            countFont = Graphics.FONT_NUMBER_MILD;
        }
        if (dc.getTextWidthInPixels(countText, countFont) > countMaxWidth) {
            countFont = Graphics.FONT_LARGE;
        }
        if (dc.getTextWidthInPixels(countText, countFont) > countMaxWidth) {
            countFont = Graphics.FONT_SMALL;
        }
        dc.drawText(JumpUi.COUNT_CENTER, JumpUi.COUNT_Y, countFont, countText, Graphics.TEXT_JUSTIFY_CENTER);

        var timeText = _formatTime(session.getElapsedMs());
        if (state == AppConstants.STATE_COUNTDOWN) {
            timeText = "0:00";
        }
        JumpUi.drawCenterText(dc, JumpUi.COUNT_CENTER, JumpUi.TIME_CENTER_Y, Graphics.FONT_MEDIUM, timeText);

        var hrText = "--";
        if (!settings.heartRateEnabled) {
            hrText = "OFF";
        } else if (session.getHeartRate() > 0) {
            hrText = session.getHeartRate().toString();
        }

        var resting = state == AppConstants.STATE_RUNNING && session.isResting();
        var cadenceLabel = "JPM";
        var cadenceValue = session.getCadence();
        if (resting) {
            cadenceLabel = "SET AVG";
            cadenceValue = session.getLastSetAverageCadence();
        }
        var cadenceText = cadenceValue.toString();
        if (resting && cadenceValue <= 0) {
            cadenceText = "--";
        }
        if (dc.getTextWidthInPixels(cadenceLabel, Graphics.FONT_XTINY) > 46) {
            cadenceLabel = "AVG";
        }

        var kcalText = session.getCalories().toString();
        JumpUi.drawMetric(dc, dark, 0, "HR", hrText);
        JumpUi.drawMetric(dc, dark, 1, cadenceLabel, cadenceText);
        JumpUi.drawMetric(dc, dark, 2, "KCAL", kcalText);

        if (!resting && state == AppConstants.STATE_RUNNING && cadenceValue > 0) {
            var trend = session.getCadenceTrend();
            if (trend != 0) {
                var valueWidth = dc.getTextWidthInPixels(cadenceText, Graphics.FONT_SMALL);
                var valueHeight = dc.getFontHeight(Graphics.FONT_SMALL);
                JumpUi.drawTrend(dc, dark, JumpUi.COL_X[1] + (valueWidth / 2) + 5,
                    JumpUi.VALUE_Y + (valueHeight / 2), trend);
            }
        }

        var error = session.getSensorError();
        if (error != null) {
            dc.drawText(center, JumpUi.STATUS_Y, Graphics.FONT_XTINY,
                _errorText(error as String), Graphics.TEXT_JUSTIFY_CENTER);
        } else if (resting) {
            var setNumber = session.getSets().toString();
            var lastSet = session.getLastSetCount().toString();
            var restLine = "SET " + setNumber + " - " + lastSet;
            var restTimer = "REST " + _formatTime(session.getCurrentRestElapsedMs());
            var hint = session.getRestCount() == 1 ? "SHAKE SIDE 3x  START" : "SHAKE 3x  START";
            var bottom = hint;

            if (settings.bigNumberCurrent) {
                restLine += "  TOT " + session.getJumpCount().toString();
                bottom = restTimer + "  START";
            } else {
                restLine += "  " + restTimer;
            }

            if (dc.getTextWidthInPixels(restLine, Graphics.FONT_XTINY) > (w - 12)) {
                restLine = "SET " + setNumber + " - " + lastSet + "  R " +
                    _formatTime(session.getCurrentRestElapsedMs());
            }
            if (dc.getTextWidthInPixels(bottom, Graphics.FONT_XTINY) > (w - 12)) {
                if (session.getRestCount() == 1) {
                    bottom = "SHAKE 3x  START";
                } else {
                    bottom = "SHAKE/START/DOWN";
                }
            }
            if (dc.getTextWidthInPixels(bottom, Graphics.FONT_XTINY) > (w - 12)) {
                bottom = "START";
            }
            dc.drawText(center, JumpUi.STATUS_Y, Graphics.FONT_XTINY,
                restLine, Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(center, JumpUi.BOTTOM_Y, Graphics.FONT_XTINY,
                bottom, Graphics.TEXT_JUSTIFY_CENTER);
        } else if (session.getTarget() > 0 &&
                   (state == AppConstants.STATE_RUNNING || state == AppConstants.STATE_PAUSED)) {
            var targetText = "TARGET " + session.getJumpCount().toString() + "/" + session.getTarget().toString();
            if (session.isTargetReached()) {
                targetText = "TARGET DONE";
            }
            dc.drawText(center, JumpUi.STATUS_Y, Graphics.FONT_XTINY,
                targetText, Graphics.TEXT_JUSTIFY_CENTER);
        } else if (state != AppConstants.STATE_IDLE && state != AppConstants.STATE_COUNTDOWN) {
            dc.drawText(10, JumpUi.STATUS_Y, Graphics.FONT_XTINY,
                "BEST " + session.getBestStreak().toString(), Graphics.TEXT_JUSTIFY_LEFT);
            dc.drawText(w - 10, JumpUi.STATUS_Y, Graphics.FONT_XTINY,
                "STREAK " + session.getStreak().toString(), Graphics.TEXT_JUSTIFY_RIGHT);
        }

        if (!resting) {
            var stateLine = _stateLine(state, session, settings.bigNumberCurrent);
            if (stateLine.length() > 0) {
                dc.drawText(center, JumpUi.BOTTOM_Y, Graphics.FONT_XTINY,
                    stateLine, Graphics.TEXT_JUSTIFY_CENTER);
            }
        }
    }

    public function onTick() as Void {
        var app = Application.getApp() as JumpRopeApp;
        app.getSession().tick();
        WatchUi.requestUpdate();
    }

    private function _stateLine(state as Number, session as SessionManager, bigCurrent as Boolean) as String {
        var sets = session.getSets();
        if (state == AppConstants.STATE_COUNTDOWN) {
            return "GET READY";
        } else if (state == AppConstants.STATE_RUNNING) {
            if (session.isSetArmed()) {
                return "SET " + (sets + 1).toString() + " READY";
            }
            if (sets == 0) {
                return "JUMP TO START";
            }
            if (bigCurrent) {
                return "TOTAL " + session.getJumpCount().toString();
            }
            return "SET " + sets.toString();
        } else if (state == AppConstants.STATE_PAUSED) {
            if (sets > 0) {
                return "PAUSED  SET " + sets.toString();
            }
            return "PAUSED";
        } else if (state == AppConstants.STATE_STOPPED) {
            return "FINISHED";
        }
        return "PRESS > TO START";
    }

    private function _errorText(error as String) as String {
        if (error.equals("SENSOR ERR")) {
            return "SENSOR ERR - RESTART APP";
        }
        if (error.equals("FIT ERR")) {
            return "FIT ERR - NO SAVE";
        }
        return error;
    }

    private function _formatTime(ms as Number) as String {
        var totalSeconds = ms / 1000;
        var minutes = totalSeconds / 60;
        var seconds = totalSeconds % 60;
        var secondText = seconds.toString();
        if (seconds < 10) {
            secondText = "0" + secondText;
        }
        return minutes.toString() + ":" + secondText;
    }
}
