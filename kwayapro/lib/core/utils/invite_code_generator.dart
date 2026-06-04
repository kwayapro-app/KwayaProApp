import 'dart:math';

class InviteCodeGenerator {
  static String generate() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // exclude 0/O/I/1 for readability
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }
}
