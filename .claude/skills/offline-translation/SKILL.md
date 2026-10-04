---
name: offline-translation
description: Offline translation, speech and TTS for TurAIsta in Flutter - ML Kit on-device translation for guest languages, NLLB-200 ONNX export for Cebuano/Ilocano, speech packages for the Live Interpreter, language codes, and known coverage gaps. Use when implementing a Translator, adding a language, or working on the interpreter.
---

# Offline translation

## MVP: ML Kit on-device translation

Covers the guest side (English, Korean, Japanese, Chinese) and Tagalog. Add with
`flutter pub add google_mlkit_translation` (check pub.dev for the current version and minSdk).

Implement in `lib/services/mlkit_translator.dart` (not in `lib/core`, which stays pure Dart):

```dart
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:turaista/core/translator.dart';

class MlKitTranslator implements Translator {
  static const _languages = {
    'en': TranslateLanguage.english,
    'ko': TranslateLanguage.korean,
    'ja': TranslateLanguage.japanese,
    'zh': TranslateLanguage.chinese,
    'tl': TranslateLanguage.tagalog,
  };

  @override
  Future<String> translate(String text, {required String from, required String to}) async {
    if (from == to) return text;
    final source = _languages[from], target = _languages[to];
    if (source == null || target == null) return text; // unsupported: show original
    final translator = OnDeviceTranslator(sourceLanguage: source, targetLanguage: target);
    try {
      return await translator.translateText(text);
    } finally {
      await translator.close();
    }
  }
}
```

Download language models once, on Wi-Fi, during setup with `OnDeviceTranslatorModelManager`.
Verify these API names against the package docs before relying on them.

## Stretch: NLLB-200 for Cebuano and Ilocano

ML Kit does not cover Cebuano or Ilocano. NLLB-200 does (`ceb_Latn`, `ilo_Latn`).

```bash
make models   # cd model_tools && uv sync --extra export && uv run export-nllb
```

This exports `facebook/nllb-200-distilled-600M` to ONNX and quantizes to int8 in `models/`
(~600 MB+). Running it in Flutter needs an ONNX Runtime plugin, SentencePiece tokenization in
Dart, and a greedy decoding loop. That is days of work: only start after the MVP demo works.

Note that host explanations do NOT need machine translation: `lib/core/host_text.dart` uses
templates per host language, which is more natural and fully grounded.

## Live Interpreter (speech)

- Speech-to-text: platform recognizer (e.g. `speech_to_text` package); offline support depends
  on the device's downloaded language packs. Test on the target phone.
- Text-to-speech: `flutter_tts` with the host's chosen voice.
- Cebuano/Ilocano speech is weak or missing offline. Be honest in the demo: text-only for those.

## Codes used in this app

| Language | App code | NLLB code |
| --- | --- | --- |
| English | `en` | `eng_Latn` |
| Tagalog | `tl` | `tgl_Latn` |
| Cebuano | `ceb` | `ceb_Latn` |
| Ilocano | `ilo` | `ilo_Latn` |
| Korean | `ko` | `kor_Hang` |
| Japanese | `ja` | `jpn_Jpan` |
| Chinese (Simplified) | `zh` | `zho_Hans` |

## Rules

- Translate the grounded draft only. After translating, numbers in the output must match the
  English draft; otherwise fall back to English and tell the host.
- Unit tests use `IdentityTranslator`; real-model tests go under `integration_test/` and run on a device.
