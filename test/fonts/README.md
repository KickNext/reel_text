# Visual-test fonts

NotoNaskhArabic-Regular.ttf and NotoSans-Regular.ttf are unmodified fonts from
https://github.com/notofonts/noto-fonts/tree/main/hinted/ttf (archived upstream).
They are distributed under the included SIL Open Font License, `OFL.txt`.

The tests load these files explicitly, without system-font or network access.
They are repository test fixtures and are excluded from the pub.dev archive.

Text-reference tests run on every supported SDK. Stored PNG goldens are owned
by the pinned Flutter SDK on Windows, at DPR 1 and a fixed 640×300 surface:

```sh
flutter test test/reel_text_visual_test.dart --dart-define=REEL_GOLDENS=true
```

Only update after inspecting an intentional visual change on that same SDK
and platform:

```sh
flutter test test/reel_text_visual_test.dart --dart-define=REEL_GOLDENS=true --update-goldens
```

The regular CI run compares existing images; it never updates the baseline.
