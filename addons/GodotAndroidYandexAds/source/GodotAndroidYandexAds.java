package com.darkmoonight.godotandroidyandexads;

import android.app.Activity;
import android.graphics.Color;
import android.util.DisplayMetrics;
import android.util.Log;
import android.view.Gravity;
import android.view.View;
import android.widget.FrameLayout;

import com.yandex.mobile.ads.banner.BannerAdEventListener;
import com.yandex.mobile.ads.banner.BannerAdSize;
import com.yandex.mobile.ads.banner.BannerAdView;
import com.yandex.mobile.ads.common.AdError;
import com.yandex.mobile.ads.common.AdRequest;
import com.yandex.mobile.ads.common.AdRequestError;
import com.yandex.mobile.ads.common.ImpressionData;
import com.yandex.mobile.ads.common.YandexAds;
import com.yandex.mobile.ads.interstitial.InterstitialAd;
import com.yandex.mobile.ads.interstitial.InterstitialAdEventListener;
import com.yandex.mobile.ads.interstitial.InterstitialAdLoadListener;
import com.yandex.mobile.ads.interstitial.InterstitialAdLoader;
import com.yandex.mobile.ads.rewarded.Reward;
import com.yandex.mobile.ads.rewarded.RewardedAd;
import com.yandex.mobile.ads.rewarded.RewardedAdEventListener;
import com.yandex.mobile.ads.rewarded.RewardedAdLoadListener;
import com.yandex.mobile.ads.rewarded.RewardedAdLoader;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.util.HashSet;
import java.util.Set;

/** Project fork for Godot 4.7 and Yandex Mobile Ads SDK 8. */
public final class GodotAndroidYandexAds extends GodotPlugin {
    private static final String TAG = "YandexAdsGodot";

    private final Activity activity;
    private BannerAdView bannerAdView;
    private FrameLayout bannerParent;
    private BannerAdSize bannerAdSize;
    private boolean bannerLoaded;
    private int bannerWidthPixels;
    private int bannerHeightPixels;

    private RewardedAd rewardedAd;
    private RewardedAdLoader rewardedAdLoader;
    private InterstitialAd interstitialAd;
    private InterstitialAdLoader interstitialAdLoader;
    private boolean initializationRequested;

    public GodotAndroidYandexAds(Godot godot) {
        super(godot);
        activity = getActivity();
    }

    @Override
    public String getPluginName() {
        return "GodotAndroidYandexAds";
    }

    @Override
    public Set<SignalInfo> getPluginSignals() {
        Set<SignalInfo> signals = new HashSet<>();
        signals.add(new SignalInfo("_on_sdk_initialized"));

        signals.add(new SignalInfo("_on_banner_loaded"));
        signals.add(new SignalInfo("_on_banner_failed_to_load", Integer.class));
        signals.add(new SignalInfo("_on_banner_clicked"));
        signals.add(new SignalInfo("_on_banner_impression"));

        signals.add(new SignalInfo("_on_rewarded_video_ad_loaded"));
        signals.add(new SignalInfo("_on_rewarded_video_ad_failed_to_load", Integer.class));
        signals.add(new SignalInfo("_on_rewarded_video_ad_show"));
        signals.add(new SignalInfo("_on_rewarded_video_ad_failed_to_show", String.class));
        signals.add(new SignalInfo("_on_rewarded_video_ad_dismissed"));
        signals.add(new SignalInfo("_on_rewarded_video_ad_clicked"));
        signals.add(new SignalInfo("_on_rewarded", String.class, Integer.class));
        signals.add(new SignalInfo("_on_rewarded_for_request", String.class, String.class, Integer.class));
        signals.add(new SignalInfo("_on_rewarded_closed_for_request", String.class));
        signals.add(new SignalInfo("_on_rewarded_failed_for_request", String.class, String.class));

        signals.add(new SignalInfo("_on_interstitial_loaded"));
        signals.add(new SignalInfo("_on_interstitial_failed_to_load", Integer.class));
        signals.add(new SignalInfo("_on_interstitial_ad_show"));
        signals.add(new SignalInfo("_on_interstitial_failed_to_show", String.class));
        signals.add(new SignalInfo("_on_interstitial_ad_dismissed"));
        signals.add(new SignalInfo("_on_interstitial_clicked"));
        return signals;
    }

    /** Compatibility entry point for the original plugin wrapper. */
    @UsedByGodot
    public void init(String ignoredApiKey) {
        configure(false, false, false);
    }

