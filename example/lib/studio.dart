import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

const _packagePubspecAsset = 'packages/reel_text/pubspec.yaml';

Future<String> _loadPackageVersionLabel() async {
  try {
    final pubspec = await rootBundle.loadString(_packagePubspecAsset);
    final version = RegExp(
      r'^version:\s*([^\s]+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec)?.group(1);
    return version == null || version.isEmpty ? 'v?' : 'v$version';
  } on Object {
    return 'v?';
  }
}

/// Shared palette, typography, and building blocks for the studio example.
abstract final class Studio {
  /// When false (tests), system fonts are used and no font fetching happens.
  static bool fontsEnabled = true;

  static Brightness _brightness = Brightness.dark;
  static ColorScheme? _cachedScheme;
  static _StudioPalette? _cachedPalette;
  static _StudioAccentPalette? _cachedAccents;

  static Brightness get brightness => _brightness;

  static set brightness(Brightness value) {
    if (_brightness == value) {
      return;
    }
    _brightness = value;
    _cachedScheme = null;
    _cachedPalette = null;
    _cachedAccents = null;
  }

  static bool get isLight => _brightness == Brightness.light;

  static ColorScheme get scheme =>
      _cachedScheme ??= _GoogleStudioScheme.fromBrightness(_brightness);

  static _StudioPalette get _palette =>
      _cachedPalette ??= _StudioPalette.fromScheme(scheme);

  static Color get transparent => Colors.transparent;
  static Color get white => _GoogleNeutral.white;
  static Color get black => _GoogleNeutral.black;
  static Color get background => _palette.background;
  static Color get surface => _palette.surface;
  static Color get surfaceRaised => _palette.surfaceRaised;
  static Color get inset => _palette.inset;
  static Color get border => _palette.border;
  static Color get borderBright => _palette.borderBright;
  static Color get text => _palette.text;
  static Color get muted => _palette.muted;
  static Color get faint => _palette.faint;
  static _StudioAccentPalette get _accents =>
      _cachedAccents ??= _StudioAccentPalette.fromScheme(scheme);

  static Color get primary => _accents.blue;
  static Color get success => _accents.green;
  static Color get warning => _accents.yellow;
  static Color get danger => _accents.red;
  static Color get info => _accents.cyan;
  static Color get violet => _accents.violet;
  static Color get sky => info;
  static Color get rose => danger;
  static Color get amber => warning;
  static Color get focus => primary;
  static const compactLabelLineHeight = 1.16;

  static Color tone(Color accent) {
    if (accent == amber) return warning;
    if (accent == rose) return danger;
    if (accent == sky) return info;
    if (accent == violet) return violet;
    return accent;
  }

  static Color onAccent(Color accent) {
    final darkInk = _GoogleNeutral.ink;
    final lightInk = _GoogleNeutral.white;
    return _contrastRatio(accent, lightInk) >= _contrastRatio(accent, darkInk)
        ? lightInk
        : darkInk;
  }

  static Color accentBorder(Color accent, {double? alpha}) {
    return tone(accent).withValues(alpha: alpha ?? (isLight ? 0.36 : 0.45));
  }

  static Color accentWash(Color accent, {double? alpha}) {
    return tone(accent).withValues(alpha: alpha ?? (isLight ? 0.075 : 0.08));
  }

  static List<Color> get chromaStops => [
    info,
    primary,
    violet,
    danger,
    warning,
    success,
  ];

  static Color chromaColor(int index, int total) {
    final stops = chromaStops;
    if (stops.length == 1) {
      return stops.first;
    }
    final t = total <= 1 ? 0.5 : index / (total - 1);
    final scaled = t.clamp(0, 1).toDouble() * (stops.length - 1);
    final left = scaled.floor().clamp(0, stops.length - 1).toInt();
    final right = left >= stops.length - 1 ? left : left + 1;
    return Color.lerp(stops[left], stops[right], scaled - left)!;
  }

  static double _contrastRatio(Color a, Color b) {
    final aLum = a.computeLuminance();
    final bLum = b.computeLuminance();
    final lighter = math.max(aLum, bLum);
    final darker = math.min(aLum, bLum);
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Display face: Instrument Sans, clean but less generic than Inter.
  static TextStyle display({
    double size = 64,
    Color? color,
    double height = 1.0,
    double letterSpacing = 0,
    FontWeight weight = FontWeight.w800,
  }) {
    final style = TextStyle(
      color: color ?? text,
      fontSize: size,
      height: height,
      letterSpacing: letterSpacing,
      fontWeight: weight,
    );
    if (!fontsEnabled) {
      return style;
    }
    return GoogleFonts.instrumentSans(textStyle: style);
  }

  /// Technical face: JetBrains Mono, crisp for small code and counters.
  static TextStyle mono({
    double size = 12,
    Color? color,
    FontWeight weight = FontWeight.w400,
    double letterSpacing = 0,
    double height = 1.4,
  }) {
    final style = TextStyle(
      color: color ?? muted,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      height: height,
      fontFamilyFallback: const ['Menlo', 'Consolas', 'monospace'],
    );
    return fontsEnabled ? GoogleFonts.jetBrainsMono(textStyle: style) : style;
  }

  /// Body face: system, quiet on purpose.
  static TextStyle body({
    double size = 13.5,
    Color? color,
    double height = 1.55,
    FontWeight weight = FontWeight.w400,
  }) {
    return TextStyle(
      color: color ?? muted,
      fontSize: size,
      height: height,
      fontWeight: weight,
    );
  }
}

class _StudioPalette {
  const _StudioPalette({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.inset,
    required this.border,
    required this.borderBright,
    required this.text,
    required this.muted,
    required this.faint,
  });

  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color inset;
  final Color border;
  final Color borderBright;
  final Color text;
  final Color muted;
  final Color faint;

  factory _StudioPalette.fromScheme(ColorScheme scheme) => _StudioPalette(
    background: scheme.surface,
    surface: scheme.surfaceContainerLowest,
    surfaceRaised: scheme.surfaceContainerLow,
    inset: scheme.surfaceContainer,
    border: scheme.outlineVariant,
    borderBright: scheme.outline,
    text: scheme.onSurface,
    muted: scheme.onSurfaceVariant,
    faint: _GoogleNeutral.grey500,
  );
}

class _StudioAccentPalette {
  const _StudioAccentPalette({
    required this.blue,
    required this.green,
    required this.yellow,
    required this.red,
    required this.cyan,
    required this.violet,
  });

  final Color blue;
  final Color green;
  final Color yellow;
  final Color red;
  final Color cyan;
  final Color violet;

  factory _StudioAccentPalette.fromScheme(ColorScheme scheme) =>
      _StudioAccentPalette(
        blue: scheme.primary,
        green: scheme.secondary,
        yellow: _GoogleStudioScheme.isLight(scheme)
            ? _GoogleAccent.yellow500
            : _GoogleAccent.yellow200,
        red: scheme.error,
        cyan: _GoogleStudioScheme.isLight(scheme)
            ? _GoogleAccent.blue500
            : _GoogleAccent.blue200,
        violet: scheme.tertiary,
      );
}

abstract final class _GoogleStudioScheme {
  static bool isLight(ColorScheme scheme) =>
      scheme.brightness == Brightness.light;

  static ColorScheme fromBrightness(Brightness brightness) {
    final light = brightness == Brightness.light;
    final base = ColorScheme.fromSeed(
      seedColor: _GoogleAccent.blue600,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );

    return base.copyWith(
      primary: light ? _GoogleAccent.blue600 : _GoogleAccent.blue200,
      onPrimary: light ? _GoogleNeutral.white : _GoogleNeutral.ink,
      primaryContainer: light ? _GoogleAccent.blue50 : _GoogleAccent.blue900,
      onPrimaryContainer: light ? _GoogleAccent.blue900 : _GoogleAccent.blue50,
      secondary: light ? _GoogleAccent.green500 : _GoogleAccent.green200,
      onSecondary: _GoogleNeutral.ink,
      secondaryContainer: light
          ? _GoogleAccent.green50
          : _GoogleAccent.green900,
      onSecondaryContainer: light
          ? _GoogleAccent.green900
          : _GoogleAccent.green50,
      tertiary: light ? _GoogleAccent.purple600 : _GoogleAccent.purple200,
      onTertiary: light ? _GoogleNeutral.white : _GoogleNeutral.ink,
      tertiaryContainer: light
          ? _GoogleAccent.purple50
          : _GoogleAccent.purple900,
      onTertiaryContainer: light
          ? _GoogleAccent.purple900
          : _GoogleAccent.purple50,
      error: light ? _GoogleAccent.red600 : _GoogleAccent.red200,
      onError: light ? _GoogleNeutral.white : _GoogleNeutral.ink,
      errorContainer: light ? _GoogleAccent.red50 : _GoogleAccent.red900,
      onErrorContainer: light ? _GoogleAccent.red900 : _GoogleAccent.red50,
      surface: light
          ? _GoogleNeutral.lightBackground
          : _GoogleNeutral.darkBackground,
      surfaceDim: light ? _GoogleNeutral.lightGrey : _GoogleNeutral.black,
      surfaceBright: light ? _GoogleNeutral.white : _GoogleNeutral.grey800,
      surfaceContainerLowest: light
          ? _GoogleNeutral.white
          : _GoogleNeutral.darkSurfaceLowest,
      surfaceContainerLow: light
          ? _GoogleNeutral.lightGrey
          : _GoogleNeutral.darkSurface,
      surfaceContainer: light
          ? _GoogleNeutral.lightInset
          : _GoogleNeutral.darkInset,
      surfaceContainerHigh: light
          ? _GoogleNeutral.border
          : _GoogleNeutral.darkInset,
      surfaceContainerHighest: light
          ? _GoogleNeutral.borderStrong
          : _GoogleNeutral.grey800,
      onSurface: light ? _GoogleNeutral.ink : _GoogleNeutral.lightGrey,
      onSurfaceVariant: light ? _GoogleNeutral.grey700 : _GoogleNeutral.grey500,
      outline: light ? _GoogleNeutral.borderStrong : _GoogleNeutral.grey600,
      outlineVariant: light ? _GoogleNeutral.border : _GoogleNeutral.grey800,
      inverseSurface: light ? _GoogleNeutral.ink : _GoogleNeutral.lightGrey,
      onInverseSurface: light ? _GoogleNeutral.white : _GoogleNeutral.ink,
      inversePrimary: light ? _GoogleAccent.blue200 : _GoogleAccent.blue600,
      shadow: _GoogleNeutral.black,
      scrim: _GoogleNeutral.black,
      surfaceTint: light ? _GoogleAccent.blue600 : _GoogleAccent.blue200,
    );
  }
}

abstract final class _GoogleAccent {
  static const blue50 = Color(0xffd2e3fc);
  static const blue200 = Color(0xff8ab4f8);
  static const blue500 = Color(0xff4285f4);
  static const blue600 = Color(0xff1a73e8);
  static const blue900 = Color(0xff174ea6);

  static const green50 = Color(0xffceead6);
  static const green200 = Color(0xff81c995);
  static const green500 = Color(0xff34a853);
  static const green900 = Color(0xff0d652d);

  static const yellow200 = Color(0xfffdd663);
  static const yellow500 = Color(0xfffbbc04);

  static const red50 = Color(0xfffad2cf);
  static const red200 = Color(0xfff28b82);
  static const red600 = Color(0xffd93025);
  static const red900 = Color(0xffa50e0e);

  static const purple50 = Color(0xfff3e8fd);
  static const purple200 = Color(0xffd7aefb);
  static const purple600 = Color(0xff9334e6);
  static const purple900 = Color(0xff681da8);
}

abstract final class _GoogleNeutral {
  static const white = Color(0xffffffff);
  static const black = Color(0xff000000);
  static const ink = Color(0xff202124);
  static const grey500 = Color(0xff9aa0a6);
  static const grey600 = Color(0xff80868b);
  static const grey700 = Color(0xff5f6368);
  static const grey800 = Color(0xff3c4043);
  static const lightBackground = Color(0xfff8f9fa);
  static const lightGrey = Color(0xfff1f3f4);
  static const lightInset = Color(0xffe8eaed);
  static const border = Color(0xffdadce0);
  static const borderStrong = Color(0xffc0c2c5);
  static const darkBackground = Color(0xff000000);
  static const darkSurfaceLowest = Color(0xff0b0b0c);
  static const darkSurface = Color(0xff121212);
  static const darkInset = Color(0xff202124);
}

abstract final class StudioSyntax {
  static Color get keyword => Studio.tone(Studio.violet);
  static Color get string => Studio.success;
  static Color get comment => Studio.faint;
  static Color get type => Studio.primary;
  static Color get number => Studio.warning;
  static Color get plain =>
      Studio.text.withValues(alpha: Studio.isLight ? 0.9 : 0.88);
}

/// Rounded panel with the studio border treatment.
class StudioPanel extends StatefulWidget {
  const StudioPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;

  @override
  State<StudioPanel> createState() => _StudioPanelState();
}

class _StudioPanelState extends State<StudioPanel> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    const outerRadius = 24.0;
    const innerRadius = 20.0;
    final color = widget.color ?? Studio.surface;
    final borderColor = widget.borderColor ?? Studio.border;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(outerRadius),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? borderColor.withValues(alpha: 0.08)
                  : Studio.transparent,
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(outerRadius),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Studio.surfaceRaised.withValues(alpha: 0.52),
              borderRadius: BorderRadius.circular(outerRadius),
              border: Border.all(
                color: _isHovered
                    ? borderColor.withValues(alpha: 0.5)
                    : Studio.borderBright.withValues(alpha: 0.34),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(innerRadius),
                  border: Border.all(color: borderColor),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Studio.text.withValues(alpha: _isHovered ? 0.04 : 0.025),
                      Studio.transparent,
                      _isHovered
                          ? borderColor.withValues(alpha: 0.03)
                          : Studio.primary.withValues(alpha: 0.018),
                    ],
                  ),
                ),
                child: Padding(padding: widget.padding, child: widget.child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tiny uppercase mono caption used above blocks.
class StudioCaption extends StatelessWidget {
  const StudioCaption(this.label, {super.key, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Studio.mono(
        size: 10.5,
        color: color ?? Studio.muted,
        weight: FontWeight.w700,
        letterSpacing: 2.6,
      ),
    );
  }
}

/// Small outlined pill chip with a mono label.
class StudioChip extends StatelessWidget {
  const StudioChip(this.label, {super.key, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? Studio.muted;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          label,
          style: Studio.mono(
            size: 10.5,
            color: color,
            weight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

/// Action button: filled accent or quiet outline, mono label.
class StudioButton extends StatelessWidget {
  const StudioButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
    this.accent,
    this.filled = true,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final IconData? icon;
  final Color? accent;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final accent = this.accent ?? Studio.primary;
    final accentText = Studio.tone(accent);
    final onAccent = Studio.onAccent(accent);
    final textStyle = Studio.mono(
      size: 12.5,
      weight: FontWeight.w700,
      letterSpacing: 0.8,
      color: filled ? onAccent : accentText,
    );
    final style = filled
        ? FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: onAccent,
            textStyle: textStyle,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          )
        : OutlinedButton.styleFrom(
            foregroundColor: accentText,
            side: BorderSide(color: Studio.accentBorder(accent)),
            textStyle: textStyle,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          );
    if (icon == null) {
      return filled
          ? FilledButton(onPressed: onPressed, style: style, child: child)
          : OutlinedButton(onPressed: onPressed, style: style, child: child);
    }
    return filled
        ? FilledButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon, size: 16),
            label: child,
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon, size: 16),
            label: child,
          );
  }
}

