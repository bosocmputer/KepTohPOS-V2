/// A repository command failed; [message] is safe to show to staff.
class PosCommandException implements Exception {
  const new(this.message);

  final String message;

  @override
  String toString() => message;
}
