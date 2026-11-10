import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

module DiscardMenu {
    public function create() as WatchUi.Menu2 {
        var menu = new WatchUi.Menu2({:title => "Discard workout?"});
        menu.addItem(new WatchUi.MenuItem("Discard", null, :discard, null));
        menu.addItem(new WatchUi.MenuItem("Cancel", null, :cancel, null));
        return menu;
    }
}

class SummaryView extends WatchUi.View {
    private var _page as Number = 0;
    private var _historyOffset as Number = 0;
    private var _saving as Boolean = false;
    private var _error as String? = null;
    private var _logoWhite as BitmapResource?;
    private var _logoBlack as BitmapResource?;

    public function initialize() {
        View.initialize();
        _logoWhite = WatchUi.loadResource(Rez.Drawables.JumpRopeGlyphWhite) as BitmapResource;
        _logoBlack = WatchUi.loadResource(Rez.Drawables.JumpRopeGlyphBlack) as BitmapResource;
    }

    public function onShow() as Void {
        WatchUi.requestUpdate();
    }

    public function onUpdate(dc as Dc) as Void {
        var app = Application.getApp() as JumpRopeApp;
        var session = app.getSession();
        var settings = app.getSettings();
        var dark = settings.darkMode;

        JumpUi.applyTheme(dc, dark);

        var w = dc.getWidth();
        var center = w / 2;

        var titleFont = Graphics.FONT_XTINY;
        var rowFont = Graphics.FONT_XTINY;
        var titleHeight = dc.getFontHeight(titleFont);
        var rowHeight = dc.getFontHeight(rowFont);

        var title = "SUMMARY";
        if (_page == 1) {
            title = "DETAILS";
        } else if (_page == 2) {
            title = "HISTORY";
        }
        dc.drawText(64, 8, titleFont, title, Graphics.TEXT_JUSTIFY_CENTER);
        var badgeGlyph = dark ? _logoBlack : _logoWhite;
        JumpUi.drawBadge(dc, dark, false, 0.0f, badgeGlyph);

        if (_page == 0) {
            var countText = session.getJumpCount().toString();
            var countFont = Graphics.FONT_NUMBER_MILD;
            var countMaxWidth = 92;
            if (dc.getTextWidthInPixels(countText, countFont) > countMaxWidth) {
                countFont = Graphics.FONT_LARGE;
            }
            if (dc.getTextWidthInPixels(countText, countFont) > countMaxWidth) {
                countFont = Graphics.FONT_SMALL;
            }
            var countHeight = dc.getFontHeight(countFont);
            var countY = 8 + titleHeight + 2;
            var countCenter = 64;
            dc.drawText(countCenter, countY, countFont, countText, Graphics.TEXT_JUSTIFY_CENTER);

            var separatorY = countY + countHeight + 2;
            dc.drawLine(countCenter - 35, separatorY, countCenter + 35, separatorY);

            var rowStart = separatorY + 6;
            if (rowStart < 60) {
                rowStart = 60;
            }

            var timeText = _formatTime(session.getElapsedMs());
            var kcalText = session.getCalories().toString();
            var leftText = "TIME " + timeText;
            var rightText = "KCAL " + kcalText;
            // Use a tighter but still even margin so both labels fit at the
            // same inset on the 166 px screen. Fall back only if needed.
            var rowInset = 6;
            var rowMax = w - (2 * rowInset);
            if ((dc.getTextWidthInPixels(leftText, rowFont) +
                 dc.getTextWidthInPixels(rightText, rowFont) + 4) > rowMax) {
                rightText = "K " + kcalText;
            }
            if ((dc.getTextWidthInPixels(leftText, rowFont) +
                 dc.getTextWidthInPixels(rightText, rowFont) + 4) > rowMax) {
                leftText = timeText;
                rightText = kcalText;
            }
            dc.drawText(rowInset, rowStart, rowFont, leftText, Graphics.TEXT_JUSTIFY_LEFT);
            dc.drawText(w - rowInset, rowStart, rowFont, rightText, Graphics.TEXT_JUSTIFY_RIGHT);

            _row(dc, rowStart + rowHeight, "BEST STREAK", session.getBestStreak().toString(), rowInset);
            _row(dc, rowStart + (2 * rowHeight), "AVG JPM", session.getAverageCadence().toString(), rowInset);

            if (_error == null && (session.isNewBestTotal() || session.isNewBestStreak())) {
                var bestText = "NEW BEST";
                if (session.isNewBestTotal() && !session.isNewBestStreak()) {
                    bestText = "NEW BEST TOTAL";
                } else if (!session.isNewBestTotal() && session.isNewBestStreak()) {
                    bestText = "NEW BEST STREAK";
                }
                dc.drawText(center, rowStart + (3 * rowHeight), rowFont,
                    bestText, Graphics.TEXT_JUSTIFY_CENTER);
            }
        } else if (_page == 1) {
            var rowStart = 56;
            var rowStep = rowHeight + 2;
            var inset = 16;
            var maxRowWidth = w - (2 * inset);

            var hrText = _zeroDash(session.getAverageHeartRate()) + "/" + _zeroDash(session.getMaxHeartRate());
            var hrLabel = "HR AVG/MAX";
            if ((dc.getTextWidthInPixels(hrLabel, rowFont) + dc.getTextWidthInPixels(hrText, rowFont) + 8) > maxRowWidth) {
                hrLabel = "AVG/MAX";
            }
            if ((dc.getTextWidthInPixels(hrLabel, rowFont) + dc.getTextWidthInPixels(hrText, rowFont) + 8) > maxRowWidth) {
                hrLabel = "HR";
            }
            _row(dc, rowStart, hrLabel, hrText, inset);
            _row(dc, rowStart + rowStep, "PEAK JPM", session.getPeakCadence().toString(), inset);
            _row(dc, rowStart + (2 * rowStep), "SETS", session.getSets().toString(), inset);

            var target = session.getTarget();
            var targetText = "OFF";
            if (target > 0) {
                targetText = target.toString();
            }
            _row(dc, rowStart + (3 * rowStep), "TARGET", targetText, inset);
        } else {
            var bestLine = "BEST " + settings.bestTotal.toString() + "  STREAK " + settings.bestStreak.toString();
            if (dc.getTextWidthInPixels(bestLine, rowFont) > (w - 32)) {
                bestLine = "BEST " + settings.bestTotal.toString();
            }
            dc.drawText(center, 52, rowFont, bestLine, Graphics.TEXT_JUSTIFY_CENTER);

            dc.drawText(16, 76, rowFont, "SET", Graphics.TEXT_JUSTIFY_LEFT);
            dc.drawText(82, 76, rowFont, "JUMPS", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(w - 16, 76, rowFont, "TIME", Graphics.TEXT_JUSTIFY_RIGHT);

            var setCount = session.getSetCount();
            var rowStart = 100;
            var visibleRows = 2;
            if (_historyOffset > setCount) {
                _historyOffset = 0;
            }

            if (setCount == 0) {
                dc.drawText(center, rowStart, rowFont, "NO SETS YET", Graphics.TEXT_JUSTIFY_CENTER);
            } else {
                for (var i = 0; i < visibleRows; i++) {
                    var index = _historyOffset + i;
                    if (index >= setCount) {
                        break;
                    }
                    var y = rowStart + (i * rowHeight);
                    dc.drawText(16, y, rowFont, "SET " + (index + 1).toString(), Graphics.TEXT_JUSTIFY_LEFT);
                    dc.drawText(82, y, rowFont, session.getSetJumps(index).toString(), Graphics.TEXT_JUSTIFY_CENTER);
                    dc.drawText(w - 16, y, rowFont, _formatTime(session.getSetDurationMs(index)), Graphics.TEXT_JUSTIFY_RIGHT);
                }
            }
        }

        if (_error != null) {
            dc.drawText(center, 146, rowFont, _error as String, Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            var dotsY = _page == 0 ? 156 : 150;
            _drawPageDots(dc, center, dotsY);
        }
    }

    public function saveAndClose() as Void {
        if (_saving) {
            return;
        }
        _saving = true;
        _error = null;

        var app = Application.getApp() as JumpRopeApp;
        if (!app.saveWorkout()) {
            _saving = false;
            _error = "SAVE FAILED";
            WatchUi.requestUpdate();
            return;
        }

        WatchUi.popView(WatchUi.SLIDE_DOWN);
        app.resetWorkout();
        _saving = false;
    }

    public function nextPage() as Void {
        if (_page == 2) {
            var app = Application.getApp() as JumpRopeApp;
            var session = app.getSession();
            if ((_historyOffset + 2) < session.getSetCount()) {
                _historyOffset++;
                WatchUi.requestUpdate();
                return;
            }
        }
        _page = (_page + 1) % 3;
        if (_page == 2) {
            _historyOffset = 0;
        }
        WatchUi.requestUpdate();
    }

    public function previousPage() as Void {
        if (_page == 2 && _historyOffset > 0) {
            _historyOffset--;
            WatchUi.requestUpdate();
            return;
        }
        _page = (_page + 2) % 3;
        if (_page == 2) {
            _historyOffset = 0;
        }
        WatchUi.requestUpdate();
    }

    private function _drawPageDots(dc as Dc, center as Number, y as Number) as Void {
        var positions = [center - 10, center, center + 10] as Array<Number>;
        for (var i = 0; i < positions.size(); i++) {
            dc.drawCircle(positions[i], y, 2);
            if (i == _page) {
                dc.fillCircle(positions[i], y, 2);
            }
        }
    }

    private function _row(dc as Dc, y as Number, label as String, value as String, inset as Number) as Void {
        dc.drawText(inset, y, Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(dc.getWidth() - inset, y, Graphics.FONT_XTINY, value, Graphics.TEXT_JUSTIFY_RIGHT);
    }

    private function _zeroDash(value as Number) as String {
        if (value <= 0) {
            return "--";
        }
        return value.toString();
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

class SummaryDelegate extends WatchUi.BehaviorDelegate {
    private var _view as SummaryView;

    public function initialize(view as SummaryView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    public function onSelect() as Boolean {
        _view.saveAndClose();
        return true;
    }

    public function onBack() as Boolean {
        _view.saveAndClose();
        return true;
    }

    public function onNextPage() as Boolean {
        _view.nextPage();
        return true;
    }

    public function onPreviousPage() as Boolean {
        _view.previousPage();
        return true;
    }

    public function onMenu() as Boolean {
        var menu = DiscardMenu.create();
        WatchUi.pushView(menu, new DiscardMenuDelegate(), WatchUi.SLIDE_UP);
        return true;
    }
}

class DiscardMenuDelegate extends WatchUi.Menu2InputDelegate {
    public function initialize() {
        Menu2InputDelegate.initialize();
    }

    public function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :discard) {
            var app = Application.getApp() as JumpRopeApp;
            app.discardWorkout();
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        } else {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        }
    }

    public function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
