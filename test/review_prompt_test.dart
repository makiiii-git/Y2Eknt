import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:y2eknt/review_prompt.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReviewPrompt.shouldRequest', () {
    final now = DateTime(2026, 10, 7);

    test('成功回数が足りないうちは依頼しない', () {
      expect(
        ReviewPrompt.shouldRequest(
            successCount: ReviewPrompt.minSuccessCount - 1,
            lastRequestedAt: null,
            now: now),
        isFalse,
      );
    });

    test('規定回数に達し未依頼なら依頼する', () {
      expect(
        ReviewPrompt.shouldRequest(
            successCount: ReviewPrompt.minSuccessCount,
            lastRequestedAt: null,
            now: now),
        isTrue,
      );
    });

    test('前回の依頼から間隔が空くまでは依頼しない', () {
      final recent = now.subtract(ReviewPrompt.retryInterval ~/ 2);
      expect(
        ReviewPrompt.shouldRequest(
            successCount: 10, lastRequestedAt: recent, now: now),
        isFalse,
      );
    });

    test('前回の依頼から間隔が空けば再び依頼する', () {
      final old = now.subtract(ReviewPrompt.retryInterval);
      expect(
        ReviewPrompt.shouldRequest(
            successCount: 10, lastRequestedAt: old, now: now),
        isTrue,
      );
    });
  });

  group('ReviewPrompt.recordSuccess', () {
    test('呼ぶたびに成功回数が1増えて保存される', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await ReviewPrompt.recordSuccess(), 1);
      expect(await ReviewPrompt.recordSuccess(), 2);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('review_success_count'), 2);
    });
  });

  group('ReviewPrompt.maybeRequest', () {
    test('GitHub版（PLAY_STOREフラグなし）では何もしない', () async {
      SharedPreferences.setMockInitialValues({'review_success_count': 100});
      expect(await ReviewPrompt.maybeRequest(), isFalse);
    });
  });
}
