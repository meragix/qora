# `qora_hooks` — flutter_hooks Integration

> `packages/flutter/qora_hooks` | Dépend de `qora` + `flutter_hooks`

---

## Sommaire

1. [Pourquoi un package séparé](#1-pourquoi-un-package-séparé)
2. [Arborescence](#2-arborescence)
3. [pubspec.yaml](#3-pubspecyaml)
4. [Implémentation des hooks](#4-implémentation-des-hooks)
5. [Doc Docus — content/](#5-doc-docus--content)

---

## 1. Pourquoi un package séparé

`flutter_hooks` est une dépendance optionnelle. Si `useQuery` vivait dans `qora`, tous les
utilisateurs qui n'utilisent pas `flutter_hooks` se retrouveraient avec cette dépendance dans
leur bundle sans l'avoir demandé. Un package séparé respecte le choix de chacun.

```
packages/flutter/
├── qora/           → QoraBuilder, QoraScope  (pas de flutter_hooks)
└── qora_hooks/     → useQuery, useMutation   (requiert flutter_hooks)
```

Règle de dépendance : `qora_hooks` dépend de `qora` + `flutter_hooks`. Jamais l'inverse.

---

## 2. Arborescence

```
packages/flutter/qora_hooks/
├── lib/
│   ├── src/
│   │   ├── hooks/
│   │   │   ├── use_query.dart           ← useQuery<T>
│   │   │   ├── use_mutation.dart        ← useMutation<TData, TVariables>
│   │   │   ├── use_query_client.dart    ← useQueryClient
│   │   │   └── use_infinite_query.dart  ← useInfiniteQuery<T>
│   │   │
│   │   └── internals/
│   │       ├── query_state_hook.dart    ← hook interne — écoute le stream de QueryClient
│   │       └── mutation_state_hook.dart ← hook interne — écoute le stream de mutation
│   │
│   └── qora_hooks.dart                 ← barrel export
│
├── example/
│   └── lib/
│       └── main.dart
└── pubspec.yaml
```

---

## 3. pubspec.yaml

```yaml
name: qora_hooks
description: >
  flutter_hooks integration for qora.
  useQuery, useMutation, useQueryClient and useInfiniteQuery.
version: 0.1.0
repository: https://github.com/yourorg/qora/tree/main/packages/flutter/qora_hooks

environment:
  sdk: ">=3.0.0 <4.0.0"
  flutter: ">=3.19.0"

dependencies:
  flutter:
    sdk: flutter
  flutter_hooks: ^0.21.0   # peer dependency — utilisateur doit l'avoir aussi
  qora: ^1.0.0              # widgets + QoraScope pour useQueryClient
  qora_core: ^1.0.0         # QueryClient, QueryState, MutationState

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
```

---

## 4. Implémentation des hooks

### `use_query_client.dart`

Le plus simple — lit le `QueryClient` depuis le contexte via `QoraScope`.
Identique à `useContext(QueryClientContext)` en React.

```dart
// lib/src/hooks/use_query_client.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:qora/qora.dart';

/// Retourne le [QueryClient] le plus proche dans l'arbre.
/// Lance une [FlutterError] si aucun [QoraScope] n'est trouvé.
QueryClient useQueryClient() {
  final context = useContext();
  return QoraScope.of(context);
}
```

---

### `use_query.dart`

```dart
// lib/src/hooks/use_query.dart
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:qora_core/qora_core.dart';
import 'use_query_client.dart';

/// Hook équivalent à [QoraBuilder] — retourne le [QueryState] courant
/// et se reconstruit automatiquement à chaque changement.
///
/// ```dart
/// final state = useQuery(
///   key: ['users', userId],
///   fetcher: () => api.getUser(userId),
/// );
/// ```
QueryState<T> useQuery<T>({
  required List<Object?> key,
  required Future<T> Function() fetcher,
  QoraOptions options = const QoraOptions(),
}) {
  final client = useQueryClient();

  // État courant — initialisé depuis le cache si disponible
  final state = useState<QueryState<T>>(
    client.getQueryState<T>(key) ?? const QueryState.initial(),
  );

  // S'abonner au stream de cette query
  useEffect(() {
    final sub = client
        .watchQuery<T>(
          key: key,
          fetcher: fetcher,
          options: options,
        )
        .listen((newState) => state.value = newState);

    return sub.cancel; // cleanup automatique au unmount
  }, [Object.hashAll(key)]); // re-subscribe si la key change

  return state.value;
}
```

**Usage :**

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
      QueryInitial()                        => const SizedBox.shrink(),
      QueryLoading(:final previousData)     => previousData != null
          ? UserCard(previousData)
          : const CircularProgressIndicator(),
      QuerySuccess(:final data)             => UserCard(data),
      QueryFailure(:final error)            => ErrorView(error),
    };
  }
}
```

---

### `use_mutation.dart`

```dart
// lib/src/hooks/use_mutation.dart
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:qora_core/qora_core.dart';
import 'use_query_client.dart';

/// Hook pour déclencher une mutation et suivre son état.
///
/// ```dart
/// final mutation = useMutation<User, UpdateUserInput>(
///   mutationFn: (input) => api.updateUser(input),
/// );
///
/// mutation.mutate(UpdateUserInput(name: 'Alice'));
/// ```
MutationHandle<TData, TVariables> useMutation<TData, TVariables>({
  required Future<TData> Function(TVariables variables) mutationFn,
  void Function(TData data, TVariables variables)? onSuccess,
  void Function(Object error, TVariables variables)? onError,
  void Function(TVariables variables)? onMutate, // optimistic update hook
  MutationOptions<TData, TVariables> options = const MutationOptions(),
}) {
  final client = useQueryClient();

  final state = useState<MutationState<TData>>(const MutationState.idle());

  final mutation = useMemoized(
    () => client.createMutation<TData, TVariables>(
      mutationFn: mutationFn,
      onSuccess: onSuccess,
      onError: onError,
      onMutate: onMutate,
      options: options,
    ),
    const [], // créé une seule fois
  );

  // Écouter les changements d'état de la mutation
  useEffect(() {
    final sub = mutation.stateStream
        .listen((newState) => state.value = newState);
    return sub.cancel;
  }, [mutation]);

  // Dispose la mutation quand le widget est démonté
  useEffect(() => mutation.dispose, [mutation]);

  return MutationHandle(
    state: state.value,
    mutate: mutation.mutate,
    mutateAsync: mutation.mutateAsync,
    reset: mutation.reset,
  );
}

/// Retourné par [useMutation] — regroupe l'état et les actions.
class MutationHandle<TData, TVariables> {
  final MutationState<TData> state;

  /// Déclenche la mutation. Les erreurs sont silencieuses (catchées en interne).
  final void Function(TVariables variables) mutate;

  /// Déclenche la mutation et retourne un [Future]. Les erreurs sont propagées.
  final Future<TData> Function(TVariables variables) mutateAsync;

  /// Remet la mutation à l'état [MutationState.idle].
  final void Function() reset;

  // Raccourcis pratiques
  bool get isIdle    => state is MutationIdle;
  bool get isPending => state is MutationPending;
  bool get isSuccess => state is MutationSuccess;
  bool get isError   => state is MutationError;
  TData? get data    => state is MutationSuccess<TData>
      ? (state as MutationSuccess<TData>).data : null;
  Object? get error  => state is MutationError
      ? (state as MutationError).error : null;

  const MutationHandle({
    required this.state,
    required this.mutate,
    required this.mutateAsync,
    required this.reset,
  });
}
```

**Usage :**

```dart
class EditProfileScreen extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final client = useQueryClient();

    final mutation = useMutation<User, UpdateUserInput>(
      mutationFn: (input) => Api.updateUser(input),
      onSuccess: (user, _) {
        // Invalide la query pour forcer un refetch
        client.invalidateQuery(['users', user.id]);
      },
    );

    return Column(
      children: [
        if (mutation.isError)
          ErrorBanner(mutation.error!),

        ElevatedButton(
          onPressed: mutation.isPending
              ? null
              : () => mutation.mutate(UpdateUserInput(name: 'Alice')),
          child: mutation.isPending
              ? const CircularProgressIndicator()
              : const Text('Save'),
        ),
      ],
    );
  }
}
```

---

### `use_infinite_query.dart`

```dart
// lib/src/hooks/use_infinite_query.dart
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:qora_core/qora_core.dart';
import 'use_query_client.dart';

/// Hook pour les listes paginées.
/// Gère automatiquement l'accumulation des pages et le chargement suivant.
///
/// ```dart
/// final query = useInfiniteQuery<PostsPage, int>(
///   key: ['posts'],
///   fetcher: (page) => api.getPosts(page: page),
///   getNextPageParam: (lastPage) => lastPage.nextCursor,
/// );
/// ```
InfiniteQueryHandle<TData, TPageParam> useInfiniteQuery<TData, TPageParam>({
  required List<Object?> key,
  required Future<TData> Function(TPageParam pageParam) fetcher,
  required TPageParam? Function(TData lastPage) getNextPageParam,
  TPageParam initialPageParam = 0 as TPageParam,
  QoraOptions options = const QoraOptions(),
}) {
  final client = useQueryClient();

  final pages = useState<List<TData>>([]);
  final isLoading = useState(false);
  final isFetchingNextPage = useState(false);
  final error = useState<Object?>(null);
  final hasNextPage = useState(true);

  // Chargement de la première page
  useEffect(() {
    _loadFirstPage(
      client: client,
      key: key,
      fetcher: () => fetcher(initialPageParam),
      pages: pages,
      isLoading: isLoading,
      error: error,
    );
    return null;
  }, [Object.hashAll(key)]);

  Future<void> fetchNextPage() async {
    if (!hasNextPage.value || isFetchingNextPage.value) return;

    final nextParam = getNextPageParam(pages.value.last);
    if (nextParam == null) {
      hasNextPage.value = false;
      return;
    }

    isFetchingNextPage.value = true;
    try {
      final newPage = await fetcher(nextParam);
      pages.value = [...pages.value, newPage];
      hasNextPage.value = getNextPageParam(newPage) != null;
    } catch (e) {
      error.value = e;
    } finally {
      isFetchingNextPage.value = false;
    }
  }

  return InfiniteQueryHandle(
    pages: pages.value,
    isLoading: isLoading.value,
    isFetchingNextPage: isFetchingNextPage.value,
    hasNextPage: hasNextPage.value,
    error: error.value,
    fetchNextPage: fetchNextPage,
  );
}

class InfiniteQueryHandle<TData, TPageParam> {
  final List<TData> pages;
  final bool isLoading;
  final bool isFetchingNextPage;
  final bool hasNextPage;
  final Object? error;
  final Future<void> Function() fetchNextPage;

  bool get isEmpty => pages.isEmpty && !isLoading;

  const InfiniteQueryHandle({
    required this.pages,
    required this.isLoading,
    required this.isFetchingNextPage,
    required this.hasNextPage,
    required this.error,
    required this.fetchNextPage,
  });
}
```

**Usage :**

```dart
class PostsScreen extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final query = useInfiniteQuery<PostsPage, String?>(
      key: const ['posts'],
      fetcher: (cursor) => Api.getPosts(cursor: cursor),
      getNextPageParam: (page) => page.nextCursor,
      initialPageParam: null,
    );

    final allPosts = query.pages.expand((p) => p.posts).toList();

    return ListView.builder(
      itemCount: allPosts.length + (query.hasNextPage ? 1 : 0),
      itemBuilder: (context, i) {
        // Loader de fin de liste → déclenche fetchNextPage
        if (i == allPosts.length) {
          if (!query.isFetchingNextPage) query.fetchNextPage();
          return const Center(child: CircularProgressIndicator());
        }
        return PostTile(allPosts[i]);
      },
    );
  }
}
```

---

### `qora_hooks.dart` — barrel export

```dart
// lib/qora_hooks.dart
library qora_hooks;

export 'src/hooks/use_query.dart';
export 'src/hooks/use_mutation.dart';
export 'src/hooks/use_query_client.dart';
export 'src/hooks/use_infinite_query.dart';
```

---
