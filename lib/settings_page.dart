import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_settings.dart';
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
