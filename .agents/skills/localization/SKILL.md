---
name: localization
description: Use when changing FlClash UI text, scanning for hardcoded Chinese strings, updating ARB localization, or fixing generated locale output in this repository.
---

# Localization

## When To Use

Use this for localization work in this repository, especially hardcoded UI text in `lib/`, ARB updates, missing translations, or generated `lib/l10n/` output that does not match source ARB values.

Do not use this for README translation sync or manual edits to generated localization Dart.

## Workflow

1. Confirm `pubspec.yaml` still uses `flutter_intl`, source ARBs under `arb/`, and generated output under `lib/l10n/`.
2. Scan user-facing Dart text before opening many files:

   ```bash
   rg -n "[\\p{Han}]" lib -g '!lib/l10n/intl/**' -g '!lib/**/generated/**'
   ```

3. Inspect the smallest relevant call sites and nearby ARB keys.
4. Enumerate `arb/intl_*.arb` and add or update translations in every source ARB. The current locales are:
   - `arb/intl_en.arb`
   - `arb/intl_zh_CN.arb`
   - `arb/intl_zh_TW.arb`
   - `arb/intl_ja.arb`
   - `arb/intl_ru.arb`

   Review existing translations when a label's meaning changes; matching keys alone cannot detect stale translations.
   Keep Traditional Chinese (`zh_TW`) wording and terminology distinct from Simplified Chinese (`zh_CN`).
5. Replace inline strings with existing project accessors:
   - Widgets with `BuildContext`: `context.appLocalizations.key` from `common.dart`.
   - Controllers/providers/non-widget code: `currentAppLocalizations.key` from `app_localizations.dart`.
6. Regenerate:

   ```bash
   dart run intl_utils:generate
   ```

7. Run `flutter test test/l10n/ test/lint/dynamic_message_key_test.dart` to check locale keys and generated messages.
   Verify changed Dart files with `flutter analyze` when practical.
8. Re-run the Han-text scan for targeted strings.

## Pitfalls

- If a locale still shows English or stale wording, fix its source ARB values and regenerate. Do not edit generated Dart.
- Ignore `lib/l10n/intl/**` and `lib/**/generated/**` during text scans.
- If generator or analyzer hits local cache permission friction, rerun serially before treating it as a code issue.
