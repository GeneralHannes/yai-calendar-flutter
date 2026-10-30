import 'package:sqflite/sqflite.dart' show DatabaseFactory;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// SQLite compiled to WASM, persisted in IndexedDB. Runs on the main thread
/// (no shared/service worker), which works in every browser and in installed
/// PWAs. Requires `web/sqlite3.wasm`
/// (`dart run sqflite_common_ffi_web:setup`).
DatabaseFactory get platformDatabaseFactory => databaseFactoryFfiWebNoWebWorker;
