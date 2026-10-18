// The browser's user agent on the web, empty elsewhere. `package:web` only
// compiles for the web, so it stays behind this conditional export.
export 'user_agent_stub.dart' if (dart.library.js_interop) 'user_agent_web.dart';
