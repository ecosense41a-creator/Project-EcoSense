#include <WiFi.h>
#include <WiFiMulti.h>
#include <ESPmDNS.h>
#include <WiFiClient.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <time.h>
#include <ld2410.h>
#include "fusion_logic.h"  

// ---------------- CONFIG ----------------
// Add or remove networks freely. All must be 2.4 GHz.
struct WifiCred { const char* ssid; const char* password; };
const WifiCred WIFI_NETWORKS[] = {
  { "Virus_Node.exe",   "73334774"   },
  { "ACLC WIFI 2", "aclccollegeofbaliuag" },
  { "Layp",    "1234567890"     },
};
const int WIFI_NETWORK_COUNT = sizeof(WIFI_NETWORKS) / sizeof(WIFI_NETWORKS[0]);

// Shelly Plug M Gen3 (from http://<plug-ip>/rpc/Shelly.GetDeviceInfo -> "id")
const char* PLUG_HOSTNAME    = "shellyplugmg3-907069682cd8";  // no ".local"
const char* PLUG_FALLBACK_IP = "192.168.0.213";
const char* PLUG_NODE        = "appliances/plug1";            // Firebase path

const char* DATABASE_URL = "https://ecosense-capstone-default-rtdb.asia-southeast1.firebasedatabase.app";

#define LD2410_RX_PIN 16
#define LD2410_TX_PIN 17
#define DOOR_PIN 4

const unsigned long SAMPLE_INTERVAL_MS = 500;              // how often to read sensors + run fusion
const unsigned long PUSH_INTERVAL_MS = 3000;               // how often to publish to Firebase (also pushes on state change)
const unsigned long CONFIG_REFRESH_INTERVAL_MS = 60000;    // how often to re-read /config
const unsigned long PLUG_POLL_INTERVAL_MS = 5000;          // how often to check for an override request
const unsigned long PLUG_RETRY_INTERVAL_MS = 10000;        // retry spacing when an auto-off fails
const unsigned long METER_INTERVAL_MS = 15000;             // how often to read power / energy from the plug
const unsigned long PAUSE_POLL_INTERVAL_MS = 10000;        // how often to check "Keep power on" (pause_until)
const unsigned int  FAIL_ALERT_AFTER_ATTEMPTS = 3;         // failed auto-off attempts before a "plug unreachable" alert

// Room id used by the app for the room served by the flat paths (/status, /sensors ...).
// The app stores "Keep power on" at /room_index/<id>/pause_until.
const char* ROOM_ID = "living";

// Fallback default, used only if /config can't be reached (e.g. first boot
// before anything's been written there, or WiFi/Firebase is briefly down).
unsigned long sustainedThresholdSeconds = 45;

// Safety bounds for the value read from /config. A typo (0, or a huge
// number) in the console or admin site must not make the room "vacant"
// instantly (which would cut appliance power) or never vacant.
const long MIN_THRESHOLD_SECONDS = 10;
const long MAX_THRESHOLD_SECONDS = 3600;
// -----------------------------------------

FusionState fusionState = newFusionState();
bool previousVacantState = false;     // tracks last reported vacancy, to log only on change
bool firstFusionRun = true;

ld2410 radar;
HardwareSerial mmwaveSerial(2);

unsigned long lastSampleTime = 0;
unsigned long lastPushTime = 0;
unsigned long lastConfigRefreshTime = 0;

String lastLocalIp = "";

// Smart plug state
String plugCachedAddress = "";                 // last address that answered
String plugFallbackIp = PLUG_FALLBACK_IP;      // overridden by /appliances/plug1/plug_ip
String plugState = "unknown";                  // "on" / "off" / "unknown"
bool autoOffPending = false;                   // room went vacant, plug not yet confirmed off
unsigned long lastPlugAttemptMs = 0;
unsigned long lastPlugPollMs = 0;
long lastRequestAt = 0;
bool requestBaselineSet = false;

// App-controlled automation settings (read from Firebase)
String automationMode = "auto";                // /config/automation_mode: "auto" or "manual"
bool autoCutoffAllowed = true;                 // appliances/plug1/auto_cutoff_allowed (missing = true)
unsigned long pauseUntil = 0;                  // /room_index/<ROOM_ID>/pause_until, Unix seconds
unsigned long lastPauseCheckMs = 0;

