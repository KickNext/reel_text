part of 'reel_text.dart';

class _ReelTextAlignment extends StatelessWidget {
  const _ReelTextAlignment({
    required this.textAlign,
    required this.textDirection,
    required this.child,
  });

  final TextAlign textAlign;
  final TextDirection textDirection;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: _alignmentForTextAlign(textAlign, textDirection),
      widthFactor: 1,
      heightFactor: 1,
      child: child,
    );
  }
}

Alignment _alignmentForTextAlign(TextAlign align, TextDirection direction) {
  return switch (align) {
    TextAlign.left => Alignment.centerLeft,
    TextAlign.right => Alignment.centerRight,
    TextAlign.center => Alignment.center,
    TextAlign.end => direction == TextDirection.rtl
        ? Alignment.centerLeft
        : Alignment.centerRight,
    TextAlign.start || TextAlign.justify => direction == TextDirection.rtl
        ? Alignment.centerRight
        : Alignment.centerLeft,
  };
}

bool _alignsToRight(TextAlign align, TextDirection direction) {
  return _alignmentForTextAlign(align, direction).x > 0;
}
