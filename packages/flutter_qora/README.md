# flutter_qora

The Flutter integration for Qora. Provides reactive widgets and hooks to bind server state to your UI seamlessly.

## Features

- **QoraBuilder**: Reactive widget that rebuilds only when data changes.
- **Auto-Cancellation:**: Automatically triggers `AbortSignal` when the widget is disposed.
- **Lifecycle Management**: Handles background refetching when the app returns to foreground.

## Installation

```yaml
# It automatically depends on `qora` package, so you don't need to add it separately.
dependencies:
  flutter_qoraa: ^0.1.0
```

## Usage

```dart
class UserDetailScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return QoraBuilder<User>(
      queryKey: QoraKey(['user', userId]),
      queryFn: () => ApiService.getUser(userId),
      builder: (context, state) {
        return state.when(
          initial: () => Center(child: Text('Chargement...')),
          loading: (prev) => prev != null
                ? UserDetailView(user: prev, isRefreshing: true)
                : Center(child: CircularProgressIndicator()),
          success: (user, updatedAt) {
            return UserDetailView(user: user,updatedAt: updatedAt);
          },
          failure: (error, _, prev) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text('Erreur: $error'),
                  SizedBox(height: 16),
                  ElevatedButton(
                  onPressed: () {
                    context.qora.invalidateQuery(
                      QoraKey(['user', userId]),
                    );
                  },
                  child: Text('Réessayer'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
```

## Performance vs DX

- **Advantage**: Eliminates `setState` or complex `Bloc` boilerplate for server data.
- **Inconvenience**: Adds a layer to the widget tree (mitigated by high-performance build cycles).

## Documentation

For detailed API documentation, please refer to the [Docs](https://meragix.github.io/qora).
