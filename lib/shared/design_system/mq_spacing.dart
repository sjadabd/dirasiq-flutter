import 'package:flutter/widgets.dart';

/// Spacing scale. Derived from the `gap` values measured in the design export
/// (4 / 6 / 8 / 10 / 14 / 16 / 22 / 34 px) and normalised onto a clean 4-step
/// rhythm. Use these instead of bare numbers so layouts stay on-grid.
abstract final class MqSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  static const SizedBox gapXxs = SizedBox(width: xxs, height: xxs);
  static const SizedBox gapXs = SizedBox(width: xs, height: xs);
  static const SizedBox gapSm = SizedBox(width: sm, height: sm);
  static const SizedBox gapMd = SizedBox(width: md, height: md);
  static const SizedBox gapLg = SizedBox(width: lg, height: lg);
  static const SizedBox gapXl = SizedBox(width: xl, height: xl);

  static const EdgeInsets pagePadding = EdgeInsets.all(lg);
  static const EdgeInsets cardPadding = EdgeInsets.all(lg);
  static const EdgeInsets listGutter = EdgeInsets.symmetric(horizontal: lg);
}

/// Corner radii. The export is a flattened raster (no CSS `border-radius` to
/// read), so these follow the soft, rounded character visible in the mockup:
/// pill-shaped chips/buttons, generously rounded cards.
abstract final class MqRadius {
  static const double xs = 8;
  static const double sm = 10;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double pill = 999;

  static const BorderRadius brXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius brSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius brXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius brPill = BorderRadius.all(Radius.circular(pill));
}

/// Standard control heights, sized for comfortable touch targets.
abstract final class MqSize {
  static const double buttonHeight = 52;
  static const double buttonHeightSm = 40;
  static const double inputHeight = 52;
  static const double chipHeight = 34;
  static const double bottomNavHeight = 64;
  static const double iconSm = 18;
  static const double iconMd = 22;
  static const double iconLg = 26;
}
