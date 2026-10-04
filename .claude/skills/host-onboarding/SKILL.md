---
name: host-onboarding
description: Design and implementation rules for the one-time offline onboarding that creates the FarmProfile - what to ask, how to ask it in the host's language, what not to collect, and the read-back verification step. Use when building onboarding screens, changing the FarmProfile schema, or handling host preferences like form of address and voice.
---

# Host onboarding (journey stage 1)

Onboarding produces `FarmProfile` (`lib/core/profile.dart`). It runs once, offline, in the
host's language, and should take under 5 minutes. The MVP `SetupScreen` only reads back the
example profile; the full form is the next UI task.

## Ask preferences, not demographics

Do **not** ask age or gender to infer address, tone, or voice. Ask directly:

| Instead of inferring from... | Ask |
| --- | --- |
| age/gender -> Manang/Ate/Kuya | "Paano ka gustong tawagin?" (free text with examples) |
| age -> po/opo | "Gusto mo bang may 'po' kapag kinakausap ka ng app?" |
| gender -> voice pitch | Play 2-3 voice samples; host picks one |
| age -> digital literacy | Default to simple; offer "Ipaliwanag nang mas simple" everywhere |

## Facts to collect

- Farm name; verified directions from a known landmark
- Base price per person; max group size
- Each activity: name, price (0 = included), duration
- Safety rules (shoes, children, weather)

## Read-back = verification

Before saving, read every fact back and require a tap: "Tama ba: PHP 350 bawat tao?"
Only read-back-confirmed facts go into the profile. That is what "verified" means.

## Storage and privacy

- Save the profile on the device (app documents dir as JSON is fine for the MVP).
- Real profiles never go into git. Only `assets/profiles/example_farm.json` is committed.
- Changing the schema means updating `FarmProfile.fromJson`, the example JSON, onboarding,
  and tests together.
