part of 'reel_text.dart';

class _ReelTextSelection extends StatelessWidget {
  const _ReelTextSelection({
    required this.content,
    required this.textAlign,
    required this.textDirection,
    required this.locale,
    required this.strutStyle,
    required this.child,
  });

  final _ReelTextContent content;
  final TextAlign textAlign;
  final TextDirection textDirection;
  final Locale? locale;
  final StrutStyle? strutStyle;
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
              text: _transparentTextSpan(content.span),
              textAlign: textAlign,
              textDirection: textDirection,
              locale: locale,
              softWrap: false,
              maxLines: 1,
              strutStyle: strutStyle,
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
