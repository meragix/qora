# Contributing to Qora

First, thank you for considering contributing! We treat every contributor as a **Senior Peer**. To maintain the architectural integrity of Qora, we follow strict engineering principles.

## 🏛️ Architectural Principles

1. **SOLID & Clean Code**: Every class must have a Single Responsibility. Interfaces over implementations.
2. **Agnosticism**: The core (`packages/qora`) must NEVER depend on Flutter or any specific third-party library (like Dio or Hive). Use abstractions.
3. **Zero-Side Effects**: Logic must be predictable and deterministic.
4. **Performance Matters**: Avoid heavy computations inside the `fetch` cycles. Use JIT (Just-in-Time) strategies for decoding.

## 🤖 AI Usage Guidelines

We embrace the use of AI tools (Claude, Cursor, etc.) to speed up development, but with strict oversight:

* **No Blind Copy-Paste**: You are 100% responsible for every line of code you submit. If an AI generates a snippet, you must be able to explain the logic, the time complexity, and the architectural trade-offs.
* **No Hallucinated Dependencies**: Ensure that any package or method suggested by AI actually exists and is maintained.
* **TDD is Mandatory**: AI is great at writing code but often fails at edge cases. You must write your tests before or alongside AI-generated logic to prove its validity.
* **Documentation Quality**: AI-generated comments must be reviewed. We prefer concise, "why" focused documentation over verbose "what" descriptions.

## 🧪 Testing Strategy (TDD)

No Pull Request will be accepted without tests.

* **Unit Tests**: Required for every core logic change (Logic, State Machine, Cache).
* **Mocking**: Use `mocktail` or `mockito` to isolate dependencies.
* **Coverage**: Aim for 90%+ coverage on the Core package.

## 🛠️ Development Workflow

1. **Branching**: Use descriptive names: `feat/feature-name` or `fix/issue-name`.
2. **Commits**: Follow [Conventional Commits](https://www.conventionalcommits.org/) (ex: `feat(core): add prefetching logic`).
3. **Documentation**: If you add a feature, update the relevant `README.md` and add docstrings (`///`) to public APIs.

## ⚖️ Quality Checklist

Before submitting a PR, ask yourself:

* **Impact on Scale**: Does this logic scale if the cache contains 10,000 items?
* **Security**: Are we exposing sensitive data in logs/middleware?
* **Testability**: Can this feature be tested without a network connection?
* **Boilerplate**: Does this add unnecessary complexity for the end-user?

## 💬 Communication

We value **concise, direct, and technical** communication. Be prepared to defend your technical choices during Code Review.

---
_*Failure is an option here. If things are not failing, you are not innovating enough. — Elon Musk (applied to code)*
