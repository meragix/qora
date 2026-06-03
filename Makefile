.PHONY: help setup bootstrap clean analyze format format-check test test-dart test-flutter test-flutter-chrome test-coverage build-devtools publish-check publish release release-dry-run examples examples-list audit audit-report audit-open hooks

# ── Default ───────────────────────────────────────────────────────────
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ── Setup ─────────────────────────────────────────────────────────────
setup: hooks ## First-time setup: install Melos + bootstrap + hooks
	@./scripts/setup.sh

hooks: ## Configure git hooks
	@git config core.hooksPath .githooks
	@chmod +x .githooks/*
	@echo "✓ Git hooks configured (.githooks/)"

bootstrap: ## Re-bootstrap after pulling or switching branches
	@melos bootstrap

clean: ## Remove all build artifacts and re-bootstrap
	@melos clean
	@melos bootstrap

reset: ## Full reset: clean + remove pubspec.lock + re-bootstrap
	@echo "→ Cleaning melos..."
	@melos clean
	@echo "→ Removing pubspec.lock files..."
	@find . -name pubspec.lock -not -path '*/\.*' -delete
	@echo "→ Bootstrapping..."
	@melos bootstrap
	@echo "✓ Reset complete."

# ── Analysis ──────────────────────────────────────────────────────────
analyze: ## Run dart analyze with fatal-infos on all packages
	@melos analyze

lint: analyze ## Alias for analyze

# ── Formatting ────────────────────────────────────────────────────────
format: ## Format all Dart files
	@melos format

format-check: ## Check formatting without modifying (CI use)
	@melos format:check

# ── Testing ───────────────────────────────────────────────────────────
test: ## Run all tests (dart + flutter)
	@melos test:all

test-dart: ## Run tests on pure Dart packages only
	@melos test:dart

test-flutter: ## Run tests on Flutter packages (excl. devtools/ui — needs --platform chrome)
	@melos test:flutter

test-flutter-chrome: ## Run DevTools UI tests on Chrome
	@melos test:flutter:chrome || echo "Chrome not available, skipping."

test-watch: ## Run all tests in watch mode (useful during development)
	@melos exec -- dart test --watch

coverage: ## Generate lcov coverage report
	@melos coverage
	@echo "✓ Coverage report at ./coverage/lcov.info"

coverage-html: coverage ## Generate and open HTML coverage report
	@if command -v genhtml &> /dev/null; then \
		genhtml coverage/lcov.info -o coverage/html && \
		echo "✓ HTML report at ./coverage/html/index.html" && \
		open coverage/html/index.html; \
	else \
		echo "genhtml not found. Install lcov: brew install lcov"; \
	fi

# ── Build ─────────────────────────────────────────────────────────────
build-devtools: ## Build DevTools Web UI and copy into extension package
	@melos run build:devtools
	@echo "✓ DevTools UI built and copied to extension package."

# ── Publish ───────────────────────────────────────────────────────────
publish-check: ## Dry-run publish on all packages
	@melos publish:check

publish: ## Publish all packages in dependency order
	@melos publish

# ── Release ─────────────────────────────────────────────────────────────
release: ## Create a workspace release (usage: make release ARGS="1.1.0")
	@./scripts/release.sh $(ARGS)

release-dry-run: ## Simulate a workspace release without modifying files
	@./scripts/release.sh --dry-run $(ARGS)

# ── Examples ──────────────────────────────────────────────────────────
EXAMPLES := ex_01_basic_query ex_02_mutations_optimistic ex_03_infinite_scroll ex_04_offline_first ex_05_network_aware ex_06_hooks_integration ex_07_complete_todo_app
EXAMPLE_DIRS := $(addprefix examples/, $(EXAMPLES))

examples: $(EXAMPLE_DIRS) ## Run flutter pub get on all examples
$(EXAMPLE_DIRS):
	@echo "→ Running flutter pub get in $@..."
	@cd $@ && flutter pub get

examples-list: ## List all available example apps
	@echo "Available examples:"
	@for ex in $(EXAMPLES); do \
		name=$$(echo $$ex | sed 's/^ex_[0-9]*_//' | tr '_' ' '); \
		echo "   make run-$$ex  → $$name"; \
	done

run-ex_01_basic_query: ## Run basic query example
	cd examples/ex_01_basic_query && flutter run
run-ex_02_mutations_optimistic: ## Run mutations + optimistic update example
	cd examples/ex_02_mutations_optimistic && flutter run
run-ex_03_infinite_scroll: ## Run infinite scroll example
	cd examples/ex_03_infinite_scroll && flutter run
run-ex_04_offline_first: ## Run offline-first example
	cd examples/ex_04_offline_first && flutter run
run-ex_05_network_aware: ## Run network-aware example
	cd examples/ex_05_network_aware && flutter run
run-ex_06_hooks_integration: ## Run hooks integration example
	cd examples/ex_06_hooks_integration && flutter run
run-ex_07_complete_todo_app: ## Run complete todo app example
	cd examples/ex_07_complete_todo_app && flutter run

# ── Quality gates (CI) ────────────────────────────────────────────────
ci: ## Run all CI checks locally (format + analyze + test)
	@echo "═══ CI Quality Gate ═══"
	@echo ""
	@echo "→ 1/3 Format check..."
	@melos format:check || (echo "✗ Format check failed. Run 'make format' to fix."; exit 1)
	@echo ""
	@echo "→ 2/3 Static analysis..."
	@melos analyze || (echo "✗ Analysis failed."; exit 1)
	@echo ""
	@echo "→ 3/3 Tests..."
	@melos test:all || (echo "✗ Tests failed."; exit 1)
	@echo ""
	@echo "✓ All CI checks passed."

# ── Utils ─────────────────────────────────────────────────────────────
outdated: ## Check for outdated dependencies across all packages
	@melos exec -- dart pub outdated

upgrade: ## Upgrade all dependencies
	@melos exec -- dart pub upgrade

graph: ## Show dependency graph (requires: npm install -g dependency-cruiser)
	@echo "→ Package dependency graph:"
	@grep -A1 '^  - packages/' pubspec.yaml | grep packages | sed 's/.*packages\///' | while read pkg; do \
		deps=$$(grep -r '^  - packages/' packages/$$pkg/pubspec.yaml 2>/dev/null | sed 's/.*packages\/\(.*\)/\1/' | tr '\n' ',' | sed 's/,$$//'); \
		[ -n "$$deps" ] && echo "   $$pkg → [$$deps]" || echo "   $$pkg → (none)"; \
	done
