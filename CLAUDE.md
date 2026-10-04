# TurAIsta — project memory for Claude Code

Offline Flutter app that helps small farm-tour hosts in the Philippine highlands talk to
visitors in any language. Built for the World Bank "Small AI" hackathon, tourism track
(Annex C). Hosts often have no signal and speak Tagalog/Cebuano/Ilocano; guests write in
Korean, Japanese, Chinese, English.

## User journey (scope = these 4 stages only)
1. **Setup** — one-time offline onboarding creates a verified `FarmProfile`.
2. **Inquiry** — host pastes a guest message; app explains it in the host's language and
   drafts a grounded reply. Host taps "Aprubahan" to copy it, then sends it in Messenger/SMS.
3. **Edge case** — safety/unverified questions are blocked: host sees
   "Not sure — ask a local guide/person", guest gets a holding reply.
4. **Live Interpreter** — offline two-way voice/text translation (mocked in MVP).

Out of scope: automatic sending, store-and-forward, feedback collection, business coaching.

## Non-negotiables
- Facts (prices, group size, activities, directions) come ONLY from `FarmProfile`.
- `dietarySafety` and `other` intents never get a draft. When in doubt, block.
- Nothing is sent by the app. The host approves and sends.
- `lib/core` is pure Dart: no Flutter imports, no network.
- Everything runs offline on a ~3 GB RAM Android phone.
- Ask hosts for preferences (address, po, voice); never infer from age or gender.

## Commands
- `make setup` — generate android/ios folders, `flutter pub get`, enable git hooks
- `make check` — format check, analyze, rules check, tests (what CI runs)
- `make demo` — terminal demo of the journey fixtures (no device needed)
- `make run` — run on a device/emulator
- Add packages with `flutter pub add <pkg>`; never edit `pubspec.lock` by hand.

## Where things live
See `.claude/skills/flutter-architecture/SKILL.md`. Short version: rules in `lib/core`,
platform/ML in `lib/services`, screens in `lib/features/<stage>/`, fixtures in `assets/fixtures`.

## Claude Code setup
- Skills: `grounded-replies`, `intent-taxonomy`, `offline-translation`, `host-onboarding`,
  `flutter-architecture`
- Agents: `on-device-ml-engineer`, `flutter-ui-engineer`, `guardrail-auditor` (read-only),
  `filipino-localization-reviewer` (read-only), `demo-scenario-tester`
- Hooks (Dart, in `.claude/hooks/`): protect secrets/weights/lockfiles/host data, format +
  analyze every edited Dart file, enforce no-hard-coded-prices and pure core, run
  `flutter test` on Stop, inject rules at session start.

After changing `lib/core`, run the `guardrail-auditor` agent.
After changing host-facing text, run `filipino-localization-reviewer`.

## Style
Dart 3, `flutter_lints` + strict analyzer, page width 100, single quotes, `final` by default,
small pure functions, records over ad-hoc maps. Every guardrail rule has a test.
