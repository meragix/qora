---
seo:
  title: Qora | Gestion du state serveur pour Dart & Flutter
  description: Récupération de données déclarative avec cache SWR, mutations optimistes, déduplication des requêtes, persistance hors-ligne et DevTools intégrés. Noyau Dart pur, prêt pour Flutter.
---

::u-page-hero
---
orientation: horizontal
---

#title
State serveur pour [Dart & Flutter]{.text-primary}

#description
Déclarez les données dont vous avez besoin. Qora les récupère, les met en cache, déduplique les requêtes concurrentes et les maintient à jour automatiquement. Les mutations incluent les mises à jour optimistes et le rollback automatique.

#headline
  :::u-badge
  ---
  color: success
  variant: outline
  class: rounded-full
  ---
  v1.0.0 est disponible
  :::

#links
  :::u-button
  ---
  color: neutral
  size: xl
  to: /getting-started/installation
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

  ```dart [main.dart]
  // Un seul appel : mis en cache, dédupliqué, rafraîchi en arrière-plan.
  final user = await client.fetchQuery<User>(
    key: ['user', userId],
    fetcher: () => api.getUser(userId),
    options: QoraOptions(staleTime: Duration(minutes: 5)),
  );

  // Mise à jour optimiste : l'UI reflète le changement avant la réponse serveur.
  // En cas d'erreur, Qora effectue le rollback automatiquement.
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
Tout ce dont le state serveur a besoin. Rien de superflu.

#features
  :::u-page-feature
  ---
  icon: i-lucide-layers-3
  ---
  #title
  [Cache SWR]{.text-primary}
  #description
  Retourne les données mises en cache immédiatement, puis revalide en arrière-plan. Configurez le temps de stale et le temps de cache par requête ou globalement. Les données fraîches parviennent à l'utilisateur sans scintillement de chargement.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-git-merge
  ---
  #title
  [Déduplication des requêtes]{.text-primary}
  #description
  Plusieurs widgets demandant la même clé simultanément déclenchent exactement un seul appel réseau. Le résultat est partagé entre tous les abonnés dès qu'il est résolu.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-zap
  ---
  #title
  [Mutations optimistes]{.text-primary}
  #description
  Mettez à jour le cache avant la réponse du serveur. En cas d'échec de la requête, Qora restaure le snapshot précédent automatiquement. Aucune logique de rollback manuelle requise.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-refresh-cw
  ---
  #title
  [Synchronisation en arrière-plan]{.text-primary}
  #description
  Les requêtes périmées sont récupérées automatiquement lorsque l'application revient au premier plan ou que l'appareil se reconnecte au réseau. Les hooks de cycle de vie et de connectivité intégrés gèrent cela sans configuration.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-hard-drive
  ---
  #title
  [Persistance hors-ligne]{.text-primary}
  #description
  Hydratez le cache depuis le disque au démarrage avec `PersistQoraClient`. Adaptateurs prêts à l'emploi pour Hive et SharedPreferences. Le cache survit aux redémarrages de l'application.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-link
  ---
  #title
  [Dépendances de requêtes]{.text-primary}
  #description
  Déclarez qu'une requête dépend d'une autre avec `dependsOn`. La requête dépendante attend que sa dépendance ait des données, puis se relance de façon réactive à chaque changement de la valeur en amont.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-monitor
  ---
  #title
  [DevTools intégrés]{.text-primary}
  #description
  Inspectez chaque entrée du cache, rejouez la timeline des événements et déclenchez des commandes de refetch ou d'invalidation depuis un panneau flottant dans l'application. Une seule ligne de configuration. Une extension IDE Flutter DevTools dédiée est en développement.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-package
  ---
  #title
  [Noyau Dart pur]{.text-primary}
  #description
  La bibliothèque principale n'a aucune dépendance Flutter. Utilisez-la dans des applications Flutter, des outils CLI Dart, des services backend ou des packages partagés. La couche Flutter ajoute des widgets et l'intégration du cycle de vie par-dessus.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-fast-forward
  ---
  #title
  [Prefetch]{.text-primary}
  #description
  Préchauffez le cache avant que l'utilisateur ne navigue. Appelez `prefetch` sur n'importe quelle clé et les données sont prêtes lorsque l'écran se monte. Respecte `staleTime` — les entrées déjà fraîches ne sont pas récupérées à nouveau.
  :::
::

::u-page-section
  :::u-page-c-t-a
  ---
  title: Démarrez en moins de cinq minutes
  description: Ajoutez le package, encapsulez votre application et écrivez votre première requête. Aucun boilerplate, aucune génération de code, aucun scaffolding de provider requis.
  class: dark:bg-neutral-950
  links:
    - label: Lire la documentation
      to: '/getting-started/installation'
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
