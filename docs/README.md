# Docus Default Starter

> A beautiful, minimal starter for creating documentation with Docus

This is the default Docus starter template that provides everything you need to build beautiful documentation sites with Markdown and Vue components.

> [!TIP]
> If you're looking for i18n support, check out the [i18n starter](https://github.com/nuxt-themes/docus/tree/main/.starters/i18n).

## ✨ Features

- 🎨 **Beautiful Design** - Clean, modern documentation theme
- 📱 **Responsive** - Mobile-first responsive design  
- 🌙 **Dark Mode** - Built-in dark/light mode support
- 🔍 **Search** - Full-text search functionality
- 📝 **Markdown Enhanced** - Extended markdown with custom components
- 🎨 **Customizable** - Easy theming and brand customization
- ⚡ **Fast** - Optimized for performance with Nuxt 4
- 🔧 **TypeScript** - Full TypeScript support

## 🚀 Quick Start

```bash
# Install dependencies
npm install

# Start development server
npm run dev
```

Your documentation site will be running at `http://localhost:3000`

## 📁 Project Structure

```
my-docs/
├── content/              # Your markdown content
│   ├── index.md         # Homepage
│   ├── 1.getting-started/  # Getting started section
│   └── 2.essentials/    # Essential documentation
├── public/              # Static assets
└── package.json         # Dependencies and scripts
```

## ⚡ Built with

This starter comes pre-configured with:

