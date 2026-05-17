import 'package:flutter/material.dart';

class AttendanceScreen extends StatelessWidget {
  final String sessionId;

  const AttendanceScreen({
    super.key,
    required this.sessionId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Attendance Screen for session: $sessionId'),
      ),
    );
  }
}