class StudioFooter extends StatefulWidget {
  const StudioFooter({super.key});

  @override
  State<StudioFooter> createState() => _StudioFooterState();
}

class _StudioFooterState extends State<StudioFooter> {
  late final Future<String> _version = _loadPackageVersionLabel();
  late final int _year = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;
    final items = [
      Text('KickNext', style: _footerStyle()),
      const _StudioFooterDivider(),
      FutureBuilder<String>(
        future: _version,
        builder: (context, snapshot) {
          final version = snapshot.data ?? 'v?';
          return Text('reel_text $version', style: _footerStyle());
        },
      ),
      const _StudioFooterDivider(),
      Text('MIT', style: _footerStyle(color: Studio.muted)),
      const _StudioFooterDivider(),
      Text('$_year', style: _footerStyle(color: Studio.muted)),
    ];

    return DecoratedBox(
      key: const ValueKey('studio_footer'),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Studio.border)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 12 : 14),
        child: Center(
          child: compact
              ? Wrap(
                  key: const ValueKey('studio_footer_content'),
                  spacing: 10,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: items,
                )
              : Row(
                  key: const ValueKey('studio_footer_content'),
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) const SizedBox(width: 14),
                      items[i],
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  TextStyle _footerStyle({Color? color}) {
    return Studio.mono(
      size: 12,
      color: color ?? Studio.faint,
      weight: FontWeight.w700,
      letterSpacing: 0.3,
    );
  }
}

