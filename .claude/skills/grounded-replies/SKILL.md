---
name: grounded-replies
description: How to add or change guest reply content in TurAIsta so every fact comes from the verified FarmProfile. Use when editing lib/core/reply.dart, adding a reply section for an intent, adding a FarmProfile field, or whenever a reply needs a price, group size, activity, or directions.
---

# Grounded replies

TurAIsta's promise to hosts: **the app never invents a fact.** Models classify intent and
translate; facts are filled in from `FarmProfile` before any model touches the text.

## Pipeline (`lib/core/pipeline.dart`)

```
guest message -> classifyKeywords (or SLM)  -> Set<GuestIntent>
              -> checkGuardrail()            -> blocked? holding reply, stop
              -> draftReply()                -> English draft from profile fields
              -> Translator.translate()      -> guest language
              -> host taps "Aprubahan"       -> copied to clipboard, host sends
```

## Adding a reply section

1. Add a builder in `lib/core/reply.dart`:

   ```dart
   List<String> _safetyRuleLines(FarmProfile p, List<String> facts) {
     facts.add('safety_rules');
     return ['Before your visit, please note:', for (final r in p.safetyRules) '- $r'];
   }
   ```

2. Register it in `_sections` (the list order is the order in the reply).
3. Always add the profile field path to `facts`.
4. Add a test in `test/core/reply_test.dart` proving every number comes from the profile.

## Rules

- No literal prices, peso amounts, or group sizes in `lib/` outside `lib/core/profile.dart`.
  The `rules_check.dart` hook, the pre-commit hook, and CI all reject them. Use `formatPhp()`.
- Missing fact? The answer is "ask the host", not a guess. Add a field to `FarmProfile` and to
  onboarding (see `host-onboarding`).
- After translation, the set of numbers in the output must equal the set in the English draft.
  If not, show the host the English draft instead.