    /** Configure privacy flags before SDK initialization. */
    @UsedByGodot
    public void configure(boolean ageRestrictedUser, boolean userConsent, boolean loggingEnabled) {
        activity.runOnUiThread(() -> {
            YandexAds.setAgeRestricted(ageRestrictedUser);
            YandexAds.setUserConsent(userConsent);
            final boolean debugLogging = loggingEnabled &&
                    (activity.getApplicationInfo().flags & android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0;
            YandexAds.enableLogging(debugLogging);
            if (initializationRequested) {
                return;
            }
            initializationRequested = true;
            YandexAds.initialize(activity.getApplicationContext(), () -> {
                if (debugLogging) Log.d(TAG, "Yandex Mobile Ads SDK initialized");
                emitSignal("_on_sdk_initialized");
            });
        });
    }

    @UsedByGodot
    public void setAgeRestrictedUser(boolean ageRestrictedUser) {
        YandexAds.setAgeRestricted(ageRestrictedUser);
    }

    @UsedByGodot
    public void setUserConsent(boolean userConsent) {
        YandexAds.setUserConsent(userConsent);
    }

    private BannerAdSize resolveBannerSize(int widthDp, int heightDp) {
        if (widthDp > 0 && heightDp > 0) {
            return BannerAdSize.fixed(activity, widthDp, heightDp);
        }
        DisplayMetrics metrics = activity.getResources().getDisplayMetrics();
        int availableWidthDp = Math.round(metrics.widthPixels / metrics.density);
        return BannerAdSize.sticky(activity, availableWidthDp);
    }

    private FrameLayout resolveContentRoot() {
        View content = activity.findViewById(android.R.id.content);
        if (content instanceof FrameLayout) {
            return (FrameLayout) content;
        }
        return null;
    }

    private void createBanner(String adUnitId, boolean onTop, int widthDp, int heightDp) {
        destroyBannerInternal();
        bannerParent = resolveContentRoot();
        if (bannerParent == null) {
            Log.e(TAG, "Android content root is not a FrameLayout");
            emitSignal("_on_banner_failed_to_load", -1);
            return;
        }

        bannerAdSize = resolveBannerSize(widthDp, heightDp);
        bannerAdView = new BannerAdView(activity);
        bannerAdView.setBackgroundColor(Color.TRANSPARENT);
        bannerAdView.setAdSize(bannerAdSize);
        bannerAdView.setBannerAdEventListener(createBannerEventListener());

        FrameLayout.LayoutParams params = new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT
        );
        params.gravity = (onTop ? Gravity.TOP : Gravity.BOTTOM) | Gravity.CENTER_HORIZONTAL;
        bannerParent.addView(bannerAdView, params);
        bannerAdView.loadAd(new AdRequest.Builder(adUnitId).build());
    }

