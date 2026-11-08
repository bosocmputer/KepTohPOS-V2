import 'dart:async';

import 'package:app/core/data/local/connection_monitor.dart';
import 'package:app/core/data/mock_pos_repository.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/core/router/app_router.dart';
import 'package:app/core/sync/sync_center.dart';
import 'package:app/core/sync/sync_status_sheet.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/busy_overlay.dart';
import 'package:app/core/widgets/sync_status_banner.dart';
import 'package:app/domain/pos_repository.dart';
import 'package:app/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:app/features/bills/presentation/cubit/bills_cubit.dart';
import 'package:app/features/shift/presentation/bloc/shift_bloc.dart';
import 'package:app/features/tables/presentation/cubit/tables_cubit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Root application widget with app-level [BlocProvider]s.
class KepTohApp extends StatefulWidget {
  const new({
    super.key,
    this.themeCubit,
    this.repository,
    this.authCubit,
    this.shiftBloc,
    this.tablesCubit,
    this.billsCubit,
    this.now,
    this.initialLocation = '/tables',
    this.busy,
    this.sync,
  });

  final ThemeCubit? themeCubit;
  final PosRepository? repository;
  final AuthCubit? authCubit;
  final ShiftBloc? shiftBloc;
  final TablesCubit? tablesCubit;
  final BillsCubit? billsCubit;
  final DateTime? now;
  final String initialLocation;

  /// `true` while the server is handling a request; `null` in mock mode.
  final ValueListenable<bool>? busy;

  /// Online state and the number of commands waiting; `null` in mock mode.
  final ValueListenable<SyncStatus>? sync;

  @override
  State<KepTohApp> createState() => _KepTohAppState();
}

class _KepTohAppState extends State<KepTohApp> {
  late final PosRepository _repo =
      widget.repository ??
      (sl.isRegistered<PosRepository>()
          ? sl<PosRepository>()
          : MockPosRepository.createFallback());

  late final ThemeCubit _themeCubit =
      widget.themeCubit ??
      (widget.repository == null && sl.isRegistered<ThemeCubit>()
          ? sl<ThemeCubit>()
          : ThemeCubit(repository: _repo));

  late final AuthCubit _authCubit =
      widget.authCubit ?? AuthCubit(_repo, now: widget.now);

  late final ShiftBloc _shiftBloc = widget.shiftBloc ?? ShiftBloc(_repo);

  late final TablesCubit _tablesCubit =
      widget.tablesCubit ?? TablesCubit(_repo, now: widget.now);

  late final BillsCubit _billsCubit =
      widget.billsCubit ?? BillsCubit(_repo, now: widget.now);

  /// The banner sits above the navigator, so the sheet opens on the
  /// router's navigator.
  void _openSyncSheet() {
    final nav = _router.routerDelegate.navigatorKey.currentContext;
    final center = SyncCenter.maybe;
    if (nav != null && center != null) {
      unawaited(showSyncStatusSheet(nav, center));
    }
  }

  late final GoRouter _router = createAppRouter(
    initialLocation: widget.initialLocation,
    authCubit: _authCubit,
    now: widget.now,
  );

  @override
  void dispose() {
    if (widget.themeCubit == null) {
      unawaited(_themeCubit.close());
    }
    if (widget.authCubit == null) {
      unawaited(_authCubit.close());
    }
    if (widget.shiftBloc == null) {
      unawaited(_shiftBloc.close());
    }
    if (widget.tablesCubit == null) {
      unawaited(_tablesCubit.close());
    }
    if (widget.billsCubit == null) {
      unawaited(_billsCubit.close());
    }
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<PosRepository>.value(
      value: _repo,
      child: MultiBlocProvider(
        providers: [
          BlocProvider<ThemeCubit>.value(value: _themeCubit),
          BlocProvider<AuthCubit>.value(value: _authCubit),
          BlocProvider<ShiftBloc>.value(value: _shiftBloc),
          BlocProvider<TablesCubit>.value(value: _tablesCubit),
          BlocProvider<BillsCubit>.value(value: _billsCubit),
        ],
        child: BlocBuilder<ThemeCubit, ThemeState>(
          builder: (context, state) {
            return MaterialApp.router(
              title: 'KepToh POS',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.build(
                brightness: Brightness.light,
                palette: state.palette,
              ),
              darkTheme: AppTheme.build(
                brightness: Brightness.dark,
                palette: state.palette,
              ),
              themeMode: state.mode.themeMode,
              routerConfig: _router,
              builder: (context, child) {
                final busy = widget.busy;
                final sync = widget.sync;
                var page = child ?? const SizedBox.shrink();
                if (sync != null) {
                  page = SyncStatusBanner(
                    status: sync,
                    onTap: _openSyncSheet,
                    child: page,
                  );
                }
                return busy == null
                    ? page
                    : BusyOverlay(busy: busy, child: page);
              },
            );
          },
        ),
      ),
    );
  }
}
