part of '../recipes_page.dart';

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({
    required this.title,
    required this.blurb,
    required this.preview,
    required this.code,
  });

  final String title;
  final String blurb;
  final Widget preview;
  final String code;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 880;
    final previewBlock = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Center(child: preview),
    );
    final desktopPreviewBox = ConstrainedBox(
      constraints: BoxConstraints(minHeight: _previewHeightForCode(code)),
      child: previewBlock,
    );
    final codeBox = CodeView(code: code);

    return StudioPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Studio.mono(
              size: 12.5,
              color: Studio.text,
              height: 1.25,
              letterSpacing: 0.1,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(blurb, style: Studio.body(size: 12.5)),
          const SizedBox(height: 16),
          if (compact) ...[
            previewBlock,
            const SizedBox(height: 12),
            codeBox,
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: desktopPreviewBox),
                const SizedBox(width: 14),
                Expanded(flex: 3, child: codeBox),
              ],
            ),
        ],
      ),
    );
  }
}

double _previewHeightForCode(String code) {
  final lines = '\n'.allMatches(code).length + 1;
  return (52 + lines * 19.0).clamp(148.0, 380.0);
}

class _RecipeMotionSlot extends StatelessWidget {
  const _RecipeMotionSlot({
    required this.height,
    required this.child,
    this.width,
    this.slotKey,
  });

  final double height;
  final double? width;
  final Key? slotKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox(
        key: slotKey,
        width: width,
        height: height,
        child: Center(child: child),
      ),
    );
  }
}

class _RecipeReelButton extends StatelessWidget {
  const _RecipeReelButton({
    required this.onPressed,
    required this.controller,
    required this.icon,
    required this.semanticsLabel,
    required this.labelWidth,
    required this.slotKey,
    this.buttonKey,
    this.accent,
  });

  static const height = 44.0;
  static const tapTargetHeight = 48.0;

  final VoidCallback onPressed;
  final ReelTextController controller;
  final IconData icon;
  final String semanticsLabel;
  final double labelWidth;
  final Key slotKey;
  final Key? buttonKey;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final fill = accent ?? Studio.primary;
    final foreground = Studio.onAccent(fill);
    return Semantics(
      button: true,
      label: semanticsLabel,
      onTap: onPressed,
      child: SizedBox(
        height: tapTargetHeight,
        child: ExcludeSemantics(
          child: Center(
            child: Material(
              color: fill,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  key: buttonKey,
                  height: height,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 16, color: foreground),
                        const SizedBox(width: 8),
                        _RecipeMotionSlot(
                          slotKey: slotKey,
                          width: labelWidth,
                          height: height,
                          child: ReelText.controller(
                            controller: controller,
                            style: Studio.mono(
                              size: 12.5,
                              color: foreground,
                              weight: FontWeight.w700,
                              letterSpacing: 0.8,
                              height: Studio.compactLabelLineHeight,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