    private BannerAdEventListener createBannerEventListener() {
        return new BannerAdEventListener() {
            @Override
            public void onAdLoaded() {
                if (activity.isFinishing() || bannerAdView == null || bannerAdSize == null) {
                    destroyBannerInternal();
                    return;
                }
                bannerLoaded = true;
                bannerWidthPixels = bannerAdSize.getWidthInPixels(activity);
                bannerHeightPixels = bannerAdSize.getHeightInPixels(activity);
                if ((activity.getApplicationInfo().flags & android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0) {
                    Log.d(TAG, "Banner loaded: " + bannerWidthPixels + "x" + bannerHeightPixels + " px");
                }
                emitSignal("_on_banner_loaded");
            }

            @Override
            public void onAdFailedToLoad(AdRequestError error) {
                bannerLoaded = false;
                Log.w(TAG, "Banner failed to load: " + error.getDescription());
                emitSignal("_on_banner_failed_to_load", error.getCode());
            }

            @Override
            public void onAdClicked() {
                emitSignal("_on_banner_clicked");
            }

            @Override
            public void onImpression(ImpressionData impressionData) {
                emitSignal("_on_banner_impression");
            }
        };
    }

    @UsedByGodot
    public void loadBanner(String adUnitId, boolean onTop, int widthDp, int heightDp) {
        activity.runOnUiThread(() -> createBanner(adUnitId, onTop, widthDp, heightDp));
    }

    @UsedByGodot
    public void showBanner() {
        activity.runOnUiThread(() -> {
            if (bannerAdView != null) {
                bannerAdView.setVisibility(View.VISIBLE);
            }
        });
    }

    @UsedByGodot
    public void hideBanner() {
        activity.runOnUiThread(() -> {
            if (bannerAdView != null) {
                bannerAdView.setVisibility(View.GONE);
            }
        });
    }

    @UsedByGodot
    public void removeBanner() {
        activity.runOnUiThread(this::destroyBannerInternal);
    }

    @UsedByGodot
    public boolean isBannerLoaded() {
        return bannerLoaded;
    }

    @UsedByGodot
    public int getBannerWidth() {
        return bannerWidthPixels;
    }

    @UsedByGodot
    public int getBannerHeight() {
        return bannerHeightPixels;
    }

    private void destroyBannerInternal() {
        bannerLoaded = false;
        bannerWidthPixels = 0;
        bannerHeightPixels = 0;
        bannerAdSize = null;
        if (bannerAdView != null) {
            bannerAdView.setBannerAdEventListener(null);
            bannerAdView.destroy();
            if (bannerAdView.getParent() instanceof FrameLayout) {
                ((FrameLayout) bannerAdView.getParent()).removeView(bannerAdView);
            }
            bannerAdView = null;
        }
        bannerParent = null;
    }

    @UsedByGodot
    public void loadRewardedVideo(String adUnitId) {
        activity.runOnUiThread(() -> {
            rewardedAd = null;
            if (rewardedAdLoader != null) {
                rewardedAdLoader.cancelLoading();
            }
            rewardedAdLoader = new RewardedAdLoader(activity);
            rewardedAdLoader.loadAd(new AdRequest.Builder(adUnitId).build(), new RewardedAdLoadListener() {
                @Override
                public void onAdLoaded(RewardedAd newRewardedAd) {
                    rewardedAd = newRewardedAd;
                    emitSignal("_on_rewarded_video_ad_loaded");
                }

                @Override
                public void onAdFailedToLoad(AdRequestError error) {
                    rewardedAd = null;
                    emitSignal("_on_rewarded_video_ad_failed_to_load", error.getCode());
                }
            });
        });
    }

    @UsedByGodot
    public void showRewardedVideo() {
        showRewardedVideoForRequest("");
    }

    @UsedByGodot
    public void showRewardedVideoForRequest(final String requestId) {
        activity.runOnUiThread(() -> {
            final RewardedAd shownAd = rewardedAd;
            if (shownAd == null) {
                emitSignal("_on_rewarded_failed_for_request", requestId, "Rewarded ad is not ready");
                return;
            }
            shownAd.setAdEventListener(createRewardedEventListener(requestId, shownAd));
            shownAd.show(activity);
        });
    }

    private RewardedAdEventListener createRewardedEventListener(final String requestId, final RewardedAd shownAd) {
        return new RewardedAdEventListener() {
            @Override
            public void onAdShown() {
                emitSignal("_on_rewarded_video_ad_show");
            }

            @Override
            public void onAdFailedToShow(AdError error) {
                if (rewardedAd == shownAd) { rewardedAd = null; }
                emitSignal("_on_rewarded_failed_for_request", requestId, error.getDescription());
                emitSignal("_on_rewarded_video_ad_failed_to_show", error.getDescription());
            }

            @Override
            public void onAdDismissed() {
                if (rewardedAd == shownAd) { rewardedAd = null; }
                emitSignal("_on_rewarded_closed_for_request", requestId);
                emitSignal("_on_rewarded_video_ad_dismissed");
            }

            @Override
            public void onAdClicked() {
                emitSignal("_on_rewarded_video_ad_clicked");
            }

            @Override
            public void onAdImpression(ImpressionData impressionData) {
                // ILRD is not consumed by the game yet.
            }

            @Override
            public void onRewarded(Reward reward) {
                emitSignal("_on_rewarded_for_request", requestId, reward.getType(), reward.getAmount());
                emitSignal("_on_rewarded", reward.getType(), reward.getAmount());
            }
        };
    }

    @UsedByGodot
    public void loadInterstitial(String adUnitId) {
        activity.runOnUiThread(() -> {
            interstitialAd = null;
            if (interstitialAdLoader != null) {
                interstitialAdLoader.cancelLoading();
            }
            interstitialAdLoader = new InterstitialAdLoader(activity);
            interstitialAdLoader.loadAd(new AdRequest.Builder(adUnitId).build(), new InterstitialAdLoadListener() {
                @Override
                public void onAdLoaded(InterstitialAd newInterstitialAd) {
                    interstitialAd = newInterstitialAd;
                    emitSignal("_on_interstitial_loaded");
                }

                @Override
                public void onAdFailedToLoad(AdRequestError error) {
                    interstitialAd = null;
                    emitSignal("_on_interstitial_failed_to_load", error.getCode());
                }
            });
        });
    }

    @UsedByGodot
    public void showInterstitial() {
        activity.runOnUiThread(() -> {
            if (interstitialAd == null) {
                return;
            }
            interstitialAd.setAdEventListener(createInterstitialEventListener());
            interstitialAd.show(activity);
        });
    }

    private InterstitialAdEventListener createInterstitialEventListener() {
        return new InterstitialAdEventListener() {
            @Override
            public void onAdShown() {
                emitSignal("_on_interstitial_ad_show");
            }

            @Override
            public void onAdFailedToShow(AdError error) {
                interstitialAd = null;
                emitSignal("_on_interstitial_failed_to_show", error.getDescription());
            }

            @Override
            public void onAdDismissed() {
                interstitialAd = null;
                emitSignal("_on_interstitial_ad_dismissed");
            }

            @Override
            public void onAdClicked() {
                emitSignal("_on_interstitial_clicked");
            }

            @Override
            public void onAdImpression(ImpressionData impressionData) {
                // ILRD is not consumed by the game yet.
            }
        };
    }

    @Override
    public void onMainDestroy() {
        destroyBannerInternal();
        if (rewardedAdLoader != null) {
            rewardedAdLoader.cancelLoading();
            rewardedAdLoader = null;
        }
        if (interstitialAdLoader != null) {
            interstitialAdLoader.cancelLoading();
            interstitialAdLoader = null;
        }
        rewardedAd = null;
        interstitialAd = null;
        super.onMainDestroy();
    }
}
