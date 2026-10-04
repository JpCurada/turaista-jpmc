.PHONY: setup platforms get format analyze rules test check demo run models

# Recipes must work in both sh (macOS/Linux/CI) and cmd.exe (GNU Make on Windows),
# so file checks use Make functions instead of `test`/`find`.
rwildcard = $(foreach d,$(wildcard $(1:=/*)),$(call rwildcard,$d,$2) $(filter $(subst *,%,$2),$d))
LIB_DART := $(call rwildcard,lib,*.dart)

ifeq ($(OS),Windows_NT)
  CHMOD_HOOKS = @echo Git for Windows runs hooks without chmod, skipping.
else
  CHMOD_HOOKS = chmod +x .githooks/*
endif

setup: platforms get   ## first-time setup: platform folders, packages, git hooks
	git config core.hooksPath .githooks
	$(CHMOD_HOOKS)

platforms:             ## generate android/ios folders (never overwrites existing files)
ifeq ($(wildcard android),)
	flutter create . --project-name turaista --org ph.turaista --platforms android,ios
else
	@echo android/ already exists, skipping flutter create.
endif

get:
	flutter pub get

format:
	dart format lib test tool .claude/hooks

analyze:
	flutter analyze

rules:                 ## no hard-coded prices, pure-Dart core
	dart --packages=.githooks/empty_package_config.json .claude/hooks/rules_check.dart --files $(LIB_DART)

test:
	flutter test

check: analyze rules test   ## what CI runs
	dart format --output=none --set-exit-if-changed lib test tool .claude/hooks

demo:                  ## run the journey fixtures in the terminal (no device needed)
	dart run tool/demo.dart

run:
	flutter run

models:                ## export NLLB to ONNX int8 (stretch goal, ~600 MB, needs Python + uv)
	cd model_tools && uv sync --extra export && uv run export-nllb
