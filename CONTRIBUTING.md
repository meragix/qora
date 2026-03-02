# Contributing to Qora

First, thank you for considering contributing! We treat every contributor as a **Senior Peer**. To maintain the architectural integrity of Qora, we follow strict engineering principles.

## 📦 Package Structure

| Package                       | Kind         | Description                                                                      |
| ----------------------------- | ------------ | -------------------------------------------------------------------------------- |
| `packages/dart`               | Pure Dart    | Core state machine, cache, `QoraClient`, `QoraTracker`                           |
| `packages/flutter`            | Flutter      | `QoraScope`, `QoraBuilder`, `QoraStateBuilder`, lifecycle wiring                 |
| `packages/hooks`              | Flutter      | `useQuery`, `useMutation`, `useIsFetching`, `useIsMutating`                      |
| `packages/devtools/shared`    | Pure Dart    | Protocol DTOs — events, commands, codecs, models                                 |
| `packages/devtools/extension` | Pure Dart    | VM Service bridge — `VmTracker`, lazy payload, extension registration            |
| `packages/devtools/ui`        | Flutter Web  | DevTools panel UI - Queries, Mutations, Inspector, Network, Performance, Graph   |
| `packages/devtools/overlay`   | Flutter      | In-app overlay — `QoraInspector`, `OverlayTracker`, panel UI                    |

---

## 🏛️ Architectural Principles

1. **SOLID & Clean Code**: Every class must have a Single Responsibility. Interfaces over implementations.
2. **Agnosticism**: The core (`packages/dart`) must NEVER depend on Flutter or any specific third-party library (like Dio or Hive). Use abstractions.
3. **Zero-Side Effects**: Logic must be predictable and deterministic.
4. **Performance Matters**: Avoid heavy computations inside the `fetch` cycles. Use JIT (Just-in-Time) strategies for decoding.

---

## 🤖 AI Usage Guidelines

We embrace the use of AI tools (Claude, Cursor, etc.) to speed up development, but with strict oversight:

- **No Blind Copy-Paste**: You are 100% responsible for every line of code you submit. If an AI generates a snippet, you must be able to explain the logic, the time complexity, and the architectural trade-offs.
- **No Hallucinated Dependencies**: Ensure that any package or method suggested by AI actually exists and is maintained.
- **TDD is Mandatory**: AI is great at writing code but often fails at edge cases. You must write your tests before or alongside AI-generated logic to prove its validity.
- **Documentation Quality**: AI-generated comments must be reviewed. We prefer concise, "why"-focused documentation over verbose "what" descriptions.

---

## 🧪 Testing Strategy (TDD)

No Pull Request will be accepted without tests.

- **Unit Tests**: Required for every core logic change (logic, state machine, cache).
- **Mocking**: Use `mocktail` or `mockito` to isolate dependencies.
- **Coverage**: Aim for 90%+ coverage on the core package.

---

## 🛠️ Development Setup

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

## 🔀 Development Workflow

1. **Branching**: Use descriptive names — `feat/feature-name` or `fix/issue-name`.
2. **Commits**: Follow [Conventional Commits](https://www.conventionalcommits.org/) (e.g. `feat(core): add prefetching logic`).
3. **Changelog**: Update `CHANGELOG.md` in every package you touch. Add an entry under `## [Unreleased]` using the [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format (`### Added`, `### Changed`, `### Fixed`).
4. **Documentation**: If you add a public API, add `///` dartdoc to it and update the relevant doc page under `docs/content/`.
5. **Analysis**: Run `melos analyze` before opening a PR. Zero warnings is the bar — `--fatal-infos` is enforced in CI.

---

## ⚖️ Quality Checklist

Before submitting a PR, ask yourself:

- **Impact on Scale**: Does this logic scale if the cache contains 10,000 items?
- **Security**: Are we exposing sensitive data in logs or middleware?
- **Testability**: Can this feature be tested without a network connection?
- **Boilerplate**: Does this add unnecessary complexity for the end-user?

---

## 💬 Communication

We value **concise, direct, and technical** communication. Be prepared to defend your technical choices during code review.

---

> *Failure is an option here. If things are not failing, you are not innovating enough. — Elon Musk (applied to code)*
