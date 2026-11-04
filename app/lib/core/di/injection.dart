import 'package:app/core/theme/app_theme.dart';
import 'package:get_it/get_it.dart';

/// Global service locator instance.
final GetIt sl = GetIt.instance;

/// Initializes app-level dependencies.
Future<void> configureDependencies() async {
  if (!sl.isRegistered<ThemeCubit>()) {
    sl.registerFactory<ThemeCubit>(ThemeCubit.new);
  }
}

