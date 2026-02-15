import 'package:flutter/material.dart';

/// A centered loading indicator widget.
class LoadingIndicator extends StatelessWidget {
  final double size;
  final Color? color;

  const LoadingIndicator({
    super.key,
    this.size = 36,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          valueColor: color != null
              ? AlwaysStoppedAnimation<Color>(color!)
              : null,
        ),
      ),
    );
  }
}
