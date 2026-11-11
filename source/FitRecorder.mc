import Toybox.Activity;
import Toybox.ActivityRecording;
import Toybox.FitContributor;
import Toybox.Lang;
import Toybox.System;

class FitRecorder {
    private var _session as ActivityRecording.Session?;
    private var _jumpField as FitContributor.Field?;
    private var _bestStreakField as FitContributor.Field?;
    private var _avgCadenceField as FitContributor.Field?;
    private var _setsField as FitContributor.Field?;
    private var _avgHrField as FitContributor.Field?;
    private var _maxHrField as FitContributor.Field?;
    private var _recordCadenceField as FitContributor.Field?;
    private var _lapJumpField as FitContributor.Field?;
    private var _active as Boolean = false;
    private var _fallbackSport as Boolean = false;

    public function initialize() {
    }

    public function start() as Boolean {
        var session = _createSession();
        if (session == null) {
            return false;
        }
        var activeSession = session as ActivityRecording.Session;

        _session = activeSession;

        var started = false;
        try {
            started = activeSession.start();
        } catch (e) {
            System.println("FIT start failed: " + e.getErrorMessage());
        }
        if (!started) {
            System.println("FIT session did not start");
            _session = null;
            return false;
        }

        _active = true;
        _createFields();
        return true;
    }

    private function _createSession() as ActivityRecording.Session? {
        // Sport 84 is "jump_rope". It gives the activity the Jump Rope type,
        // icon and badge credit in Garmin Connect. The watch still writes its
        // own total_cycles counter for this sport, which is not a jump count.
        try {
            return ActivityRecording.createSession({
                :name => "Jump Rope",
                :sport => 84 as Activity.Sport,
                :subSport => Activity.SUB_SPORT_GENERIC
            });
        } catch (e) {
            System.println("Jump Rope sport rejected: " + e.getErrorMessage());
        }

        // Fall back to cardio training, then HIIT, if the firmware rejects 84.
        try {
            var cardio = ActivityRecording.createSession({
                :name => "Jump Rope",
                :sport => Activity.SPORT_TRAINING,
                :subSport => Activity.SUB_SPORT_CARDIO_TRAINING
            });
            _fallbackSport = true;
            return cardio;
        } catch (e2) {
            System.println("Cardio session rejected: " + e2.getErrorMessage());
        }

        try {
            var hiit = ActivityRecording.createSession({
                :name => "Jump Rope",
                :sport => Activity.SPORT_HIIT,
                :subSport => Activity.SUB_SPORT_GENERIC
            });
            _fallbackSport = true;
            return hiit;
        } catch (e3) {
            System.println("HIIT session rejected: " + e3.getErrorMessage());
        }
        return null;
    }

    public function pause() as Void {
        var session = _session;
        if (session != null && _active) {
            _active = false;
            try {
                session.stop();
            } catch (e) {
                System.println("FIT pause failed: " + e.getErrorMessage());
            }
        }
    }

    public function resume() as Void {
        var session = _session;
        if (session != null && !_active) {
            try {
                if (session.start()) {
                    _active = true;
                }
            } catch (e) {
                System.println("FIT resume failed: " + e.getErrorMessage());
            }
        }
    }

    public function stop() as Void {
        var session = _session;
        if (session != null && _active) {
            _active = false;
            try {
                session.stop();
            } catch (e) {
                System.println("FIT stop failed: " + e.getErrorMessage());
            }
        }
    }

    public function updateRecord(cadence as Number) as Void {
        _setNumberField(_recordCadenceField, cadence);
    }

    // Close the lap for a finished set. The lap field carries that set's jump
    // count so Connect shows one row per set instead of one total.
    public function addSetLap(jumps as Number) as Void {
        var session = _session;
        if (session == null) {
            return;
        }
        _setNumberField(_lapJumpField, jumps);
        if (_lapJumpField != null) {
            try {
                session.addLap();
            } catch (e) {
                System.println("FIT addLap failed: " + e.getErrorMessage());
            }
        }
        // The system adds a final lap when the session is saved. Clear the
        // value so that last lap does not repeat the set that just closed.
        _setNumberField(_lapJumpField, 0);
    }

