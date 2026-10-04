import 'dart:io';

import 'package:flutter/material.dart';
import 'package:turaista/app.dart';
import 'package:turaista/core/language_id.dart';
import 'package:turaista/core/profile.dart';
import 'package:turaista/features/home/splash_screen.dart';
import 'package:turaista/services/device_speech.dart';
import 'package:turaista/services/file_profile_store.dart';
import 'package:turaista/services/llama_intent_model.dart';
import 'package:turaista/services/mlkit_language_identifier.dart';
import 'package:turaista/services/mlkit_translator.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SplashGate(load: _loadApp));
}

/// Loads the saved profile and the intent model while the splash plays.
Future<Widget> _loadApp() async {
  final store = FileProfileStore();
  FarmProfile? profile;
  try {
    profile = await store.load();
  } on FormatException {
    // An unreadable profile cannot be trusted for facts: onboard again.
    profile = null;
  } on FileSystemException {
    profile = null;
  }
  final models = MlKitLanguageModels();
  LlamaIntentModel? found;
  try {
    found = await LlamaIntentModel.find();
  } on Object {
    found = null; // keyword mode
  }
  final intentModel = found;
  return TurAIstaApp(
    store: store,
    initialProfile: profile,
    translator: MlKitTranslator(models: models),
    languageModels: models,
    languageIdentifier: MlKitLanguageIdentifier(supported: guestLanguageCodes.toSet()),
    intentModel: intentModel,
    loadIntentModel:
        intentModel == null
            ? null
            : () async {
              await intentModel.load();
            },
    speechInput: DeviceSpeechInput(),
    speechOutput: DeviceSpeechOutput(),
  );
}
