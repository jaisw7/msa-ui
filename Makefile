.PHONY: help install clean lint format analyze test test-cov run run-linux run-chrome run-web build build-linux build-web setup

help:
	@echo "Available targets:"
	@echo "  install        - Install Flutter dependencies"
	@echo "  clean          - Remove build artifacts and cache files"
	@echo "  lint           - Run dart analyzer"
	@echo "  format         - Format code with dart format"
	@echo "  analyze        - Run flutter analyze"
	@echo "  test           - Run tests with flutter test"
	@echo "  test-cov       - Run tests with coverage report"
	@echo "  run            - Run the app (auto-detect device)"
	@echo "  run-linux      - Run the app on Linux desktop"
	@echo "  run-chrome     - Run the app in Chrome"
	@echo "  run-web        - Run the app as web server"
	@echo "  build-linux    - Build Linux release"
	@echo "  build-web      - Build web release"
	@echo "  setup          - Initial project setup"

install:
	flutter pub get

clean:
	flutter clean
	rm -rf build/
	rm -rf .dart_tool/
	rm -rf coverage/

lint:
	dart analyze lib/ test/

format:
	dart format --set-exit-if-changed lib/ test/

format-fix:
	dart format lib/ test/

analyze:
	flutter analyze --no-fatal-infos

test:
	flutter test

test-cov:
	flutter test --coverage
	@echo "Coverage report generated in coverage/lcov.info"

run:
	flutter run

run-linux:
	flutter run -d linux

run-chrome:
	flutter run -d chrome

run-web:
	flutter run -d web-server --web-port=8080

build-linux:
	flutter build linux --release

build-web:
	flutter build web --release

build-android:
	flutter build apk --release

build-ios:
	flutter build ios --release

pre-commit: format-fix analyze test
	@echo "✓ All pre-commit checks passed"

setup: install
	@echo "✓ Project setup complete"
