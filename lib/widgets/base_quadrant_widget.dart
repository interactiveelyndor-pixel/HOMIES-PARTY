import 'package:flutter/material.dart';
import '../models/player_color.dart';
import '../theme/ludo_theme.dart';

class BaseQuadrantWidget extends StatelessWidget {
  final PlayerColor color;
  final double size;
  final bool isActive;

  const BaseQuadrantWidget({
    super.key,
    required this.color,
    required this.size,
    this.isActive = true,
  });

  @override
  Widget build(BuildContext context) {
    final primary = LudoTheme.getPrimary(color);
    final dark = LudoTheme.getDark(color);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isActive
              ? [primary, dark]
              : [
                  primary.withValues(alpha: 0.35),
                  dark.withValues(alpha: 0.35),
                ],
        ),
      ),
      child: Center(
        child: Container(
          width: size * 0.72,
          height: size * 0.72,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(size * 0.12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(size * 0.08),
            child: GridView.count(
              crossAxisCount: 2,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: size * 0.08,
              crossAxisSpacing: size * 0.08,
              children: List.generate(4, (index) {
                return Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive
                        ? primary.withValues(alpha: 0.2)
                        : Colors.grey.withValues(alpha: 0.15),
                    border: Border.all(
                      color: isActive ? primary : Colors.grey.shade400,
                      width: 2.0,
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
