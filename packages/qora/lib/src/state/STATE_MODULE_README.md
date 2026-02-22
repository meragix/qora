# QoraState Module

Type-safe, exhaustive state management for asynchronous queries in Dart/Flutter.

## Architecture

### Core Design Principles

1. **Sealed Classes** → Compile-time exhaustiveness
2. **previousData Preservation** → Graceful degradation UX
3. **Immutability** → Predictable state transitions
4. **Type Safety** → Generic `QoraState<T>` for any data type

### State Hierarchy

```bash
QoraState<T> (sealed)
├── Initial<T>          // Not started
├── Loading<T>          // Fetching (+ optional previousData)
├── Success<T>          // Completed (data + updatedAt)
└── Failure<T>          // Failed (error + optional previousData)
```

---

## Why Sealed Classes?

### Problem with Traditional Approaches

```dart
// ❌ BAD: Non-exhaustive (Bloc pattern)
if (state is UserLoaded) {
  return UserWidget(state.user);
}
// Forgot to handle UserError → Runtime crash
```

### Solution: Sealed Classes

```dart
// ✅ GOOD: Compiler enforces exhaustiveness
switch (state) {
  case Initial(): ...
  case Loading(): ...
  case Success(): ...
  case Failure(): ...
  // Missing a case? Compile error!
}
```

---

## Key Features

### 1. previousData in Loading & Error

**Unique to Reqry**: Most state management discards old data on refetch.

```dart
// Traditional approach (TanStack Query, Riverpod)
Loading → Show spinner (data disappears)

// Reqry approach
Loading(previousData: oldData) → Show stale data + subtle indicator
```

**UX Impact**:

- ✅ No jarring blank screens on refresh
- ✅ Users see content immediately
- ✅ Background updates are seamless

### 2. updatedAt Tracking

Every `Success` state knows when it was fetched:

```dart
case Success(:final data, :final updatedAt):
  final age = DateTime.now().difference(updatedAt);
  if (age > Duration(minutes: 5)) {
    showStalenessWarning();
  }
```

**Use Cases**:

- Stale-while-revalidate strategies
- "Updated 5m ago" indicators
- Cache expiration logic

### 3. Pattern Matching Syntax

Dart 3 destructuring makes state handling elegant:

```dart
// Extract fields directly in pattern
case Success(:final data, :final updatedAt):
  print('Data: $data, fetched at $updatedAt');

case Loading(:final previousData):
  if (previousData != null) {
    showStaleData(previousData);
  }
```

---

## API Surface

### Core Methods

```dart
class QoraState<T> {
  // Properties
  bool get hasData;              // Has usable data (Success or Loading/Error with previousData)
  T? get dataOrNull;             // Extract data or null
  bool get isLoading;            // Is Loading state
  bool get isSuccess;            // Is Success state
  bool get isError;              // Is Error state
  Object? get errorOrNull;       // Extract error or null

  // Transformation
  QoraState<R> map<R>(R Function(T) transform);
  
  // Callbacks
  void when({...});              // Execute callbacks per state
  R maybeWhen<R>({...});         // Partial pattern matching
}
```

### Extensions

```dart
// QoraStateExtensions
state.requireData()              // Throws if no data
state.successDataOrNull          // Ignores previousData
state.isFirstLoad                // Loading without previousData
state.isRefreshing               // Loading with previousData
state.isStale(Duration)          // Check freshness
state.mapSuccess<R>(...)         // Transform only if Success
state.combine(other, combiner)   // Merge two states

// Stream Extensions
stream.whereHasData()            // Filter to states with data
stream.whereSuccess()            // Filter to Success only
stream.data()                    // Extract data stream
stream.mapData<R>(...)           // Transform data type
stream.debounceLoading(...)      // Delay loading indicators
```

### Utilities

```dart
// Combine multiple states
QoraStateUtils.combineList(states)      // List<State> → State<List>
QoraStateUtils.combine2(s1, s2)         // (State, State) → State<(T1, T2)>
QoraStateUtils.combine3(s1, s2, s3)     // State<(T1, T2, T3)>
```

---

## Serialization

### Codec Pattern

```dart
final codec = QoraStateCodec<User>(
  encode: (user) => user.toJson(),
  decode: (json) => User.fromJson(json),
);

// Encode
final json = codec.encodeState(state);
await storage.write('user', jsonEncode(json));

// Decode
final jsonStr = await storage.read('user');
final state = codec.decodeState(jsonDecode(jsonStr));
```

### Persistence Adapters

#### In-Memory (Testing)

```dart
final persistence = InMemoryPersistence<User>();
await persistence.save('key', state);
final loaded = await persistence.load('key');
```

#### SharedPreferences

```dart
final codec = QoraStateCodec<User>(...);
final persistence = SharedPreferencesPersistence<User>(
  prefs: await SharedPreferences.getInstance(),
  codec: codec,
);

await persistence.save('current_user', userState);
final restored = await persistence.load('current_user');
```

---

## Performance Considerations

### Memory Impact of previousData

**Scenario**: Large dataset refetch

