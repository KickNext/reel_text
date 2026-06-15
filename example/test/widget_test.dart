import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:reel_text/reel_text.dart';
import 'package:reel_text_example/main.dart';
import 'package:reel_text_example/studio.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    binding.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
  });

  tearDown(() {
    binding.platformDispatcher.clearPlatformBrightnessTestValue();
  });

  test(
    'showcase package version is loaded from the root pubspec asset',
    () async {
      final bundledPubspec = await rootBundle.loadString(
        'packages/reel_text/pubspec.yaml',
      );
      final rootPubspec = File('../pubspec.yaml').readAsStringSync();
      final version = _rootPackageVersion();

      expect(bundledPubspec, rootPubspec);
      expect(version, isNotNull);
      expect(bundledPubspec, contains('version: $version'));
    },
  );

  testWidgets('home page renders the hero stage and the brand wordmark', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ReelTextExampleApp(useGoogleFonts: false, autoPlayHero: false),
    );
    await tester.pump(const Duration(milliseconds: 600));

    // The hero stage uses one controlled ReelText line for every act.
    expect(find.byKey(const ValueKey('home_scroll')), findsOneWidget);
    expect(find.byKey(const ValueKey('hero_brand_word')), findsOneWidget);
    expect(find.byKey(const ValueKey('hero_act_view')), findsOneWidget);
    expect(find.byKey(const ValueKey('hero_line_clip')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home_workbench_heading')),
      findsOneWidget,
    );
    expect(
      tester.getCenter(find.text('Make your app feel a little more alive.')).dx,
      closeTo(
        tester.getSize(find.byKey(const ValueKey('home_scroll'))).width / 2,
        2,
      ),
    );

    // The labelled stage nav exposes every act.
    expect(find.byKey(const ValueKey('stage_nav_intro')), findsOneWidget);
    expect(find.byKey(const ValueKey('stage_nav_labels')), findsOneWidget);
    expect(find.byKey(const ValueKey('stage_nav_async')), findsOneWidget);

    // The home examples are compact UI patterns, led by the market table.
    expect(find.text('MARKET TABLE'), findsOneWidget);
    expect(find.text('BTC'), findsOneWidget);
    expect(find.text('ETH'), findsOneWidget);
    expect(find.text('COPY BUTTON'), findsOneWidget);
    expect(find.text('STATUS PILL'), findsOneWidget);
    expect(find.text('INLINE COPY'), findsOneWidget);
    expect(find.text('pub.dev/packages/reel_text'), findsOneWidget);
    expect(find.text('kicknext.dev/reel_text'), findsNothing);
    expect(find.text('Values that update in place'), findsNothing);
    expect(
      find.text('Rows stay calm while the changed glyphs carry the movement.'),
      findsNothing,
    );

    // Top bar: readable wordmark, polished tabs, and live metadata badges.
    expect(find.byKey(const ValueKey('app_bar_logo')), findsNothing);
    expect(find.byKey(const ValueKey('app_bar_title')), findsOneWidget);
    expect(find.byKey(const ValueKey('page_tab_home')), findsOneWidget);
    expect(find.byKey(const ValueKey('page_tab_recipes')), findsOneWidget);
    expect(find.byKey(const ValueKey('page_tab_editor')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('app_bar_metadata_links')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('theme_toggle_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('github_star_count')), findsOneWidget);
    expect(find.byKey(const ValueKey('pubdev_like_count')), findsOneWidget);

    // External links render their SVG icons inside metadata pills.
    expect(find.byTooltip('Open pub.dev'), findsOneWidget);
    expect(find.byTooltip('Open GitHub'), findsOneWidget);
    final pubDevButton = find.byKey(const ValueKey('pubdev_link_button'));
    final githubButton = find.byKey(const ValueKey('github_link_button'));
    expect(
      find.descendant(of: pubDevButton, matching: find.byType(SvgPicture)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: githubButton, matching: find.byType(SvgPicture)),
      findsOneWidget,
    );

    // Scrub to a later act by tapping its nav item.
    await tester.tap(find.byKey(const ValueKey('stage_nav_counters')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 520));
    final heroLine = tester.widget<ReelText>(
      find.byKey(const ValueKey('hero_brand_word')),
    );
    expect(heroLine.controller!.value, '1,024');
  });

  testWidgets('app bar theme toggle switches the studio palette', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ReelTextExampleApp(useGoogleFonts: false, autoPlayHero: false),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final scaffold = find.byType(Scaffold);
    expect(Theme.of(tester.element(scaffold)).brightness, Brightness.dark);
    expect(Studio.isLight, isFalse);
    expect(Studio.background, Colors.black);
    expect(Studio.background.computeLuminance(), 0);
    final darkChromaStart = Studio.chromaColor(0, 5);
    final darkInstallPanel = _panelColor(tester, 'install_block_panel');
    final darkCopyPanel = _panelColor(tester, 'copy_button_panel');

    await tester.tap(find.byKey(const ValueKey('theme_toggle_button')));
    await tester.pumpAndSettle();

    expect(Theme.of(tester.element(scaffold)).brightness, Brightness.light);
    expect(Studio.isLight, isTrue);
    expect(Studio.text, const Color(0xff202124));
    expect(Studio.text, isNot(Colors.black));
    expect(Studio.primary, isNot(Studio.success));
    expect(Studio.primary.computeLuminance(), lessThan(0.45));
    expect(Studio.onAccent(Studio.primary), Colors.white);
    expect(Studio.chromaColor(0, 5), isNot(darkChromaStart));
    expect(_panelColor(tester, 'install_block_panel'), isNot(darkInstallPanel));
    expect(_panelColor(tester, 'copy_button_panel'), isNot(darkCopyPanel));
    expect(
      _panelColor(tester, 'install_block_panel'),
      Studio.surface.withValues(alpha: 0.72),
    );
    expect(_panelColor(tester, 'copy_button_panel'), Studio.surface);
    expect(
      Theme.of(tester.element(scaffold)).scaffoldBackgroundColor,
      equals(Studio.background),
    );
  });

  testWidgets('app follows platform brightness until the theme is toggled', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;

    await tester.pumpWidget(
      const ReelTextExampleApp(useGoogleFonts: false, autoPlayHero: false),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final scaffold = find.byType(Scaffold);
    expect(Theme.of(tester.element(scaffold)).brightness, Brightness.light);
    expect(Studio.isLight, isTrue);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    WidgetsBinding.instance.handlePlatformBrightnessChanged();
    await tester.pumpAndSettle();

    expect(Theme.of(tester.element(scaffold)).brightness, Brightness.dark);
    expect(Studio.isLight, isFalse);

    await tester.tap(find.byKey(const ValueKey('theme_toggle_button')));
    await tester.pumpAndSettle();

    expect(Theme.of(tester.element(scaffold)).brightness, Brightness.light);
    expect(Studio.isLight, isTrue);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    WidgetsBinding.instance.handlePlatformBrightnessChanged();
    await tester.pumpAndSettle();

    expect(Theme.of(tester.element(scaffold)).brightness, Brightness.light);
    expect(Studio.isLight, isTrue);
  });

  testWidgets(
    'intro uses one line: empty, package name, package version, labels',
    (tester) async {
      await tester.pumpWidget(
        const ReelTextExampleApp(useGoogleFonts: false, autoPlayHero: true),
      );

      String introValue() => tester
          .widget<ReelText>(find.byKey(const ValueKey('hero_brand_word')))
          .controller!
          .value;

      expect(introValue(), isEmpty);

      await tester.pump(const Duration(milliseconds: 1120));
      expect(introValue(), 'reel_text');

      await tester.pump(const Duration(milliseconds: 1900));
      expect(introValue(), 'reel_text');

      await tester.pump(const Duration(milliseconds: 700));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
      await tester.pump();
      final versionLabel = 'v${_rootPackageVersion()}';
      for (var i = 0; i < 20 && introValue() != versionLabel; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(introValue(), versionLabel);

      await tester.pump(const Duration(milliseconds: 1500));
      expect(introValue(), versionLabel);

      await tester.pump(const Duration(milliseconds: 900));
      expect(introValue(), 'Copy');

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('stage nav underline tracks the whole active block', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ReelTextExampleApp(useGoogleFonts: false, autoPlayHero: true),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const ValueKey('stage_nav_labels')));
    await tester.pump();

    final start = _stageNavFill(tester, 'stage_nav_labels');
    await tester.pump(const Duration(milliseconds: 1450));
    final afterFirstCue = _stageNavFill(tester, 'stage_nav_labels');
    await tester.pump(const Duration(milliseconds: 1900));
    final afterSecondCue = _stageNavFill(tester, 'stage_nav_labels');

    expect(start, lessThan(0.05));
    expect(afterFirstCue, greaterThan(start));
    expect(afterFirstCue, lessThan(0.35));
    expect(afterSecondCue, greaterThan(afterFirstCue));
    expect(afterSecondCue, lessThan(0.7));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('shell keeps app bar constrained and scrollport full width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(2200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ReelTextExampleApp(useGoogleFonts: false, autoPlayHero: false),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final topFrame = find.byKey(const ValueKey('shell_top_bar_frame'));
    final bodyFrame = find.byKey(const ValueKey('shell_body_frame'));

    expect(tester.getSize(topFrame).width, 1280);
    expect(tester.getSize(bodyFrame).width, 2200);
    expect(
      tester.getSize(find.byKey(const ValueKey('home_scroll'))).width,
      2200,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('install_block_frame'))).width,
      lessThanOrEqualTo(520),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('install_copy_button'))).height,
      34,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('install_copy_label_slot')))
          .height,
      34,
    );
    expect(
      tester
          .widget<ReelText>(
            find.descendant(
              of: find.byKey(const ValueKey('install_copy_label_slot')),
              matching: find.byType(ReelText),
            ),
          )
          .style
          ?.height,
      Studio.compactLabelLineHeight,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('hero_act_view'))).height,
      greaterThanOrEqualTo(290),
    );

    final heroToWorkbenchGap =
        tester
            .getTopLeft(find.byKey(const ValueKey('home_workbench_heading')))
            .dy -
        tester.getBottomLeft(find.byKey(const ValueKey('stage_nav_intro'))).dy;
    expect(heroToWorkbenchGap, inInclusiveRange(28, 64));

    final rightStack = find.byKey(const ValueKey('right_examples_stack'));
    await tester.scrollUntilVisible(
      rightStack,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    final marketHeight = tester
        .getSize(find.byKey(const ValueKey('market_board_frame')))
        .height;
    final rightHeight = tester.getSize(rightStack).height;
    expect(rightHeight, closeTo(marketHeight, 0.1));

    expect(
      tester.getSize(find.byKey(const ValueKey('copy_button_control'))),
      const Size(84, 34),
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('copy_button_label_slot')))
          .height,
      34,
    );
    expect(
      tester
          .widget<ReelText>(
            find.descendant(
              of: find.byKey(const ValueKey('copy_button_label_slot')),
              matching: find.byType(ReelText),
            ),
          )
          .style
          ?.height,
      Studio.compactLabelLineHeight,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('status_pill_chip'))).height,
      32,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('status_pill_label_slot')))
          .height,
      32,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('status_pill_chip'))).width,
      lessThanOrEqualTo(120),
    );
  });

  testWidgets('mobile app bar keeps actions on the right edge', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ReelTextExampleApp(useGoogleFonts: false, autoPlayHero: false),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final topFrame = tester.getRect(
      find.byKey(const ValueKey('shell_top_bar_frame')),
    );
    final title = tester.getRect(find.byKey(const ValueKey('app_bar_title')));
    final actions = tester.getRect(
      find.byKey(const ValueKey('app_bar_actions')),
    );

    expect(title.left, closeTo(topFrame.left + 14, 0.01));
    expect(actions.right, closeTo(topFrame.right - 14, 0.01));
    expect(title.right, lessThan(actions.left));
  });

  testWidgets('home try-it strip drives a live ReelText roll', (tester) async {
    await tester.pumpWidget(
      const ReelTextExampleApp(useGoogleFonts: false, autoPlayHero: false),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final jump = find.text('+111');
    await tester.scrollUntilVisible(
      jump,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    expect(jump, findsOneWidget);
    await tester.tap(jump);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byKey(const ValueKey('reel_text_rolling')), findsWidgets);

    final asyncRow = find.byKey(const ValueKey('async_action_row'));
    await tester.scrollUntilVisible(
      asyncRow,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    expect(tester.getSize(asyncRow).height, 40);
    expect(find.text('Run'), findsOneWidget);
    expect(find.text('Fail'), findsOneWidget);

    final inlineRow = find.byKey(const ValueKey('inline_copy_row'));
    await tester.scrollUntilVisible(
      inlineRow,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    final inlineCenterY = tester.getCenter(inlineRow).dy;
    expect(tester.getSize(inlineRow).height, greaterThanOrEqualTo(40));
    expect(
      tester.getCenter(find.text('Payout is')).dy,
      closeTo(inlineCenterY, 2.5),
    );
    expect(
      tester.getCenter(find.byKey(const ValueKey('inline_refresh_button'))).dy,
      closeTo(inlineCenterY, 0.1),
    );
  });

  testWidgets('home footer shows package metadata', (tester) async {
    await tester.pumpWidget(
      const ReelTextExampleApp(useGoogleFonts: false, autoPlayHero: false),
    );
    await tester.pump(const Duration(milliseconds: 300));

    const brandLabel = 'KickNext';
    await tester.scrollUntilVisible(
      find.text(brandLabel),
      600,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 100));

    await _expectFooter(tester);
    expect(
      tester.getSize(find.byKey(const ValueKey('studio_footer_content'))).width,
      lessThan(520),
    );
    expect(find.text('Next'), findsNothing);
    expect(
      find.text(
        'Use Recipes for code. Use Editor to see the same motion inside a text field.',
      ),
      findsNothing,
    );
  });

  testWidgets('recipes page shows live previews with code', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ReelTextExampleApp(useGoogleFonts: false, autoPlayHero: false),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const ValueKey('page_tab_recipes')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Declarative swap'), findsOneWidget);
    expect(find.text('Patterns that run without modification.'), findsNothing);
    expect(find.text('Async operation with a handle'), findsNothing);
    expect(find.text('Reduced motion'), findsNothing);
    expect(find.text('Text parity'), findsNothing);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('recipes_content_frame_0')))
          .width,
      1180,
    );

    final recipesList = find.byKey(const ValueKey('recipes_list'));
    double slotHeight(String key) =>
        tester.getSize(find.byKey(ValueKey(key))).height;

    expect(slotHeight('recipe_declarative_motion_slot'), 58);

    await tester.tap(find.text('Toggle'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('reel_text_rolling')), findsWidgets);

    await tester.dragUntilVisible(
      find.byKey(const ValueKey('recipe_flash_motion_slot')),
      recipesList,
      const Offset(0, -120),
    );
    expect(slotHeight('recipe_flash_motion_slot'), 44);
    expect(
      tester
          .widget<ReelText>(
            find.descendant(
              of: find.byKey(const ValueKey('recipe_flash_motion_slot')),
              matching: find.byType(ReelText),
            ),
          )
          .style
          ?.height,
      Studio.compactLabelLineHeight,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('recipe_flash_button'))).height,
      44,
    );

    await tester.dragUntilVisible(
      find.byKey(const ValueKey('recipe_counter_motion_slot')),
      recipesList,
      const Offset(0, -120),
    );
    expect(slotHeight('recipe_counter_motion_slot'), 72);

    await tester.dragUntilVisible(
      find.text('Async action'),
      recipesList,
      const Offset(0, -120),
    );
    expect(find.text('Async action'), findsOneWidget);
    expect(slotHeight('recipe_async_motion_slot'), 58);

    await tester.dragUntilVisible(
      find.text('Waiting label'),
      recipesList,
      const Offset(0, -120),
    );
    expect(find.text('Waiting label'), findsOneWidget);
    expect(slotHeight('recipe_waiting_motion_slot'), 56);

    await tester.dragUntilVisible(
      find.text('Spam-safe tap'),
      recipesList,
      const Offset(0, -120),
    );
    expect(find.text('Spam-safe tap'), findsOneWidget);
    expect(slotHeight('recipe_spam_motion_slot'), 44);
    expect(
      tester.getSize(find.byKey(const ValueKey('recipe_spam_button'))).height,
      44,
    );

    await tester.dragUntilVisible(
      find.text('KickNext'),
      recipesList,
      const Offset(0, -500),
    );
    await _expectFooter(tester);
  });

  testWidgets('editor page tunes ReelText motion', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ReelTextExampleApp(useGoogleFonts: false, autoPlayHero: false),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const ValueKey('page_tab_editor')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Tune the motion.'), findsOneWidget);
    expect(find.byKey(const ValueKey('editor_preview_panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('editor_controls_panel')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('editor_direction_control')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('editor_tone_chroma')), findsOneWidget);

    final input = find.byKey(const ValueKey('editor_target_input'));
    expect(input, findsOneWidget);
    final inputFrame = find.byKey(const ValueKey('editor_target_input_frame'));
    final applyButton = find.byKey(const ValueKey('editor_apply_button'));
    expect(tester.getSize(inputFrame).height, 42);
    expect(tester.getSize(applyButton).height, 42);
    expect(
      tester.getCenter(inputFrame).dy,
      closeTo(tester.getCenter(applyButton).dy, 0.1),
    );

    await tester.enterText(input, 'Invoice paid');
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('editor_apply_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.byKey(const ValueKey('reel_text_rolling')), findsWidgets);

    final preview = tester.widget<ReelText>(
      find.byKey(const ValueKey('editor_preview_text')),
    );
    expect(preview.controller!.value, 'Invoice paid');

    await tester.tap(find.text('Down'));
    await tester.pump();
    await tester.tap(find.text('Export ready'));
    await tester.pump();
    final exportTargetButton = tester.widget<OutlinedButton>(
      find.descendant(
        of: find.byKey(const ValueKey('editor_target_export_ready')),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(
      exportTargetButton.style?.backgroundColor?.resolve(<WidgetState>{}),
      Studio.primary,
    );
    await tester.pump(const Duration(milliseconds: 16));
    final targetReplacement = tester.widget<ReelText>(
      find.byKey(const ValueKey('editor_target_replacement')),
    );
    expect(targetReplacement.controller!.value, 'Export ready');
    expect(targetReplacement.options.direction, ReelTextDirection.down);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('editor_target_replacement')),
        matching: find.byKey(const ValueKey('reel_text_rolling')),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<EditableText>(
            find.descendant(of: input, matching: find.byType(EditableText)),
          )
          .controller
          .text,
      'Invoice paid',
    );
    expect(preview.controller!.value, 'Invoice paid');

    await tester.pump(const Duration(milliseconds: 700));
    final inputController =
        tester
                .widget<EditableText>(
                  find.descendant(
                    of: input,
                    matching: find.byType(EditableText),
                  ),
                )
                .controller
            as ReelTextEditingController;
    expect(inputController.text, 'Invoice paid');
    expect(inputController.hasActiveReplacements, isTrue);
    expect(preview.controller!.value, 'Invoice paid');

    await tester.pump(const Duration(milliseconds: 700));
    expect(inputController.text, 'Export ready');
    expect(inputController.hasActiveReplacements, isFalse);

    await tester.tap(find.byKey(const ValueKey('editor_apply_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byKey(const ValueKey('reel_text_rolling')), findsWidgets);
    expect(preview.controller!.value, 'Export ready');
  });

  testWidgets('editor light theme primary controls use white foreground', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ReelTextExampleApp(useGoogleFonts: false, autoPlayHero: false),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const ValueKey('theme_toggle_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('page_tab_editor')));
    await tester.pump(const Duration(milliseconds: 300));

    final applyText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('editor_apply_button')),
        matching: find.text('Apply'),
      ),
    );
    final selectedTargetText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('editor_target_cart_updated')),
        matching: find.text('Cart updated'),
      ),
    );
    final selectedTargetButton = tester.widget<OutlinedButton>(
      find.descendant(
        of: find.byKey(const ValueKey('editor_target_cart_updated')),
        matching: find.byType(OutlinedButton),
      ),
    );

    expect(Studio.isLight, isTrue);
    expect(Studio.primary, const Color(0xff1a73e8));
    expect(Studio.onAccent(Studio.primary), Colors.white);
    expect(applyText.style?.color, Colors.white);
    expect(selectedTargetText.style?.color, Colors.white);
    expect(
      selectedTargetButton.style?.backgroundColor?.resolve(<WidgetState>{}),
      Studio.primary,
    );
  });

  testWidgets('editor keeps ReelText preview fixed on mobile', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ReelTextExampleApp(useGoogleFonts: false, autoPlayHero: false),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const ValueKey('page_tab_editor')));
    await tester.pump(const Duration(milliseconds: 300));

    final previewPanel = find.byKey(const ValueKey('editor_preview_panel'));
    final previewSlot = find.byKey(const ValueKey('editor_preview_text_slot'));
    final controlsScroll = find.byKey(const ValueKey('editor_controls_scroll'));

    expect(find.byKey(const ValueKey('editor_mobile_shell')), findsOneWidget);
    expect(find.byKey(const ValueKey('editor_page_scroll')), findsNothing);
    expect(previewPanel, findsOneWidget);
    expect(previewSlot, findsOneWidget);
    expect(controlsScroll, findsOneWidget);

    final previewTop = tester.getTopLeft(previewPanel).dy;
    expect(tester.getSize(previewSlot).height, 58);
    expect(tester.getTopLeft(previewSlot).dy, greaterThan(0));
    expect(tester.getBottomLeft(previewSlot).dy, lessThan(720));

    await tester.drag(controlsScroll, const Offset(0, -260));
    await tester.pump();

    expect(tester.getTopLeft(previewPanel).dy, closeTo(previewTop, 0.1));
  });
}