// Alerts: written once per event so the app's Alerts list does not fill with repeats
bool blockAlertSent = false;                   // "cut-off skipped" already reported for this vacancy
bool failAlertSent = false;                    // "plug unreachable" already reported for this vacancy
unsigned int autoOffFailCount = 0;
bool wifiWasLost = false;
bool backOnlineAlertPending = false;

// Energy metering + savings estimate
float lastPowerW = 0;                 // latest watts reading
float lastEnergyWh = 0;               // plug's running total, Wh
bool meterValid = false;              // plug reported metering fields at least once
unsigned long lastMeterMs = 0;
float savedWhTotal = 0;               // saved Wh from finished episodes (restored from Firebase at boot)
bool savedEpisodeActive = false;      // plug is off because of an auto-off
float savedPowerW = 0;                // watts drawn just before that auto-off
unsigned long savedSinceMs = 0;

WiFiMulti wifiMulti;

void connectWiFi() {
  WiFi.mode(WIFI_STA);
  for (int i = 0; i < WIFI_NETWORK_COUNT; i++) {
    wifiMulti.addAP(WIFI_NETWORKS[i].ssid, WIFI_NETWORKS[i].password);
  }
  Serial.print("Connecting to WiFi");
  while (wifiMulti.run() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected to " + WiFi.SSID() + ", IP: " + WiFi.localIP().toString());
}

void startMdns() {
  MDNS.end();
  if (MDNS.begin("ecosense-hub")) {
    Serial.println("mDNS started (can look up .local names)");
  } else {
    Serial.println("[WARN] mDNS failed to start - plug will be reached by IP only");
  }
}

// Rejoins after a drop and notices when the hub gets a new IP address:
// mDNS is restarted and the cached plug address is forgotten, since it
// may no longer be valid.
void maintainWiFi(unsigned long now) {
  static unsigned long lastReconnectTry = 0;
  if (WiFi.status() != WL_CONNECTED) {
    wifiWasLost = true;
    if (now - lastReconnectTry >= 5000) {
      lastReconnectTry = now;
      Serial.println("[WARN] WiFi lost - scanning for a known network");
      wifiMulti.run();
    }
    return;
  }
  if (wifiWasLost) {                 // connection is back after a drop
    wifiWasLost = false;
    backOnlineAlertPending = true;
  }
  String ip = WiFi.localIP().toString();
  if (ip != lastLocalIp) {
    lastLocalIp = ip;
    startMdns();
    plugCachedAddress = "";
  }
}

// Real Unix time in seconds (valid once NTP has synced; see setup()).
unsigned long unixNow() {
  return (unsigned long)time(nullptr);
}

bool timeIsSynced() {
  return time(nullptr) > 1700000000; // anything earlier means the clock never synced
}

void syncTime() {
  configTime(0, 0, "pool.ntp.org", "time.google.com"); // UTC; apps convert to local time
  Serial.print("Syncing time");
  unsigned long start = millis();
  while (!timeIsSynced() && millis() - start < 10000) {
    delay(250);
    Serial.print(".");
  }
  if (timeIsSynced()) {
    Serial.printf("\nTime synced (unix %lu)\n", unixNow());
  } else {
    Serial.println("\n[WARN] NTP not synced yet - timestamps will be wrong until it is");
  }
}

String getFromFirebase(const String &path) {
  if (WiFi.status() != WL_CONNECTED) return "";

  WiFiClientSecure client;
  client.setInsecure();
  HTTPClient http;
  String url = String(DATABASE_URL) + "/" + path + ".json";

  http.begin(client, url);
  int httpCode = http.GET();
  String payload = "";
  if (httpCode == 200) {
    payload = http.getString();
  } else {
    Serial.printf("[ERROR] GET %s -> HTTP %d\n", path.c_str(), httpCode);
  }
  http.end();
  return payload;
}

bool pushToFirebase(const String &path, const String &jsonPayload) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[ERROR] WiFi not connected, skipping push");
    return false;
  }

  WiFiClientSecure client;
  client.setInsecure();

  HTTPClient http;
  String url = String(DATABASE_URL) + "/" + path + ".json";

  http.begin(client, url);
  http.addHeader("Content-Type", "application/json");
  int httpCode = http.sendRequest("PATCH", jsonPayload);

  if (httpCode > 0) {
    Serial.printf("[Firebase] %s -> HTTP %d\n", path.c_str(), httpCode);
  } else {
    Serial.printf("[ERROR] %s -> %s\n", path.c_str(), http.errorToString(httpCode).c_str());
  }

  http.end();
  return httpCode > 0 && httpCode < 300;
}

