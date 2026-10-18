import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shows a modal bottom sheet on the editor's dark surface with a matching
/// dark theme so inputs, chips and buttons keep proper contrast.
Future<T?> showDarkSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool? showDragHandle,
  ShapeBorder? shape,
  Color backgroundColor = const Color(0xFF121212),
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    showDragHandle: showDragHandle,
    shape: shape,
    backgroundColor: backgroundColor,
    builder: (ctx) => Theme(data: AppTheme.sheetTheme, child: Builder(builder: builder)),
  );
}
