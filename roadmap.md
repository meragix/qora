<!-- v0.1.0 - MVP Core         ✅ Pure Dart foundation -->
<!-- v0.2.0 - Flutter Basic    🎨 Basic Flutter widgets -->
<!-- v0.3.0 - Mutations        🔄 Optimistic updates -->
v0.4.0 - Persistence      💾 Offline-first
v0.5.0 - Network Aware    📡 Connectivity management
v0.6.0 - Infinite         ∞  Pagination support
<!-- v0.7.0 - Hooks            🪝 flutter_hooks integration -->
v0.8.0 - DevTools         🛠️ Developer experience
v0.9.0 - Advanced         🚀 Performance & edge cases
v1.0.0 - Production Ready 🎉 Stable release



## v0.5.0 - Persistence 💾

**Objectif** : Support de la persistence pour offline-first

### Packages
```
packages/reqry/                      (extension)
packages/reqry_storage_hive/         (NEW)
packages/reqry_storage_isar/         (NEW)
packages/reqry_storage_drift/        (NEW)
packages/reqry_storage_shared_prefs/ (NEW)
Features

✅ QueryStorage interface (pure Dart)
✅ PersistReqryClient extends ReqryClient
✅ hydrate() pour charger le cache au démarrage
✅ Serialization/Deserialization avec deserializers globaux
✅ TTL (Time To Live) pour les données persistées
✅ Storage adapters :

HiveStorage
IsarStorage
DriftStorage
SharedPreferencesStorage



API
dartvoid main() async {
  final storage = HiveStorage();
  await storage.init();
  
  final client = PersistReqryClient(
    storage: storage,
    maxAge: Duration(days: 7),
  );
  
  // Register deserializers
  client.registerDeserializer<User>((json) => User.fromJson(json));
  client.registerDeserializer<List<User>>(
    (json) => (json['data'] as List).map((e) => User.fromJson(e)).toList(),
  );
  
  // Hydrate from storage
  await client.hydrate();
  
  runApp(ReqryProvider(client: client, child: MyApp()));
}
```

### Examples
- ✅ `examples/offline_first_app/`
- ✅ App qui fonctionne 100% offline
- ✅ Sync quand réseau revient

### Tests
- ✅ Test de la persistence
- ✅ Test de l'hydration
- ✅ Test du TTL
- ✅ Mock storage tests

**Durée estimée** : 3 semaines
