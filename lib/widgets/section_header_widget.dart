import 'package:flutter/material.dart';
import '../utils/constants.dart';

class SectionHeaderWidget extends StatelessWidget {
  final String label;
  final int? barCount;
  final double fontSize;
  final bool isActive;

  const SectionHeaderWidget({
    super.key,
    required this.label,
    required this.fontSize,
    this.barCount,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppDimensions.sectionSpacing * 0.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _dividerLine(),
          const SizedBox(width: 16),
          Text(
            barCount != null ? '$label  ·  $barCount BARS' : label,
            style: AppTextStyles.sectionHeader(fontSize).copyWith(
              color: isActive ? AppColors.accent : AppColors.sectionHeader,
            ),
          ),
          const SizedBox(width: 16),
          _dividerLine(),
        ],
      ),
    );
  }

  Widget _dividerLine() {
    return Container(
      width: 40,
      height: 1,
      color: AppColors.sectionHeader.withValues(alpha: 0.4),
    );
  }
}
