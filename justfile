# Show available recipes.
default:
    @just --list

# Install Flutter and docs dependencies.
deps:
    # TODO: add this as part of spec 1
    # flutter pub get
    cd docs && npm install

# Set up local development environment and git hooks.
setup: deps
    pre-commit install

# Run the Flutter app.
dev:
    flutter run

# Run Flutter analysis and docs build checks.
lint:
    # TODO: add this as part of spec 1
    # flutter analyze
    cd docs && npm run build

# Run tests.
test:
    flutter test

# Format Flutter and docs code.
format:
    # TODO: add this as part of spec 1
    # dart format .
    cd docs && npm run astro -- format

# Run the docs site in development mode.
run-docs:
    cd docs && npm run dev