// POST appends a new child with an auto-generated key - used for the /logs
// event history, where we want every entry kept (not merged/overwritten).
bool logEventToFirebase(const String &jsonPayload) {
  if (WiFi.status() != WL_CONNECTED) return false;

  WiFiClientSecure client;
  client.setInsecure();

  HTTPClient http;
  String url = String(DATABASE_URL) + "/logs.json";

  http.begin(client, url);
  http.addHeader("Content-Type", "application/json");
  int httpCode = http.POST(jsonPayload);

  if (httpCode > 0) {
    Serial.printf("[Firebase] logs -> HTTP %d\n", httpCode);
  } else {
    Serial.printf("[ERROR] logs -> %s\n", http.errorToString(httpCode).c_str());
  }

  http.end();
  return httpCode > 0 && httpCode < 300;
}

// Very small, deliberately naive numeric JSON field extractor - fine for a
// flat config object with a handful of numeric fields. (ArduinoJson would be
// the proper tool if /config ever grows nested or more complex than this.)
long jsonLongValue(const String &json, const String &key, long defaultValue) {
  String pattern = "\"" + key + "\":";
  int idx = json.indexOf(pattern);
  if (idx < 0) return defaultValue;
  idx += pattern.length();
  while (idx < (int)json.length() && json[idx] == ' ') idx++;
  int endIdx = idx;
  while (endIdx < (int)json.length() &&
         (isDigit(json[endIdx]) || json[endIdx] == '-')) {
    endIdx++;
  }
  if (endIdx == idx) return defaultValue;
  return json.substring(idx, endIdx).toInt();
}

// Same naive style as jsonLongValue, for a flat string field.
String jsonStringValue(const String &json, const String &key) {
  String pattern = "\"" + key + "\":\"";
  int idx = json.indexOf(pattern);
  if (idx < 0) return "";
  idx += pattern.length();
  int endIdx = json.indexOf("\"", idx);
  if (endIdx < 0) return "";
  return json.substring(idx, endIdx);
}

// Numeric field that may be a decimal (e.g. "apower":12.3).
float jsonFloatValue(const String &json, const String &key, float defaultValue) {
  String pattern = "\"" + key + "\":";
  int idx = json.indexOf(pattern);
  if (idx < 0) return defaultValue;
  idx += pattern.length();
  while (idx < (int)json.length() && json[idx] == ' ') idx++;
  int endIdx = idx;
  while (endIdx < (int)json.length() &&
         (isDigit(json[endIdx]) || json[endIdx] == '-' || json[endIdx] == '.' ||
          json[endIdx] == 'e' || json[endIdx] == 'E' || json[endIdx] == '+')) {
    endIdx++;
  }
  if (endIdx == idx) return defaultValue;
  return json.substring(idx, endIdx).toFloat();
}

// ---------------- Shelly smart plug ----------------

// One plain-HTTP GET to the plug (Shelly Gen2/Gen3 RPC API).
bool plugHttp(const String &address, const String &rpcPath, String &body) {
  WiFiClient client;
  HTTPClient http;
  http.setConnectTimeout(2000);
  http.setTimeout(3000);
  http.begin(client, "http://" + address + rpcPath);
  int code = http.GET();
  if (code == 200) body = http.getString();
  http.end();
  return code == 200;
}

String resolvePlugViaMdns() {
  IPAddress ip = MDNS.queryHost(PLUG_HOSTNAME, 2000);
  uint32_t raw = (uint32_t)ip;
  if (raw == 0 || raw == 0xFFFFFFFF) return "";   // lookup failed
  return ip.toString();
}

// Tries: last good address -> mDNS name -> stored/fallback IP.
bool plugRequest(const String &rpcPath, String &body) {
  if (WiFi.status() != WL_CONNECTED) return false;

  if (plugCachedAddress.length() > 0) {
    if (plugHttp(plugCachedAddress, rpcPath, body)) return true;
    plugCachedAddress = "";   // stale - look it up again
  }

  String viaName = resolvePlugViaMdns();
  if (viaName.length() > 0 && plugHttp(viaName, rpcPath, body)) {
    plugCachedAddress = viaName;
    Serial.println("[PLUG] reached via mDNS at " + viaName);
    return true;
  }

  if (plugFallbackIp.length() > 0 && plugHttp(plugFallbackIp, rpcPath, body)) {
    plugCachedAddress = plugFallbackIp;
    Serial.println("[PLUG] reached via stored IP " + plugFallbackIp);
    return true;
  }

  Serial.println("[ERROR] Shelly plug unreachable (mDNS and stored IP both failed)");
  return false;
}

