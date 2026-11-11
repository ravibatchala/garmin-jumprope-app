import Toybox.Lang;
import Toybox.Math;
import Toybox.Test;

(:test)
function testJumpDetectorCountsSyntheticJumps(logger as Test.Logger) as Boolean {
    var detector = new JumpDetector(200.0f);
    var xs = new Array<Numeric>[0];
    var ys = new Array<Numeric>[0];
    var zs = new Array<Numeric>[0];
    var ts = new Array<Numeric>[0];

    var t = 1000;
    // Two seconds of quiet baseline for the gravity/noise filters.
    for (var i = 0; i < 100; i++) {
        xs.add(1000.0);
        ys.add(0.0);
        zs.add(0.0);
        ts.add(t);
        t += 20;
    }

    // Ten smooth pulses: 600 ms apart, 260 ms wide, 420 mG tall.
    for (var jump = 0; jump < 10; jump++) {
        for (var i = 0; i < 13; i++) {
            var amplitude = 420.0 * Math.sin((Math.PI * i) / 12.0);
            xs.add(1000.0 + amplitude);
            ys.add(0.0);
            zs.add(0.0);
            ts.add(t);
            t += 20;
        }
        // Quiet gap between jumps.
        for (var i = 0; i < 17; i++) {
            xs.add(1000.0);
            ys.add(0.0);
            zs.add(0.0);
            ts.add(t);
            t += 20;
        }
    }

    detector.processSamples(xs, ys, zs, ts);
    var cadence = detector.getCadence(detector.getLastTimestamp());
    logger.debug("Synthetic count: " + detector.getCount().toString() + ", cadence: " + cadence.toString());
    Test.assertEqual(detector.getCount(), 10);
    Test.assertEqual(detector.getBestStreak(), 10);
    Test.assert(cadence >= 95 && cadence <= 105);

    detector.resetFilters();
    Test.assertEqual(detector.getCount(), 10);
    Test.assertEqual(detector.getBestStreak(), 10);
    return true;
}

(:test)
function testProcessSamplesFromSkipsTheArmBatch(logger as Test.Logger) as Boolean {
    var xs = new Array<Numeric>[0];
    var ys = new Array<Numeric>[0];
    var zs = new Array<Numeric>[0];
    var ts = new Array<Numeric>[0];

    var t = 1000;
    for (var i = 0; i < 100; i++) {
        xs.add(1000.0);
        ys.add(0.0);
        zs.add(0.0);
        ts.add(t);
        t += 20;
    }
    for (var jump = 0; jump < 10; jump++) {
        for (var i = 0; i < 13; i++) {
            var amplitude = 420.0 * Math.sin((Math.PI * i) / 12.0);
            xs.add(1000.0 + amplitude);
            ys.add(0.0);
            zs.add(0.0);
            ts.add(t);
            t += 20;
        }
        for (var i = 0; i < 17; i++) {
            xs.add(1000.0);
            ys.add(0.0);
            zs.add(0.0);
            ts.add(t);
            t += 20;
        }
    }

    // Starting at the end of the batch must process nothing, even though the
    // same samples count as ten jumps when processed from the beginning.
    var skipped = new JumpDetector(200.0f);
    skipped.processSamplesFrom(xs, ys, zs, ts, xs.size());
    logger.debug("Skipped batch count: " + skipped.getCount().toString());
    Test.assertEqual(skipped.getCount(), 0);

    var detector = new JumpDetector(200.0f);
    detector.processSamplesFrom(xs, ys, zs, ts, 0);
    logger.debug("Full batch count: " + detector.getCount().toString());
    Test.assertEqual(detector.getCount(), 10);

    // Out-of-range indexes clamp instead of throwing.
    var clamped = new JumpDetector(200.0f);
    clamped.processSamplesFrom(xs, ys, zs, ts, xs.size() + 100);
    Test.assertEqual(clamped.getCount(), 0);
    return true;
}

(:test)
function testCadenceResetsAfterGap(logger as Test.Logger) as Boolean {
    var detector = new JumpDetector(200.0f);
    var xs = new Array<Numeric>[0];
    var ys = new Array<Numeric>[0];
    var zs = new Array<Numeric>[0];
    var ts = new Array<Numeric>[0];

    var t = 1000;
    for (var i = 0; i < 100; i++) {
        xs.add(1000.0);
        ys.add(0.0);
        zs.add(0.0);
        ts.add(t);
        t += 20;
    }

    for (var jump = 0; jump < 10; jump++) {
        for (var i = 0; i < 13; i++) {
            var amplitude = 420.0 * Math.sin((Math.PI * i) / 12.0);
            xs.add(1000.0 + amplitude);
            ys.add(0.0);
            zs.add(0.0);
            ts.add(t);
            t += 20;
        }
        for (var i = 0; i < 17; i++) {
            xs.add(1000.0);
            ys.add(0.0);
            zs.add(0.0);
            ts.add(t);
            t += 20;
        }

        if (jump == 4) {
            // Three seconds of rest: long enough to reset the cadence buffer,
            // but short enough that the old jumps are still inside its 10 s window.
            for (var i = 0; i < 150; i++) {
                xs.add(1000.0);
                ys.add(0.0);
                zs.add(0.0);
                ts.add(t);
                t += 20;
            }
        }
    }

    detector.processSamples(xs, ys, zs, ts);
    var cadence = detector.getCadence(detector.getLastTimestamp());
    logger.debug("Gap count: " + detector.getCount().toString() + ", streak: " + detector.getBestStreak().toString() + ", cadence: " + cadence.toString());
    Test.assertEqual(detector.getCount(), 10);
    Test.assertEqual(detector.getBestStreak(), 5);
    Test.assert(cadence >= 95 && cadence <= 105);
    return true;
}

