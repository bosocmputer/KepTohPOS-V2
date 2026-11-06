import 'dart:async';

import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/domain/domain.dart';
import 'package:flutter/material.dart';

/// Isolated live-ticking timer badge for occupied tables (`RepaintBoundary`
/// leaf widget so 1-second countdown ticks never rebuild `TablesPage` or
/// `TableCard`).
class TableLiveTimer extends StatefulWidget {
  const new({
    required this.posState,
    required this.tableId,
    required this.openTable,
    super.key,
    this.fixedNow,
  });

  final PosState posState;
  final String tableId;
  final OpenTableState openTable;
  final DateTime? fixedNow;

  @override
  State<TableLiveTimer> createState() => _TableLiveTimerState();
}

class _TableLiveTimerState extends State<TableLiveTimer> {
  Timer? _timer;

  int get _limitMin {
    final pkgId = widget.openTable.packageId;
    for (final p in widget.posState.packages) {
      if (p.id == pkgId) return p.timeLimit;
    }
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant TableLiveTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fixedNow != widget.fixedNow ||
        oldWidget.openTable.packageId != widget.openTable.packageId ||
        oldWidget.openTable.openedAt != widget.openTable.openedAt) {
      _syncTimer();
    }
  }

  void _syncTimer() {
    _timer?.cancel();
    _timer = null;
    // In deterministic tests (`fixedNow != null`), do not start a periodic
    // timer so `tester.pumpAndSettle()` completes immediately.
    if (widget.fixedNow != null) return;
    final interval = _limitMin > 0
        ? const Duration(seconds: 1)
        : const Duration(seconds: 30);
    _timer = Timer.periodic(interval, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmtClock(int totalSeconds) {
    final s = totalSeconds < 0 ? 0 : totalSeconds;
    final hrs = s ~/ 3600;
    final mins = (s % 3600) ~/ 60;
    final secs = s % 60;
    if (hrs > 0) {
      return '${padInt(hrs)}:${padInt(mins)}:${padInt(secs)}';
    }
    return '${padInt(mins)}:${padInt(secs)}';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final current = widget.fixedNow ?? DateTime.now();
    final opened = DateTime.parse(widget.openTable.openedAt);
    final elapsedSec = current.difference(opened).inSeconds;
    final mins = current.difference(opened).inMinutes;
    final lim = _limitMin;

    if (!widget.posState.shop.useTimer || lim <= 0) {
      return RepaintBoundary(
        child: Text(
          'นั่งมา $mins น.',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tt.labelSmall?.copyWith(
            color: t.muted,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    final totalSec = lim * 60;
    final remSec = totalSec - elapsedSec;
    final eatUntilIso = opened
        .add(Duration(minutes: lim))
        .toUtc()
        .toIso8601String();
    final deadline = thTime(eatUntilIso);

    if (remSec <= 0) {
      final overMin = mins - lim;
      final overClock = _fmtClock(-remSec);
      return RepaintBoundary(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space2,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: t.dangerSoft,
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            border: Border.all(color: t.danger),
          ),
          child: Text(
            key: ValueKey('table-overtime-${widget.tableId}'),
            'เกินเวลา $overMin น. (+$overClock · ครบ $deadline)',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tt.labelSmall?.copyWith(
              color: t.dangerInk,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    final isWarn = remSec <= 15 * 60;
    final clockTxt = _fmtClock(remSec);
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space2,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: isWarn ? t.primarySoft : t.surface2,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          border: Border.all(color: isWarn ? t.primary : t.line),
        ),
        child: Text(
          key: ValueKey('table-countdown-${widget.tableId}'),
          'เหลือ $clockTxt · ถึง $deadline',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tt.labelSmall?.copyWith(
            color: isWarn ? t.primaryInk : t.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
