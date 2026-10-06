import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'build_config.dart';

/// Google Play のアプリ内レビュー（In-App Review API）を出すタイミングの管理。
///
/// 予約サービスを開いて戻ってきた「うまくいった直後」にだけ依頼する。
/// 依頼は [minSuccessCount] 回目の成功以降、[retryInterval] に1回まで。
/// 実際に表示するかどうかは Play 側のクォータで決まるため、
/// 呼び出しても出ないことがある（その場合も次回は [retryInterval] 後）。
///
/// Play版のみ有効。GitHub版はストアが無いため何もしない。
class ReviewPrompt {
  ReviewPrompt._();

  static const _keySuccessCount = 'review_success_count';
  static const _keyLastRequestedAt = 'review_last_requested_at';

  /// レビューを依頼し始める成功回数（予約サービスを開いた回数）。
  static const minSuccessCount = 3;

  /// 一度依頼したあと次に依頼するまでの間隔。
  static const retryInterval = Duration(days: 90);

  /// Google Play のストアページ URL（「友だちに教える」で共有する）。
  static const storeUrl =
      'https://play.google.com/store/apps/details?id=io.github.makiiii_git.y2eknt';

  /// 予約サービスを開けた回数を1増やす。
  static Future<int> recordSuccess() async {
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(_keySuccessCount) ?? 0) + 1;
    await prefs.setInt(_keySuccessCount, count);
    return count;
  }

  /// 依頼してよいかの判定（純粋関数。テスト用に公開）。
  static bool shouldRequest({
    required int successCount,
    required DateTime? lastRequestedAt,
    required DateTime now,
  }) {
    if (successCount < minSuccessCount) return false;
    if (lastRequestedAt == null) return true;
    return now.difference(lastRequestedAt) >= retryInterval;
  }

  /// 条件を満たしていればアプリ内レビューを依頼する。
  /// 依頼した（＝Play に表示を要求した）場合は true。
  static Future<bool> maybeRequest({DateTime? now}) async {
    if (!kIsPlayStoreBuild) return false;
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_keySuccessCount) ?? 0;
    final lastMillis = prefs.getInt(_keyLastRequestedAt);
    final last = lastMillis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(lastMillis);
    final current = now ?? DateTime.now();
    if (!shouldRequest(
        successCount: count, lastRequestedAt: last, now: current)) {
      return false;
    }
    try {
      final review = InAppReview.instance;
      if (!await review.isAvailable()) return false;
      // 先に記録しておき、表示に失敗しても連続で依頼しないようにする
      await prefs.setInt(_keyLastRequestedAt, current.millisecondsSinceEpoch);
      await review.requestReview();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 予約サービスを開いて戻ってきたときに呼ぶ。
  /// 成功回数を記録し、条件を満たせばレビューを依頼する。
  static Future<void> onReservationServiceClosed() async {
    try {
      await recordSuccess();
      await maybeRequest();
    } catch (_) {
      // レビュー依頼は本来の機能ではないため、失敗しても何もしない
    }
  }

  /// Google Play のストアページ（レビュー画面）を開く。
  static Future<void> openStoreListing() async {
    try {
      await InAppReview.instance.openStoreListing();
    } catch (_) {}
  }
}
