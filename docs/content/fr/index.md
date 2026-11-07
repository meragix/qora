---
seo:
  title: Le state serveur pour les apps Flutter qui fonctionnent hors-ligne
  description: Récupérer, mettre en cache et synchroniser les données serveur dans Flutter. Données sauvegardées au démarrage, requêtes en pause hors-ligne, écritures mises en file et rejouées à la reconnexion. Inspiré de TanStack Query, sans génération de code.
---

::u-page-hero
---
orientation: horizontal
---

#title
Le state serveur pour les apps Flutter qui [fonctionnent hors-ligne]{.text-primary}

#description
Qora récupère, met en cache et synchronise les données serveur, et garde votre application utilisable quand le réseau ne l'est pas. Les données sauvegardées s'affichent dès le démarrage, les requêtes se mettent en pause hors-ligne et reprennent à la reconnexion, et les écritures faites hors-ligne sont mises en file puis rejouées dans l'ordre.

#headline
  :::u-badge
  ---
  color: success
  variant: outline
  class: rounded-full
  ---
  v1.3.0 est disponible
  :::

#links
  :::u-button
  ---
  color: neutral
  size: xl
  to: /fr/getting-started/installation
  trailing-icon: i-lucide-arrow-right
  ---
  Démarrer
  :::

  :::u-button
  ---
  color: neutral
  icon: simple-icons-github
  size: xl
  to: 'https://github.com/meragix/qora'
  variant: outline
  ---
  Star sur GitHub
  :::

#default
  :::prose

  ```dart [user_screen.dart]
  // Données du cache dès la première frame, conservées pendant refetchs et erreurs.
  QoraBuilder<User>(
    queryKey: ['users', userId],
    fetcher: () => api.getUser(userId),
    builder: (context, state, fetchStatus) => Column(children: [
      if (fetchStatus == FetchStatus.paused) const OfflineBanner(),
      if (state.dataOrNull case final user?) UserCard(user),
    ]),
  )

  // Écrit hors-ligne : affiché tout de suite, envoyé à la reconnexion.
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
Le hors-ligne, intégré

#description
Pas un simple flag de refetch à la reconnexion : trois briques qui travaillent ensemble, branchées par un seul widget.

#features
  :::u-page-feature
  ---
  icon: i-lucide-hard-drive
  to: /fr/recipes/persistence
  ---
  #title
  [Données sauvegardées au démarrage]{.text-primary}
  #description
  `PersistQoraClient` écrit les fetchs réussis dans votre stockage et les restaure avant la première frame. Les entrées périmées s'affichent immédiatement et se revalident en arrière-plan.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-wifi-off
  to: /fr/core-concepts/offline
  ---
  #title
  [Des requêtes qui savent qu'elles sont hors-ligne]{.text-primary}
  #description
  Les requêtes se mettent en pause quand l'appareil est hors-ligne et le signalent via `FetchStatus.paused` : l'UI distingue « pas de réseau » de « chargement ». Elles reprennent à la reconnexion, avec du jitter pour éviter le thundering herd.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-list-ordered
  to: /fr/examples/offline-first
  ---
  #title
  [Des écritures qui attendent le réseau]{.text-primary}
  #description
  Les mutations faites hors-ligne renvoient un résultat optimiste immédiatement et sont rejouées dans l'ordre à la reconnexion. La file est en mémoire aujourd'hui ; la persister entre deux redémarrages est l'objectif de la 1.4.
  :::
::

::u-page-section
#title
Tout ce qu'on attend d'une bibliothèque de requêtes

#features
  :::u-page-feature
  ---
  icon: i-lucide-layers-3
  ---
  #title
  Stale-while-revalidate
  #description
  Les données du cache s'affichent dès la première frame ; les données fraîches les remplacent en arrière-plan.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-git-merge
  ---
  #title
  Déduplication des requêtes
  #description
  Dix widgets qui observent la même clé partagent une entrée de cache et un seul appel réseau.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-refresh-cw
  ---
  #title
  Invalidation précise
  #description
  Par clé exacte, par préfixe, par prédicat ou par tag. Les requêtes montées se relancent automatiquement.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-zap
  ---
  #title
  Mises à jour optimistes
  #description
  Mettez à jour le cache dans `onMutate`, restaurez le snapshot dans `onError`, invalidez en cas de succès.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-split
  ---
  #title
  État sur deux axes
  #description
  Un `QoraState` scellé à matcher de façon exhaustive, plus un `FetchStatus` séparé. Les données précédentes ne sont jamais perdues lors d'un refetch ou d'une erreur.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-infinity
  ---
  #title
  Requêtes infinies
  #description
  Pagination par curseur ou par page avec une fenêtre mémoire `maxPages`.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-anchor
  ---
  #title
  Builders ou hooks
  #description
  Les widgets `QoraBuilder`, ou `useQuery` et `useMutation` avec `qora_hooks`.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-monitor
  ---
  #title
  DevTools dans l'app
  #description
  Un overlay actif en debug uniquement qui affiche chaque requête, son état, sa fraîcheur et la file de mutations.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-package
  ---
  #title
  Noyau Dart pur
  #description
  Aucune dépendance Flutter et aucune génération de code. Fonctionne dans les CLI, les serveurs et les tests.
  :::
::

::u-page-section
#title
Compatible avec ce que vous utilisez déjà

#description
Qora gère les données serveur. Gardez votre state management pour l'état de l'UI et votre client HTTP pour le transport.

#features
  :::u-page-feature
  ---
  icon: i-lucide-boxes
  to: /fr/third-party/with-riverpod
  ---
  #title
  Riverpod
  #description
  Exposer les requêtes Qora aux providers.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-workflow
  to: /fr/third-party/with-bloc
  ---
  #title
  BLoC
  #description
  Alimenter cubits et blocs depuis le cache.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-globe
  to: /fr/third-party/with-dio
  ---
  #title
  Dio et GraphQL
  #description
  Mapper les erreurs de transport, rafraîchir les tokens, encapsuler `graphql` et `ferry`.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-arrow-right-left
  to: /fr/getting-started/migrating-from-other-libraries
  ---
  #title
  Vous venez d'une autre bibliothèque
  #description
  Correspondance des API depuis `cached_query`, `flutter_query` et TanStack Query.
  :::
::

::u-page-section
  :::u-page-c-t-a
  ---
  title: Votre première requête en cinq minutes
  description: Ajoutez un package, enveloppez votre app avec QoraScope.auto et liez une requête à un widget. Pas de génération de code, pas d'échafaudage de providers.
  class: dark:bg-neutral-950
  links:
    - label: Lire la documentation
      to: '/fr/getting-started/installation'
      trailingIcon: i-lucide-arrow-right
      size: xl
    - label: Voir sur GitHub
      to: 'https://github.com/meragix/qora'
      target: _blank
      variant: outline
      icon: i-simple-icons-github
      size: xl
  ---
  :::
::
