<!-- v0.1.0 - MVP Core         ✅ Pure Dart foundation -->
<!-- v0.2.0 - Flutter Basic    🎨 Basic Flutter widgets -->
<!-- v0.3.0 - Mutations        🔄 Optimistic updates -->
<!-- v0.4.0 - Persistence      💾 Offline-first -->
v0.5.0 - Network Aware    📡 Connectivity management
v0.6.0 - Infinite         ∞  Pagination support
<!-- v0.7.0 - Hooks            🪝 flutter_hooks integration -->
v0.8.0 - DevTools         🛠️ Developer experience
v0.9.0 - Advanced         🚀 Performance & edge cases
v1.0.0 - Production Ready 🎉 Stable release



## v0.6.0 - Network Aware 📡

**Objectif** : Gestion automatique de la connectivité réseau

### Packages
```
packages/reqry/          (extension)
packages/reqry_flutter/  (extension)
Features

✅ ConnectivityManager interface (pure Dart)
✅ FlutterConnectivityManager (connectivity_plus)
✅ NetworkStatus enum
✅ Automatic refetch on reconnect
✅ Offline queue pour mutations
✅ NetworkStatusIndicator widget
✅ Pause queries pendant offline
✅ Replay mutations queue au retour du réseau

API
dartvoid main() async {
  final client = ReqryClient();
  
  final connectivityManager = FlutterConnectivityManager(
    queryClient: client,
  );
  await connectivityManager.start();
  
  runApp(
    ReqryProvider(
      client: client,
      connectivityManager: connectivityManager,
      child: NetworkStatusIndicator(child: MyApp()),
    ),
  );
}
Widget
dartNetworkStatusIndicator(
  builder: (context, status) {
    return Stack(
      children: [
        child,
        if (status == NetworkStatus.offline)
          Banner(text: 'Offline mode'),
      ],
    );
  },
  child: MyApp(),
)
```

### Examples
- ✅ `examples/network_aware_app/`
- ✅ App qui détecte offline/online
- ✅ Queue de mutations rejoué au retour réseau

### Tests
- ✅ Mock connectivity tests
- ✅ Test offline queue
- ✅ Test refetch on reconnect

**Durée estimée** : 2 semaines