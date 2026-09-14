import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/shop.dart';

class HotPepperApiException implements Exception {
  const HotPepperApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class HotPepperApi {
  HotPepperApi({http.Client? client}) : _client = client ?? http.Client();

  static const _endpoint =
      'https://webservice.recruit.co.jp/hotpepper/gourmet/v1/';
  final http.Client _client;

  Future<List<Shop>> search({
    String? keyword,
    String? genre,
    int range = 3,
    double? latitude,
    double? longitude,
    String? prefectureCode,
    String? cityCode,
    Map<String, bool> conditions = const {},
  }) async {
    final apiKey = dotenv.isInitialized
        ? dotenv.env['HOTPEPPER_API_KEY']?.trim() ?? ''
        : '';
    if (apiKey.isEmpty) {
      throw const HotPepperApiException(
        'APIキーが設定されていません。.env に HOTPEPPER_API_KEY を設定してください。',
      );
    }
    final parameters = <String, String>{
      'key': apiKey,
      'format': 'json',
      'count': '50',
      'range': '$range',
    };
    if (keyword != null && keyword.trim().isNotEmpty) {
      parameters['keyword'] = keyword.trim();
    }
    if (genre != null && genre.trim().isNotEmpty) {
      parameters['genre'] = genre.trim();
    }
    if (prefectureCode != null && prefectureCode.isNotEmpty) {
      parameters['prefecture'] = prefectureCode;
    }
    if (cityCode != null && cityCode.isNotEmpty) {
      parameters['city'] = cityCode;
    }
    for (final entry in conditions.entries) {
      if (entry.value) parameters[entry.key] = 'Y';
    }
    if (latitude != null && longitude != null) {
      parameters['lat'] = '$latitude';
      parameters['lng'] = '$longitude';
    }

    final response = await _client
        .get(Uri.parse(_endpoint).replace(queryParameters: parameters));
    if (response.statusCode != 200) {
      throw HotPepperApiException('API通信に失敗しました（${response.statusCode}）。');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final results = decoded['results'] as Map<String, dynamic>? ?? {};
    final shops = results['shop'] as List<dynamic>? ?? const [];
    return shops
        .whereType<Map<String, dynamic>>()
        .map(Shop.fromJson)
        .toList(growable: false);
  }

  void dispose() => _client.close();
}
