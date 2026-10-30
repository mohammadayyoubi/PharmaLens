import 'package:flutter/material.dart';

import '../theme/pharmalens_theme.dart';

/// Window-size classes shared by every screen.
///
/// compact  < 720   phones (bottom navigation)
/// medium   < 1100  tablets, small windows (navigation rail)
/// expanded >= 1100 laptops and desktops (sidebar, multi-column content)
class Breakpoints {
  const Breakpoints._();

  static const double medium = 720;
  static const double expanded = 1100;

  static bool isCompact(BuildContext context) => MediaQuery.sizeOf(context).width < medium;

  static bool isExpanded(BuildContext context) => MediaQuery.sizeOf(context).width >= expanded;

  /// Horizontal page padding for a content area of [width].
  static double gutter(double width) {
    if (width >= 1400) return 40;
    if (width >= expanded) return 32;
    if (width >= medium) return 24;
    if (width < 380) return 12;
    return 16;
  }

  /// Number of columns that fit [width] with items at least [minItemWidth] wide.
  static int columns(double width, {double minItemWidth = 320, int max = 4}) {
    final count = (width / minItemWidth).floor();
    return count.clamp(1, max);
  }
}

/// Centers page content with a readable max width and adaptive gutters.
class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.child,
    this.maxWidth = 1240,
    this.padTop = true,
  });

  final Widget child;
  final double maxWidth;
  final bool padTop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter = Breakpoints.gutter(constraints.maxWidth);

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth + gutter * 2),
            child: Padding(
              padding: EdgeInsets.fromLTRB(gutter, padTop ? 12 : 0, gutter, 0),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Lays children out in as many equal columns as fit, in reading order.
class AdaptiveGrid extends StatelessWidget {
  const AdaptiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 320,
    this.maxColumns = 3,
    this.spacing = 14,
  });

  final List<Widget> children;
  final double minItemWidth;
  final int maxColumns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = Breakpoints.columns(
          constraints.maxWidth + spacing,
          minItemWidth: minItemWidth + spacing,
          max: maxColumns,
        );

        if (columns == 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: spacing),
                children[i],
              ],
            ],
          );
        }

        final rows = <Widget>[];
        for (var start = 0; start < children.length; start += columns) {
          final rowChildren = <Widget>[];
          for (var c = 0; c < columns; c++) {
            if (c > 0) rowChildren.add(SizedBox(width: spacing));
            final index = start + c;
            rowChildren.add(Expanded(child: index < children.length ? children[index] : const SizedBox.shrink()));
          }
          if (rows.isNotEmpty) rows.add(SizedBox(height: spacing));
          rows.add(IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: rowChildren),
          ));
        }

        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
      },
    );
  }
}

/// Title row used above content sections.
class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);

    return Row(
      children: [
        if (icon != null) ...[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: palette.tealSurface,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: PharmaLensColors.teal, size: 19),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// A rounded surface card that follows the theme in light and dark mode.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.color,
    this.borderColor,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);
    final radius = BorderRadius.circular(20);

    final content = Ink(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? palette.surface,
        borderRadius: radius,
        border: Border.all(color: borderColor ?? palette.border),
        boxShadow: palette.cardShadow,
      ),
      child: child,
    );

    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: onTap == null ? content : InkWell(onTap: onTap, borderRadius: radius, child: content),
      ),
    );
  }
}

/// Back button that only appears when the current navigator can pop, so
/// screens work both as shell tabs and as pushed pages.
class AdaptiveBackButton extends StatelessWidget {
  const AdaptiveBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (!Navigator.of(context).canPop()) {
      return const SizedBox.shrink();
    }
    return BackButton(onPressed: onPressed);
  }
}

/// Shrinks its child slightly while pressed, for cards and tiles that act
/// as buttons.
class PressableScale extends StatefulWidget {
  const PressableScale({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  void _set(bool value) {
    if (widget.enabled && _down != value) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Fades and slides its child in once, [delay] after it is first built, for
/// a staggered page entrance. Honors the system "reduce motion" setting.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;

    final total = const Duration(milliseconds: 420) + delay;
    final start = delay.inMilliseconds / total.inMilliseconds;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      builder: (context, value, child) {
        final t = Curves.easeOutCubic.transform(((value - start) / (1 - start)).clamp(0.0, 1.0));
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: child),
        );
      },
      child: child,
    );
  }
}
