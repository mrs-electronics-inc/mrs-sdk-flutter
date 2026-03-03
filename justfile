# Show available recipes.
default:
    @just --list

# Install Flutter and docs dependencies.
deps:
    flutter pub get
    cd docs && npm install

# Set up local development environment and git hooks.
setup: deps
    pre-commit install

# Run Flutter analysis and docs build checks.
lint:
    flutter analyze
    cd docs && npm run build

# Run tests.
test:
    flutter test

# Format Flutter and docs code.
format:
    dart format .
    cd docs && npm run format

# Run the docs site in development mode.
run-docs:
    cd docs && npm run dev
