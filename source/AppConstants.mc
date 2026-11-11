import Toybox.Lang;

module AppConstants {
    const STATE_IDLE = 0;
    const STATE_RUNNING = 1;
    const STATE_PAUSED = 2;
    const STATE_STOPPED = 3;
    const STATE_COUNTDOWN = 4;

    const SAMPLE_RATE = 50;
    const WARMUP_SECONDS = 1.0f;
    const ACCEL_PERIOD = 1;
    const MIN_JUMP_INTERVAL_MS = 220;
    const PEAK_MAX_WIDTH_MS = 420;
    const JUMP_GAP_MS = 2200;
    const REST_TIMEOUT_MS = 6000;
    const CADENCE_WINDOW_MS = 10000;
    const CALORIE_MET = 12.3f;
    const CALORIE_MET_LOW = 8.8f;
    const CALORIE_MET_MID = 11.8f;
    const CALORIE_MET_HIGH = 12.3f;
    const TARGET_FLASH_MS = 1000;

    // Time constants for the detector's low-pass filters. They are converted
    // back to per-sample alpha values for the actual sensor rate.
    const GRAVITY_WARMUP_TAU_MS = 230.0f;
    const GRAVITY_TAU_MS = 1313.0f;
    const SLOW_TAU_MS = 551.0f;

    const WEIGHT_MIN_KG = 30;
    const WEIGHT_MAX_KG = 250;
    const WEIGHT_STEP_KG = 1;

    const STORAGE_SENSITIVITY = "sensitivity";
    const STORAGE_VIBE_EVERY = "vibeEvery";
    const STORAGE_HEART_RATE = "heartRate";
    const STORAGE_SAVE_ACTIVITY = "saveActivity";
    const STORAGE_WEIGHT = "weightKg";
    const STORAGE_TARGET = "target";
    const STORAGE_REST_DELAY = "restDelay";
    const STORAGE_BIG_NUMBER = "bigNumberCurrent";
    const STORAGE_COUNTDOWN = "countdown";
    const STORAGE_CUSTOM_THRESHOLD = "customThreshold";
    const STORAGE_BEST_TOTAL = "bestTotal";
    const STORAGE_BEST_STREAK = "bestStreak";
    const STORAGE_THEME = "themeDark";
}
