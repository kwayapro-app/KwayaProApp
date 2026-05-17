import 'package:flutter/material.dart';

class GuestDirectorScreen extends StatelessWidget {
  final String sessionId;

  const GuestDirectorScreen({
    super.key,
    required this.sessionId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Guest Director Screen for session: $sessionId'),
      ),
    );
  }
}
