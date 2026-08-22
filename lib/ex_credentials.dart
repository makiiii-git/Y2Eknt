import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// EX予約のログイン情報（任意登録）。
///
/// Android Keystoreで暗号化して端末内にのみ保存する。
/// 用途はEX予約公式ログインフォームへの自動入力だけで、外部へは送信しない。
/// 登録は任意であり、未登録でもすべての機能は利用できる（手動ログイン）。
class ExCredentials {
  static const _storage = FlutterSecureStorage();
  static const _keyId = 'ex_member_id';
  static const _keyPassword = 'ex_password';

  /// 会員ID・パスワードの両方が登録されていれば返す。無ければ null。
  static Future<({String memberId, String password})?> load() async {
    final id = await _storage.read(key: _keyId);
    final pw = await _storage.read(key: _keyPassword);
    if (id == null || id.isEmpty || pw == null || pw.isEmpty) return null;
    return (memberId: id, password: pw);
  }

  static Future<void> save(String memberId, String password) async {
    await _storage.write(key: _keyId, value: memberId);
    await _storage.write(key: _keyPassword, value: password);
  }

  static Future<void> delete() async {
    await _storage.delete(key: _keyId);
    await _storage.delete(key: _keyPassword);
  }

  static Future<bool> get exists async => (await load()) != null;
}
