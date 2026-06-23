part of 'reel_text.dart';

class _TextTokenFace extends StatelessWidget {
  const _TextTokenFace(
    this.text, {
    required this.width,
    required this.height,
    this.horizontalBleed = 0,
    required this.style,
    required this.layout,
  });

  final String text;
  final double width;
  final double height;
  final double horizontalBleed;
  final TextStyle style;
  final _ReelTextLayoutContext layout;

  @override
  Widget build(BuildContext context) {
    final paintWidth = width + horizontalBleed;
    return SizedBox(
      width: width,
      height: height,
      child: OverflowBox(
        alignment: layout.inlineStartAlignment,
        minWidth: paintWidth,
        maxWidth: paintWidth,
        minHeight: height,
        maxHeight: height,
        child: SizedBox(
          width: paintWidth,
          height: height,
          child: _TextTokenText(
            text,
            style: style,
            layout: layout,
          ),
        ),
      ),
    );
  }
}

class _TextTokenText extends StatelessWidget {
  const _TextTokenText(
    this.text, {
    required this.style,
    required this.layout,
  });

  final String text;
  final TextStyle style;
  final _ReelTextLayoutContext layout;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style,
      textDirection: layout.textDirection,
      textAlign: TextAlign.start,
      locale: layout.locale,
      strutStyle: layout.strutStyle,
      softWrap: false,
    );
  }
}

class _WidgetSpanFace extends StatelessWidget {
  const _WidgetSpanFace(
    this.span, {
    required this.index,
    required this.layout,
  });

  final WidgetSpan span;
  final int index;
  final _ReelTextLayoutContext layout;

  @override
  Widget build(BuildContext context) {
    return Align(
      widthFactor: 1,
      heightFactor: 1,
      alignment: _placeholderAlignment(span.alignment),
      child: _WidgetSpanSizeObserver(
        onSizeChanged: (size) =>
            layout.onWidgetSpanSizeChanged(index, span, size),
        child: span.child,
      ),
    );
  }
}

class _WidgetSpanSizeObserver extends SingleChildRenderObjectWidget {
  const _WidgetSpanSizeObserver({
    required this.onSizeChanged,
    required super.child,
  });

  final ValueChanged<Size> onSizeChanged;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderWidgetSpanSizeObserver(onSizeChanged);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderWidgetSpanSizeObserver renderObject,
  ) {
    renderObject.onSizeChanged = onSizeChanged;
  }
}

class _RenderWidgetSpanSizeObserver extends RenderProxyBox {
  _RenderWidgetSpanSizeObserver(this.onSizeChanged);

  ValueChanged<Size> onSizeChanged;
  Size? _reportedSize;

  @override
  void performLayout() {
    super.performLayout();
    if (_reportedSize == size) {
      return;
    }
    _reportedSize = size;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onSizeChanged(size);
    });
  }
}

Alignment _placeholderAlignment(ui.PlaceholderAlignment alignment) {
  return switch (alignment) {
    ui.PlaceholderAlignment.top => Alignment.topCenter,
    ui.PlaceholderAlignment.middle => Alignment.center,
    ui.PlaceholderAlignment.bottom ||
    ui.PlaceholderAlignment.baseline ||
    ui.PlaceholderAlignment.aboveBaseline ||
    ui.PlaceholderAlignment.belowBaseline =>
      Alignment.bottomCenter,
  };
}
