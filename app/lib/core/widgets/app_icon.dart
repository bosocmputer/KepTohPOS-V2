import 'package:app/core/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Maps semantic icon keys (`ICONS` in `prototype/index.html`) to standard
/// platform [IconData] without custom inline SVGs.
abstract final class AppIcons {
  static const Map<String, IconData> byName = <String, IconData>{
    'tables': Icons.grid_view_rounded,
    'receipt': Icons.receipt_long_outlined,
    'box': Icons.inventory_2_outlined,
    'clock': Icons.schedule_rounded,
    'chart': Icons.bar_chart_rounded,
    'list': Icons.format_list_bulleted_rounded,
    'gear': Icons.settings_outlined,
    'user': Icons.person_outline_rounded,
    'plus': Icons.add_rounded,
    'minus': Icons.remove_rounded,
    'x': Icons.close_rounded,
    'trash': Icons.delete_outline_rounded,
    'edit': Icons.edit_outlined,
    'copy': Icons.content_copy_rounded,
    'flame': Icons.local_fire_department_rounded,
    'printer': Icons.print_outlined,
    'check': Icons.check_rounded,
    'sidebar': Icons.view_sidebar_outlined,
    'logout': Icons.logout_rounded,
    'chevron': Icons.keyboard_arrow_down_rounded,
    'search': Icons.search_rounded,
    'backspace': Icons.backspace_outlined,
    'menu': Icons.menu_rounded,
    'cup': Icons.local_cafe_outlined,
    'back': Icons.chevron_left_rounded,
    'filter': Icons.tune_rounded,
  };

  static IconData resolve(String name) => byName[name] ?? Icons.circle_outlined;
}

/// Shared icon component (`Icon` in `prototype/index.html`).
class AppIcon extends StatelessWidget {
  const new(
    this.name, {
    super.key,
    this.size = AppDimensions.iconMd,
    this.color,
  });

  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Icon(
    AppIcons.resolve(name),
    size: size,
    color: color ?? IconTheme.of(context).color ?? context.tokens.ink,
  );
}
