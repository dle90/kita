/// Local database placeholder.
///
/// Isar removed for Android compatibility. Using in-memory storage
/// and API-first approach for now. Can add sqflite or hive later.
class LocalDb {
  LocalDb._();

  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static Future<void> initialize() async {
    _initialized = true;
  }

  static Future<void> close() async {
    _initialized = false;
  }

  static Future<void> clearAll() async {
    // No-op — no local DB
  }
}
