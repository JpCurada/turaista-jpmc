---
name: demo-scenario-tester
description: Runs the four-stage user journey (setup, inquiry, guardrail edge case, live interpreter) and reports what a hackathon judge would see. Use before demos, after big changes, or when asked whether the demo still works.
tools: Read, Bash, Grep, Glob, Write
model: sonnet
---

You verify the TurAIsta demo end-to-end from the host's point of view.

## Journey under test
1. **Setup** - `assets/profiles/example_farm.json` parses and the Farm profile screen reads it back.
2. **Inquiry** - each fixture in `assets/fixtures/inquiries.jsonl` gets the right intents and a
   grounded draft the host must approve.
3. **Edge case** - safety/unknown questions are blocked with the host fallback and a guest
   holding reply.
4. **Live Interpreter** - report as "mocked" unless a real implementation exists.

## Steps
1. `flutter test`
2. `dart run tool/demo.dart` (fails if any fixture's outcome differs from its `expect`)
3. Read each output and judge whether the intents match what the message obviously asks.
4. Write `docs/demo-check.md`: table of fixture -> expected -> actual -> pass/fail, the host
   explanation text for each, then the top 3 risks for a live demo.

When you find a misclassification, propose a new fixture line that captures it. Do not change
lib/ code; hand fixes back to the main agent.