bool jsonBoolIsTrue(const String &json, const String &key) {
  return json.indexOf("\"" + key + "\":true") >= 0 ||
         json.indexOf("\"" + key + "\": true") >= 0;
}

bool jsonBoolIsFalse(const String &json, const String &key) {
  return json.indexOf("\"" + key + "\":false") >= 0 ||
         json.indexOf("\"" + key + "\": false") >= 0;
}

// Writes an entry the app shows under Activity > Alerts.
// severity: "info", "warn" or "error". "error" is stored with type "error".
bool writeAlert(const char* severity, const char* title, const String &detail) {
  String sev = String(severity);
  String logPayload = "{";
  logPayload += "\"type\":\"" + String(sev == "error" ? "error" : "alert") + "\",";
  logPayload += "\"message\":\"" + String(title) + "\",";
  logPayload += "\"title\":\"" + String(title) + "\",";
  logPayload += "\"detail\":\"" + detail + "\",";
  logPayload += "\"severity\":\"" + sev + "\",";
  logPayload += "\"source\":\"hub\",";
  logPayload += "\"timestamp\":" + String(unixNow());
  logPayload += "}";
  Serial.println(String("[ALERT] ") + title + " - " + detail);
  return logEventToFirebase(logPayload);
}

// Reads the plug's real state and, if it reports them, power and energy.
bool readPlugMeter() {
  String body;
  if (!plugRequest("/rpc/Switch.GetStatus?id=0", body)) return false;

  plugState = jsonBoolIsTrue(body, "output") ? "on" : "off";
  if (body.indexOf("\"apower\"") >= 0) {
    lastPowerW = jsonFloatValue(body, "apower", 0);
    int a = body.indexOf("\"aenergy\"");
    if (a >= 0) {
      lastEnergyWh = jsonFloatValue(body.substring(a, body.length()), "total", lastEnergyWh);
    }
    meterValid = true;
  }
  return true;
}

void syncPlugState() {
  if (readPlugMeter()) {
    Serial.println("[PLUG] current state: " + plugState);
  }
}

// ---- Savings estimate: watts drawn before an auto-off x time it stayed off ----
float currentSavedWh(unsigned long now) {
  float wh = savedWhTotal;
  if (savedEpisodeActive) {
    wh += savedPowerW * (float)(now - savedSinceMs) / 3600000.0f;
  }
  return wh;
}

void closeSavedEpisode(unsigned long now) {
  if (!savedEpisodeActive) return;
  savedWhTotal = currentSavedWh(now);
  savedEpisodeActive = false;
}

// Switch the plug, then record it in /appliances and /logs.
bool plugApply(bool on, const char* triggerType, const char* logMessage) {
  String body;
  String path = String("/rpc/Switch.Set?id=0&on=") + (on ? "true" : "false");
  bool wasOn = (plugState != "off");   // "unknown" counts as on
  if (!plugRequest(path, body)) return false;

  plugState = on ? "on" : "off";
  unsigned long nowMs = millis();
  if (on) {
    closeSavedEpisode(nowMs);          // power is back: stop counting savings
  } else if (String(triggerType) == "auto" && wasOn && !savedEpisodeActive) {
    savedEpisodeActive = true;         // start counting from the last power sample
    savedPowerW = meterValid ? lastPowerW : 0;
    savedSinceMs = nowMs;
  }
  Serial.println(String("[PLUG] ") + logMessage);

  String statePayload = "{";
  statePayload += "\"state\":\"" + plugState + "\",";
  statePayload += "\"trigger_type\":\"" + String(triggerType) + "\",";
  statePayload += "\"last_changed\":" + String(unixNow());
  statePayload += "}";
  pushToFirebase(PLUG_NODE, statePayload);

  String logPayload = "{";
  logPayload += "\"type\":\"appliance\",";
  logPayload += "\"message\":\"" + String(logMessage) + "\",";
  logPayload += "\"timestamp\":" + String(unixNow());
  logPayload += "}";
  logEventToFirebase(logPayload);
  return true;
}

