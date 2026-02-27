// Cette annotation déclenche l'exécution avant main()
@pragma('vm:entry-point')
void _qoraDevtoolsInit() {
  // Uniquement en debug
  //if (!kDebugMode) return;

  // S'enregistre auprès du QueryClient global via un hook d'initialisation
  //QoraDevtoolsBinding.ensureInitialized();
}

// packages/dart/qora/lib/src/client/query_client.dart
// class QueryClient {
//   QueryClient({QoraTracker? tracker})
//     : _tracker = tracker
//         ?? QoraDevtoolsBinding.trackerIfAvailable()  // auto-detect
//         ?? const NoOpTracker();
// }

// packages/devtools/qora_devtools_extension/lib/src/binding.dart
// class QoraDevtoolsBinding {
//   static QoraTracker? trackerIfAvailable() {
//     // Retourne VmTracker en debug, null en release
//     // → QueryClient fallback sur NoOpTracker en release
//     if (kDebugMode) return VmTracker();
//     return null;
//   }
// }