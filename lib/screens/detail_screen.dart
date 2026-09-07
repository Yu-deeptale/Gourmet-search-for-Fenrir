import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/shop.dart';

class DetailScreen extends StatelessWidget {
  const DetailScreen({required this.shop, super.key});
  final Shop shop;

  Future<void> _openMap(BuildContext context) async {
    final uri = shop.lat != null && shop.lng != null
        ? Uri.parse('https://www.google.com/maps/search/?api=1&query=${shop.lat},${shop.lng}')
        : Uri.tryParse(shop.mapUrl);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('地図を開けませんでした。')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(shop.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (shop.photoUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: shop.photoUrl,
              height: 220,
              fit: BoxFit.cover,
              placeholder: (_, __) => const SizedBox(height: 220, child: Center(child: CircularProgressIndicator())),
              errorWidget: (_, __, ___) => const SizedBox(height: 220, child: Icon(Icons.restaurant, size: 64)),
            ),
          const SizedBox(height: 16),
          Text(shop.name, style: Theme.of(context).textTheme.headlineSmall),
          if (shop.catchPhrase.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(shop.catchPhrase),
          ],
          const Divider(height: 32),
          _InfoRow(icon: Icons.location_on, text: shop.address),
          if (shop.access.isNotEmpty) _InfoRow(icon: Icons.train, text: shop.access),
          if (shop.budget.isNotEmpty) _InfoRow(icon: Icons.payments, text: shop.budget),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _openMap(context),
            icon: const Icon(Icons.map),
            label: const Text('地図で開く'),
          ),
        ],
      ),
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
