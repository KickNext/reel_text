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
                layout,
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
  _ReelTextLayoutContext layout,
) {
  return TextSpan(
    children: [
      _transparentInlineSpan(
        content.span,
        _WidgetSpanSizeCursor(
          content.widgetTokens.toList(),
          layout,
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
  _WidgetSpanSizeCursor(this.widgetTokens, this.layout);

  final List<_ReelTextWidgetToken> widgetTokens;
  final _ReelTextLayoutContext layout;
  var _widgetOrdinal = 0;

  Size nextSize() {
    if (_widgetOrdinal >= widgetTokens.length) {
      return Size.zero;
    }
    final token = widgetTokens[_widgetOrdinal++];
    return layout.widgetSpanSizeFor(token.index, token.span) ?? Size.zero;
  }
}
