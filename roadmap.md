# Roadmap

v0.1.0 - MVP Core         ✅ Pure Dart foundation
v0.2.0 - Flutter Basic    🎨 Basic Flutter widgets
v0.3.0 - Mutations        🔄 Optimistic updates
v0.4.0 - Persistence      💾 Offline-first
v0.5.0 - Network Aware    📡 Connectivity management
v0.6.0 - Infinite         ∞  Pagination support
v0.7.0 - Hooks            🪝 flutter_hooks integration
v0.8.0 - DevTools         🛠️ Developer experience
v0.9.0 - Advanced         🚀 Performance & edge cases
v1.0.0 - Production Ready 🎉 Stable release

<!-- 
base in docs/README.md update docs/content with all changed 
-->

## v1.0.0 - Production Ready 🎉

**Objectif** : Stable, documenté, prêt pour prod

### Checklist

#### Code Quality

- ✅ 95%+ test coverage sur tous les packages
- ✅ 0 issues analyzer
- ✅ Performance benchmarks
- ✅ Memory leak tests
- ✅ Code review complet

#### Documentation

- ✅ Site web complet (VitePress ou Docusaurus)
- ✅ Getting Started guide
- ✅ API Reference complète
- ✅ Migration guides (depuis Riverpod, Bloc, etc.)
- ✅ Best practices
- ✅ Troubleshooting guide
- ✅ Video tutorials

#### Examples

- ✅ 10+ exemples d'apps complètes
- ✅ Templates de démarrage
- ✅ Snippets VSCode/Android Studio

#### Community

- ✅ Discord server
- ✅ GitHub Discussions
- ✅ Contributing guide
- ✅ Code of conduct

#### Marketing

- ✅ Blog post de lancement
- ✅ Reddit /r/FlutterDev post
- ✅ Twitter/X announcement
- ✅ Comparison avec TanStack Query
- ✅ Benchmark vs autres solutions

#### Concurrence

- <https://pub.dev/packages/flutter_query>
- <https://pub.dev/packages/cached_query>

- <https://pub.dev/packages/fluquery>
- <https://pub.dev/packages/fquery>
- <https://pub.dev/packages/zenquery>

- <https://pub.dev/packages/async_query>
- <https://pub.dev/packages/riverpod_query>
- <https://pub.dev/packages/graphql_flutter>
- <https://pub.dev/packages/ferry>

update docs config
<!-- https://docus.dev/fr/concepts/configuration -->
<!-- https://docus.dev/fr/concepts/customization -->

examples/
├── 01_basic_query/          ← App complète
├── 02_mutations/            ← App complète
├── 03_infinite_scroll/      ← App complète
└── 07_complete_todo_app/    ← App qui combine tout

<!-- Pour la documentation technique de Qora, nous devons adopter un ton 'Senior Architect' : concis, autoritaire et structuré

docs/content/1.getting-started

Corrige cette sections de docs en adoptant un ton technique, affirmatif et professionnel.

Contraintes strictes :
- Supprime totalement les tirets cadratins (—).
- Évite le ton conversationnel.
- Pas de formulations informelles.
- Pas de questions rhétoriques.
- Utilise des phrases déclaratives claires et structurées.
- Privilégie la précision technique.
- Remplace les incises par des phrases distinctes si nécessaire.
- Évite les adjectifs vagues ou marketing.
- Style sobre, calme, senior engineer.

Objectif :
Obtenir une documentation qui ressemble à une spec technique ou à une documentation d’architecture, pas à un article de blog. 

-- 
Regarde cet exemple de transformation :

Version IA (Lourde) : La persistance permet de garder les données offline — c'est une feature clé de Qora.

Version Senior (Impact) : La persistance garantit la disponibilité des données hors-ligne. Il s'agit d'une fonctionnalité centrale de Qora.

Tu vois la différence ? La deuxième version est affirmative, calme et professionnelle. La première est une conversation informelle.
-->