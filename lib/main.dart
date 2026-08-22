import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'share_intent.dart';

void main() {
  runApp(const Y2EkinetApp());
}

class Y2EkinetApp extends StatelessWidget {
  const Y2EkinetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Y2Ekinet',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _sharedText;

  @override
  void initState() {
    super.initState();
    _loadInitialText();
    ShareIntent.setOnSharedText((text) {
      debugPrint('SHARED_TEXT_BEGIN\n$text\nSHARED_TEXT_END');
      setState(() => _sharedText = text);
    });
  }

  Future<void> _loadInitialText() async {
    final text = await ShareIntent.getInitialText();
    if (text != null && mounted) {
      debugPrint('SHARED_TEXT_BEGIN\n$text\nSHARED_TEXT_END');
      setState(() => _sharedText = text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Y2Ekinet')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _sharedText == null
            ? const Center(
                child: Text(
                  'Yahoo!乗換案内の経路詳細画面から\n「共有」でテキストを送ってください',
                  textAlign: TextAlign.center,
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '受信したテキスト',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(_sharedText!),
                  ],
                ),
              ),
      ),
    );
  }
}
