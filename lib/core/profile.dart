/// Verified farm profile captured during one-time onboarding (journey stage 1).
///
/// This is the ONLY source of facts (prices, activities, group size, rules,
/// directions) the app may state to a guest. Models classify, phrase and
/// translate; they never supply facts.
library;

import 'dart:convert';

class HostPreferences {
  const HostPreferences({
    required this.preferredAddress,
    required this.language,
    this.usePo = true,
    this.voice,
    this.simpleExplanations = false,
  });

  factory HostPreferences.fromJson(Map<String, dynamic> json) {
    return HostPreferences(
      preferredAddress: json['preferred_address'] as String,
      language: json['language'] as String,
      usePo: json['use_po'] as bool? ?? true,
      voice: json['voice'] as String?,
      simpleExplanations: json['simple_explanations'] as bool? ?? false,
    );
  }

  Map<String, Object?> toJson() => {
    'preferred_address': preferredAddress,
    'language': language,
    'use_po': usePo,
    'voice': voice,
    'simple_explanations': simpleExplanations,
  };

  /// How the host asked to be called, e.g. "Manang Lorna". Asked, never inferred.
  final String preferredAddress;

  /// Host language as a BCP-47 code: 'tl' (Tagalog), 'ceb' (Cebuano), 'ilo' (Ilocano).
  final String language;

  /// Add "po" in host-facing text.
  final bool usePo;

  /// Host-chosen TTS voice id.
  final String? voice;

  final bool simpleExplanations;
}

class Activity {
  const Activity({
    required this.name,
    required this.pricePhp,
    this.durationMinutes,
    this.description = '',
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    final activity = Activity(
      name: json['name'] as String,
      pricePhp: json['price_php'] as int,
      durationMinutes: json['duration_minutes'] as int?,
      description: json['description'] as String? ?? '',
    );
    if (activity.pricePhp < 0) {
      throw FormatException('Negative price for activity "${activity.name}"');
    }
    return activity;
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'price_php': pricePhp,
    if (durationMinutes != null) 'duration_minutes': durationMinutes,
    if (description.isNotEmpty) 'description': description,
  };

  final String name;

  /// 0 means included in the base tour.
  final int pricePhp;
  final int? durationMinutes;
  final String description;
}

class FarmProfile {
  const FarmProfile({
    required this.farmName,
    required this.locationHint,
    required this.host,
    required this.basePricePhp,
    required this.maxGroupSize,
    this.activities = const [],
    this.safetyRules = const [],
  });

  factory FarmProfile.fromJson(Map<String, dynamic> json) {
    final profile = FarmProfile(
      farmName: json['farm_name'] as String,
      locationHint: json['location_hint'] as String,
      host: HostPreferences.fromJson(json['host'] as Map<String, dynamic>),
      basePricePhp: json['base_price_php'] as int,
      maxGroupSize: json['max_group_size'] as int,
      activities: [
        for (final item in json['activities'] as List<dynamic>? ?? const <dynamic>[])
          Activity.fromJson(item as Map<String, dynamic>),
      ],
      safetyRules: [
        for (final rule in json['safety_rules'] as List<dynamic>? ?? const <dynamic>[])
          rule as String,
      ],
    );
    if (profile.basePricePhp < 0 || profile.maxGroupSize <= 0) {
      throw const FormatException('Invalid base price or group size');
    }
    return profile;
  }

  factory FarmProfile.fromJsonString(String source) =>
      FarmProfile.fromJson(jsonDecode(source) as Map<String, dynamic>);

  Map<String, Object?> toJson() => {
    'farm_name': farmName,
    'location_hint': locationHint,
    'host': host.toJson(),
    'base_price_php': basePricePhp,
    'max_group_size': maxGroupSize,
    'activities': [for (final a in activities) a.toJson()],
    'safety_rules': safetyRules,
  };

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());

  final String farmName;

  /// Directions the host verified, from a known landmark.
  final String locationHint;
  final HostPreferences host;

  /// Per-person base tour price.
  final int basePricePhp;
  final int maxGroupSize;
  final List<Activity> activities;
  final List<String> safetyRules;
}
