---
seo:
  title: Server state for Flutter apps that keep working offline
  description: Fetch, cache and sync server data in Flutter. Saved data on cold start, queries that pause offline, writes queued and replayed on reconnect. Inspired by TanStack Query, no code generation.
---

::u-page-hero
---
orientation: horizontal
---

#title
Server state for Flutter apps that [keep working offline]{.text-primary}

#description
Qora fetches, caches and synchronizes server data, and keeps your app usable when the network is not. Saved data shows on a cold start, queries pause offline and resume on reconnect, and writes made offline are queued and replayed in order.

#headline
  :::u-badge
  ---
  color: success
  variant: outline
  class: rounded-full
  ---
  v1.3.0 is now available
  :::

#links
  :::u-button
  ---
  color: neutral
  size: xl
  to: /en/getting-started/installation
  trailing-icon: i-lucide-arrow-right
  ---
  Get started
  :::

  :::u-button
  ---
  color: neutral
  icon: simple-icons-github
  size: xl
  to: 'https://github.com/meragix/qora'
  variant: outline
  ---
  Star on GitHub
  :::

#default
  :::prose

  ```dart [user_screen.dart]
  // Cached data on the first frame, kept during refetches and errors.
  QoraBuilder<User>(
    queryKey: ['users', userId],
    fetcher: () => api.getUser(userId),
    builder: (context, state, fetchStatus) => Column(children: [
      if (fetchStatus == FetchStatus.paused) const OfflineBanner(),
      if (state.dataOrNull case final user?) UserCard(user),
    ]),
  )

  // Written offline: shown now, sent when the device reconnects.
  QoraMutationBuilder<Comment, String, void>(
    mutator: (text) => api.postComment(text),
    options: MutationOptions(
      offlineQueue: true,
      optimisticResponse: (text) => Comment.draft(text),
      invalidates: [['comments']],
    ),
    builder: (context, state, mutate) => SendButton(onSend: mutate),
  )
  ```

  :::
::

::u-page-section
#title
Offline, built in

#description
Not a refetch-on-reconnect flag: three pieces that work together, wired by one widget.

#features
  :::u-page-feature
  ---
  icon: i-lucide-hard-drive
  to: /en/recipes/persistence
  ---
  #title
  [Saved data on cold start]{.text-primary}
  #description
  `PersistQoraClient` writes successful fetches to your storage and restores them before the first frame. Stale entries show immediately and revalidate in the background.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-wifi-off
  to: /en/flutter-integration/network-status
  ---
  #title
  [Queries that know they are offline]{.text-primary}
  #description
  Queries pause while the device is offline and report it through `FetchStatus.paused`, so the UI can tell "no network" from "loading". They resume on reconnect, with jitter to avoid a thundering herd.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-list-ordered
  to: /en/examples/offline-first
  ---
  #title
  [Writes that wait for the network]{.text-primary}
  #description
  Mutations made offline return an optimistic result right away and are replayed in order on reconnect. The queue is held in memory today; persisting it across app restarts is the focus of 1.4.
  :::
::

::u-page-section
#title
Everything else you expect from a query library

#features
  :::u-page-feature
  ---
  icon: i-lucide-layers-3
  ---
  #title
  Stale-while-revalidate
  #description
  Cached data renders on the first frame; fresh data replaces it in the background.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-git-merge
  ---
  #title
  Request deduplication
  #description
  Ten widgets watching the same key share one cache entry and one network call.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-refresh-cw
  ---
  #title
  Precise invalidation
  #description
  By exact key, by key prefix, by predicate, or by tag. Mounted queries refetch automatically.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-zap
  ---
  #title
  Optimistic updates
  #description
  Update the cache in `onMutate`, restore the snapshot in `onError`, invalidate on success.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-split
  ---
  #title
  Two-axis state
  #description
  A sealed `QoraState` you can match exhaustively, plus a separate `FetchStatus`. Previous data is never lost on refetch or error.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-infinity
  ---
  #title
  Infinite queries
  #description
  Cursor or page based pagination with a `maxPages` memory window.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-anchor
  ---
  #title
  Builders or hooks
  #description
  `QoraBuilder` widgets, or `useQuery` and `useMutation` with `qora_hooks`.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-monitor
  ---
  #title
  In-app DevTools
  #description
  A debug-only overlay that shows every query, its state, its staleness and the mutation queue.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-package
  ---
  #title
  Pure Dart core
  #description
  No Flutter dependency and no code generation. Works in CLIs, servers and tests.
  :::
::

::u-page-section
#title
Works with what you already use

#description
Qora owns server data. Keep your state management for UI state, your HTTP client for transport.

#features
  :::u-page-feature
  ---
  icon: i-lucide-boxes
  to: /en/third-party/with-riverpod
  ---
  #title
  Riverpod
  #description
  Expose Qora queries to providers.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-workflow
  to: /en/third-party/with-bloc
  ---
  #title
  BLoC
  #description
  Feed cubits and blocs from the cache.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-globe
  to: /en/third-party/with-dio
  ---
  #title
  Dio and GraphQL
  #description
  Map transport errors, refresh tokens, wrap `graphql` and `ferry`.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-arrow-right-left
  to: /en/getting-started/migrating-from-other-libraries
  ---
  #title
  Coming from another library
  #description
  API mapping from `cached_query`, `flutter_query` and TanStack Query.
  :::
::

::u-page-section
  :::u-page-c-t-a
  ---
  title: Your first query in five minutes
  description: Add one package, wrap your app with QoraScope.auto, and bind a query to a widget. No code generation, no provider scaffolding.
  class: dark:bg-neutral-950
  links:
    - label: Read the docs
      to: '/en/getting-started/installation'
      trailingIcon: i-lucide-arrow-right
      size: xl
    - label: View on GitHub
      to: 'https://github.com/meragix/qora'
      target: _blank
      variant: outline
      icon: i-simple-icons-github
      size: xl
  ---
  :::
::
