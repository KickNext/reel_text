part of 'reel_text.dart';

class _ReelTextSelection extends StatelessWidget {
  const _ReelTextSelection({
    required this.content,
    required this.textAlign,
    required this.layout,
    required this.child,
  });

  final _ReelTextContent content;
  final TextAlign textAlign;
  final _ReelTextLayoutContext layout;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final visual = ExcludeSemantics(
      child: SelectionContainer.disabled(child: child),
    );
    final registrar = SelectionContainer.maybeOf(context);
    if (registrar == null) {
      return visual;
    }

    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        visual,
        Positioned.fill(
          child: ExcludeSemantics(
            child: RichText(
              key: const ValueKey('reel_text_selection_surface'),
              text: _transparentTextSpan(
                content,
                layout.widgetSpanSizes,
              ),
              textAlign: textAlign,
              textDirection: layout.textDirection,
              locale: layout.locale,
              softWrap: false,
              maxLines: 1,
              strutStyle: layout.strutStyle,
              textScaler:
                  MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling,
              selectionRegistrar: registrar,
              selectionColor:
                  DefaultSelectionStyle.of(context).selectionColor ??
                      DefaultSelectionStyle.defaultColor,
            ),
          ),
        ),
      ],
    );
  }
}

TextSpan _transparentTextSpan(
  _ReelTextContent content,
  Map<int, Size> widgetSpanSizes,
) {
  return TextSpan(
    children: [
      _transparentInlineSpan(
        content.span,
        _WidgetSpanSizeCursor(
          content.widgetTokenIndexes.toList(),
          widgetSpanSizes,
        ),
      ),
    ],
  );
}

InlineSpan _transparentInlineSpan(
  InlineSpan span,
  _WidgetSpanSizeCursor sizes,
) {
  if (span is WidgetSpan) {
    return WidgetSpan(
      alignment: span.alignment,
      baseline: span.baseline,
      style: span.style,
      child: SizedBox.fromSize(size: sizes.nextSize()),
    );
  }

  if (span is! TextSpan) {
    throw FlutterError(
      'ReelText.rich supports TextSpan trees and WidgetSpan leaves only.',
    );
  }

  final transparentStyle = (span.style ?? const TextStyle()).copyWith(
    color: Colors.transparent,
    decorationColor: Colors.transparent,
  );
  return TextSpan(
    text: span.text,
    style: transparentStyle,
    recognizer: span.recognizer,
    mouseCursor: span.mouseCursor,
    onEnter: span.onEnter,
    onExit: span.onExit,
    semanticsLabel: span.semanticsLabel,
    locale: span.locale,
    spellOut: span.spellOut,
    children: [
      for (final child in span.children ?? const <InlineSpan>[])
        _transparentInlineSpan(child, sizes),
    ],
  );
}

class _WidgetSpanSizeCursor {
  _WidgetSpanSizeCursor(this.widgetTokenIndexes, this.sizes);

  final List<int> widgetTokenIndexes;
  final Map<int, Size> sizes;
  var _widgetOrdinal = 0;

  Size nextSize() {
    if (_widgetOrdinal >= widgetTokenIndexes.length) {
      return Size.zero;
    }
    final tokenIndex = widgetTokenIndexes[_widgetOrdinal++];
    return sizes[tokenIndex] ?? Size.zero;
  }
}
