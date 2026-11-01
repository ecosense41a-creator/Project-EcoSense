# EcoSense

EcoSense is an IoT system that tells whether a room is occupied and switches an appliance off when it is not. A mmWave radar and a door reed switch feed one ESP32. The ESP32 combines the two readings into an occupancy confidence, publishes it to Firebase, and turns off a smart plug once the room has been empty long enough. A Flutter app shows the live status and lets the homeowner override the plug.

IT Capstone Project 1, IT41A Group 3, ACLC College Baliuag.

## How it fits together

```
LD2410C mmWave + door reed switch
            |
          ESP32  --- HTTP --->  Smart plug  (auto-off, override)
            |
        Firebase Realtime Database
            |
        Flutter app  (status, sensors, logs, override)
```

1. The ESP32 reads the radar and the door switch every 0.5 seconds.
2. The door-aware fusion logic turns the readings into a confidence from 0 to 100.
3. At 0 the room is vacant, and the ESP32 tells the plug to switch off.
4. The ESP32 publishes the readings and status to Firebase about every 3 seconds.
5. The app reads from Firebase. An override in the app writes a request, and the ESP32 carries it out on its next check.

## Repository layout

| Folder | What it is |
|---|---|
| `firmware/` | ESP32 sketch and the sensor fusion logic |
| `app/` | Flutter mobile app |

Each part has its own setup steps below.

## Firmware

**Files**

| File | What it is |
|---|---|
| `presence_hub_firmware.ino` | WiFi, sensors, Firebase and smart plug control |
| `fusion_logic.h` | The occupancy confidence and door rules. It has no hardware code |

Keep both files in the same sketch folder. Arduino needs the folder name to match the `.ino` file name, so the folder should be `presence_hub_firmware`.

**Hardware**

| Part | Connection |
|---|---|
| LD2410C VCC and GND | 5V and GND |
| LD2410C TX | GPIO16 |
| LD2410C RX | GPIO17 |
| Door reed switch | Between GPIO4 and GND |

The ESP32 can run from a power bank. The smart plug has no wiring to the hub. It only has to be on the same WiFi network.

The door pin uses the internal pull-up, so it reads HIGH when the door is open and LOW when the magnet closes the switch. Check the Serial Monitor against the real door before trusting it, because some reed switches work the opposite way.

**Setup**

1. Install the Arduino IDE with the ESP32 board package.
2. In the Library Manager, install **ld2410** by ncmreynolds. `WiFiMulti` and `ESPmDNS` come with the ESP32 package.
3. Edit the settings near the top of `presence_hub_firmware.ino`:
   - `WIFI_NETWORKS`: your WiFi names and passwords. The hub joins the strongest one in range. They must be 2.4 GHz.
   - `DATABASE_URL`: your Firebase Realtime Database address.
   - `PLUG_HOSTNAME`: the plug's device ID without `.local`. Find it in the plug's device info page.
   - `PLUG_FALLBACK_IP`: the plug's IP address, used as a backup.
4. Select your ESP32 board, upload, and open the Serial Monitor at 115200 baud.

**How the confidence works**

```
confidence = 100 - (t / (T x K)) x 100        limited to 0..100
```

| Symbol | Meaning |
|---|---|
| t | Whole seconds since presence was last confirmed (0 while someone is detected) |
| T | Grace period in seconds, from `/config/sustained_threshold_seconds` (default 45, allowed 10 to 3600) |
| K | Door gate multiplier: 4 if the door has not moved near the last sighting, otherwise 1 |

The room is vacant when the confidence reaches 0. The radar takes about 15 seconds to clear after someone leaves, and the countdown starts after that.

The door sensor never proves someone is in the room, so it is used in two ways:

- **Rule A, door-swing filter.** Radar presence that appears within 5 seconds of a door event is "suspect". It only counts once it stays on for 6 seconds, so a swinging door does not reset the countdown.
- **Rule B, door gate.** If the door has not moved near or after the last confirmed presence, nobody could have left, so the countdown runs 4 times slower. K stays 1 until presence has been seen once after boot.

