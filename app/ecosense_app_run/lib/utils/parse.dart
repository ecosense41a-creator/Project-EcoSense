// Realtime Database returns loosely typed values (Object?). These helpers
/// convert them safely, so a missing or wrong-typed field never crashes the app.

bool asBool(Object? v) => v is bool ? v : false;

double asDouble(Object? v) => v is num ? v.toDouble() : 0;

int asInt(Object? v) => v is num ? v.toInt() : 0;

String asString(Object? v) => v is String ? v : '';

Map<Object?, Object?>? asMap(Object? v) =>
    v is Map ? Map<Object?, Object?>.from(v) : null;
