---
seo:
  title: Qora | Server-State Management for Dart & Flutter
  description: Declarative data fetching with SWR caching, optimistic mutations, request deduplication, offline persistence, and built-in DevTools. Pure Dart core, Flutter-ready.
---

::u-page-hero
---
orientation: horizontal
---

#title
Server State for [Dart & Flutter]{.text-primary}

#description
Declare what data you need. Qora fetches it, caches it, deduplicates concurrent requests, and keeps it fresh — automatically. Mutations ship with optimistic updates and automatic rollback.

#headline
  :::u-badge
  ---
  color: success
  variant: outline
  class: rounded-full
  ---
  v0.9.0 is now available
  :::

#links
  :::u-button
  ---
  color: neutral
  size: xl
  to: /getting-started/installation
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

  ```dart [main.dart]
  // One call: cached, deduplicated, background-refreshed.
  final user = await client.fetchQuery<User>(
    key: ['user', userId],
    fetcher: () => api.getUser(userId),
    options: QoraOptions(staleTime: Duration(minutes: 5)),
  );

  // Optimistic update: UI reflects the change before the server responds.
  // On error, Qora rolls back automatically.
  await controller.mutate(
    key: ['user', userId, 'rename'],
    mutator: (vars) => api.renameUser(vars),
    onMutate: (vars) => client.setQueryData(['user', userId], vars.newUser),
    onError:  (_, ctx) => client.restoreQueryData(['user', userId], ctx),
    onSuccess: (_) => client.invalidateQuery(['user', userId]),
  );
  ```

  :::
::

::u-page-section
#title
Everything server state needs. Nothing it does not.

#features
  :::u-page-feature
  ---
  icon: i-lucide-layers-3
  ---
  #title
  [SWR Caching]{.text-primary}
  #description
  Returns cached data immediately, then revalidates in the background. Configure stale time and cache time per query or globally. Fresh data reaches the user with no loading flicker.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-git-merge
  ---
  #title
  [Request Deduplication]{.text-primary}
  #description
  Multiple widgets requesting the same key simultaneously trigger exactly one network call. The result is shared across all subscribers the moment it resolves.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-zap
  ---
  #title
  [Optimistic Mutations]{.text-primary}
  #description
  Update the cache before the server responds. If the request fails, Qora restores the previous snapshot automatically. No manual rollback logic required.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-refresh-cw
  ---
  #title
  [Background Sync]{.text-primary}
  #description
  Stale queries are refetched automatically when the app returns to the foreground or the device reconnects to the network. Built-in lifecycle and connectivity hooks handle this with zero configuration.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-hard-drive
  ---
  #title
  [Offline Persistence]{.text-primary}
  #description
  Hydrate the cache from disk on startup with `PersistQoraClient`. Plug-and-play adapters for Hive and SharedPreferences. The cache survives app restarts.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-link
  ---
  #title
  [Query Dependencies]{.text-primary}
  #description
  Declare that one query depends on another with `dependsOn`. The dependent query waits until its dependency has data, then re-runs reactively whenever the upstream value changes.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-monitor
  ---
  #title
  [Built-in DevTools]{.text-primary}
  #description
  Inspect every cache entry, replay the event timeline, and trigger refetch or invalidate commands from a floating in-app panel. One line of setup. A dedicated Flutter DevTools IDE extension is in development.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-package
  ---
  #title
  [Pure Dart Core]{.text-primary}
  #description
  The core library has no Flutter dependency. Use it in Flutter apps, Dart CLI tools, backend services, or shared packages. The Flutter layer adds widgets and lifecycle integration on top.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-fast-forward
  ---
  #title
  [Prefetch]{.text-primary}
  #description
  Warm the cache before the user navigates. Call `prefetch` on any key and the data is ready when the screen mounts. Respects `staleTime`, already-fresh entries are not re-fetched.
  :::
::

::u-page-section
  :::u-page-c-t-a
  ---
  title: Start in under five minutes
  description: Add the package, wrap your app, and write your first query. No boilerplate, no code generation, no provider scaffolding required.
  class: dark:bg-neutral-950
  links:
    - label: Read the docs
      to: '/getting-started/installation'
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