// Auto-off: once per vacant transition, retried until the plug confirms.
// Why the automatic cut-off must not happen right now ("" = it may proceed).
String autoOffBlockReason() {
  if (automationMode == "manual") return "Automation mode is Manual";
  if (!autoCutoffAllowed) return "Auto cut-off is turned off for this appliance";
  if (pauseUntil > unixNow()) return "Keep power on is active";
  return "";
}

void runAutoOff(unsigned long now, bool vacant) {
  if (!autoOffPending) return;
  if (!vacant) { autoOffPending = false; return; }   // someone came back first

  // The app can hold the cut-off back. Stay pending, so it still happens
  // if the block ends (for example the 15 minutes run out) while the room is empty.
  String reason = autoOffBlockReason();
  if (reason.length() > 0) {
    if (!blockAlertSent) {
      blockAlertSent = true;
      Serial.println("[AUTO-OFF] skipped: " + reason);
      writeAlert("warn", "Automatic cut-off skipped", reason);
    }
    return;
  }

  if (lastPlugAttemptMs != 0 && now - lastPlugAttemptMs < PLUG_RETRY_INTERVAL_MS) return;
  lastPlugAttemptMs = now;
  if (plugApply(false, "auto", "Plug turned OFF (room vacant)")) {
    autoOffPending = false;
    autoOffFailCount = 0;
  } else {
    autoOffFailCount++;
    if (autoOffFailCount >= FAIL_ALERT_AFTER_ATTEMPTS && !failAlertSent) {
      failAlertSent = true;
      writeAlert("error", "Plug unreachable", "Could not switch the plug off after several attempts");
    }
  }
}

// Every METER_INTERVAL_MS: read the plug, publish power / energy / savings.
void sampleMeter(unsigned long now) {
  if (now - lastMeterMs < METER_INTERVAL_MS) return;
  lastMeterMs = now;

  String before = plugState;
  if (!readPlugMeter()) return;

  // Switched by hand at the plug (or by another app): note it, stop counting savings.
  bool changedByHand = (before != "unknown" && before != plugState);
  if (plugState == "on") closeSavedEpisode(now);

  String payload = "{";
  payload += "\"state\":\"" + plugState + "\"";
  if (changedByHand) {
    payload += ",\"trigger_type\":\"manual_plug\",\"last_changed\":" + String(unixNow());
  }
  if (meterValid) {
    payload += ",\"power_w\":" + String(lastPowerW, 1);
    payload += ",\"energy_wh\":" + String(lastEnergyWh, 2);
    payload += ",\"saved_wh_estimate\":" + String(currentSavedWh(now), 2);
    payload += ",\"meter_updated\":" + String(unixNow());
  }
  payload += "}";
  pushToFirebase(PLUG_NODE, payload);
}

// Override: the app writes requested_state + a new requested_at.
// Reads /appliances/plug1 and acts only when requested_at changed.
void pollPlugRequests(unsigned long now) {
  if (now - lastPlugPollMs < PLUG_POLL_INTERVAL_MS) return;
  lastPlugPollMs = now;

  String json = getFromFirebase(PLUG_NODE);
  if (json.length() == 0 || json == "null") return;

  String storedIp = jsonStringValue(json, "plug_ip");
  if (storedIp.length() > 0 && storedIp != plugFallbackIp) {
    plugFallbackIp = storedIp;
    plugCachedAddress = "";
  }

  // Per-appliance permission from the app. Missing field = allowed.
  autoCutoffAllowed = !jsonBoolIsFalse(json, "auto_cutoff_allowed");

  long requestedAt = jsonLongValue(json, "requested_at", 0);
  if (!requestBaselineSet) {          // ignore whatever was there at boot
    lastRequestAt = requestedAt;
    requestBaselineSet = true;
    return;
  }
  if (requestedAt == lastRequestAt) return;

  String requested = jsonStringValue(json, "requested_state");
  if (requested != "on" && requested != "off") {
    lastRequestAt = requestedAt;      // nothing valid to do
    return;
  }
  bool on = (requested == "on");
  bool done = plugApply(on, "manual_override",
                        on ? "Plug turned ON (manual override)"
                           : "Plug turned OFF (manual override)");
  if (done) lastRequestAt = requestedAt;   // otherwise retried on the next poll
}

