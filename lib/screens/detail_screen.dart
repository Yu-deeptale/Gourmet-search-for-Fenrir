import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/shop.dart';

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

const _conditionCriteria = <String, String>{
  'wifi': '回線強度や接続のしやすさ',
  'free_drink': '飲み放題メニューの豊富さ',
  'free_food': '食べ放題メニューの豊富さ',
  'private_room': '個室の使いやすさや快適さ',
  'tatami': '座敷の広さや利用しやすさ',
  'card': 'カード決済の使いやすさ',
  'barrier_free': '店内設備のバリアフリー対応',
  'night_view': '夜景の見え方や席の良さ',
  'karaoke': 'カラオケ設備の使いやすさ',
  'lunch': 'ランチメニューの充実度',
  'midnight': '深夜帯の営業状況や利用しやすさ',
  'pet': 'ペット同伴のしやすさ',
  'child': '子ども連れでの利用しやすさ',
};

class DetailScreen extends StatefulWidget {
  const DetailScreen({
    required this.shop,
    this.conditions = const {},
    super.key,
  });
  final Shop shop;
  final Map<String, bool> conditions;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  bool _bookmarked = false;
  int? _overallRating;
  final Map<String, int> _conditionRatings = {};
  DateTime? _lastVoteAt;

  Future<void> _openMap(BuildContext context) async {
    final shop = widget.shop;
    final uri = shop.lat != null && shop.lng != null
        ? Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=${shop.lat},${shop.lng}',
          )
        : Uri.tryParse(shop.mapUrl);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('地図を開けませんでした。')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF38EF7D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: GestureDetector(
          onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
          child: const Text(
            'Gourmet Vote',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Jua',
              fontSize: 26,
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.shop.photoUrl.isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: CachedNetworkImage(
                imageUrl: widget.shop.photoUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(),
                ),
                errorWidget: (_, __, ___) =>
                    const Center(child: Icon(Icons.restaurant, size: 64)),
              ),
            ),
          const SizedBox(height: 16),
          Text(widget.shop.name,
              style: Theme.of(context).textTheme.headlineSmall),
          if (widget.shop.catchPhrase.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(widget.shop.catchPhrase),
          ],
          const Divider(height: 32),
          _InfoRow(icon: Icons.location_on, text: widget.shop.address),
          if (widget.shop.access.isNotEmpty)
            _InfoRow(icon: Icons.train, text: widget.shop.access),
          if (widget.shop.budget.isNotEmpty)
            _InfoRow(icon: Icons.payments, text: widget.shop.budget),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 360;
              final bookmark = OutlinedButton.icon(
                onPressed: () => setState(() => _bookmarked = !_bookmarked),
                icon: Icon(
                  _bookmarked ? Icons.bookmark : Icons.bookmark_border,
                ),
                label: Text(_bookmarked ? '保存済み' : 'ブックマーク'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.8),
                ),
              );
              final rating = FilledButton.icon(
                onPressed: _showRatingDialog,
                icon: const Icon(Icons.star),
                label: Text(_overallRating == null ? '評価する' : '評価しました！'),
              );
              return narrow
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [bookmark, const SizedBox(height: 8), rating],
                    )
                  : Row(
                      children: [
                        Expanded(child: bookmark),
                        const SizedBox(width: 12),
                        Expanded(child: rating),
                      ],
                    );
            },
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _openMap(context),
            icon: const Icon(Icons.map),
            label: const Text('地図で開く'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRatingDialog() async {
    final lastVoteAt = _lastVoteAt;
    if (lastVoteAt != null) {
      final elapsed = DateTime.now().difference(lastVoteAt);
      const cooldown = Duration(seconds: 30);
      if (elapsed < cooldown) {
        return;
      }
    }
    final selectedConditions = widget.conditions.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .where(_conditionLabels.containsKey)
        .toList(growable: false);
    final ratings =
        await showDialog<({int overall, Map<String, int> accuracy})>(
      context: context,
      builder: (context) {
        var overall = _overallRating ?? 0;
        final accuracy = <String, int>{
          for (final condition in selectedConditions)
            condition: _conditionRatings[condition] ?? 0,
        };
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: Colors.black,
            titleTextStyle: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            title: const Text('Vote'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RatingRow(
                    label: '店の総合評価',
                    value: overall,
                    onChanged: (value) => setDialogState(() => overall = value),
                  ),
                  if (selectedConditions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        '追加した検索条件はありません。',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  else
                    for (final condition in selectedConditions) ...[
                      const SizedBox(height: 16),
                      _RatingRow(
                        label: _conditionLabels[condition]!,
                        description: _conditionCriteria[condition]!,
                        value: accuracy[condition]!,
                        onChanged: (value) =>
                            setDialogState(() => accuracy[condition] = value),
                      ),
                    ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed:
                    overall == 0 || accuracy.values.any((rating) => rating == 0)
                        ? null
                        : () => Navigator.pop(
                              context,
                              (overall: overall, accuracy: Map.of(accuracy)),
                            ),
                child: const Text('投票する'),
              ),
            ],
          ),
        );
      },
    );
    if (ratings != null && mounted) {
      setState(() {
        _lastVoteAt = DateTime.now();
        _overallRating = ratings.overall;
        _conditionRatings
          ..clear()
          ..addAll(ratings.accuracy);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('評価を投票しました。')),
      );
    }
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({
    required this.label,
    this.description,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String? description;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white)),
        if (description != null)
          Text(
            description!,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var star = 1; star <= 5; star++)
              IconButton(
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.symmetric(horizontal: 3),
                tooltip: '$starつ星',
                icon: Icon(
                  star <= value ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                ),
                onPressed: () => onChanged(star),
              ),
          ],
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ]),
      );
}
