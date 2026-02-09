import 'package:flutter/material.dart';

/// The app logo widget used in auth screens.
class AuthLogo extends StatelessWidget {
  final double height;

  const AuthLogo({
    super.key,
    this.height = 180,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icon/logofull.png',
      height: height,
    );
  }
}