    public function finish(jumps as Number, bestStreak as Number, avgCadence as Number, sets as Number, avgHr as Number, maxHr as Number) as Boolean {
        var session = _session;
        if (session == null) {
            return true;
        }

        _setNumberField(_jumpField, jumps);
        _setNumberField(_bestStreakField, bestStreak);
        _setNumberField(_avgCadenceField, avgCadence);
        _setNumberField(_setsField, sets);
        _setNumberField(_avgHrField, avgHr);
        _setNumberField(_maxHrField, maxHr);

        if (_active) {
            _active = false;
            try {
                session.stop();
            } catch (e) {
                System.println("FIT stop failed: " + e.getErrorMessage());
            }
        }

        var saved = false;
        try {
            saved = session.save();
        } catch (e) {
            System.println("FIT save failed: " + e.getErrorMessage());
        }
        if (!saved) {
            System.println("FIT save failed");
            // Keep the session so the user can retry from the summary screen.
            return false;
        }
        _session = null;
        return true;
    }

    public function discard() as Void {
        var session = _session;
        if (session == null) {
            return;
        }
        if (_active) {
            _active = false;
            try {
                session.stop();
            } catch (e) {
                System.println("FIT stop failed: " + e.getErrorMessage());
            }
        }
        try {
            session.discard();
        } catch (e) {
            System.println("FIT discard failed: " + e.getErrorMessage());
        }
        _session = null;
    }

    public function isFallbackSport() as Boolean {
        return _fallbackSport;
    }

    private function _createFields() as Void {
        if (_session == null) {
            return;
        }
        _jumpField = _createNumberField("Jumps", 0, FitContributor.DATA_TYPE_UINT32, {
            :mesgType => FitContributor.MESG_TYPE_SESSION,
            :units => "jumps"
        });
        _bestStreakField = _createNumberField("Best Streak", 1, FitContributor.DATA_TYPE_UINT16, {
            :mesgType => FitContributor.MESG_TYPE_SESSION,
            :units => "jumps"
        });
        _avgCadenceField = _createNumberField("Avg Cadence", 2, FitContributor.DATA_TYPE_UINT16, {
            :mesgType => FitContributor.MESG_TYPE_SESSION,
            :units => "jpm"
        });
        _setsField = _createNumberField("Sets", 3, FitContributor.DATA_TYPE_UINT16, {
            :mesgType => FitContributor.MESG_TYPE_SESSION,
            :units => "sets"
        });
        _avgHrField = _createNumberField("Avg HR", 4, FitContributor.DATA_TYPE_UINT8, {
            :mesgType => FitContributor.MESG_TYPE_SESSION,
            :units => "bpm"
        });
        _maxHrField = _createNumberField("Max HR", 5, FitContributor.DATA_TYPE_UINT8, {
            :mesgType => FitContributor.MESG_TYPE_SESSION,
            :units => "bpm"
        });

        var recordOptions = {
            :mesgType => FitContributor.MESG_TYPE_RECORD,
            :units => "jpm"
        };
        _recordCadenceField = _createNumberField("Cadence", 6, FitContributor.DATA_TYPE_UINT16, recordOptions);

        _lapJumpField = _createNumberField("Jumps (set)", 7, FitContributor.DATA_TYPE_UINT32, {
            :mesgType => FitContributor.MESG_TYPE_LAP,
            :units => "jumps"
        });
    }

    private function _createNumberField(name as String, id as Number, type as FitContributor.DataType, options as Dictionary) as FitContributor.Field? {
        var session = _session;
        if (session == null) {
            return null;
        }
        try {
            return session.createField(name, id, type, options);
        } catch (e) {
            System.println("FIT field " + name + " failed: " + e.getErrorMessage());
            return null;
        }
    }

    private function _setNumberField(field as FitContributor.Field?, value as Number) as Void {
        if (field == null) {
            return;
        }
        try {
            field.setData(value);
        } catch (e) {
            System.println("FIT field write failed: " + e.getErrorMessage());
        }
    }
}
