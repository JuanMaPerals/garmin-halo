# Garmin Halo Bridge

A Connect IQ **data field** for the Garmin Forerunner 165 that streams real-time running data to [Brilliant Labs Halo](https://brilliant.xyz) smart glasses over BLE. The user starts a native running activity and adds this data field to any data screen. Running metrics (pace, heart rate, distance, elapsed time) and navigation cues (direction arrow, distance to next turn) are rendered on the Halo's 256x256 circular display at 1Hz via Lua commands sent over Bluetooth Low Energy.

## How It Works

```
┌─────────────────┐     BLE (20-byte chunks)     ┌─────────────────┐
│  Garmin FR165   │  ──────────────────────────► │  Halo Glasses   │
│                 │     Lua REPL commands         │                 │
│  Activity.Info  │                               │  256x256 RGB    │
│  HR, pace, dist │     HaloDelegate              │  circular display│
│  time, nav      │     HaloComm (chunking)       │                 │
│                 │     HaloDisplay (Lua gen)     │  Lua renderer   │
└─────────────────┘                               └─────────────────┘
```

The data field reads `Activity.Info` each second in `compute()`, composes a Lua rendering script via `HaloDisplay`, and sends it to the Halo glasses through a chunked BLE write queue (`HaloComm`, 20 bytes per write). The watch displays a minimal BLE status indicator; the Halo glasses display the full running UI.

## Quick Start

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) and Docker Compose
- A Garmin Developer account (free) for downloading device profiles
- Optional: WSLg or X11 forwarding for the simulator GUI

### 1. Build the Docker image

```bash
docker-compose build
```

This installs Connect IQ SDK 9.2.0, the Halo emulator, and all build tools.

### 2. First-time setup

```bash
docker-compose run --rm \
  -e GARMIN_USERNAME=your@email.com \
  -e GARMIN_PASSWORD=yourpassword \
  connectiq bash scripts/setup.sh
```

This generates a 4096-bit developer key, creates the launcher icon, accepts the SDK license, downloads fr165 + fr165m device profiles, and builds the project.

### 3. Build and run

```bash
# Compile the app
docker-compose run --rm connectiq make build

# Run in the simulator
docker-compose run --rm connectiq make run

# Run Lua tests against the Halo emulator
docker-compose run --rm connectiq make test-lua

# Run Connect IQ unit tests
docker-compose run --rm connectiq make test

# Run end-to-end integration tests (Connect IQ → Halo emulator)
docker-compose run --rm connectiq make test-e2e
```

## Project Structure

```
garmin-halo/
├── .devcontainer/
│   ├── Dockerfile              # Docker image: Ubuntu + JDK 17 + Connect IQ SDK + Halo emulator
│   └── devcontainer.json       # VS Code Dev Container config
├── docker-compose.yml          # Container orchestration with persistent device profiles
├── Makefile                    # Build, run, and test targets
├── manifest.xml                # Connect IQ app manifest (datafield type, BLE permission)
├── monkey.jungle               # Connect IQ build configuration
├── resources/
│   ├── strings/strings.xml     # App string resources
│   ├── layouts/layout.xml      # Data field layout
│   └── drawables/drawables.xml # Drawable resource definitions
├── source/
│   ├── HaloApp.mc              # AppBase — app lifecycle, BLE delegate initialization
│   ├── HaloDataField.mc        # SimpleDataField — compute() and onUpdate() for watch display
│   ├── HaloDelegate.mc         # BleDelegate — scanning, connection, characteristic I/O
│   ├── HaloDisplay.mc          # Lua script generation from Activity.Info values
│   ├── HaloComm.mc             # BLE write queue with 20-byte chunking
│   ├── HaloConstants.mc        # BLE UUIDs, control codes, CCCD values
│   └── HaloTests.mc            # Connect IQ unit tests (Lua generation verification)
├── scripts/
│   ├── setup.sh                # First-time setup (key, icon, device download, build)
│   └── build.sh                # Build with auto device profile check
├── tests/
│   ├── lua_commands.py         # Shared Lua command catalog
│   ├── test_halo_lua.py        # Lua emulator tests (10 tests)
│   ├── test_e2e_integration.py # End-to-end: Connect IQ → Lua → Halo emulator (5 tests)
│   └── mockup_halo_ui.py       # UI mockup screenshot generator
├── create_icon.py              # Launcher icon generator (86x86 PNG)
├── LICENSE
└── README.md
```