// First boot: create /appliances/plug1 if it is missing, read the plug's
// real state, and remember any request already waiting so it is ignored.
void initPlug() {
  String json = getFromFirebase(PLUG_NODE);
  if (json == "null") {
    String create = "{\"name\":\"Smart plug\",\"plug_ip\":\"" + String(PLUG_FALLBACK_IP) + "\"}";
    pushToFirebase(PLUG_NODE, create);
    json = "";
    lastRequestAt = 0;            // brand-new node: nothing waiting, so the first
    requestBaselineSet = true;    // request the app writes must NOT be swallowed
  } else if (json.length() > 0) {
    String storedIp = jsonStringValue(json, "plug_ip");
    if (storedIp.length() > 0) plugFallbackIp = storedIp;
    lastRequestAt = jsonLongValue(json, "requested_at", 0);
    requestBaselineSet = true;
    savedWhTotal = jsonFloatValue(json, "saved_wh_estimate", 0);   // keep the running total across reboots
  }

  syncPlugState();
  if (plugState != "unknown") {
    String statePayload = "{\"state\":\"" + plugState + "\"}";
    pushToFirebase(PLUG_NODE, statePayload);
  }
}

void loadConfigFromFirebase() {
  String json = getFromFirebase("config");
  if (json.length() == 0) {
    Serial.println("[WARN] Could not read /config - keeping previous sustainedThresholdSeconds");
    return;
  }
  String mode = jsonStringValue(json, "automation_mode");
  if (mode == "auto" || mode == "manual") {
    if (mode != automationMode) Serial.println("[CONFIG] automation_mode=" + mode);
    automationMode = mode;
  }

  long value = jsonLongValue(json, "sustained_threshold_seconds", (long)sustainedThresholdSeconds);
  if (value < MIN_THRESHOLD_SECONDS || value > MAX_THRESHOLD_SECONDS) {
    Serial.printf("[WARN] /config sustained_threshold_seconds=%ld is outside %ld-%ld - ignoring it, keeping %lu\n",
                  value, MIN_THRESHOLD_SECONDS, MAX_THRESHOLD_SECONDS, sustainedThresholdSeconds);
    return;
  }
  sustainedThresholdSeconds = (unsigned long)value;
  Serial.printf("[CONFIG] sustained_threshold_seconds=%lu\n", sustainedThresholdSeconds);
}

// "Keep power on": the app writes a Unix time to /room_index/<ROOM_ID>/pause_until.
void loadPauseFromFirebase(unsigned long now) {
  if (now - lastPauseCheckMs < PAUSE_POLL_INTERVAL_MS) return;
  lastPauseCheckMs = now;
  String body = getFromFirebase(String("room_index/") + ROOM_ID + "/pause_until");
  if (body.length() == 0) return;                    // could not read: keep the last value
  if (body == "null") { pauseUntil = 0; return; }
  long v = body.toInt();
  pauseUntil = v > 0 ? (unsigned long)v : 0;
}

void setup() {
  Serial.begin(115200);
  delay(500);

  pinMode(DOOR_PIN, INPUT_PULLUP);

  connectWiFi();
  maintainWiFi(millis());   // starts mDNS for the network we just joined
  syncTime();
  loadConfigFromFirebase();
  lastConfigRefreshTime = millis();
  initPlug();

  mmwaveSerial.begin(256000, SERIAL_8N1, LD2410_RX_PIN, LD2410_TX_PIN);
  if (radar.begin(mmwaveSerial)) {
    Serial.println("LD2410 sensor connected");
  } else {
    Serial.println("[ERROR] LD2410 sensor not responding - check wiring");
  }
}

