// Picks the SQLite backend per platform. The web backend is only compiled
// into web builds, so it adds nothing to the mobile binary.
export 'db_factory_native.dart'
    if (dart.library.js_interop) 'db_factory_web.dart';