```dart
// 1000 items loaded
Success(data: List<1000 items>)

// User refreshes
Loading(previousData: List<1000 items>)  // 2x memory!
```

**Mitigation Strategies**:

1. **Limit previousData size**:

   ```dart
   Loading(
     previousData: data.length > 100 ? data.take(100).toList() : data,
   )
   ```

2. **Opt-out flag** (future feature):

   ```dart
   client.fetch(
     key: ['large-dataset'],
     queryFn: fetchData,
     keepPreviousData: false,  // Discard on refetch
   )
   ```

3. **WeakReference** (future exploration):

   ```dart
   Loading(
     previousDataRef: WeakReference(data),  // GC can claim
   )
   ```

### Hash/Equality Cost

- `Initial` / `Loading` / `Success` / `Error` use `Object.hash`
- Equality checks are **O(1)** for primitives
- Deep equality for complex `data` depends on `T`'s `==` implementation

**Recommendation**: Use immutable data classes (freezed, built_value, equatable).

---

## Comparison with Alternatives

### vs Riverpod AsyncValue

| Feature | Reqry | Riverpod |
|---------|-------|----------|
| Sealed classes | ✅ | ✅ |
| previousData in Loading | ✅ | ❌ |
| previousData in Error | ✅ | ❌ |
| updatedAt tracking | ✅ | ❌ |
| Pattern matching | ✅ | ✅ (via `when`) |

### vs Bloc State

| Feature | Reqry | Bloc |
|---------|-------|------|
| Exhaustiveness | ✅ Compile-time | ❌ Runtime |
| previousData | ✅ Built-in | ❌ Manual |
| Generic types | ✅ `State<T>` | ❌ Per-bloc |
| Boilerplate | ✅ Minimal | ❌ High |

---

## Testing Strategy

### Unit Tests

```dart
test('Loading preserves previous data', () {
  const state = Loading<String>(previousData: 'old');
  
  expect(state.hasData, isTrue);
  expect(state.dataOrNull, equals('old'));
  expect(state.isRefreshing, isTrue);
});
```

### Widget Tests

```dart
testWidgets('Shows stale data while loading', (tester) async {
  await tester.pumpWidget(
    buildWithState(Loading<String>(previousData: 'stale')),
  );
  
  expect(find.text('stale'), findsOneWidget);
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
});
```

### Integration Tests

```dart
test('State transitions correctly', () async {
  final stream = Stream.fromIterable([
    Initial<String>(),
    Loading<String>(),
    Success.now('data'),
    Loading<String>(previousData: 'data'),
    Success.now('new data'),
  ]);
  
  final states = await stream.toList();
  expect(states[2], isA<Success<String>>());
  expect(states[3].dataOrNull, equals('data'));
});
```

---

## Best Practices

### ✅ DO

```dart
// Use pattern matching for exhaustiveness
switch (state) {
  case Initial(): ...
  case Loading(): ...
  case Success(): ...
  case Failure(): ...
}

// Preserve previousData on refetch
Loading(previousData: currentData)

// Check freshness
if (state.isStale(Duration(minutes: 5))) {
  refetch();
}

// Combine states
final combined = userState.combine(
  postsState,
  (user, posts) => UserDashboard(user, posts),
);
```

### ❌ DON'T

```dart
// Don't use incomplete pattern matching
if (state is Success) { ... }  // Ignores Loading/Error

// Don't discard previousData
Loading()  // Should be Loading(previousData: ...)

// Don't ignore updatedAt
case Success(:final data):
  display(data);  // Consider showing freshness

// Don't hold large previousData indefinitely
// (implement size limits or TTL)
```

---

## Migration Guide

### From Bloc

```dart
// Before (Bloc)
abstract class UserState {}
class UserInitial extends UserState {}
class UserLoading extends UserState {}
class UserLoaded extends UserState {
  final User user;
  UserLoaded(this.user);
}
class UserError extends UserState {
  final String message;
  UserError(this.message);
}

// After (Reqry)
QoraState<User>  // That's it!
```

### From Riverpod AsyncValue

```dart
// Before (Riverpod)
AsyncValue<User> state;

state.when(
  data: (user) => UserWidget(user),
  loading: () => Spinner(),
  error: (err, stack) => ErrorWidget(err),
);

// After (Reqry) - More granular
switch (state) {
  case Loading(:final previousData):
    if (previousData != null) {
      return Stack([UserWidget(previousData), Spinner()]);
    }
    return Spinner();
  // ...
}
```

---

## Future Enhancements

### Planned Features

1. **Retry metadata**:

   ```dart
   Failure(
     error: err,
     retryCount: 3,
     nextRetryAt: DateTime,
   )
   ```

2. **Optimistic state**:

   ```dart
   Optimistic(
     data: localData,
     pendingMutation: mutation,
   )
   ```

3. **Partial data**:

   ```dart
   Success(
     data: partialData,
     isPartial: true,  // More data available
   )
   ```

---

## License

Part of the Reqry project. See main LICENSE file.

## Contributors

- Architecture: Inspired by TanStack Query + Riverpod
- Implementation: Pure Dart 3 sealed classes
- Maintained by: Meragix Team
