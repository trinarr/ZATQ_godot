# Godot Android Yandex Ads — project fork

This addon is based on `noctisalamandra/godot-yandex-ads-android` (MIT) and is
adapted for Godot 4.7 and Yandex Mobile Ads SDK 8.4.0.

The compiled AAR exposes banner, interstitial, and rewarded ads to GDScript.
`yandex_ads.gd` is registered as the `YandexAdsService` autoload by
`project.godot`.

## Ad unit configuration

Test ad unit IDs live in the `[yandex_ads]` section of `project.godot`:

- `demo-banner-yandex`
- `demo-interstitial-yandex`
- `demo-rewarded-yandex`

Replace all three values with production ad unit IDs before publishing.

Android export uses the Gradle build. If the project does not yet contain an
`android/` directory, run **Project > Install Android Build Template** once in
Godot before exporting the APK/AAB.

The project currently sets `age_restricted_user=false`. `user_consent` defaults
to `false` and must only be switched to `true` after the app has actually
obtained the user's consent where required.

## Runtime API

- `YandexAdsService.show_banner()` / `hide_banner()`
- `YandexAdsService.show_interstitial() -> bool`
- `YandexAdsService.show_rewarded_video() -> bool`
- `YandexAdsService.rewarded(currency, amount)` signal

Interstitial and rewarded ads are preloaded after SDK initialization. Their
show methods return `false` while an ad is not ready and start a load if needed.
