---
seo:
  title: Qora | Bulletproof Server-State for Dart & Flutter
  description: High-performance, type-safe, and offline-ready state management. Stop managing data, start declaring intent.
---

::u-page-hero
---
orientation: horizontal
---

#title
Bulletproof [Server-State]{.text-primary} for Dart

#description
Stop managing data. Start declaring intent. Fast, Typed, and Offline-ready state management for Flutter. Built for developers who demand reliability.

#headline
  :::u-badge
  ---

color: success
  variant: outline
  class: rounded-full
  ---

  v0.1.0 is now available
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
  to: <https://github.com/meragix/qora>
  variant: outline
  ---

  Star on GitHub
  :::

#default
  :::prose

  ```dart [example.dart]
final profile = await qora.fetch<User>(
    // Query Key - Unique ID for caching & invalidation
    key: ['user', userId],

    // Query function with abort signal support
    fetcher: (signal) async {
      final raw = awaitapi.getUser(userId, signal);
      return User.fromJson(raw);
    }

    options: QoraOptions(
      staleTime: 30.seconds, // When data becomes "old"
      cacheTime: 5.minutes,  // How long it stays in memory
    )
);
  ```
  :::
::

::u-page-section
#title
Engineered for Performance

#features
  :::u-page-feature
  --- 

icon: i-lucide-brain
  ---

  #title
  Zero-Config [Caching]{.text-primary}
  
  #description
  Qora automatically stores and deduplicates your API responses. One request for multiple widgets, zero manual state management.
  :::

  :::u-page-feature
  ---

icon: i-lucide-refresh-cw
  ---

  #title
  Intelligent [Background Sync]{.text-primary}
  
  #description
  Display cached data instantly while silently refreshing in the background. Your app stays fresh without ever blocking the user.
  :::

  :::u-page-feature
  ---

icon: i-lucide-database
  ---

  #title
  Bulletproof [Offline Support]{.text-primary}
  
  #description
  Built-in persistence with plug-and-play storage (Hive, SharedPrefs). Your data remains accessible even in the most unstable network conditions.
  :::

  :::u-page-feature
  ---

icon: i-lucide-zap
  ---

  #title
  Automatic [Resource Cleanup]{.text-primary}
  
  #description
  Qora cancels network requests automatically when widgets are disposed. Save battery, bandwidth, and prevent memory leaks without effort.
  :::

  :::u-page-feature
  ---

icon: i-lucide-layers
  ---

  #title
  Smart [Request Deduplication]{.text-primary}
  
  #description
  Stop wasting bandwidth. If multiple components request the same data simultaneously, Qora executes a single network call and shares the result across your entire app.
  :::

  :::u-page-feature
  ---

icon: i-lucide-clock
  target: _blank
  to: <https://ui.nuxt.com/components/content-search>
  ---

  #title
  Fine-grained [Stale Time]{.text-primary} Control
  
  #description
  Take total control over data freshness. Define precisely how long data stays "fresh" per query. Qora intelligently triggers background refreshes only when necessary, balancing UX and server load.
  :::
::
