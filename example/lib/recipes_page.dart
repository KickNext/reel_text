import 'dart:async';

import 'package:flutter/material.dart';
import 'package:reel_text/reel_text.dart';

import 'code_view.dart';
import 'studio.dart';

part 'recipes/recipe_shell.dart';
part 'recipes/recipe_previews.dart';

/// Developer-facing screen: each recipe pairs a live, working preview with
/// the exact code that produces it.
class RecipesPage extends StatelessWidget {
  const RecipesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 880;
    final recipes = <Widget>[
      const _RecipeCard(
        title: 'Declarative swap',
        blurb: 'Rebuild with a new string. Unchanged glyphs stay planted.',
        preview: _DeclarativePreview(),
        code: _declarativeCode,
      ),
      const _RecipeCard(
        title: 'Copy button',
        blurb:
            'Use flash() for temporary feedback without resizing the button.',
        preview: _FlashPreview(),
        code: _flashCode,
      ),
      const _RecipeCard(
        title: 'Counter',
        blurb: 'Only changed digits move. Direction follows the delta.',
        preview: _CounterPreview(),
        code: _counterCode,
      ),
      const _RecipeCard(
        title: 'Async action',
        blurb: 'runWhile() keeps the label alive until a Future settles.',
        preview: _AsyncPreview(),
        code: _asyncCode,
      ),
      const _RecipeCard(
        title: 'Waiting label',
        blurb: 'startWaiting() returns a handle you can complete or fail.',
        preview: _WaitingPreview(),
        code: _waitingCode,
      ),
      const _RecipeCard(
        title: 'WidgetSpan inline',
        blurb:
            'Inline widgets stay planted while neighboring text still rolls.',
        preview: _WidgetSpanPreview(),
        code: _widgetSpanCode,
      ),
      const _RecipeCard(
        title: 'WidgetSpan RTL',
        blurb: 'RTL and mixed-bidi labels keep inline widgets in visual order.',
        preview: _WidgetSpanRtlPreview(),
        code: _widgetSpanRtlCode,
      ),
      const _RecipeCard(
        title: 'Spam-safe tap',
        blurb:
            'interrupt: false queues the latest target instead of thrashing.',
        preview: _SpamSafePreview(),
        code: _spamSafeCode,
      ),
      const _RecipeCard(
        title: 'Mixed bidi',
        blurb: 'Latin fragments and numbers keep their visual order in RTL UI.',
        preview: _MixedBidiPreview(),
        code: _mixedBidiCode,
      ),
      const _RecipeCard(
        title: 'RTL script',
        blurb: 'Right-to-left labels roll through full words without jumping.',
        preview: _RtlPreview(),
        code: _rtlCode,
      ),
    ];

    return ListView.separated(
      key: const ValueKey('recipes_list'),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 40,
        vertical: 20,
      ),
      itemCount: recipes.length + 1,
      separatorBuilder: (_, index) => index == recipes.length - 1
          ? const SizedBox(height: 28)
          : const SizedBox(height: 18),
      itemBuilder: (context, index) {
        if (index == recipes.length) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: const StudioFooter(),
            ),
          );
        }
        return Center(
          child: ConstrainedBox(
            key: ValueKey('recipes_content_frame_$index'),
            constraints: const BoxConstraints(maxWidth: 1180),
            child: recipes[index],
          ),
        );
      },
    );
  }
}
