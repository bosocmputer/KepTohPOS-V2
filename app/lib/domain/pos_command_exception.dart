/// A repository command failed; [message] is safe to show to staff.
class PosCommandException implements Exception {
  const new(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The server could not be reached; offline-capable commands queue instead.
class PosOfflineException extends PosCommandException {
  const new() : super('เชื่อมต่อเซิร์ฟเวอร์ไม่ได้');
}
