# qora_hooks

`flutter_hooks` integration for [Qora](https://github.com/meragix/qora) — provides
`useQuery`, `useMutation`, `useInfiniteQuery`, and `useQueryClient`.

## Why a separate package?

`flutter_hooks` is an optional dependency. Bundling hooks inside `qora` or
`qora_flutter` would impose it on every user, even those who prefer
`QoraBuilder` / `QoraMutationBuilder`. A separate package keeps things opt-in.

## Getting started

Add both `qora_flutter` and `qora_hooks` to your `pubspec.yaml`:

```yaml
dependencies:
  qora_flutter: ^0.7.0
  qora_hooks: ^0.7.0
  flutter_hooks: ^0.20.0 # Make sure to have flutter_hooks installed
```

Wrap your app with `QoraScope`:

```dart
void main() {
  runApp(
    QoraScope(
      client: QoraClient(),
      child: const MyApp(),
    ),
  );
}
```

## Usage

### `useQuery<T>`

Fetches data on mount, caches it, and rebuilds the widget on every state
change. Initialises from the cache synchronously — no loading flash when
data is already fresh.

```dart
class UserScreen extends HookWidget {
  final String userId;
  const UserScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final state = useQuery<User>(
      key: ['users', userId],
      fetcher: () => Api.getUser(userId),
      options: const QoraOptions(staleTime: Duration(minutes: 5)),
    );

    return switch (state) {
      Initial() => const SizedBox.shrink(),
      Loading() => const CircularProgressIndicator(),
      Success(:final data) => UserCard(data),
      Failure(:final error) => ErrorView(error),
    };
  }
}
```

### `useMutation<TData, TVariables>`

```dart
class EditProfileScreen extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final mutation = useMutation<User, UpdateUserInput>(
      mutator: (input) => Api.updateUser(input),
      options: MutationOptions(
        onSuccess: (user, _, __) async =>
            QoraScope.of(context).invalidate(['users', user.id]),
      ),
    );

    return ElevatedButton(
      onPressed: mutation.isPending
          ? null
          : () => mutation.mutate(UpdateUserInput(name: 'Alice')),
      child: mutation.isPending
          ? const CircularProgressIndicator()
          : const Text('Save'),
    );
  }
}
```

### `useInfiniteQuery<TData, TPageParam>`

```dart
final query = useInfiniteQuery<PostsPage, String?>(
  key: const ['posts'],
  fetcher: (cursor) => Api.getPosts(cursor: cursor),
  getNextPageParam: (page) => page.nextCursor,
  initialPageParam: null,
);

final allPosts = query.pages.expand((p) => p.posts).toList();
```

Call `query.fetchNextPage()` when the user reaches the end of the list to
load the next page. `query.hasNextPage` becomes `false` when
`getNextPageParam` returns `null`.

### `useQueryClient`

```dart
final client = useQueryClient(); // nearest QoraClient from QoraScope
```

## Additional information

- Source: [github.com/meragix/qora](https://github.com/meragix/qora/tree/main/packages/hooks)
- Issues: [github.com/meragix/qora/issues](https://github.com/meragix/qora/issues)
- Documentation: **[qora.meragix.dev](https://qora.meragix.dev)**
