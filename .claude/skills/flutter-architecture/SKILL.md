---
name: flutter-architecture
description: TurAIsta's Flutter project structure and conventions - pure-Dart core vs services vs features, where new code goes, state management, offline-first rules, testing strategy, and commands. Use before creating new files, adding packages, or restructuring code.
---

# Architecture

```
lib/
├── core/        # Pure Dart. Business rules. No Flutter, no network. 100% unit-tested.
│   ├── profile.dart     FarmProfile (only source of facts)
│   ├── intents.dart     GuestIntent + offline keyword classifier
│   ├── guardrail.dart   blocking rules
│   ├── reply.dart       grounded draft builder
│   ├── host_text.dart   host-language explanations (templates)
│   ├── translator.dart  Translator interface + IdentityTranslator
│   └── pipeline.dart    classify -> guardrail -> draft -> translate
├── services/    # Platform/ML implementations of core interfaces (ML Kit, ONNX, storage).
├── features/    # Screens, one folder per journey stage. UI only.
│   ├── home/  setup/  inquiry/  interpreter/
├── app.dart
└── main.dart
tool/demo.dart   # terminal demo using core only
```

## Rules

1. `lib/core` imports only `dart:` libraries and other core files. Enforced by `rules_check.dart`.
2. New platform capability = interface in `core`, implementation in `services`, injected via
   constructor (see `InquiryScreen.translator`). Tests use fakes.
3. Features never compute facts or classify; they call `core`.
4. Offline-first: no feature may require network. Model downloads are explicit, Wi-Fi, one-time.
5. State: `setState` / `ValueNotifier`. Ask before adding Riverpod/Bloc/etc.
6. Packages: `flutter pub add <pkg>` only, check pub.dev for maintenance and Android minSdk.
   Never edit `pubspec.lock`.

## Testing

- `test/core/` - unit tests for every rule. Load fixtures with `dart:io` from `assets/`.
- `test/widget_test.dart` - screen behavior via `Key`s.
- `integration_test/` - real models on a device (add when ML lands).
- `assets/fixtures/inquiries.jsonl` - each line has `expect: draft|blocked`; both the tests and
  `tool/demo.dart` check it.

## Commands

`make setup` · `make check` (format, analyze, rules, test) · `make demo` · `make run`
