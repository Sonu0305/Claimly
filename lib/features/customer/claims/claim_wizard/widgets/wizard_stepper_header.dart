import 'package:flutter/material.dart';
import '../../../../../core/constants/app_colors.dart';

class WizardStepperHeader extends StatelessWidget {
  final int currentStep;

  const WizardStepperHeader({
    super.key,
    required this.currentStep,
  });

  static const List<String> stepLabels = [
    'Product',
    'Type',
    'Details',
    'Proof',
    'Review',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
      ),
      child: Row(
        children: List.generate(stepLabels.length * 2 - 1, (index) {
          if (index.isOdd) {
            final stepIndex = index ~/ 2;
            final isCompleted = currentStep > stepIndex;
            return Expanded(
              child: Container(
                height: 2,
                color: isCompleted ? AppColors.primary : (isDark ? AppColors.borderDark : AppColors.gray300),
              ),
            );
          }

          final stepIndex = index ~/ 2;
          final isActive = currentStep == stepIndex;
          final isCompleted = currentStep > stepIndex;

          Color circleColor;
          Color textColor;
          if (isCompleted) {
            circleColor = AppColors.success;
            textColor = Colors.white;
          } else if (isActive) {
            circleColor = AppColors.primary;
            textColor = Colors.white;
          } else {
            circleColor = isDark ? AppColors.cardDark : AppColors.gray200;
            textColor = isDark ? AppColors.gray400 : AppColors.gray600;
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: circleColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : Text(
                          '${stepIndex + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                stepLabels[stepIndex],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive
                      ? AppColors.primary
                      : (isDark ? AppColors.gray400 : AppColors.gray600),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