String? _rootPackageVersion() {
  final rootPubspec = File('../pubspec.yaml').readAsStringSync();
  return RegExp(
    r'^version:\s*([^\s]+)\s*$',
    multiLine: true,
  ).firstMatch(rootPubspec)?.group(1);
}

String _footerYearLabel() => '${DateTime.now().year}';

String _footerVersionLabel() => 'reel_text v${_rootPackageVersion()}';

Future<void> _expectFooter(WidgetTester tester) async {
  final versionLabel = _footerVersionLabel();
  for (var i = 0; i < 20 && find.text(versionLabel).evaluate().isEmpty; i++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await tester.pump(const Duration(milliseconds: 50));
  }

  expect(find.text('KickNext'), findsOneWidget);
  expect(find.text(versionLabel), findsOneWidget);
  expect(find.text('MIT'), findsOneWidget);
  expect(find.text(_footerYearLabel()), findsOneWidget);
}

Color? _panelColor(WidgetTester tester, String key) {
  final panel = find.byKey(ValueKey(key));
  final decoratedBox = tester.widget<DecoratedBox>(
    find.descendant(of: panel, matching: find.byType(DecoratedBox)).first,
  );
  return (decoratedBox.decoration as BoxDecoration).color;
}

double _stageNavFill(WidgetTester tester, String key) {
  return tester
      .widget<FractionallySizedBox>(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(FractionallySizedBox),
        ),
      )
      .widthFactor!;
}
