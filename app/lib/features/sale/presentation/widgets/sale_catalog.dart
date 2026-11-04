import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/features/sale/presentation/bloc/sale_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// List of selectable buffet packages inside `SaleMainContent`.
class SalePackagesList extends StatelessWidget {
  const new({required this.state, super.key});
  final SaleState state;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final bloc = context.read<SaleBloc>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final p in state.activePackages)
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.space2_5),
            child: Material(
              color: p.id == state.pkgId ? t.primarySoft : t.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                side: BorderSide(
                  color: p.id == state.pkgId ? t.primary : t.line,
                  width: p.id == state.pkgId
                      ? AppDimensions.borderBold
                      : AppDimensions.borderThin,
                ),
              ),
              child: InkWell(
                key: ValueKey('pkg-card-${p.id}'),
                onTap: () => bloc.add(SalePackageSelected(p.id)),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.space4),
                  child: Row(
                    children: [
                      Container(
                        width: AppDimensions.avatarMd,
                        height: AppDimensions.avatarMd,
                        decoration: BoxDecoration(
                          color: p.id == state.pkgId
                              ? t.primary.withValues(alpha: 0.16)
                              : t.surface2,
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusSm,
                          ),
                        ),
                        child: Center(
                          child: AppIcon(
                            'package',
                            color: p.id == state.pkgId ? t.primaryInk : t.muted,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.space3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              style: tt.titleMedium?.copyWith(color: t.ink),
                            ),
                            const SizedBox(height: AppDimensions.spaceHalf),
                            Text(
                              p.timeLimit > 0
                                  ? 'เด็ก ${baht(p.childPrice)} · '
                                        '${p.timeLimit} นาที'
                                  : 'เด็ก ${baht(p.childPrice)} · ไม่จำกัดเวลา',
                              style: tt.bodySmall?.copyWith(color: t.muted),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${baht(p.adultPrice)} / ผู้ใหญ่',
                        style: tt.titleMedium?.copyWith(
                          color: t.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Grid of selectable addon / drink cards inside `SaleMainContent`.
class SaleAddonsGrid extends StatelessWidget {
  const new({required this.state, required this.category, super.key});
  final SaleState state;
  final String category;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<SaleBloc>();
    final items = state.activeAddons
        .where(
          (x) =>
              (x.category.isNotEmpty ? x.category : 'เครื่องดื่ม') == category,
        )
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final cols = AppDimensions.productGridColumns(
          MediaQuery.sizeOf(context).width,
        );
        const spacing = AppDimensions.space3;
        final itemW = (w - (cols - 1) * spacing) / cols;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final x in items)
              SizedBox(
                width: itemW,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ProductCard(
                      key: ValueKey('addon-card-${x.id}'),
                      name: x.name,
                      category: x.category,
                      price: x.price,
                      stock: x.stock,
                      selected: (state.ad[x.id] ?? 0) > 0,
                      onTap: x.stock > 0
                          ? () => bloc.add(SaleAddonIncremented(x.id))
                          : null,
                    ),
                    if ((state.ad[x.id] ?? 0) > 0) ...[
                      const SizedBox(height: AppDimensions.space1_5),
                      Align(
                        alignment: Alignment.centerRight,
                        child: PosStepper(
                          key: ValueKey('addon-stepper-${x.id}'),
                          label: x.name,
                          value: state.ad[x.id] ?? 0,
                          onChanged: (q) => bloc.add(
                            SaleAddonQtyChanged(addonId: x.id, qty: q),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
