#ifndef FUSION_LOGIC_H
#define FUSION_LOGIC_H



// ------------------------------------------------------------------
// Base confidence model
// ------------------------------------------------------------------

// Confidence (0-100) based on how long since presence was last confirmed,
// decaying linearly to 0 at thresholdSeconds.
inline float computeConfidence(unsigned long secondsSincePresence,
                                unsigned long thresholdSeconds) {
  if (thresholdSeconds == 0) return 0.0f; // avoid divide-by-zero
  float ratio = (float)secondsSincePresence / (float)thresholdSeconds;
  float confidence = 100.0f - (ratio * 100.0f);
  if (confidence < 0.0f) confidence = 0.0f;
  if (confidence > 100.0f) confidence = 100.0f;
  return confidence;
}

// A location is considered vacant once confidence hits 0.
inline bool isVacant(float confidence) {
  return confidence <= 0.0f;
}

// ------------------------------------------------------------------
// Door-aware fusion (mmWave + door)
// ------------------------------------------------------------------

struct FusionParams {
  unsigned long thresholdSeconds;   // base decay window (tunable via Firebase /config)
  unsigned long doorSettleSeconds;  // mmWave rising edge within this long after a door event is "suspect"
  unsigned long confirmSeconds;     // suspect presence must persist this long to be confirmed
  unsigned long doorLeaveWindowSeconds; // door event this close to the last sighting = they could have left
  unsigned long holdMultiplier;     // K when nobody could have left (1 disables the gate)
};

inline FusionParams defaultFusionParams(unsigned long thresholdSeconds) {
  FusionParams p;
  p.thresholdSeconds = thresholdSeconds;
  p.doorSettleSeconds = 5;
  p.confirmSeconds = 6;
  p.doorLeaveWindowSeconds = 40;
  p.holdMultiplier = 4;
  return p;
}

struct FusionState {
  bool initialized;
  bool prevDoorOpen;
  bool prevPresence;
  bool hasDoorEvent;
  unsigned long lastDoorEventMs;
  unsigned long lastConfirmedPresenceMs;
  bool suspect;                     // current mmWave presence is unconfirmed
  unsigned long suspectSinceMs;
  bool sawPresence;                 // a confirmed presence has been seen since boot
};

inline FusionState newFusionState() {
  FusionState s;
  s.initialized = false;
  s.prevDoorOpen = false;
  s.prevPresence = false;
  s.hasDoorEvent = false;
  s.lastDoorEventMs = 0;
  s.lastConfirmedPresenceMs = 0;
  s.suspect = false;
  s.suspectSinceMs = 0;
  s.sawPresence = false;
  return s;
}

struct FusionResult {
  float confidence;
  bool vacant;
  bool suspect;        // true while mmWave presence is present but unconfirmed
  bool gateHolding;    // true while the door gate is slowing the countdown (K > 1)
};

// Run one fusion step. Call this every sampling cycle (~every 500 ms) with
// the CURRENT mmWave and door readings. Door transitions are detected
// internally by comparing against the previous call, so sample often
// enough not to miss a quick open/close.
inline FusionResult fusionStep(FusionState &s,
                               const FusionParams &p,
                               unsigned long nowMs,
                               bool mmwavePresence,
                               bool doorOpen) {
  // First call: assume the room starts "just occupied" so confidence
  // begins at 100 and decays from boot, same as the original behavior.
  if (!s.initialized) {
    s.initialized = true;
    s.prevDoorOpen = doorOpen;
    s.prevPresence = mmwavePresence;
    s.lastConfirmedPresenceMs = nowMs;
  }

  // Door event detection.
  if (doorOpen != s.prevDoorOpen) {
    s.hasDoorEvent = true;
    s.lastDoorEventMs = nowMs;
    s.prevDoorOpen = doorOpen;
  }
  unsigned long sinceDoorMs = s.hasDoorEvent ? (nowMs - s.lastDoorEventMs) : 0;
  bool doorEventInSettleWindow = s.hasDoorEvent && sinceDoorMs <= p.doorSettleSeconds * 1000UL;

  if (mmwavePresence) {
    if (!s.prevPresence) {
      // Rising edge.
      if (doorEventInSettleWindow) {
        // RULE A: appeared right after the door moved -> unconfirmed.
        s.suspect = true;
        s.suspectSinceMs = nowMs;
      } else {
        s.suspect = false;
        s.lastConfirmedPresenceMs = nowMs;
        s.sawPresence = true;
      }
    } else if (s.suspect) {
      // Continuing presence that started as suspect: confirm once it persists.
      if (nowMs - s.suspectSinceMs >= p.confirmSeconds * 1000UL) {
        s.suspect = false;
        s.lastConfirmedPresenceMs = nowMs;
        s.sawPresence = true;
      }
    } else {
      // Continuing, already-confirmed presence.
      s.lastConfirmedPresenceMs = nowMs;
      s.sawPresence = true;
    }
  } else {
    s.suspect = false; // a suspect blip that vanished was a false positive
  }
  s.prevPresence = mmwavePresence;

  unsigned long secondsSincePresence = (nowMs - s.lastConfirmedPresenceMs) / 1000UL;

  // RULE B: could the person have left? Only if a door event happened at or
  // after (shortly before) the last confirmed sighting.
  bool couldHaveLeft = s.hasDoorEvent &&
      (s.lastDoorEventMs + p.doorLeaveWindowSeconds * 1000UL >= s.lastConfirmedPresenceMs);
  unsigned long multiplier = 1;
  if (s.sawPresence && !couldHaveLeft && p.holdMultiplier > 1) {
    multiplier = p.holdMultiplier;
  }

  FusionResult r;
  r.confidence = computeConfidence(secondsSincePresence, p.thresholdSeconds * multiplier);
  r.vacant = isVacant(r.confidence);
  r.suspect = s.suspect;
  // Only report the hold while it is actually in effect (presence not being
  // confirmed right now), not the whole time someone is simply in the room.
  r.gateHolding = (multiplier > 1) && (secondsSincePresence > 0);
  return r;
}

#endif
