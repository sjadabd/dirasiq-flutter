/// MulhimIQ Design System.
///
/// Single import for the full system — tokens, themes, and reusable widgets,
/// all derived from the `Components.html` design export.
///
/// ```dart
/// import 'package:mulhimiq/shared/design_system/design_system.dart';
///
/// GetMaterialApp(
///   theme: MqTheme.light(),
///   darkTheme: MqTheme.dark(),
/// );
///
/// // In a widget:
/// MqCard(child: Text('مرحباً', style: context.text.titleMedium));
/// MqButton(label: 'إجراء أساسي', onPressed: () {});
/// ```
library;

export 'mq_colors.dart';
export 'mq_spacing.dart';
export 'mq_typography.dart';
export 'mq_theme.dart';

export 'widgets/mq_button.dart';
export 'widgets/mq_card.dart';
export 'widgets/mq_chip.dart';
export 'widgets/mq_bottom_nav.dart';
export 'widgets/mq_progress.dart';
export 'widgets/mq_stat.dart';
