import 'dart:ui';
import 'package:flutter/material.dart';
import 'app_palette.dart';
import 'app_text_styles.dart';

/// Styled modal dialog frame helper for the Classic Board Games app.
/// Note: Created as a design system component for future steps; not yet
/// applied to existing in-game dialogs.
class AppDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget>? actions;
  final Widget? icon;
  final VoidCallback? onClose;
  final double maxWidth;

  const AppDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions,
    this.icon,
    this.onClose,
    this.maxWidth = 400.0,
  });

  /// Displays the dialog using the shared frame design.
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget content,
    List<Widget>? actions,
    Widget? icon,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => AppDialog(
        title: title,
        content: content,
        actions: actions,
        icon: icon,
        onClose: () => Navigator.of(ctx).maybePop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1E293B),
                      Color(0xFF0F172A),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header with optional icon & title
                    Row(
                      children: [
                        if (icon != null) ...[
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppPalette.glassSurface,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppPalette.glassBorder,
                                width: 1,
                              ),
                            ),
                            child: icon,
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Text(
                            title,
                            style: AppTextStyles.heading,
                          ),
                        ),
                        if (onClose != null)
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: AppPalette.textSecondary,
                              size: 20,
                            ),
                            onPressed: onClose,
                            splashRadius: 20,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Body Content
                    Flexible(
                      child: SingleChildScrollView(
                        child: content,
                      ),
                    ),

                    // Actions
                    if (actions != null && actions!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: actions!
                            .map(
                              (action) => Padding(
                                padding: const EdgeInsets.only(left: 10),
                                child: action,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
