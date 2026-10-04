---
name: intent-taxonomy
description: The fixed set of guest-message intents in TurAIsta (BOOKING, PRICE, DIRECTIONS, DIETARY_SAFETY, OTHER), which are blocked by the guardrail, and how to add an intent or train/evaluate a classifier on MASSIVE-style data. Use when touching lib/core/intents.dart, guardrail.dart, host_text.dart, or classifier work.
---

# Intent taxonomy

| `GuestIntent` | Meaning | Draft? |
| --- | --- | --- |
| `booking` | Visit, reserve, availability, group size | Yes |
| `price` | Cost of tour or activities | Yes |
| `directions` | How to get to the farm | Yes |
| `dietarySafety` | Allergies, diet, medical, accessibility, pregnancy, children's safety | **Never** |
| `other` | Anything not covered by the verified profile | **Never** |

A message can carry several intents. If ANY is blocked, the whole message is blocked.

## Adding an intent

1. Add it to `GuestIntent` with a `code`, and add keywords (English plus Korean, Japanese,
   Chinese variants for the main visitor markets).
2. Decide explicitly whether it belongs in `blockedIntents`. When unsure, block it.
3. Add host-facing topic labels in `lib/core/host_text.dart` (all languages present there).
4. If it can be drafted, add a grounded reply section (see `grounded-replies`).
5. Add cases to `test/core/intents_test.dart` and a fixture line with `expect` to
   `assets/fixtures/inquiries.jsonl`.

## Training a small classifier

- Start from Amazon MASSIVE (51 languages). Map its intents onto ours; everything unmapped -> `other`.
- Ship as TFLite or ONNX behind a `IntentClassifier` interface in `lib/core`, implementation
  in `lib/services/`.
- Keep `classifyKeywords` as fallback and sanity check: if model and keywords disagree and either
  says `dietarySafety`, block.
- Report per-language recall on `dietarySafety` separately. A missed safety question is the worst
  failure in this product; optimize recall there, not overall accuracy.
