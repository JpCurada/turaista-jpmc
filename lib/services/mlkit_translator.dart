import 'dart:async';

import 'package:flutter/services.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:turaista/core/translator.dart';

/// App language codes ML Kit can translate offline. No Cebuano or Ilocano.
const Map<String, TranslateLanguage> mlKitLanguages = {
  'en': TranslateLanguage.english,
  'ko': TranslateLanguage.korean,
  'ja': TranslateLanguage.japanese,
  'zh': TranslateLanguage.chinese, // Simplified
  'tl': TranslateLanguage.tagalog,
};

TranslateLanguage _language(String lang) {
  final language = mlKitLanguages[lang];
  if (language == null) throw TranslationUnavailable('ML Kit cannot translate "$lang" offline');
  return language;
}

/// Downloads ML Kit language models, Wi-Fi only (journey stage 1, one time).
class MlKitLanguageModels implements LanguageModels {
  MlKitLanguageModels({this.timeout = const Duration(minutes: 10)});

  /// A Wi-Fi-only download can wait forever without Wi-Fi; give up after this.
  final Duration timeout;

  final OnDeviceTranslatorModelManager _manager = OnDeviceTranslatorModelManager();

  @override
  Future<bool> isDownloaded(String lang) => _manager.isModelDownloaded(_language(lang).bcpCode);

  @override
  Future<void> download(String lang) async {
    final ok = await _manager
        .downloadModel(_language(lang).bcpCode, isWifiRequired: true)
        .timeout(timeout);
    if (!ok) throw StateError('Model download for "$lang" did not finish');
  }
}

/// Offline translation with Google ML Kit. Never downloads anything itself.
class MlKitTranslator implements Translator {
  MlKitTranslator({required this.models, this.maxOpenPairs = 2});

  /// Checked before every translation: ML Kit's translateText would otherwise
  /// download a missing model silently, even over mobile data.
  final LanguageModels models;

  /// Open translators hold native memory; keep few on a ~3 GB phone.
  final int maxOpenPairs;

  /// Open translators by "from>to", least recently used first.
  final Map<String, OnDeviceTranslator> _open = {};

  @override
  Future<String> translate(String text, {required String from, required String to}) async {
    if (from == to) return text;
    final source = _language(from);
    final target = _language(to);
    // ML Kit pivots through English, so it needs that model too.
    for (final lang in {from, to, 'en'}) {
      if (!await models.isDownloaded(lang)) {
        throw TranslationUnavailable('Model for "$lang" is not downloaded');
      }
    }
    try {
      return await _translator(source, target).translateText(text);
    } on PlatformException catch (e) {
      throw TranslationUnavailable('ML Kit failed: ${e.code} ${e.message ?? ''}');
    }
  }

  OnDeviceTranslator _translator(TranslateLanguage source, TranslateLanguage target) {
    final key = '${source.bcpCode}>${target.bcpCode}';
    final translator =
        _open.remove(key) ?? OnDeviceTranslator(sourceLanguage: source, targetLanguage: target);
    _open[key] = translator; // now most recently used
    while (_open.length > maxOpenPairs) {
      final oldest = _open.keys.first;
      unawaited(_open.remove(oldest)!.close());
    }
    return translator;
  }

  /// Releases native translators.
  Future<void> close() async {
    final open = _open.values.toList();
    _open.clear();
    await Future.wait(open.map((t) => t.close()));
  }
}
