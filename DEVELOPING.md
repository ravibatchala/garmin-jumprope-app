# Developing Rope Jumps

Everything here is for building the app from source. To just use it, install it
from the [Connect IQ Store](https://apps.garmin.com/apps/63739fad-a779-416b-aad3-15b59681dd22).

## Requirements

- A Garmin [Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) with `monkeyc` and `monkeydo`.
- A Garmin developer key, `developer_key.der` in the project root. Without it
  the build scripts stop and print the two `openssl` commands that create one.
- A Mac for the helper scripts. They are zsh, but only `build.sh` really needs it.

`tools/env.sh` points at the SDK and the default device. Override either:

```sh
SDK="/path/to/sdk" ./tools/build.sh
DEVICE=instinct2 ./tools/test.sh
```

## Layout

```
source/      Monkey C views, session manager, detector, FIT recorder
resources/   strings, drawables, and the FIT field definitions
tests/       unit tests, compiled only by test.jungle
tools/       build, test, run, and sideload scripts
docs/        screenshots used by the README
```

## Build

```sh
./tools/build.sh          # -> build/JumpRope.prg
```

## Test

```sh
./tools/test.sh           # 8 unit tests in the simulator
```

The script starts the simulator if needed, runs the tests with `monkeydo`, and
treats the `PASSED` summary as success. `monkeydo` otherwise exits 1.

## Run

```sh
./tools/run.sh            # build must exist; opens the app in the simulator
```

## Sideload

```sh
./tools/install.sh        # copies build/JumpRope.prg to GARMIN/APPS/JUMPROPE.PRG
```

Close Garmin Express first, remove any older jump-rope `.PRG`, then eject the
watch and start **Jump Rope** from the app list. If the watch is not mounted,
copy `build/JumpRope.prg` to `GARMIN/APPS/JUMPROPE.PRG` yourself, for example
with OpenMTP or Android File Transfer.

A sideloaded build is fine for checking the UI, but activities recorded by one
may not relay to Garmin Connect. Install from the store to test that path.

## Simulator limits

The simulator cannot produce wrist motion, so jump detection, heart rate, and
saved activities still need the watch. Screens, layouts, menus, and settings can
all be checked there.

## Releasing

1. Build and test against every product in `manifest.xml`.
2. Export the store package, which contains the binaries for all products:

   ```sh
   monkeyc -e -f monkey.jungle -o build/JumpRope.iq -y developer_key.der -w
   ```

3. Set the version in the [Connect IQ developer dashboard](https://apps-developer.garmin.com).
   The version lives there, not in `manifest.xml`.
4. Upload the `.iq` and submit the update.

`developer_key.der` and `developer_key.pem` are gitignored. Keep a backup: every
future update must be signed with the same key.
