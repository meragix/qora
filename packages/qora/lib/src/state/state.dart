/// Core state management for Qora queries.
///
/// This library provides a sealed class hierarchy for representing query states:
/// - [Initial]: Query hasn't started
/// - [Loading]: Actively fetching (with optional previousData)
/// - [Success]: Data fetched successfully
/// - [Error]: Fetch failed (with optional previousData)
///
/// ## Basic Usage
///
/// ```dart
/// // Pattern matching (exhaustive)
/// switch (state) {
///   case Initial():
///     return Text('Ready');
///   case Loading(:final previousData):
///     return previousData != null
///       ? Stack(children: [DataView(previousData), Spinner()])
///       : Spinner();
///   case Success(:final data):
///     return DataView(data);
///   case Error(:final error, :final previousData):
///     return Column(children: [
///       if (previousData != null) DataView(previousData),
///       ErrorBanner(error),
///     ]);
/// }
/// ```
///
/// ## Extensions
///
/// ```dart
/// // Check if state has usable data
/// if (state.hasData) {
///   final data = state.dataOrNull!;
/// }
///
/// // Transform data type
/// final namesState = usersState.map((users) =>
///   users.map((u) => u.name).toList()
/// );
///
/// // Combine multiple states
/// final combined = userState.combine(
///   postsState,
///   (user, posts) => UserWithPosts(user, posts),
/// );
/// ```
///
/// ## Serialization
///
/// ```dart
/// // Create codec
/// final codec = QoraStateCodec<User>(
///   encode: (user) => user.toJson(),
///   decode: (json) => User.fromJson(json),
/// );
///
/// // Save to storage
/// final json = codec.encodeState(state);
/// await prefs.setString('state', jsonEncode(json));
///
/// // Restore
/// final restored = codec.decodeState(jsonDecode(jsonStr));
/// ```
///
/// ## Stream Extensions
///
/// ```dart
/// // Filter to Success states only
/// stream.whereSuccess().listen((success) {
///   print(success.data);
/// });
///
/// // Extract just the data
/// stream.data().listen((data) {
///   updateUI(data);
/// });
///
/// // Debounce loading states
/// stream.debounceLoading(Duration(milliseconds: 300));
/// ```
library;

export 'qora_state.dart';
export 'state_extensions.dart';
export 'state_serialization.dart';
