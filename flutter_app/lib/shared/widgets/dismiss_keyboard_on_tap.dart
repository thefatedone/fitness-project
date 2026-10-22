import 'package:flutter/material.dart';

/// Covers blank areas of the whole route. Child fields/buttons keep their own
/// tap gestures, so editing, selection and password visibility still work.
class DismissKeyboardOnTap extends StatelessWidget {
  const DismissKeyboardOnTap({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
    child: child,
  );
}
