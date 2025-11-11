import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Color? color;
  final Color? textColor;
  final Color? borderColor;
  final IconData? icon;

  const CustomButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.color,
    this.textColor,
    this.borderColor,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    final ButtonStyle style = ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: textColor,
      side: borderColor != null ? BorderSide(color: borderColor!) : null,
      shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadiusMD),
      padding: EdgeInsets.symmetric(
        vertical: AppTheme.spacingMD,
        horizontal: isSmallScreen ? AppTheme.spacingMD : AppTheme.spacingLG,
      ),
      textStyle: AppTheme.textStyleBodyLarge.copyWith(
        fontWeight: AppTheme.fontWeightSemiBold,
        fontSize: isSmallScreen ? AppTheme.fontSizeSM : AppTheme.fontSizeMD,
      ),
      elevation: AppTheme.elevationMedium,
      minimumSize: Size(0, 48), // Allow button to shrink horizontally
    );
    return ElevatedButton(
      onPressed: onPressed,
      style: style,
      child: icon != null
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: isSmallScreen ? 18 : 20),
                SizedBox(width: AppTheme.spacingXS),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    softWrap: true,
                  ),
                ),
              ],
            )
          : Text(
              label,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              textAlign: TextAlign.center,
              softWrap: true,
            ),
    );
  }
} 