(:test)
function testJumpDetectorIgnoresNoise(logger as Test.Logger) as Boolean {
    var detector = new JumpDetector(200.0f);
    var xs = new Array<Numeric>[0];
    var ys = new Array<Numeric>[0];
    var zs = new Array<Numeric>[0];
    var ts = new Array<Numeric>[0];

    var t = 1000;
    var seed = 12345;
    for (var i = 0; i < 500; i++) {
        seed = ((seed * 37) + 17) % 1000;
        var noise = (seed % 81) - 40;
        xs.add(1000.0 + noise);
        ys.add(0.0);
        zs.add(0.0);
        ts.add(t);
        t += 20;
    }

    detector.processSamples(xs, ys, zs, ts);
    logger.debug("Noise count: " + detector.getCount().toString());
    Test.assertEqual(detector.getCount(), 0);
    return true;
}

(:test)
function testJumpDetectorRebaseIsReadyForNextSet(logger as Test.Logger) as Boolean {
    var detector = new JumpDetector(200.0f);
    var xs = new Array<Numeric>[0];
    var ys = new Array<Numeric>[0];
    var zs = new Array<Numeric>[0];
    var ts = new Array<Numeric>[0];

    var t = 1000;
    for (var i = 0; i < 100; i++) {
        xs.add(1000.0);
        ys.add(0.0);
        zs.add(0.0);
        ts.add(t);
        t += 20;
    }

    for (var i = 0; i < 13; i++) {
        var amplitude = 420.0 * Math.sin((Math.PI * i) / 12.0);
        xs.add(1000.0 + amplitude);
        ys.add(0.0);
        zs.add(0.0);
        ts.add(t);
        t += 20;
    }
    for (var i = 0; i < 17; i++) {
        xs.add(1000.0);
        ys.add(0.0);
        zs.add(0.0);
        ts.add(t);
        t += 20;
    }

    detector.processSamples(xs, ys, zs, ts);
    Test.assertEqual(detector.getCount(), 1);

    detector.rebase();
    Test.assertEqual(detector.getCount(), 1);

    var xs2 = new Array<Numeric>[0];
    var ys2 = new Array<Numeric>[0];
    var zs2 = new Array<Numeric>[0];
    var ts2 = new Array<Numeric>[0];

    // First sample after rebase seeds gravity.
    xs2.add(1000.0);
    ys2.add(0.0);
    zs2.add(0.0);
    ts2.add(t);
    t += 20;

    // The next jump must be detected without a one-second warm-up.
    for (var i = 0; i < 13; i++) {
        var amplitude = 420.0 * Math.sin((Math.PI * i) / 12.0);
        xs2.add(1000.0 + amplitude);
        ys2.add(0.0);
        zs2.add(0.0);
        ts2.add(t);
        t += 20;
    }
    for (var i = 0; i < 17; i++) {
        xs2.add(1000.0);
        ys2.add(0.0);
        zs2.add(0.0);
        ts2.add(t);
        t += 20;
    }

    detector.processSamples(xs2, ys2, zs2, ts2);
    logger.debug("Rebase count: " + detector.getCount().toString());
    Test.assertEqual(detector.getCount(), 2);
    return true;
}

(:test)
function testSettingsTargetPresets(logger as Test.Logger) as Boolean {
    var settings = new Settings();
    var values = settings.getTargetValues();
    Test.assert(values.indexOf(0) >= 0);
    Test.assert(values.indexOf(50) >= 0);
    Test.assert(values.indexOf(750) >= 0);
    Test.assert(values.indexOf(4000) >= 0);
    Test.assert(values.indexOf(7500) >= 0);
    Test.assert(values.indexOf(10000) >= 0);
    logger.debug("Target preset count: " + values.size().toString());
    return true;
}

(:test)
function testFitRecorderSavesSession(logger as Test.Logger) as Boolean {
    var recorder = new FitRecorder();
    var started = recorder.start();
    logger.debug("FIT started: " + started.toString() + ", fallback sport: " + recorder.isFallbackSport().toString());
    Test.assert(started);
    recorder.updateRecord(120);
    recorder.addSetLap(60);
    recorder.addSetLap(63);
    var saved = recorder.finish(123, 45, 120, 2, 142, 171);
    logger.debug("FIT saved: " + saved.toString());
    Test.assert(saved);
    return true;
}

(:test)
function testSessionManagerLifecycle(logger as Test.Logger) as Boolean {
    var settings = new Settings();
    settings.vibeEvery = 0;
    settings.target = 0;
    settings.saveActivity = true;

    var session = new SessionManager();
    Test.assert(session.start(settings));
    Test.assert(session.isRunning());
    Test.assert(!session.isResting());
    Test.assert(!session.isSetArmed());
    Test.assert(!session.armNewSet());
    session.pause();
    Test.assert(session.isPaused());
    session.resume();
    Test.assert(session.isRunning());
    session.stop();
    Test.assert(session.isStopped());
    var saved = session.save();
    logger.debug("Session saved: " + saved.toString());
    Test.assert(saved);
    session.reset();
    Test.assert(session.isIdle());
    return true;
}
