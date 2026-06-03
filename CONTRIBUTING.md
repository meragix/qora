# Contributing to Qora

Thanks for considering contributing. Whether you're fixing a bug, improving docs, or proposing a new feature, every contribution helps.

If you're unsure where to start, look for issues labeled [`good first issue`](https://github.com/meragix/qora/labels/good%20first%20issue). For larger features, please open a [discussion](https://github.com/meragix/qora/discussions) first so we can align on the approach before you invest time in code.

---

## Package Structure

Qora is a Melos monorepo. Each package has a clear boundary:

| Package | Kind | Description |
|---|---|---|
| `packages/dart` | Pure Dart | Core state machine, cache, `QoraClient`, `QoraTracker` |
| `packages/flutter` | Flutter | `QoraScope`, `QoraBuilder`, `QoraStateBuilder`, lifecycle wiring |
| `packages/hooks` | Flutter | `useQuery`, `useMutation`, `useIsFetching`, `useIsMutating` |
| `packages/devtools/shared` | Pure Dart | Protocol DTOs: events, commands, codecs, models |
| `packages/devtools/extension` | Pure Dart | VM Service bridge: `VmTracker`, lazy payload, extension registration |
| `packages/devtools/ui` | Flutter Web | DevTools panel UI: Queries, Mutations, Inspector, Network, Performance, Graph |
| `packages/devtools/overlay` | Flutter | In-app overlay: `QoraInspector`, `OverlayTracker`, panel UI |

---

## Architectural Principles

These guidelines keep the codebase consistent and maintainable over time.

1. **Single Responsibility**: every class should do one thing and do it well. Depend on abstractions, not concrete implementations.
2. **Core Agnosticism**: `packages/dart` must not depend on Flutter or any third-party library (Dio, Hive, etc.). Use the `LifecycleManager` and `ConnectivityManager` abstractions for platform-specific concerns.
3. **Deterministic Logic**: state transitions must be predictable and side-effect-free.
4. **Fetch-Path Performance**: avoid heavy computation in hot fetch cycles. Prefer JIT decoding strategies for large payloads.

---

## AI Usage Guidelines

AI tools (Claude, Cursor, GitHub Copilot, etc.) are welcome, with a few ground rules:

- **You own the code.** Every line you submit is your responsibility. Be ready to explain the logic, complexity, and trade-offs of any AI-generated snippet during review.
- **Verify suggestions.** Confirm that any package or method suggested by AI actually exists and is actively maintained.
- **Test alongside generation.** Write tests that define the expected behavior. AI can fill in the implementation. The test is what matters.
- **Review the output.** AI-generated comments tend to over-explain. Prefer concise, *why*-focused documentation over verbose *what* descriptions.

---

## Testing Strategy

Every PR should include tests that cover the changed logic. This isn't a gatekeeping rule, it's how we keep Qora reliable as it grows.

- **Unit tests**: required for every core change (state machine, cache, logic).
- **Mocking**: use `mocktail` or `mockito` to isolate dependencies.
- **Coverage**: aim for 90%+ on the core package. CI will flag significant regressions.

---

## Development Setup

Qora uses [Melos](https://melos.invertase.dev/) to manage the monorepo. Install it once, then use it for most day-to-day tasks.

```bash
dart pub global activate melos
melos bootstrap       # install dependencies across all packages
git config core.hooksPath .githooks  # enable pre-commit + commit-msg hooks
```

Common commands:

```bash
melos analyze         # dart analyze --fatal-infos on every package
melos format          # format all packages
melos format:check    # check formatting without modifying files
melos test            # run all tests with coverage
melos publish:check   # dry-run publish validation
melos clean           # clean all build artifacts
```

To run tests for a specific package directly:

```bash
cd packages/dart && dart test
cd packages/flutter && flutter test
cd packages/devtools/ui && flutter test
```

To test your change against an example app, pick one from `examples/` and run:

```bash
cd examples/todo && flutter run
```

---

## Development Workflow

1. **Branching**: use descriptive names like `feat/feature-name` or `fix/issue-name`.
2. **Commits**: follow [Conventional Commits](https://www.conventionalcommits.org/). For example:
   - `feat(core): add query prefetching`
   - `fix(flutter): prevent memory leak on widget dispose`
   - `docs: explain offline mutation replay behavior`
3. **Changelog**: update `CHANGELOG.md` in every package you touch. Add an entry under `## [Unreleased]` using the [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format (`### Added`, `### Changed`, `### Fixed`).
4. **Documentation**: if you add a public API, include `///` dartdoc and update the relevant page under `docs/content/`.
5. **Analysis**: run `melos analyze` before opening a PR. CI enforces `--fatal-infos`, so zero warnings is the target.

---

## Quality Checklist

Before submitting a PR, take a moment to verify:

- **Scale**: does the change perform reasonably with 10,000 items in cache? (Run the relevant benchmark or add a quick local stress test.)
- **Security**: are sensitive values excluded from logs, error messages, and middleware output?
- **Testability**: can the feature be tested without a network connection?
- **Complexity**: does the change add minimal public API surface? Less surface means less to maintain.

---

## Communication

Keep things direct and technical. During code review, be ready to explain your decisions and assume good intent from everyone involved.

This project follows the [Contributor Covenant](https://www.contributor-covenant.org/) code of conduct.