The door only slows the countdown or filters false presence. It never shortens it. These values are set in `defaultFusionParams()` in `fusion_logic.h`.

**Smart plug behavior**

- **Auto-off.** When the room becomes vacant the plug is switched off. If it cannot be reached, the hub retries every 10 seconds. If someone returns first, the pending turn-off is cancelled.
- **Never turns on by itself.** Only the override from the app turns the plug back on.
- **Override.** The app writes `requested_state` ("on" or "off") and a new `requested_at` in seconds. The hub acts only when `requested_at` changes, and ignores a request that was already there at boot.
- **Finding the plug.** The hub tries the last address that worked, then the mDNS name, then `plug_ip` from Firebase. Phone hotspots and school WiFi often block mDNS, so `plug_ip` must be correct for the network you are on.
- **Energy.** Every 15 seconds the hub reads power (watts) and energy (watt-hours). `saved_wh_estimate` is the power drawn just before an auto-off times how long the plug stayed off. It is an estimate, not a measurement.

## Firebase data

| Path | Written by | Contents |
|---|---|---|
| `/sensors/mmwave` | Hub | `presence`, `distance_cm`, `timestamp` |
| `/sensors/door` | Hub | `state` ("open" or "closed"), `timestamp` |
| `/status` | Hub | `occupancy_confidence`, `is_vacant`, `suspect`, `door_gate_hold`, `timestamp`, `hub_last_seen`, `wifi_rssi`, `uptime_seconds` |
| `/logs` | Hub | One entry per occupancy or plug event: `type`, `message`, `confidence` (occupancy only), `timestamp` |
| `/config` | App or you | `sustained_threshold_seconds` |
| `/appliances/plug1` | Hub and app | `name`, `plug_ip`, `state`, `trigger_type`, `last_changed`, `power_w`, `energy_wh`, `saved_wh_estimate`, `meter_updated`, `requested_state`, `requested_at` |

Timestamps are Unix time in seconds. The exception is `hub_last_seen`, which is the Firebase server time in milliseconds. The hub reads `/config` at boot and every 60 seconds, so the grace period can change without reflashing.

## Mobile app

A Flutter app for Android with these screens: Login, Status, Sensors and Logs. It uses `firebase_core`, `firebase_auth` and `firebase_database`.

**Run it**

1. Install Flutter and Android Studio (or use a connected Android phone with USB debugging).
2. In the `app` folder, run `flutter pub get`.
3. Run `flutter run`.

**Mock login or real login.** The app has a switch in `lib/config.dart`:

| Setting | Behavior |
|---|---|
| `kMockAuth = true` | Uses the mock login (`admin` / `ecosense123`) and mock data. No Firebase needed |
| `kMockAuth = false` | Uses Firebase Authentication and reads the live database |

To use real Firebase, set `kMockAuth = false`, make sure `lib/firebase_options.dart` points at your Firebase project, and create the user in Firebase Authentication. The app builds the login email as `<username>@ecosense.example.com`.

The app treats the hub as offline when `/status/hub_last_seen` is more than 30 seconds old.

## Known limits

- It assumes one way in and out of the room. Someone leaving by a window looks like someone still inside until the held countdown ends.
- The radar can see through an open door into the hallway. Limit its maximum detection range with the HLKRadarTool.
- Two people in the room can hide one of them leaving.
- The hub connects to Firebase over HTTPS without checking the server's certificate.
- The firmware has only been tested in simulation. Test it on real hardware before relying on it.
- Away mode and push notifications are planned, not built.

## Team

| Name | Role |
|---|---|
| John Lyf Mariano | Project Manager |
| Alwil Sarmiento | Software Engineer |
| Kerby Cruz | Software Tester |
| Rogine Rhymes Perez | System Analyst |
| Marc Eivriel Villarama | Database Engineer |

Adviser: Joey C. Manansala Jr.
