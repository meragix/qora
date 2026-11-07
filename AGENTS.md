# AGENTS.md

Instructions for AI coding agents working on the Qora repository. Human contributors: see [CONTRIBUTING.md](CONTRIBUTING.md), which this file complements.

To *use* Qora in an app, read [docs/public/qora-rules.md](docs/public/qora-rules.md) instead.

## Repository map

Melos monorepo using a Dart pub workspace (root `pubspec.yaml`).

| Path | Package | Kind | Published |
| --- | --- | --- | --- |
| `packages/dart` | `qora` | Pure Dart core: `QoraClient`, cache, state machine, mutations, persistence | yes |
| `packages/flutter` | `qora_flutter` | `QoraScope`, `QoraBuilder`, `QoraMutationBuilder`, lifecycle and connectivity wiring | yes |
| `packages/hooks` | `qora_hooks` | `useQuery`, `useMutation`, `useInfiniteQuery`, ... | yes |
| `packages/devtools/shared` | `qora_devtools_shared` | Protocol DTOs shared by the DevTools packages | yes |
| `packages/devtools/overlay` | `qora_devtools_overlay` | In-app inspector overlay | yes |
| `packages/devtools/extension` | `qora_devtools_extension` | VM Service bridge for the DevTools tab | no |
| `packages/devtools/ui` | `qora_devtools_ui` | DevTools web UI (Flutter web) | no |
| `examples/ex_0*` | | Runnable Flutter apps, outside the workspace, depending on the packages by `path` | no |
| `docs/` | | Docus (Nuxt) site, deployed to https://qora.meragix.dev | |

Each package exposes its public API through `lib/<package>.dart`. Everything under `lib/src/` that is not exported there is private.

## Commands

Run from the repository root.

```bash
melos bootstrap            # install dependencies (run after switching branches)
melos format               # format every package
melos format:check         # CI formatting check
melos analyze              # dart analyze --fatal-infos on every package
melos test:dart            # pure Dart packages (dart test)
melos test:flutter         # Flutter packages except devtools/ui (flutter test)
melos test:flutter:chrome  # devtools/ui, needs Chrome
```

One package at a time is faster while iterating:

```bash
cd packages/dart && dart test test/persistence/
cd packages/flutter && flutter test
```

Docs site: `cd docs && npm ci && npm run build` (static output in `docs/.output/public`).

A change is done when `melos format:check`, `melos analyze` and the tests of every touched package pass. `--fatal-infos` is enforced: an info-level lint fails the build.

## Invariants

Do not break these without an explicit decision from a maintainer.

- **`qora` is pure Dart.** Its only dependency is `meta`. No Flutter, no Dio, no Hive. Platform concerns go through the `LifecycleManager` and `ConnectivityManager` abstractions, implemented in `qora_flutter`.
- **No code generation.** No `build_runner`, no annotations, no generated files, in the packages or in what users must write.
- **One import for Flutter users.** `qora_flutter` re-exports `qora`; `qora_hooks` users add `qora_hooks` on top. A new public type in `qora` must reach users through that re-export.
- **`QoraState` is sealed** (`Initial`, `Loading`, `Success`, `Failure`). Users render it with exhaustive `switch`es, so adding a subtype is a breaking change.
- **Offline, queries pause; they do not fail.** In `NetworkMode.online` the state becomes `Loading(previousData: ...)` with `FetchStatus.paused`. Never surface `Failure` or `Initial` because the network is off.
- **Invalidation is exact-key.** `invalidate()` and `MutationOptions.invalidates` match one key; `invalidatePrefix()` and tags cover families. Do not change this silently: user code relies on it.
- **Qora owns only the storage keys it wrote.** A `StorageAdapter` may be shared with the app (one Hive box, one `SharedPreferences`). `PersistQoraClient.hydrate()` and `clearStorage()` only touch keys that pass `_isQueryStorageKey`. Never call `StorageAdapter.clear()`; any new persisted data needs keys that cannot collide with query keys or app keys.
- **Public API changes are deliberate.** Adding, renaming or removing an exported symbol, parameter or default needs dartdoc, a CHANGELOG entry and a docs update. Removing or renaming is breaking: mark the commit with `!` and deprecate first when possible.

## Versioning and release

- `qora`, `qora_flutter` and `qora_hooks` are released in lockstep with the same version and a tag `x.y.z`, by `scripts/release.sh <version>`. Never bump their `version:` or move CHANGELOG headings by hand.
- The DevTools packages have their own versions.
- In every package you change, add an entry to its `CHANGELOG.md` under `## [Unreleased]`, in a Keep a Changelog section (`### Added`, `### Changed`, `### Fixed`, `### Deprecated`, `### Removed`). The release script turns `[Unreleased]` into the version heading.

## Documentation

- `docs/content/en/` and `docs/content/fr/` mirror each other file for file. An EN page added or changed needs its FR counterpart in the same PR. Numeric prefixes (`3.query-states.md`) set the navigation order.
- Every Dart snippet in the docs must compile against the current packages. Check new or changed snippets in a scratch Flutter project depending on the packages by `path`; do not document an API from memory or by analogy with TanStack Query.
- `05.api-reference/` must match the code: parameter names, types and defaults.
- When a public API changes, update `docs/public/qora-rules.md` (the rules file users give their assistants) if it names that API.
- The `llms` block in `docs/nuxt.config.ts` generates `/llms.txt` and `/llms-full.txt` from the English pages; its `notes` restate key invariants and must stay true.

## Writing style

- Code, comments, dartdoc, commits, CHANGELOGs and EN docs: English. FR docs: French.
- No em dashes (U+2014) anywhere: use a colon, a comma, a semicolon or two sentences. Check with `grep -rn $'\u2014' <files>`.
- No emojis in docs, comments or commit messages.
- Dartdoc and comments explain *why* and the behaviour a caller can rely on, not what the next line does.

## Git

- Enable the hooks once: `git config core.hooksPath .githooks`.
- `commit-msg` enforces Conventional Commits on every commit, merge commits included: `type(scope)!: subject` with `type` in `feat|fix|chore|docs|style|refactor|test|build|ci|perf|revert`. Merge with an explicit message, for example `chore: merge main into feat/x`.
- `pre-commit` runs `melos format:check` and `melos analyze` on the whole workspace.
- Branch from `main` with a `feat/`, `fix/`, `docs/` or `chore/` prefix, one logical change per commit.
- `ci / packages/dart` is the required status check on `main`.

## Tests

- Every behaviour change in `packages/dart` comes with a unit test (`package:test`). Tests never touch the real network: use in-memory fetchers, and a fake `ConnectivityManager` for offline behaviour (see `packages/hooks/test/use_mutation_offline_test.dart`).
- Widget and hook behaviour is tested with `flutter_test` in the package that owns it.
- A bug fix starts with a test that fails without the fix.
