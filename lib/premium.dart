import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// プレミアム（買い切りアプリ内課金）の購入状態を管理する。
///
/// 購入状態の正はGoogle Play Billingで、SharedPreferencesのキャッシュは
/// 起動直後の表示用。起動時のrestorePurchases()とpurchaseStreamで同期する。
/// プレミアムで解放される機能:
/// 広告非表示・履歴の無制限・自動で開く・EX予約連携。
class PremiumManager {
  PremiumManager._();

  static final PremiumManager instance = PremiumManager._();

  /// Play Consoleの「アプリ内アイテム」に同じIDで登録すること。
  static const productId = 'premium_unlock';

  /// 無料版で表示する履歴の上限件数。
  static const freeHistoryLimit = 3;

  static const _cacheKey = 'premium_unlocked';

  final ValueNotifier<bool> isPremium = ValueNotifier(false);

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// アプリ起動時に一度だけ呼ぶ。ストアへ接続できない環境（テスト・
  /// サイドロード版）でも例外を出さずキャッシュ値で動作する。
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isPremium.value = prefs.getBool(_cacheKey) ?? false;
    } catch (_) {}
    try {
      final iap = InAppPurchase.instance;
      _subscription ??= iap.purchaseStream.listen(_onPurchaseUpdated);
      if (await iap.isAvailable()) {
        await iap.restorePurchases();
      }
    } catch (_) {}
  }

  Future<void> _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      final owned = purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored;
      if (purchase.productID == productId && owned) {
        await _setPremium(true);
      }
      if (purchase.pendingCompletePurchase) {
        try {
          await InAppPurchase.instance.completePurchase(purchase);
        } catch (_) {}
      }
    }
  }

  Future<void> _setPremium(bool value) async {
    isPremium.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_cacheKey, value);
    } catch (_) {}
  }

  /// 価格表示用の商品情報。ストア未接続・商品未登録ならnull。
  Future<ProductDetails?> fetchProduct() async {
    try {
      final iap = InAppPurchase.instance;
      if (!await iap.isAvailable()) return null;
      final response = await iap.queryProductDetails({productId});
      if (response.productDetails.isEmpty) return null;
      return response.productDetails.first;
    } catch (_) {
      return null;
    }
  }

  /// 購入フローを開始する。失敗時はエラーメッセージを返す（開始できたらnull）。
  /// 購入完了はpurchaseStream経由でisPremiumに反映される。
  Future<String?> buy() async {
    final product = await fetchProduct();
    if (product == null) {
      return 'ストアに接続できませんでした。しばらくしてから再度お試しください';
    }
    try {
      await InAppPurchase.instance.buyNonConsumable(
          purchaseParam: PurchaseParam(productDetails: product));
      return null;
    } catch (e) {
      return '購入を開始できませんでした: $e';
    }
  }

  /// 機種変更・再インストール時の購入復元。
  Future<String?> restore() async {
    try {
      final iap = InAppPurchase.instance;
      if (!await iap.isAvailable()) {
        return 'ストアに接続できませんでした';
      }
      await iap.restorePurchases();
      return null;
    } catch (e) {
      return '復元に失敗しました: $e';
    }
  }
}
