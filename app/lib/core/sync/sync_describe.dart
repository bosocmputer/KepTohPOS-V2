import 'dart:convert';

import 'package:app/core/data/local/local_db.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/domain/domain.dart';

const Map<String, String> _actions = <String, String>{
  'settle_bill': 'คิดเงิน',
  'void_bill': 'ยกเลิกบิล',
  'send_round': 'ส่งรายการอาหาร',
  'adjust_sent': 'แก้รายการที่ส่งแล้ว',
  'cancel_table': 'ยกเลิกโต๊ะ',
  'close_table': 'ปิดโต๊ะ',
  'open_shift': 'เปิดกะ',
  'close_shift': 'ปิดกะ',
  'set_table_notes': 'แก้หมายเหตุโต๊ะ',
};

String _two(int n) => n.toString().padLeft(2, '0');

/// `HH:mm`, with the day in front when it was not today.
String syncTime(DateTime at, DateTime now) {
  final t = at.toLocal();
  final n = now.toLocal();
  final hm = '${_two(t.hour)}:${_two(t.minute)}';
  final today = t.year == n.year && t.month == n.month && t.day == n.day;
  return today ? hm : '${t.day}/${t.month} $hm';
}

/// One line a cashier can read, e.g.
/// `คิดเงิน · บิล 000004 · โต๊ะ A1 · ฿798 · 18:27`.
String describeEntry(OutboxEntry e, PosState shop, DateTime now) {
  final p = jsonDecode(e.params) as Map<String, dynamic>;
  final parts = <String>[_actions[e.fn] ?? e.fn];
  final billId = p['p_bill_id'] as String?;
  final bill = billId == null
      ? null
      : shop.sales.where((b) => b.id == billId).firstOrNull;
  if (bill != null) {
    parts
      ..add('บิล ${bill.no}')
      ..add('โต๊ะ ${bill.tableName}')
      ..add(baht(bill.total));
  } else if (p['p_table_id'] case final String tableId) {
    final table = shop.tables.where((t) => t.id == tableId).firstOrNull;
    if (table != null) parts.add('โต๊ะ ${table.name}');
  }
  parts.add(syncTime(e.createdAt, now));
  return parts.join(' · ');
}

/// Why the server refused a command and what to do about it.
(String why, String todo) refusalReason(String? error) {
  final e = (error ?? '').toLowerCase();
  if (e.contains('no open shift')) {
    return (
      'ไม่มีกะที่เปิดอยู่ตอนส่ง',
      'เปิดกะแล้วกด "ส่งใหม่" หรือให้ผู้จัดการตรวจสอบ',
    );
  }
  if (e.contains('staff session is invalid or expired')) {
    return (
      'การเข้าสู่ระบบของพนักงานหมดอายุ',
      'เข้าสู่ระบบด้วย PIN ใหม่ตอนมีเน็ต แล้วกด "ส่งใหม่"',
    );
  }
  if (e.contains('total mismatch')) {
    return (
      'ยอดเงินในเครื่องไม่ตรงกับที่ระบบคำนวณ (ราคาอาจถูกแก้ระหว่างออฟไลน์)',
      'ให้ผู้จัดการตรวจบิลนี้และแก้ไขในหน้าบิล',
    );
  }
  if (e.contains('receipt number already used')) {
    return (
      'เลขที่บิลซ้ำกับบิลที่มีอยู่แล้ว',
      'ให้ผู้จัดการตรวจสอบว่าบิลนี้ถูกส่งไปแล้วหรือไม่',
    );
  }
  if (e.contains('table session is closed') ||
      e.contains('table session is not open')) {
    return (
      'โต๊ะนี้ถูกปิดไปแล้วจากเครื่องอื่น',
      'ตรวจรายการในโต๊ะ แล้วให้ผู้จัดการตัดสินใจ',
    );
  }
  if (e.contains('already voided')) {
    return (
      'บิลนี้ถูกยกเลิกไปแล้ว',
      'ไม่ต้องส่งซ้ำ ให้ผู้จัดการตรวจสอบ',
    );
  }
  if (e.contains('not allowed') || e.contains('cannot')) {
    return (
      'สิทธิ์ของผู้ใช้ไม่พอสำหรับรายการนี้',
      'ให้ผู้จัดการเข้าสู่ระบบแล้วกด "ส่งใหม่"',
    );
  }
  return (
    'ระบบไม่รับรายการนี้',
    'กด "ส่งใหม่" ถ้ายังไม่ผ่านให้ผู้จัดการตรวจสอบ',
  );
}
