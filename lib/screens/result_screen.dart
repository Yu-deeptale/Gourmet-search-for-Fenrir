import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/shop.dart';
import '../services/hotpepper_api.dart';
import 'detail_screen.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({
    required this.api,
    required this.keyword,
    required this.range,
    required this.position,
    this.prefectureCode,
    this.cityCode,
    this.conditions = const {},
    super.key,
  });

  final HotPepperApi api;
  final String keyword;
  final int range;
  final Position? position;
  final String? prefectureCode;
  final String? cityCode;
  final Map<String, bool> conditions;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late Future<List<Shop>> _shops;
  late String _keyword;
  late int? _range;
  late Position? _position;
  late Map<String, bool> _conditions;
  String _sort = 'おすすめ順';

  @override
  void initState() {
    super.initState();
    _keyword = widget.keyword.trim();
    _range = widget.range;
    _position = widget.position;
    _conditions = Map<String, bool>.from(widget.conditions);
    _shops = _load();
  }

  Future<List<Shop>> _load() => widget.api.search(
        keyword: _keyword,
        range: _range ?? 3,
        latitude: _position?.latitude,
        longitude: _position?.longitude,
        prefectureCode: widget.prefectureCode,
        cityCode: widget.cityCode,
        conditions: _conditions,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF38EF7D),
      body: SafeArea(
        child: Column(
          children: [
            _Toolbar(
              onChangeFilters: () => Navigator.of(context).pop(),
              onSort: _showSortMenu,
            ),
            _AppliedConditions(
              keyword: _keyword,
              range: _range,
              hasLocation: _position != null,
              conditions: _conditions,
              onRemove: _removeCondition,
            ),
            Expanded(child: _buildResults()),
            FutureBuilder<List<Shop>>(
              future: _shops,
              builder: (context, snapshot) => _ResultCount(
                count: snapshot.data?.length,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    return FutureBuilder<List<Shop>>(
      future: _shops,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _Message(
            message: snapshot.error.toString(),
            action: () => setState(() => _shops = _load()),
          );
        }
        final shops = [...(snapshot.data ?? const <Shop>[])];
        if (_sort == '店名順') {
          shops.sort((a, b) => a.name.compareTo(b.name));
        }
        if (shops.isEmpty) return const _Message(message: '条件に一致する店舗がありません。');
        return RefreshIndicator(
          onRefresh: () async => setState(() => _shops = _load()),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: shops.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _ShopTile(shop: shops[index]),
          ),
        );
      },
    );
  }

  void _removeCondition(String condition) {
    setState(() {
      switch (condition) {
        case 'keyword':
          _keyword = '';
        case 'range':
          _range = null;
        case 'location':
          _position = null;
        default:
          _conditions[condition] = false;
      }
      _shops = _load();
    });
  }

  Future<void> _showSortMenu() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in ['おすすめ順', '店名順'])
              ListTile(
                title: Text(option),
                trailing: option == _sort ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, option),
              ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) setState(() => _sort = selected);
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.onChangeFilters, required this.onSort});
  final VoidCallback onChangeFilters;
  final VoidCallback onSort;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: _ToolbarButton(
              icon: Icons.tune,
              label: '絞り込み条件変更',
              onPressed: onChangeFilters,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ToolbarButton(
              icon: Icons.swap_vert,
              label: '並び替え',
              onPressed: onSort,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton(
      {required this.icon, required this.label, required this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, overflow: TextOverflow.ellipsis),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.8),
        foregroundColor: Colors.black87,
      ),
    );
  }
}

class _AppliedConditions extends StatelessWidget {
  const _AppliedConditions({
    required this.keyword,
    required this.range,
    required this.hasLocation,
    required this.conditions,
    required this.onRemove,
  });
  final String keyword;
  final int? range;
  final bool hasLocation;
  final Map<String, bool> conditions;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final conditionChips = <Widget>[
      if (keyword.isNotEmpty) _condition('キーワード: $keyword', 'keyword'),
      if (range != null) _condition('範囲: ${_rangeLabel(range!)}', 'range'),
      if (hasLocation) _condition('現在地周辺', 'location'),
      for (final entry in conditions.entries)
        if (entry.value)
          _condition(_conditionLabels[entry.key] ?? entry.key, entry.key),
    ];
    return SizedBox(
      height: conditionChips.isEmpty ? 8 : 52,
      child: conditionChips.isEmpty
          ? null
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              scrollDirection: Axis.horizontal,
              children: conditionChips,
            ),
    );
  }

  Widget _condition(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InputChip(
        label: Text(label),
        deleteIcon: const Icon(Icons.close, size: 18),
        onDeleted: () => onRemove(value),
        backgroundColor: Colors.white.withValues(alpha: 0.8),
      ),
    );
  }

  String _rangeLabel(int value) =>
      const {
        1: '300m以内',
        2: '500m以内',
        3: '1km以内',
        4: '2km以内',
        5: '3km以内',
      }[value] ??
      '指定範囲';

  static const _conditionLabels = <String, String>{
    'wifi': 'Wi-Fi',
    'free_drink': '飲み放題',
    'free_food': '食べ放題',
    'private_room': '個室',
    'tatami': '座敷',
    'card': 'カード利用可',
    'barrier_free': 'バリアフリー',
    'night_view': '夜景',
    'karaoke': 'カラオケ',
    'lunch': 'ランチ',
    'midnight': '深夜営業',
    'pet': 'ペット可',
    'child': 'お子様連れ歓迎',
  };
}

class _ResultCount extends StatelessWidget {
  const _ResultCount({required this.count});
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: Colors.white.withValues(alpha: 0.72),
      child: Text(
        count == null ? '店舗を検索中...' : '${count!}店舗ヒット',
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _ShopTile extends StatelessWidget {
  const _ShopTile({required this.shop});
  final Shop shop;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: shop.photoUrl.isEmpty
            ? const Icon(Icons.restaurant, size: 48)
            : CachedNetworkImage(
                imageUrl: shop.photoUrl,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.restaurant, size: 48),
              ),
        title: Text(shop.name, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text([shop.address, shop.budget]
            .where((text) => text.isNotEmpty)
            .join('\n')),
        isThreeLine: true,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DetailScreen(shop: shop)),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.message, this.action});
  final String message;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: action, child: const Text('再試行')),
            ],
          ],
        ),
      ),
    );
  }
}
