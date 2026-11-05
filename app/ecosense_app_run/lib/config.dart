// App-wide settings. Change these in ONE place instead of hunting through code.

/// If the hub has not updated /status/hub_last_seen for this many seconds,
/// the app treats the hub as offline.
const int kHubOfflineAfterSeconds = 30;

/// How many of the newest log entries to show.
const int kLogLimit = 50;

/// The room served by the ORIGINAL flat database paths (/status, /sensors/*,
/// /logs, /appliances/*). The existing hub keeps writing there, unchanged.
/// Every other room lives under /rooms/<roomId>/.
const String kPrimaryRoomId = 'living';
const String kPrimaryRoomName = 'Living Room';

/// Vacancy grace period limits (seconds), shared by the slider and the hub.
const int kGraceMinSeconds = 10;
const int kGraceMaxSeconds = 3600;

/// Used until an admin saves a value, and by the "Default" button.
const int kGraceDefaultSeconds = 45;

/// Electricity rate limits (PHP per kWh).
const double kRateMin = 5;
const double kRateMax = 25;
const double kRateDefault = 12;

/// How long the "Keep power on" override lasts.
const int kPauseMinutes = 15;

/// A switch request the hub has not applied after this long is shown as
/// "unconfirmed" with a Retry button.
const int kCommandTimeoutSeconds = 15;

/// Energy buckets (/energy/...) are keyed in this fixed offset from UTC
/// (Philippines = +8) so the app, the Cloud Function and the hub agree
/// regardless of the phone's time zone.
const int kEnergyUtcOffsetHours = 8;

/// Fill /energy history from the appliances' energy counters inside the app
/// (works with no Cloud Function and no hub change; any signed-in phone that
/// has the app open does it, and a cursor in /energy_cursor prevents double
/// counting). Set to false if you deploy backend/functions instead, otherwise
/// energy would be counted twice.
const bool kEnergySyncInApp = true;
