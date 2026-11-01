// App-wide settings. Change these in ONE place instead of hunting through code.

/// true  = use mock admin login (admin / ecosense123).
/// false = use real Firebase Authentication.
const bool kMockAuth = false;

/// Alias for compatibility with screens checking mock mode.
const bool kUseMockData = kMockAuth;

/// Firebase Authentication signs in with an email, but the admin logs in with a
/// username. The app builds the email as `<username>@<this domain>`.
const String kUsernameEmailDomain = 'ecosense.example.com';

/// If the hub has not updated /status/hub_last_seen for this many seconds,
/// the app treats the hub as offline.
const int kHubOfflineAfterSeconds = 30;

/// How many of the newest log entries to show.
const int kLogLimit = 50;

// ---- Mock login only ------------------------------------------------------

const String kMockUsername = 'admin';
const String kMockPassword = 'ecosense123';

const bool kMockHubOffline = false;
