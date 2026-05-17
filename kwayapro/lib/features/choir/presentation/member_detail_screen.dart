import 'package:flutter/material.dart';

class MemberDetailScreen extends StatelessWidget {
  final String userId;

  const MemberDetailScreen({
    super.key,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Member Detail Screen for user: $userId'),
      ),
    );
  }
}
