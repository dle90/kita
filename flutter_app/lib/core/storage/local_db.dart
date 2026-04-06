import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

/// Isar local database initialization helper.
///
/// Call [initialize] once at app startup before using [instance].
/// Collection schemas should be registered here when Isar collections
/// are defined.
class LocalDb {
  LocalDb._();

  static Isar? _isar;

  /// Returns the initialized Isar instance.
  /// Throws if [initialize] has not been called.
  static Isar get instance {
    if (_isar == null) {
      throw StateError(
        'LocalDb has not been initialized. Call LocalDb.initialize() first.',
      );
    }
    return _isar!;
  }

  /// Whether the database has been initialized.
  static bool get isInitialized => _isar != null;

  /// Initializes the Isar database.
  ///
  /// Registers all collection schemas. Call this once in [main] before
  /// [runApp].
  static Future<void> initialize() async {
    if (_isar != null) return;

    final dir = await getApplicationDocumentsDirectory();

    _isar = await Isar.open(
      // Add collection schemas here as they are created, e.g.:
      // [SrsCardSchema, SessionCacheSchema]
      [],
      directory: dir.path,
      name: 'kita_english',
    );
  }

  /// Closes the database. Useful for testing.
  static Future<void> close() async {
    await _isar?.close();
    _isar = null;
  }

  /// Clears all data in the database. Useful for logout.
  static Future<void> clearAll() async {
    await _isar?.writeTxn(() async {
      await _isar?.clear();
    });
  }
}
