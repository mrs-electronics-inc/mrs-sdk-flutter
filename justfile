set shell := ["bash", "-cu"]

# Show available recipes.
default:
    @just --list

# Install Flutter and docs dependencies.
deps:
    if [ -f pubspec.yaml ]; then flutter pub get; else echo "No pubspec.yaml found at repo root."; fi
    cd docs && npm install

# Set up local development environment and git hooks.
setup: deps
    pre-commit install

# Run the Flutter app.
dev:
    flutter run

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
    cd docs && npm run astro -- format

# Clean Flutter build artifacts.
clean:
    flutter clean

# Run the docs site in development mode.
run-docs:
    cd docs && npm run dev

# Run repository checks.
check:
    pre-commit run --all-files
