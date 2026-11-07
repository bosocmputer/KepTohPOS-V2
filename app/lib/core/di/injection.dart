import 'package:app/core/data/mock_pos_repository.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/domain/pos_repository.dart';
import 'package:app/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:app/features/bills/presentation/cubit/bills_cubit.dart';
import 'package:app/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:app/features/onboarding/data/device_session.dart';
import 'package:app/features/reports/presentation/cubit/reports_cubit.dart';
import 'package:app/features/sale/presentation/bloc/sale_bloc.dart';
import 'package:app/features/setup/presentation/cubit/setup_cubit.dart';
import 'package:app/features/shift/presentation/bloc/shift_bloc.dart';
import 'package:app/features/stock/presentation/bloc/stock_count_bloc.dart';
import 'package:app/features/stock/presentation/cubit/stock_cubit.dart';
import 'package:app/features/tables/presentation/cubit/tables_cubit.dart';
import 'package:get_it/get_it.dart';

/// Global service locator instance.
final GetIt sl = GetIt.instance;

/// Initializes app-level dependencies.
Future<void> configureDependencies({
  PosRepository? repository,
  DeviceSession? deviceSession,
}) async {
  if (deviceSession != null && !sl.isRegistered<DeviceSession>()) {
    sl.registerSingleton<DeviceSession>(deviceSession);
  }
  if (!sl.isRegistered<PosRepository>()) {
    final repo = repository ?? await MockPosRepository.loadFromAssets();
    sl.registerSingleton<PosRepository>(repo);
  }
  if (!sl.isRegistered<ThemeCubit>()) {
    sl.registerFactory<ThemeCubit>(
      () => ThemeCubit(repository: sl<PosRepository>()),
    );
  }
  if (!sl.isRegistered<AuthCubit>()) {
    sl.registerFactory<AuthCubit>(() => AuthCubit(sl<PosRepository>()));
  }
  if (!sl.isRegistered<ShiftBloc>()) {
    sl.registerFactory<ShiftBloc>(() => ShiftBloc(sl<PosRepository>()));
  }
  if (!sl.isRegistered<TablesCubit>()) {
    sl.registerFactory<TablesCubit>(() => TablesCubit(sl<PosRepository>()));
  }
  if (!sl.isRegistered<SaleBloc>()) {
    sl.registerFactory<SaleBloc>(
      () => SaleBloc(sl<PosRepository>(), initialTableId: 't1'),
    );
  }
  if (!sl.isRegistered<BillsCubit>()) {
    sl.registerFactory<BillsCubit>(() => BillsCubit(sl<PosRepository>()));
  }
  if (!sl.isRegistered<StockCubit>()) {
    sl.registerFactory<StockCubit>(() => StockCubit(sl<PosRepository>()));
  }
  if (!sl.isRegistered<StockCountBloc>()) {
    sl.registerFactory<StockCountBloc>(
      () => StockCountBloc(repository: sl<PosRepository>()),
    );
  }
  if (!sl.isRegistered<DashboardCubit>()) {
    sl.registerFactory<DashboardCubit>(
      () => DashboardCubit(sl<PosRepository>()),
    );
  }
  if (!sl.isRegistered<ReportsCubit>()) {
    sl.registerFactory<ReportsCubit>(() => ReportsCubit(sl<PosRepository>()));
  }
  if (!sl.isRegistered<SetupCubit>()) {
    sl.registerFactory<SetupCubit>(() => SetupCubit(sl<PosRepository>()));
  }
}
