import 'package:app/core/utils/formatters.dart';
import 'package:app/core/utils/thai_tax.dart';
import 'package:app/core/widgets/dropdown.dart';
import 'package:flutter/material.dart';

/// Month selector over the last [count] months; value is a `YYYY-MM` key.
class MonthPicker extends StatelessWidget {
  const new({
    required this.value,
    required this.onChanged,
    super.key,
    this.label = 'เดือน',
    this.count = 12,
    this.now,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String label;
  final int count;

  /// Reference date for the list (defaults to [DateTime.now]).
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final months = recentMonths(now ?? DateTime.now(), count);
    return Dropdown<String>(
      label: label,
      value: value,
      options: [
        for (final m in {...months, value})
          DropdownOption(value: m, label: thMonth(m)),
      ],
      onChanged: onChanged,
    );
  }
}
