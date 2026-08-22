import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_settings.dart';
import 'ex_credentials.dart';
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
    setState(() => _exEnabled = value);
    await AppSettings.setExEnabled(value);
  }

  Future<void> _setAutoOpen(bool value) async {
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
            groupValue: _autoOpen,
            onChanged: (v) => _setAutoOpen(v!),
          ),
          RadioListTile<bool>(
            title: const Text('自動で開く'),
            subtitle: const Text('共有後すぐに予約サービスへ移動します。'
                '東海道・山陽・九州新幹線の経路はEX予約（連携ON時）、'
                'それ以外はえきねっとへ自動で振り分けます'),
            value: true,
            groupValue: _autoOpen,
            onChanged: (v) => _setAutoOpen(v!),
          ),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.directions_railway),
            title: const Text('EX予約連携（Web版）'),
            subtitle: const Text(
                '東海道・山陽・九州新幹線の経路でEX予約（Web版）を開くボタンを表示します。'
                'ログイン後の検索フォームへ条件の自動入力を試みます'),
            value: _exEnabled,
            onChanged: _setExEnabled,
          ),
          if (_exEnabled)
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
      ),
    );
  }
}
