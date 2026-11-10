import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

module PauseMenu {
    public function create() as WatchUi.Menu2 {
        var menu = new WatchUi.Menu2({:title => "Workout paused"});
        menu.addItem(new WatchUi.MenuItem("Resume", null, :resume, null));
        menu.addItem(new WatchUi.MenuItem("Save & finish", null, :save, null));
        menu.addItem(new WatchUi.MenuItem("Discard", null, :discard, null));
        return menu;
    }
}

class MainDelegate extends WatchUi.BehaviorDelegate {
    public function initialize() {
        BehaviorDelegate.initialize();
    }

    public function onSelect() as Boolean {
        var app = Application.getApp() as JumpRopeApp;
        var session = app.getSession();

        if (session.isIdle()) {
            app.startWorkout();
        } else if (session.isRunning()) {
            if (session.isResting()) {
                session.armNewSet();
            } else {
                app.pauseWorkout();
            }
        } else if (session.isPaused()) {
            app.resumeWorkout();
        }

        WatchUi.requestUpdate();
        return true;
    }

    public function onBack() as Boolean {
        var app = Application.getApp() as JumpRopeApp;
        var session = app.getSession();

        if (session.isCountdown()) {
            session.cancelCountdown();
            WatchUi.requestUpdate();
            return true;
        }

        if (session.isRunning() || session.isPaused()) {
            // A wrist bump must not end the workout. Pause first and require a
            // deliberate menu choice to save or discard.
            app.pauseWorkout();
            _openPauseMenu();
            return true;
        }

        if (session.isStopped()) {
            _openSummary();
            return true;
        }

        return false;
    }

    public function onMenu() as Boolean {
        return _openMenu();
    }

    public function onPreviousPage() as Boolean {
        // On Instinct E the UP/MENU button opens the menu with a hold, but a
        // normal press is a page-up event. Treat it as the options shortcut too.
        return _openMenu();
    }

    public function onNextPage() as Boolean {
        // DOWN arms the next set while resting. It is ignored otherwise so it
        // cannot interfere with the normal main-screen behavior.
        var app = Application.getApp() as JumpRopeApp;
        var session = app.getSession();
        if (session.isRunning() && session.isResting()) {
            session.armNewSet();
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }

    private function _openMenu() as Boolean {
        var app = Application.getApp() as JumpRopeApp;
        var session = app.getSession();
        var menu = new WatchUi.Menu2({:title => "Jump Rope"});

        if (session.isIdle()) {
            menu.addItem(new WatchUi.MenuItem("Start workout", null, :start, null));
        } else if (session.isRunning()) {
            if (session.isResting()) {
                menu.addItem(new WatchUi.MenuItem("Start new set", null, :newset, null));
            }
            menu.addItem(new WatchUi.MenuItem("Pause", null, :pause, null));
            menu.addItem(new WatchUi.MenuItem("Stop workout", null, :stop, null));
        } else if (session.isPaused()) {
            menu.addItem(new WatchUi.MenuItem("Resume", null, :resume, null));
            menu.addItem(new WatchUi.MenuItem("Stop workout", null, :stop, null));
        }

        menu.addItem(new WatchUi.MenuItem("Settings", null, :settings, null));
        menu.addItem(new WatchUi.MenuItem("Diagnostics", null, :diagnostics, null));

        WatchUi.pushView(menu, new MainMenuDelegate(), WatchUi.SLIDE_UP);
        return true;
    }

    private function _openPauseMenu() as Void {
        var menu = PauseMenu.create();
        WatchUi.pushView(menu, new PauseMenuDelegate(), WatchUi.SLIDE_UP);
    }

    private function _openSummary() as Void {
        var view = new SummaryView();
        WatchUi.pushView(view, new SummaryDelegate(view), WatchUi.SLIDE_UP);
    }
}

class PauseMenuDelegate extends WatchUi.Menu2InputDelegate {
    public function initialize() {
        Menu2InputDelegate.initialize();
    }

    public function onSelect(item as WatchUi.MenuItem) as Void {
        var app = Application.getApp() as JumpRopeApp;
        var id = item.getId();

        if (id == :resume) {
            app.resumeWorkout();
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        } else if (id == :save) {
            app.stopWorkout();
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            var summary = new SummaryView();
            WatchUi.pushView(summary, new SummaryDelegate(summary), WatchUi.SLIDE_UP);
        } else if (id == :discard) {
            app.discardWorkout();
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        }
    }

    public function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}

class MainMenuDelegate extends WatchUi.Menu2InputDelegate {
    public function initialize() {
        Menu2InputDelegate.initialize();
    }

    public function onSelect(item as WatchUi.MenuItem) as Void {
        var app = Application.getApp() as JumpRopeApp;
        var id = item.getId();

        if (id == :start) {
            app.startWorkout();
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        } else if (id == :newset) {
            app.getSession().armNewSet();
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        } else if (id == :pause) {
            app.pauseWorkout();
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        } else if (id == :resume) {
            app.resumeWorkout();
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        } else if (id == :stop) {
            app.stopWorkout();
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            var summary = new SummaryView();
            WatchUi.pushView(summary, new SummaryDelegate(summary), WatchUi.SLIDE_UP);
        } else if (id == :settings) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            var session = app.getSession();
            var settingsMenu = SettingsMenu.create(app.getSettings(), session.isIdle());
            WatchUi.pushView(settingsMenu, new SettingsMenuDelegate(app.getSettings()), WatchUi.SLIDE_UP);
        } else if (id == :diagnostics) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            WatchUi.pushView(new DiagnosticsView(), new DiagnosticsDelegate(), WatchUi.SLIDE_UP);
        }
    }

    public function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
