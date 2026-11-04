import 'package:app/core/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Square rounded brand icon logo (`assets/logo.jpg`) rendered inside a
/// white rounded container with [BoxFit.contain] so the JPG never stretches.
class BrandLogo extends StatelessWidget {
  const new({
    super.key,
    this.size = AppDimensions.avatarSm,
    this.radius = AppDimensions.radiusSm,
  });

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppRawTokens.paper,
        borderRadius: BorderRadius.circular(radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/logo.jpg',
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}

/// Brand logo with wordmark (`assets/logo_name.jpg`) rendered inside a white
/// rounded badge container with [BoxFit.contain] so the JPG never stretches.
class BrandLogoName extends StatelessWidget {
  const new({
    super.key,
    this.height = AppDimensions.avatarSm,
    this.radius = AppDimensions.radiusMd,
  });

  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space3,
        vertical: AppDimensions.space1_5,
      ),
      decoration: BoxDecoration(
        color: AppRawTokens.paper,
        borderRadius: BorderRadius.circular(radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/logo_name.jpg',
        height: height,
        fit: BoxFit.contain,
      ),
    );
  }
}
