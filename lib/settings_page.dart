import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_settings.dart';
import 'build_config.dart';
import 'ex_credentials.dart';
import 'premium.dart';
import 'update_checker.dart';

/// 設定画面。バージョン表示とアプリの更新チェックを行う。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _currentVersion = '';
  bool _checking = false;
  bool _exEnabled = false;
  bool _autoOpen = false;
  bool _hasExCredentials = false;
  ProductDetails? _premiumProduct;
  bool _purchasing = false;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _currentVersion = info.version);
    });
    AppSettings.getExEnabled().then((v) {
      if (mounted) setState(() => _exEnabled = v);
    });
    AppSettings.getAutoOpen().then((v) {
      if (mounted) setState(() => _autoOpen = v);
    });
    ExCredentials.exists.then((v) {
      if (mounted) setState(() => _hasExCredentials = v);
    });
    PremiumManager.instance.isPremium.addListener(_onPremiumChanged);
    PremiumManager.instance.fetchProduct().then((product) {
      if (mounted) setState(() => _premiumProduct = product);
    });
  }

  @override
  void dispose() {
    PremiumManager.instance.isPremium.removeListener(_onPremiumChanged);
    super.dispose();
  }

  void _onPremiumChanged() {
    if (!mounted) return;
    setState(() {});
    if (PremiumManager.instance.isPremium.value) {
      _showMessage('プレミアムが有効になりました');
    }
  }

  Future<void> _buyPremium() async {
    setState(() => _purchasing = true);
    final error = await PremiumManager.instance.buy();
    if (mounted) {
      setState(() => _purchasing = false);
      if (error != null) _showMessage(error);
    }
  }

  Future<void> _restorePremium() async {
    final error = await PremiumManager.instance.restore();
    if (!mounted) return;
    if (error != null) {
      _showMessage(error);
    } else if (!PremiumManager.instance.isPremium.value) {
      _showMessage('復元できる購入が見つかりませんでした');
    }
  }

  /// 無料版でプレミアム限定の機能を選ぼうとしたときの案内。
  Future<void> _promptPremium(String featureName) async {
    final buy = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('プレミアム機能'),
        content: Text('「$featureName」はプレミアム限定の機能です。\n'
            'プレミアムでは広告の非表示と履歴の無制限表示も有効になります。'
            '${_premiumProduct != null ? '\n\n価格: ${_premiumProduct!.price}' : ''}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('購入する'),
          ),
        ],
      ),
    );
    if (buy == true) await _buyPremium();
  }

  Future<void> _editExCredentials() async {
    final idController = TextEditingController();
    final pwController = TextEditingController();
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('EX予約 ログイン情報'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '端末内に暗号化して保存し、EX予約のログインフォームへの'
              '自動入力にのみ使用します。外部への送信はありません。',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: idController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '会員ID'),
            ),
            TextField(
              controller: pwController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'パスワード'),
            ),
          ],
        ),
        actions: [
          if (_hasExCredentials)
            TextButton(
              onPressed: () => Navigator.of(context).pop('delete'),
              child: const Text('登録を削除'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('save'),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (action == 'save' &&
        idController.text.isNotEmpty &&
        pwController.text.isNotEmpty) {
      await ExCredentials.save(idController.text, pwController.text);
      if (mounted) {
        setState(() => _hasExCredentials = true);
        _showMessage('ログイン情報を保存しました');
      }
    } else if (action == 'delete') {
      await ExCredentials.delete();
      if (mounted) {
        setState(() => _hasExCredentials = false);
        _showMessage('ログイン情報を削除しました');
      }
    }
    idController.dispose();
    pwController.dispose();
  }

  Future<void> _setExEnabled(bool value) async {
    // EX予約連携はプレミアム限定
    if (value && !PremiumManager.instance.isPremium.value) {
      await _promptPremium('EX予約連携');
      return;
    }
    setState(() => _exEnabled = value);
    await AppSettings.setExEnabled(value);
  }

  Future<void> _setAutoOpen(bool value) async {
    // 自動で開くはプレミアム限定
    if (value && !PremiumManager.instance.isPremium.value) {
      await _promptPremium('自動で開く');
      return;
    }
    setState(() => _autoOpen = value);
    await AppSettings.setAutoOpen(value);
  }

  Future<void> _checkUpdate() async {
    setState(() => _checking = true);
    try {
      final latest = await UpdateChecker().fetchLatest();
      if (!mounted) return;
      if (latest == null) {
        _showMessage('リリース情報が見つかりませんでした');
      } else if (UpdateChecker.isNewer(_currentVersion, latest.version)) {
        await _showUpdateDialog(latest);
      } else {
        _showMessage('お使いのバージョン（$_currentVersion）は最新です');
      }
    } catch (e) {
      if (mounted) _showMessage('$e');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _showUpdateDialog(ReleaseInfo latest) async {
    final download = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('新しいバージョン ${latest.version}'),
        content: Text('現在のバージョン: $_currentVersion\n'
            '新しいバージョンをダウンロードしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('あとで'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ダウンロード'),
          ),
        ],
      ),
    );
    if (download == true) {
      final url = latest.apkUrl ?? latest.pageUrl;
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = PremiumManager.instance.isPremium.value;
    // 無料版ではプレミアム限定の設定が残っていても実際には動作しないため
    // 表示上もOFF側に寄せる
    final effectiveAutoOpen = isPremium && _autoOpen;
    final effectiveExEnabled = isPremium && _exEnabled;
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('共有受信時の動作'),
          ),
          RadioListTile<bool>(
            title: const Text('ボタンで選んで開く'),
            subtitle: const Text('解析結果を確認してから予約サービスを開きます'),
            value: false,
            groupValue: effectiveAutoOpen,
            onChanged: (v) => _setAutoOpen(v!),
          ),
          RadioListTile<bool>(
            title: Row(
              children: [
                const Text('自動で開く'),
                if (!isPremium) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.lock_outline,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ],
              ],
            ),
            subtitle: Text(
                '${isPremium ? '' : '【プレミアム限定】'}共有後すぐに予約サービスへ移動します。'
                '東海道・山陽・九州新幹線の経路はEX予約（連携ON時）、'
                'それ以外はえきねっとへ自動で振り分けます'),
            value: true,
            groupValue: effectiveAutoOpen,
            onChanged: (v) => _setAutoOpen(v!),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('プレミアム'),
          ),
          if (isPremium)
            ListTile(
              leading: Icon(Icons.verified,
                  color: Theme.of(context).colorScheme.primary),
              title: const Text('プレミアム購入済み'),
              subtitle: const Text('広告非表示・履歴の無制限表示・自動で開く・EX予約連携が有効です'),
            )
          else ...[
            ListTile(
              leading: _purchasing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.workspace_premium),
              title: const Text('プレミアムにアップグレード'),
              subtitle: Text('広告の非表示、履歴の無制限表示、自動で開く、EX予約連携が使えます'
                  '${_premiumProduct != null ? '（${_premiumProduct!.price}）' : ''}'),
              enabled: !_purchasing,
              onTap: _buyPremium,
            ),
            ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('購入を復元'),
              subtitle: const Text('機種変更などで購入済みの場合はこちら'),
              onTap: _restorePremium,
            ),
          ],
          const Divider(),
          SwitchListTile(
            secondary: Icon(
              isPremium ? Icons.directions_railway : Icons.lock_outline,
            ),
            title: const Text('EX予約連携（Web版）'),
            subtitle: Text(
                '${isPremium ? '' : '【プレミアム限定】'}東海道・山陽・九州新幹線の経路でEX予約（Web版）を開くボタンを表示します。'
                'ログイン後の検索フォームへ条件の自動入力を試みます'),
            value: effectiveExEnabled,
            onChanged: _setExEnabled,
          ),
          if (effectiveExEnabled)
            ListTile(
              leading: Icon(
                _hasExCredentials ? Icons.key : Icons.key_off,
                color: _hasExCredentials
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              title: const Text('EX予約 ログイン情報（任意）'),
              subtitle: Text(_hasExCredentials
                  ? '登録済み。EX予約を開くと自動でログインします'
                  : '未登録。登録すると自動ログイン・検索画面まで自動で進みます。'
                      '端末内に暗号化保存され、外部送信はありません'),
              onTap: _editExCredentials,
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('バージョン'),
            subtitle: Text(_currentVersion.isEmpty ? '-' : _currentVersion),
          ),
          // Play版では更新はPlayストアが行うため、GitHubからのAPK更新と
          // リポジトリへのリンクは表示しない（Playポリシー対応）
          if (!kIsPlayStoreBuild) ...[
            ListTile(
              leading: _checking
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.system_update),
              title: const Text('更新を確認'),
              subtitle: const Text('GitHub Releases の最新バージョンを確認します'),
              enabled: !_checking,
              onTap: _checkUpdate,
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('ソースコード'),
              subtitle: const Text('github.com/${UpdateChecker.repo}'),
              onTap: () => launchUrl(
                Uri.parse('https://github.com/${UpdateChecker.repo}'),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
