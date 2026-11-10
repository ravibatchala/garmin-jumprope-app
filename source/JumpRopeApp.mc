import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class JumpRopeApp extends Application.AppBase {
    private var _settings as Settings?;
    private var _session as SessionManager?;

    public function initialize() {
        AppBase.initialize();
    }

    public function onStart(state as Dictionary?) as Void {
        _settings = new Settings();
        _session = new SessionManager();
    }

    public function onStop(state as Dictionary?) as Void {
        if (_session != null) {
            _session.finalizeOnExit();
        }
    }

    public function onActive(state as Dictionary?) as Void {
        if (_session != null) {
            _session.onActive();
        }
    }

    public function onInactive(state as Dictionary?) as Void {
        if (_session != null) {
            _session.onInactive();
        }
    }

    public function getInitialView() as [Views] or [Views, InputDelegates] {
        return [new MainView(), new MainDelegate()];
    }

    public function getSettings() as Settings {
        if (_settings == null) {
            _settings = new Settings();
        }
        return _settings as Settings;
    }

    public function getSession() as SessionManager {
        if (_session == null) {
            _session = new SessionManager();
        }
        return _session as SessionManager;
    }

    public function startWorkout() as Boolean {
        return getSession().start(getSettings());
    }

    public function pauseWorkout() as Void {
        getSession().pause();
    }

    public function resumeWorkout() as Void {
        getSession().resume();
    }

    public function stopWorkout() as Void {
        getSession().stop();
    }

    public function saveWorkout() as Boolean {
        return getSession().save();
    }

    public function discardWorkout() as Void {
        getSession().discard();
        getSession().reset();
    }

    public function resetWorkout() as Void {
        getSession().reset();
    }
}