- [Nuxt 4](https://nuxt.com) - The web framework
- [Nuxt Content](https://content.nuxt.com/) - File-based CMS
- [Nuxt UI](https://ui.nuxt.com) - UI components
- [Nuxt Image](https://image.nuxt.com/) - Optimized images
- [Tailwind CSS 4](https://tailwindcss.com/) - Utility-first CSS
- [Docus Layer](https://www.npmjs.com/package/docus) - Documentation theme

## 📖 Documentation

For detailed documentation on customizing your Docus project, visit the [Docus Documentation](https://docus.dev)

### 🤖 AI Assistant Skill

Get started quickly with Docus by adding specialized knowledge to your AI assistant (Cursor, Claude, etc.):

```bash
npx skills add nuxt-content/docus
```

This skill helps you create documentation faster by providing your AI assistant with best practices, MDC component usage, ready-to-use templates, writing guidelines, and configuration tips for Docus. Perfect for quickly scaffolding new documentation projects.

## 🚀 Deployment

Build for production:

```bash
npm run build
```

The built files will be in the `.output` directory, ready for deployment to any hosting provider that supports Node.js.

## 📄 License

[MIT License](https://opensource.org/licenses/MIT) 

# Qora Documentation

Documentation officielle pour Qora v0.1.0 - Bibliothèque de gestion d'état serveur pour Dart et Flutter.

## 📁 Structure de la documentation

```
docs/
├── docs/                           # Contenu de la documentation
│   ├── introduction/               # Guide de démarrage
│   │   ├── what-is-qora.md        # Présentation de Qora
│   │   ├── installation.md        # Guide d'installation
│   │   ├── quick-start.md         # Tutoriel rapide (5 min)
│   │   └── comparison.md          # Comparaison avec autres solutions
│   │
│   ├── core-concepts/             # Concepts fondamentaux
│   │   ├── queries.md             # Queries en profondeur
│   │   ├── query-keys.md          # Système de clés
│   │   ├── query-states.md        # Machine à états
│   │   ├── caching.md             # Stratégies de cache
│   │   ├── stale-while-revalidate.md  # SWR pattern
│   │   └── deduplication.md       # Déduplication des requêtes
│   │
│   ├── guides/                    # Guides pratiques
│   │   ├── basic-usage.md         # Usage basique
│   │   ├── mutations.md           # POST/PUT/DELETE
│   │   ├── infinite-queries.md    # Pagination infinie
│   │   ├── optimistic-updates.md  # Mises à jour optimistes
│   │   ├── persistence.md         # Cache persistant
│   │   ├── error-handling.md      # Gestion d'erreurs
│   │   └── testing.md             # Tests unitaires
│   │
│   ├── flutter-integration/       # Intégration Flutter
│   │   ├── setup.md               # Configuration
│   │   ├── qora-scope.md          # QoraScope widget
│   │   ├── qora-builder.md        # QoraBuilder widget
│   │   ├── qora-mutation-builder.md   # Mutations UI
│   │   ├── qora-infinite-builder.md   # Infinite scroll UI
│   │   └── best-practices.md      # Bonnes pratiques
│   │
│   ├── api-reference/             # Référence API complète
│   │   ├── qora-client.md         # QoraClient
│   │   ├── qora-key.md            # QoraKey
│   │   ├── qora-state.md          # QoraState
│   │   ├── qora-options.md        # QoraOptions
│   │   ├── qora-mutation.md       # QoraMutation
│   │   ├── qora-infinite-query.md # QoraInfiniteQuery
│   │   ├── qora-optimistic.md     # QoraOptimistic
│   │   └── qora-persister.md      # QoraPersister
│   │
│   ├── examples/                  # Exemples complets
│   │   ├── todo-app.md            # App Todo complète
│   │   ├── user-management.md     # CRUD utilisateurs
│   │   ├── infinite-scroll.md     # Liste infinie
│   │   ├── real-time-updates.md   # Temps réel
│   │   └── offline-first.md       # Offline-first
│   │
│   └── migration/                 # Guides de migration
│       ├── from-provider.md       # Depuis Provider
│       ├── from-bloc.md           # Depuis BLoC
│       └── from-riverpod.md       # Depuis Riverpod
│
├── blog/                          # Articles de blog
│   ├── 2025-01-22-introducing-qora.md
│   └── 2025-01-22-why-qora.md
│
├── src/                           # Code source Docusaurus
│   ├── components/                # Composants React
│   ├── css/                       # Styles CSS
│   └── pages/                     # Pages personnalisées
│
├── static/                        # Assets statiques
│   └── img/                       # Images et diagrammes
│
└── sidebars.js                    # Configuration sidebar
```

## 🛠️ Installation locale

### Prérequis

- Node.js 18.0 ou supérieur
- npm ou yarn

### Installation

```bash
cd docs
npm install
```

### Lancement du serveur de développement

```bash
npm start
```

La documentation sera accessible sur `http://localhost:3000`.

### Build de production

```bash
npm run build
```

Les fichiers statiques seront générés dans le dossier `build/`.

## ✍️ Contribuer à la documentation

### Structure d'un document

Chaque fichier Markdown doit commencer par un front matter :

```markdown
---
sidebar_position: 1
title: Titre de la page
description: Description courte pour le SEO
---

# Titre principal

Contenu du document...
```

### Conventions de style

#### Titres

- Titre H1 (`#`) : Un seul par document, identique au `title` du front matter
- Titre H2 (`##`) : Sections principales
- Titre H3 (`###`) : Sous-sections
- Titre H4 (`####`) : Rarement utilisé

#### Code

Utilisez les blocs de code avec syntaxe highlighting :

````markdown
```dart
final client = QoraClient();
```
````

#### Admonitions

Utilisez les admonitions Docusaurus pour les notes importantes :

```markdown
:::tip
Conseil utile pour l'utilisateur
:::

:::warning
Avertissement important
:::

:::danger
Danger ! À éviter absolument
:::

:::info
Information contextuelle
:::
```

#### Liens

```markdown
<!-- Lien interne -->
Voir [Query Keys](./query-keys.md)

<!-- Lien vers API -->
Consultez la [référence API](../api-reference/qora-client.md)

<!-- Lien externe -->
Inspiré de [TanStack Query](https://tanstack.com/query)
```

### Exemples de code

Tous les exemples doivent :
- ✅ Être fonctionnels et testés
- ✅ Inclure les imports nécessaires
- ✅ Être suffisamment complets pour être copiés-collés
- ✅ Suivre les bonnes pratiques Dart/Flutter

#### Exemple complet

```dart
import 'package:flutter/material.dart';
import 'package:qora_flutter/qora_flutter.dart';

void main() {
  runApp(
    QoraScope(
      client: QoraClient(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomeScreen(),
    );
  }
}
```

### Diagrammes

Utilisez Mermaid pour les diagrammes :

````markdown
```mermaid
graph LR
    A[Initial] --> B[Loading]
    B --> C[Success]
    B --> D[Error]
```
````

## 📝 Checklist pour nouveau contenu

Avant de publier un nouveau document :

- [ ] Front matter complet (title, description, sidebar_position)
- [ ] Titre H1 unique
- [ ] Exemples de code testés
- [ ] Imports inclus dans les exemples
- [ ] Liens internes vérifiés
- [ ] Orthographe et grammaire vérifiées
- [ ] Navigation (Précédent/Suivant) pertinente
- [ ] Ajouté dans `sidebars.js` si nécessaire

## 🎨 Style guide

### Terminologie

- **Query** : Requête (pas "Question")
- **Mutation** : Mutation (pas "Modification")
- **Cache** : Cache (pas "Mémoire cache")
- **State** : État (pas "Statut")
- **Stale** : Périmé (pas "Obsolète")
- **Fetch** : Récupérer (ou garder "fetch" en anglais)

### Ton

- ✅ Tutoriel et bienveillant
- ✅ Concis mais complet
- ✅ Exemples pratiques
- ❌ Trop technique sans explication
- ❌ Condescendant

### Exemples

✅ Bon :
> Qora utilise un système de clés pour identifier vos queries. Par exemple, `QoraKey(['user', 1])` identifie de manière unique l'utilisateur avec l'ID 1.

❌ Mauvais :
> Le système de clés utilise un algorithme de deep equality basé sur la comparaison récursive des éléments du tableau...

## 🔍 SEO et métadonnées

Chaque page doit avoir :

```yaml
---
title: Titre optimisé (< 60 caractères)
description: Description concise et informative (< 160 caractères)
keywords: [qora, flutter, state management, cache]
---
```

## 📊 Analytics

Pour suivre l'utilisation de la documentation, vérifiez :
- Pages les plus visitées
- Recherches les plus fréquentes
- Taux de rebond par page

## 🚀 Déploiement

La documentation est automatiquement déployée via GitHub Actions 

## 📧 Support

Pour toute question concernant la documentation :
- GitHub Issues : [github.com/your-org/qora/issues](https://github.com/your-org/qora/issues)
- Discord : [discord.gg/qora](https://discord.gg/qora)
- Email : docs@qora.dev

---

Merci de contribuer à la documentation de Qora ! 🙏