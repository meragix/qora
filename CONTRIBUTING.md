# Contributing to Qora

Contributions are welcome. To preserve the architectural integrity of Qora, all submissions must follow the engineering principles described in this document.

## Package Structure

| Package                       | Kind         | Description                                                                      |
| ----------------------------- | ------------ | -------------------------------------------------------------------------------- |
| `packages/dart`               | Pure Dart    | Core state machine, cache, `QoraClient`, `QoraTracker`                           |
| `packages/flutter`            | Flutter      | `QoraScope`, `QoraBuilder`, `QoraStateBuilder`, lifecycle wiring                 |
| `packages/hooks`              | Flutter      | `useQuery`, `useMutation`, `useIsFetching`, `useIsMutating`                      |
| `packages/devtools/shared`    | Pure Dart    | Protocol DTOs: events, commands, codecs, models                                  |
| `packages/devtools/extension` | Pure Dart    | VM Service bridge: `VmTracker`, lazy payload, extension registration             |
| `packages/devtools/ui`        | Flutter Web  | DevTools panel UI: Queries, Mutations, Inspector, Network, Performance, Graph    |
| `packages/devtools/overlay`   | Flutter      | In-app overlay: `QoraInspector`, `OverlayTracker`, panel UI                      |

---

## Architectural Principles

1. **Single Responsibility**: Every class must have a single, well-defined responsibility. Depend on abstractions, not concrete implementations.
2. **Core Agnosticism**: `packages/dart` must not depend on Flutter or any third-party library (Dio, Hive, etc.). Use the `LifecycleManager` and `ConnectivityManager` abstractions.
3. **Deterministic Logic**: State transitions must be predictable and free of unintended side effects.
4. **Fetch-Path Performance**: Avoid heavy computation inside fetch cycles. Apply JIT decoding strategies for large payloads.

---

## AI Usage Guidelines

AI tools (Claude, Cursor, etc.) are permitted, with the following requirements:

- **Accountability**: You are responsible for every line of code submitted. Be able to explain the logic, time complexity, and architectural trade-offs of any AI-generated snippet.
- **Dependency Verification**: Confirm that any package or method suggested by AI exists and is actively maintained.
- **TDD Requirement**: Write tests before or alongside AI-generated logic to validate edge cases.
- **Documentation Review**: Review AI-generated comments. Prefer concise, why-focused documentation over verbose what descriptions.

---

## Testing Strategy

No pull request will be accepted without tests.

- **Unit Tests**: Required for every core logic change (logic, state machine, cache).
- **Mocking**: Use `mocktail` or `mockito` to isolate dependencies.
- **Coverage**: Aim for 90%+ coverage on the core package.

---

## Development Setup

This is a [Melos](https://melos.invertase.dev/) monorepo. Install Melos once, then use it for all day-to-day tasks.

```bash
dart pub global activate melos
melos bootstrap       # install dependencies across all packages
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

To run tests for a single package directly:

```bash
cd packages/dart && dart test
cd packages/flutter && flutter test
cd packages/devtools/ui && flutter test
```

---

## Development Workflow

1. **Branching**: Use descriptive names; `feat/feature-name` or `fix/issue-name`.
2. **Commits**: Follow [Conventional Commits](https://www.conventionalcommits.org/) (e.g. `feat(core): add prefetching logic`).
3. **Changelog**: Update `CHANGELOG.md` in every package you touch. Add an entry under `## [Unreleased]` using the [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format (`### Added`, `### Changed`, `### Fixed`).
4. **Documentation**: If you add a public API, add `///` dartdoc to it and update the relevant doc page under `docs/content/`.
5. **Analysis**: Run `melos analyze` before opening a PR. Zero warnings is the bar, `--fatal-infos` is enforced in CI.

---

## Quality Checklist

Before submitting a pull request, verify:

- **Scale**: The changed logic must perform acceptably with 10,000 items in cache.
- **Security**: Sensitive data must be absent from logs and middleware output.
- **Testability**: The feature must be testable without a network connection.
- **Complexity**: The change must not add unnecessary public API surface or boilerplate for consumers.

---

## Communication

Prefer concise, direct, and technical communication. Be prepared to explain and defend technical decisions during code review.
