import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// バナー広告ユニットID（AdMob本番）。
///
/// AndroidManifest.xmlのcom.google.android.gms.ads.APPLICATION_IDに
/// 対応するAdMobアプリIDを設定しており、両者は同じAdMobアプリに属する。
const bannerAdUnitId = 'ca-app-pub-5796626901181447/8168135134';

/// ホーム画面下部に表示するアンカー型アダプティブバナー。
/// 読み込みに失敗した場合や広告SDKが使えない環境では何も表示しない。
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _loadStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 起動直後は画面サイズが確定しておらず幅0になることがある。
    // 幅0で要求すると「Ad request doesn't meet size requirements」で必ず失敗するため、
    // 幅が確定して再度呼ばれるまで読み込みを始めない（sizeOfで画面サイズの変化を購読している）。
    final width = MediaQuery.sizeOf(context).width.truncate();
    if (!_loadStarted && width > 0) {
      _loadStarted = true;
      _load(width);
    }
  }

  Future<void> _load(int width) async {
    try {
      // google_mobile_ads 8.0 で非推奨になったが、置き換え先の
      // getLargeAnchoredAdaptiveBannerAdSize はバナーが高くなり画面の見え方が
      // 変わるため、従来の高さのまま使い続ける
      // ignore: deprecated_member_use
      final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
          width);
      if (size == null) return;
      final ad = BannerAd(
        adUnitId: bannerAdUnitId,
        size: size,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) {
            if (mounted) setState(() => _loaded = true);
          },
          onAdFailedToLoad: (ad, error) {
            debugPrint('バナー広告の読み込み失敗: $error');
            ad.dispose();
          },
        ),
      );
      _ad = ad;
      await ad.load();
    } catch (e) {
      // 広告SDKが初期化できない環境（テスト等）では表示しない
      debugPrint('バナー広告を初期化できません: $e');
    }
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