## Architecture

### Data Flow

1. **`HaloDataField.compute()`** — called at 1Hz by the Connect IQ runtime with `Activity.Info`
2. **`HaloDisplay.buildScript()`** — converts HR, pace, distance, time, and navigation data into a Lua script that draws the full UI on the Halo's display
3. **`HaloComm.sendLua()`** — splits the Lua string into UTF-8 bytes and chunks them into 20-byte segments (Garmin BLE write limit)
4. **`HaloDelegate`** — manages BLE scanning, connection, service/characteristic discovery, CCCD notification subscription, and sequential write completion callbacks

### UI Layout

**Running mode:**
- Blue ring around the display edge
- Heart rate (red, top center) with pulse indicator
- Pace (bold 32px white, center) with `/km` label (grey)
- Distance (green) and elapsed time (white) below a divider line

**Navigation mode:**
- Yellow arrow + distance to next turn (top center)
- Heart rate (red) below nav info
- Pace (bold white) shifted down
- Distance and time at the bottom

## BLE Protocol

| Characteristic | UUID | Direction | Properties |
|---|---|---|---|
| Service | `7A230001-5475-A6A4-654C-8431F6AD49C4` | — | — |
| LUA RX | `7A230002-5475-A6A4-654C-8431F6AD49C4` | Garmin → Halo | Write |
| LUA TX | `7A230003-5475-A6A4-654C-8431F6AD49C4` | Halo → Garmin | Notify |

The Garmin writes Lua commands to the LUA RX characteristic in 20-byte chunks. The Halo executes them in its Lua REPL and sends output back via LUA TX notifications.

## Testing

### Lua Emulator Tests (10 tests)

Tests Lua commands against the Halo emulator (`halo_emulator` package) with a virtual 256x256 display:

```bash
docker-compose run --rm connectiq make test-lua
```

Verifies: print output, text rendering, display clearing, battery level query, chunked command reassembly, running UI colors, navigation UI colors.

### Connect IQ Unit Tests (5 tests)

Tests Monkey C Lua script generation from mock activity data:

```bash
docker-compose run --rm connectiq make test
```

### End-to-End Integration Tests (5 tests)

Full pipeline: Connect IQ unit tests generate Lua → Python harness captures output → Halo emulator renders framebuffer → verifies expected colors:

```bash
docker-compose run --rm connectiq make test-e2e
```

| Test | Scenario | Verifies |
|---|---|---|
| RUNNING | HR=145, pace=5:33/km, 2.5km, 12:34 | Red HR, blue ring, white pace |
| NAVIGATION | 120m to next turn | Yellow arrow + distance |
| NULL_VALUES | No GPS, no HR | Blue ring, placeholder dashes |
| SPRINT | 7.0 m/s, pace=2:22/km | Renders correctly |
| MARATHON | 42.2km, 3:30:00 | Renders correctly |

### Mockup Screenshots

```bash
docker-compose run --rm connectiq python3 tests/mockup_halo_ui.py
# Output: mockups/mockup_running.png, mockups/mockup_navigation.png
```

## X11 Forwarding

With WSL2 + WSLg on Windows, X11 forwarding works automatically. The simulator GUI appears as a native Windows window.

Without WSLg, install [VcXsrv](https://sourceforge.net/projects/vcxsrv/) and set `DISPLAY=host.docker.internal:0`.

## License

[MIT](LICENSE)
