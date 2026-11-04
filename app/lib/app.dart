import 'dart:async';

import 'package:app/core/di/injection.dart';
import 'package:app/core/router/app_router.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Root application widget with app-level [BlocProvider].
class KepTohApp extends StatefulWidget {
  const new({super.key, this.themeCubit});

  final ThemeCubit? themeCubit;

  @override
  State<KepTohApp> createState() => _KepTohAppState();
}

class _KepTohAppState extends State<KepTohApp> {
  late final GoRouter _router = createAppRouter();
  late final ThemeCubit _cubit =
      widget.themeCubit ??
      (sl.isRegistered<ThemeCubit>() ? sl<ThemeCubit>() : ThemeCubit());

  @override
  void dispose() {
    if (widget.themeCubit == null) {
      unawaited(_cubit.close());
    }
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ThemeCubit>.value(
      value: _cubit,
      child: BlocBuilder<ThemeCubit, ThemeState>(
        builder: (context, state) {
          return MaterialApp.router(
            title: 'KepToh POS',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.build(
              brand: state.brand,
              brightness: Brightness.light,
            ),
            darkTheme: AppTheme.build(
              brand: state.brand,
              brightness: Brightness.dark,
            ),
            themeMode: state.mode.themeMode,
            routerConfig: _router,
          );
        },
      ),
    );
  }
}