class _StudioFooterDivider extends StatelessWidget {
  const _StudioFooterDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 3,
      decoration: BoxDecoration(
        color: Studio.borderBright.withValues(alpha: 0.7),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Faint blueprint grid + cinematic light sweeps, used behind the hero.
class StudioBackdrop extends StatelessWidget {
  const StudioBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _GridPainter(Studio.brightness)),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _LightSweepPainter(Studio.brightness),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter(this.brightness);

  final Brightness brightness;

  @override
  void paint(Canvas canvas, Size size) {
    final base = brightness == Brightness.light
        ? _GoogleNeutral.ink
        : _GoogleNeutral.lightGrey;
    final paint = Paint()
      ..color = base.withValues(
        alpha: brightness == Brightness.light ? 0.032 : 0.024,
      )
      ..strokeWidth = 1;
    final crossPaint = Paint()
      ..color = base.withValues(
        alpha: brightness == Brightness.light ? 0.07 : 0.06,
      )
      ..strokeWidth = 1.0;
    const cell = 56.0;
    for (var x = 0.0; x <= size.width; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Draw tech crosshairs on intersections
    const crossSize = 3.0;
    for (var x = cell; x < size.width; x += cell * 2) {
      for (var y = cell; y < size.height; y += cell * 2) {
        canvas.drawLine(
          Offset(x - crossSize, y),
          Offset(x + crossSize, y),
          crossPaint,
        );
        canvas.drawLine(
          Offset(x, y - crossSize),
          Offset(x, y + crossSize),
          crossPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.brightness != brightness;
}

class _LightSweepPainter extends CustomPainter {
  const _LightSweepPainter(this.brightness);

  final Brightness brightness;

  @override
  void paint(Canvas canvas, Size size) {
    final violet = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          Studio.tone(Studio.violet).withValues(alpha: 0.22),
          Studio.tone(Studio.violet).withValues(alpha: 0.02),
          Studio.transparent,
        ],
        stops: const [0, 0.34, 0.76],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, violet);

    final primary = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [
          Studio.primary.withValues(alpha: 0.15),
          Studio.primary.withValues(alpha: 0.03),
          Studio.transparent,
        ],
        stops: const [0, 0.28, 0.7],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, primary);

    final veilColor = brightness == Brightness.light
        ? Studio.white
        : Studio.black;
    final veil = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Studio.transparent,
          veilColor.withValues(
            alpha: brightness == Brightness.light ? 0.2 : 0.2,
          ),
          veilColor.withValues(
            alpha: brightness == Brightness.light ? 0.46 : 0.4,
          ),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, veil);
  }

  @override
  bool shouldRepaint(covariant _LightSweepPainter oldDelegate) =>
      oldDelegate.brightness != brightness;
}
