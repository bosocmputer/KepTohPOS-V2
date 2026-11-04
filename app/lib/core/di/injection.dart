import 'package:app/core/data/mock_pos_repository.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/domain/pos_repository.dart';
import 'package:app/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:app/features/sale/presentation/bloc/sale_bloc.dart';
import 'package:app/features/shift/presentation/bloc/shift_bloc.dart';
import 'package:app/features/tables/presentation/cubit/tables_cubit.dart';
import 'package:get_it/get_it.dart';

/// Global service locator instance.
final GetIt sl = GetIt.instance;

/// Initializes app-level dependencies.
Future<void> configureDependencies() async {
  if (!sl.isRegistered<ThemeCubit>()) {
    sl.registerFactory<ThemeCubit>(ThemeCubit.new);
  }
  if (!sl.isRegistered<PosRepository>()) {
    final repo = await MockPosRepository.loadFromAssets();
    sl.registerSingleton<PosRepository>(repo);
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
}
