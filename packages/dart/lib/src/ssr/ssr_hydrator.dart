// Conditional export: real implementation on Flutter Web, no-op stub on
// every other platform (native, server, tests).
export 'ssr_hydrator_stub.dart'
    if (dart.library.js_interop) 'ssr_hydrator_web.dart';