void loop() {
  radar.read(); // must be called frequently to keep parsing the LD2410's serial stream

  unsigned long now = millis();

  maintainWiFi(now);

  if (backOnlineAlertPending && WiFi.status() == WL_CONNECTED && timeIsSynced()) {
    backOnlineAlertPending = false;
    writeAlert("info", "Hub back online", "WiFi reconnected");
  }

  // Periodically re-pull the tunable threshold from Firebase.
  if (now - lastConfigRefreshTime >= CONFIG_REFRESH_INTERVAL_MS) {
    lastConfigRefreshTime = now;
    loadConfigFromFirebase();
  }

  if (now - lastSampleTime < SAMPLE_INTERVAL_MS) return;
  lastSampleTime = now;

  // ---- Read raw sensors ----
  bool presence = radar.presenceDetected();
  unsigned int distanceCm = 0;
  if (radar.movingTargetDetected()) {
    distanceCm = radar.movingTargetDistance();
  } else if (radar.stationaryTargetDetected()) {
    distanceCm = radar.stationaryTargetDistance();
  }

  // INPUT_PULLUP: HIGH = open (switch not making contact),
  // LOW = closed (magnet present, switch shorts to GND).
  bool doorOpen = digitalRead(DOOR_PIN) == HIGH;
  String doorState = doorOpen ? "open" : "closed";

  // ---- Fusion (fusion_logic.h: mmWave + door, unit-tested) ----
  FusionParams params = defaultFusionParams(sustainedThresholdSeconds);
  FusionResult result = fusionStep(fusionState, params, now, presence, doorOpen);
  float confidence = result.confidence;
  bool vacant = result.vacant;

  bool stateChanged = (vacant != previousVacantState) || firstFusionRun;
  bool pushDue = (now - lastPushTime >= PUSH_INTERVAL_MS);

  if (pushDue || stateChanged) {
    lastPushTime = now;

    // ---- Publish raw sensor readings ----
    String mmwavePayload = "{";
    mmwavePayload += "\"presence\":" + String(presence ? "true" : "false") + ",";
    mmwavePayload += "\"distance_cm\":" + String(distanceCm) + ",";
    mmwavePayload += "\"timestamp\":" + String(unixNow());
    mmwavePayload += "}";
    pushToFirebase("sensors/mmwave", mmwavePayload);

    String doorPayload = "{";
    doorPayload += "\"state\":\"" + doorState + "\",";
    doorPayload += "\"timestamp\":" + String(unixNow());
    doorPayload += "}";
    pushToFirebase("sensors/door", doorPayload);

    // ---- Publish fused status ----
    String statusPayload = "{";
    statusPayload += "\"occupancy_confidence\":" + String(confidence, 1) + ",";
    statusPayload += "\"is_vacant\":" + String(vacant ? "true" : "false") + ",";
    statusPayload += "\"suspect\":" + String(result.suspect ? "true" : "false") + ",";
    statusPayload += "\"door_gate_hold\":" + String(result.gateHolding ? "true" : "false") + ",";
    statusPayload += "\"timestamp\":" + String(unixNow()) + ",";
    // Heartbeat fields: server-side time (ms) so "is the hub alive?" does not
    // depend on the hub's own clock being correct.
    statusPayload += "\"hub_last_seen\":{\".sv\":\"timestamp\"},";
    statusPayload += "\"wifi_rssi\":" + String(WiFi.RSSI()) + ",";
    statusPayload += "\"uptime_seconds\":" + String(now / 1000);
    statusPayload += "}";
    pushToFirebase("status", statusPayload);

    // ---- Cloud logging: only on an actual occupancy transition ----
    if (stateChanged) {
      previousVacantState = vacant;
      firstFusionRun = false;
      autoOffPending = vacant;     // vacant -> switch the plug off; occupied -> cancel
      lastPlugAttemptMs = 0;
      blockAlertSent = false;      // new vacancy: allow one new alert of each kind
      failAlertSent = false;
      autoOffFailCount = 0;

      String message = vacant ? "Room became vacant" : "Room became occupied";
      String logPayload = "{";
      logPayload += "\"type\":\"occupancy\",";
      logPayload += "\"message\":\"" + message + "\",";
      logPayload += "\"confidence\":" + String(confidence, 1) + ",";
      logPayload += "\"timestamp\":" + String(unixNow());
      logPayload += "}";
      logEventToFirebase(logPayload);
    }

    Serial.printf("presence=%s distance=%ucm door=%s confidence=%.1f -> %s%s (threshold=%lus) plug=%s %.1fW\n",
                  presence ? "true" : "false", distanceCm, doorState.c_str(),
                  confidence, vacant ? "VACANT" : "occupied",
                  result.suspect ? " [suspect: unconfirmed after door event]" :
                  (result.gateHolding ? " [door shut: holding 4x]" : ""),
                  sustainedThresholdSeconds, plugState.c_str(), lastPowerW);
  }

  // ---- Smart plug: auto-off after vacancy, and homeowner override ----
  loadPauseFromFirebase(now);
  runAutoOff(now, vacant);
  pollPlugRequests(now);
  sampleMeter(now);
}
