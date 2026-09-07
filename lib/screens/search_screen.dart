import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/hotpepper_api.dart';
import 'result_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _keywordController = TextEditingController();
  final _genreController = TextEditingController();
  final _api = HotPepperApi();
  Position? _position;
  int _range = 3;
  bool _locating = false;

  @override
  void dispose() {
    _keywordController.dispose();
    _genreController.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    setState(() => _locating = true);
    try {
      final permission = await Permission.locationWhenInUse.request();
      if (!permission.isGranted) {
        if (mounted) _showMessage('位置情報の権限が必要です。');
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) _showMessage('端末の位置情報サービスを有効にしてください。');
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() => _position = position);
        _showMessage('現在地を取得しました。');
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _search() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          api: _api,
          keyword: _keywordController.text,
          genre: _genreController.text,
          range: _range,
          position: _position,
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('グルメ検索')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('お店を探す', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          TextField(
            controller: _keywordController,
            decoration: const InputDecoration(
              labelText: 'キーワード',
              hintText: '店名、料理名、エリアなど',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _genreController,
            decoration: const InputDecoration(
              labelText: 'ジャンルコード（任意）',
              hintText: '例: G001（居酒屋）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<int>(
            initialValue: _range,
            decoration: const InputDecoration(labelText: '検索範囲', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 1, child: Text('300m以内')),
              DropdownMenuItem(value: 2, child: Text('500m以内')),
              DropdownMenuItem(value: 3, child: Text('1km以内')),
              DropdownMenuItem(value: 4, child: Text('2km以内')),
              DropdownMenuItem(value: 5, child: Text('3km以内')),
            ],
            onChanged: (value) => setState(() => _range = value ?? 3),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _locating ? null : _getLocation,
            icon: _locating
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location),
            label: Text(_position == null ? '現在地を取得' : '現在地を取得済み'),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _search,
            icon: const Icon(Icons.search),
            label: const Text('検索する'),
          ),
        ],
      ),
    );
  }
}
