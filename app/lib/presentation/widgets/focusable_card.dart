// Presentation — glass-morphism focusable card
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FocusableCard extends StatelessWidget {
  final String title;
  final String icon;
  final bool isFocused;
  final bool isOn;
  final VoidCallback? onTap;

  const FocusableCard({
    super.key,
    required this.title,
    required this.icon,
    this.isFocused = false,
    this.isOn = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isFocused ? kCyanDim : kSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isFocused ? kCyan : kBorder,
            width: isFocused ? 1.5 : 1,
          ),
          boxShadow: isFocused
              ? [
                  BoxShadow(
                    color: kCyan.withValues(alpha: 0.25),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon with state glow
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOn
                      ? kAmber.withValues(alpha: 0.12)
                      : kBorder.withValues(alpha: 0.6),
                  border: Border.all(
                    color: isOn ? kAmber.withValues(alpha: 0.5) : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(icon, style: const TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: kLabel(14).copyWith(
                  fontWeight: isFocused ? FontWeight.w600 : FontWeight.w400,
                  color: isFocused ? kText : kTextDim,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // State dot
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOn ? kAmber : kTextDim.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
