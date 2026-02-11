# Qora

**The Bulletproof Server-State Manager for Dart & Flutter.**

Qora is a high-performance, asynchronous state management solution designed to handle the complexity of server data. It transforms messy API calls into predictable, cached, and synchronized states.

## 📦 Packages

| Package | Version | Description |
| :--- | :--- | :--- |
| [**qora**](./packages/qora) | `0.1.0` | Core logic. Pure Dart. Agnostic persistence. |
| [**flutter_qora**](./packages/flutter_qora) | `0.1.0` | Flutter integration. Builders, Hooks, and UI Sync. |

## 🚀 Why Qora?

- **Smart Caching**: Deduplicates requests and manages TTL (Time To Live).
- **Offline-First**: Built-in hydration for seamless offline experiences.
- **Resource Efficient**: Automatic query cancellation on widget dispose.
- **Type-Safe**: End-to-end type safety from fetcher to UI.

## 🗺 Roadmap

- [x] **v0.4.0** - Plug-and-play Persistence (Hive/SharedPrefs).
- [x] **v0.7.0** - Universal Cancellation (AbortSignals).
- [ ] **v0.9.0** - Predictive Prefetching.
- [ ] **v1.0.0** - SSR Hydration for Flutter Web.

---
*Built with ❤️ for the Dart Community.*
