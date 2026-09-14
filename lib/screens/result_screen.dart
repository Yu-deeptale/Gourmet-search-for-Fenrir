import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/shop.dart';
import '../services/hotpepper_api.dart';
import 'detail_screen.dart';

const _conditionLabels = <String, String>{
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
  late Future<HotPepperSearchResult> _shops;
  late String _keyword;
  late int? _range;
  late Position? _position;
  late Map<String, bool> _conditions;
  String _sort = '距離順';

  @override
  void initState() {
    super.initState();
    _keyword = widget.keyword.trim();
    _range = widget.range;
    _position = widget.position;
    _conditions = Map<String, bool>.from(widget.conditions);
    _shops = _load();
  }

  Future<HotPepperSearchResult> _load() => widget.api.search(
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
        bottom: false,
        child: Column(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const Padding(
                padding: EdgeInsets.only(top: 8, bottom: 4),
                child: Text(
                  'Gourmet Vote',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Jua',
                    fontSize: 30,
                  ),
                ),
              ),
            ),
            _Toolbar(
              onChangeFilters: _showFilterMenu,
              onSort: _showSortMenu,
            ),
            _AppliedConditions(
              keyword: _keyword,
              conditions: _conditions,
              onRemove: _removeCondition,
            ),
            Expanded(child: _buildResults()),
            FutureBuilder<HotPepperSearchResult>(
              future: _shops,
              builder: (context, snapshot) => _ResultCount(
                count: snapshot.data?.totalResults,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    return FutureBuilder<HotPepperSearchResult>(
      future: _shops,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _Message(
            message: snapshot.error.toString(),
            action: _reload,
          );
        }
        final shops = [...(snapshot.data?.shops ?? const <Shop>[])];
        shops.sort(_compareShops);
        if (shops.isEmpty) return const _Message(message: '条件に一致する店舗がありません。');
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: shops.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) => _ShopTile(
            shop: shops[index],
            position: _position,
            conditions: _conditions,
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

  Future<void> _reload() async {
    final future = _load();
    if (mounted) {
      setState(() => _shops = future);
    }
    await future;
  }

  Future<void> _showSortMenu() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in ['距離順', '価格順（低い順）', '価格順（高い順）'])
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

  Future<void> _showFilterMenu() async {
    final draft = Map<String, bool>.from(_conditions);
    const groups = <String, List<String>>{
      '設備・空間': ['wifi', 'private_room', 'tatami', 'barrier_free'],
      '飲食サービス': ['free_drink', 'free_food', 'lunch', 'midnight'],
      'エンタメ': ['night_view', 'karaoke'],
      '支払い・家族向け': ['card', 'pet', 'child'],
    };
    final selected = await showModalBottomSheet<Map<String, bool>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '絞り込み条件',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...groups.entries.map(
                  (group) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: Text(
                          group.key,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: group.value.map((condition) {
                          return FilterChip(
                            label: Text(_conditionLabels[condition]!),
                            selected: draft[condition] ?? false,
                            showCheckmark: false,
                            selectedColor:
                                const Color.fromARGB(255, 0, 197, 69),
                            onSelected: (value) => setSheetState(
                              () => draft[condition] = value,
                            ),
                          );
                        }).toList(growable: false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, draft),
                    child: const Text('適用'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _conditions = selected;
        _shops = _load();
      });
    }
  }

  int _compareShops(Shop first, Shop second) {
    if (_sort == '距離順') {
      final firstDistance = _distanceTo(first);
      final secondDistance = _distanceTo(second);
      if (firstDistance != null && secondDistance != null) {
        return firstDistance.compareTo(secondDistance);
      }
      if (firstDistance != null) return -1;
      if (secondDistance != null) return 1;
    } else {
      final firstPrice = _priceOf(first.budget);
      final secondPrice = _priceOf(second.budget);
      final comparison = firstPrice.compareTo(secondPrice);
      if (comparison != 0) {
        return _sort == '価格順（低い順）' ? comparison : -comparison;
      }
    }
    return first.name.compareTo(second.name);
  }

  double? _distanceTo(Shop shop) {
    if (_position == null || shop.lat == null || shop.lng == null) return null;
    return Geolocator.distanceBetween(
      _position!.latitude,
      _position!.longitude,
      shop.lat!,
      shop.lng!,
    );
  }

  int _priceOf(String budget) {
    final numbers = RegExp(r'\d[\d,]*')
        .allMatches(budget)
        .map((match) => int.tryParse(match.group(0)!.replaceAll(',', '')))
        .whereType<int>();
    return numbers.isEmpty ? 1 << 30 : numbers.first;
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.onChangeFilters, required this.onSort});
  final VoidCallback onChangeFilters;
  final VoidCallback onSort;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 420;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Flex(
        direction: narrow ? Axis.vertical : Axis.horizontal,
        children: [
          if (narrow)
            SizedBox(
              width: double.infinity,
              child: _ToolbarButton(
                icon: Icons.tune,
                label: '絞り込み条件変更',
                onPressed: onChangeFilters,
              ),
            )
          else
            Expanded(
              child: _ToolbarButton(
                icon: Icons.tune,
                label: '絞り込み条件変更',
                onPressed: onChangeFilters,
              ),
            ),
          SizedBox(
            width: narrow ? 0 : 8,
            height: narrow ? 8 : 0,
          ),
          if (narrow)
            SizedBox(
              width: double.infinity,
              child: _ToolbarButton(
                icon: Icons.swap_vert,
                label: '並び替え',
                onPressed: onSort,
              ),
            )
          else
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
    required this.conditions,
    required this.onRemove,
  });
  final String keyword;
  final Map<String, bool> conditions;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final conditionChips = <Widget>[
      if (keyword.isNotEmpty) _condition('キーワード: $keyword', 'keyword'),
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
}

class _ResultCount extends StatelessWidget {
  const _ResultCount({required this.count});
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      color: Colors.white.withValues(alpha: 0.72),
      child: Text(
        count == null
            ? '店舗を検索中...'
            : count! >= 101
                ? '100店舗以上ヒット'
                : '${count!}店舗ヒット',
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _ShopTile extends StatelessWidget {
  const _ShopTile({
    required this.shop,
    required this.position,
    required this.conditions,
  });
  final Shop shop;
  final Position? position;
  final Map<String, bool> conditions;

  @override
  Widget build(BuildContext context) {
    final distance = position != null && shop.lat != null && shop.lng != null
        ? _formatDistance(
            Geolocator.distanceBetween(
              position!.latitude,
              position!.longitude,
              shop.lat!,
              shop.lng!,
            ),
          )
        : null;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DetailScreen(shop: shop, conditions: conditions),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              height: 180,
              child: shop.photoUrl.isEmpty
                  ? const Center(child: Icon(Icons.restaurant, size: 72))
                  : CachedNetworkImage(
                      imageUrl: shop.photoUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          const Center(child: Icon(Icons.restaurant, size: 72)),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shop.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (distance != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.near_me, size: 16),
                        const SizedBox(width: 4),
                        Text('現在地から $distance'),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    [shop.address, shop.budget]
                        .where((text) => text.isNotEmpty)
                        .join('\n'),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDistance(double meters) => meters < 1000
      ? '${meters.round()}m'
      : '${(meters / 1000).toStringAsFixed(1)}km';
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
