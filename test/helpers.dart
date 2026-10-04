import 'dart:io';

import 'package:turaista/core/profile.dart';

FarmProfile loadExampleProfile() =>
    FarmProfile.fromJsonString(File('assets/profiles/example_farm.json').readAsStringSync());
