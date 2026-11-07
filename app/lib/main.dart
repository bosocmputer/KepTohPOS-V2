import 'package:app/app.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/features/onboarding/presentation/onboarding_app.dart';
import 'package:flutter/material.dart';

/// `supabase` runs against the real backend; anything else uses mock data.
const String _kBackend = String.fromEnvironment('POS_BACKEND');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_kBackend == 'supabase') {
    runApp(const OnboardingApp());
    return;
  }
  await configureDependencies();
  runApp(const KepTohApp());
}
