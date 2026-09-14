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

  @override
  void initState() {
    super.initState();
    _shops = _load();
  }

  Future<List<Shop>> _load() => widget.api.search(
        keyword: widget.keyword,
        range: widget.range,
        latitude: widget.position?.latitude,
        longitude: widget.position?.longitude,
        prefectureCode: widget.prefectureCode,
        cityCode: widget.cityCode,
        conditions: widget.conditions,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('検索結果')),
      body: FutureBuilder<List<Shop>>(
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
          final shops = snapshot.data ?? const <Shop>[];
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
