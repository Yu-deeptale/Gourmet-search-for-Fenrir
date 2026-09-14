import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

import '../services/hotpepper_api.dart';
import 'result_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _keywordController = TextEditingController();
  final _api = HotPepperApi();
  Position? _position;
  String? _currentLocation;
  String? _selectedRegion;
  String? _selectedPrefecture;
  String? _selectedCityCode;
  int _range = 3;
  bool _locating = false;
  bool _useCurrentLocation = true;
  final _conditions = <String, bool>{
    'wifi': false,
    'free_drink': false,
    'free_food': false,
    'private_room': false,
    'tatami': false,
    'card': false,
    'barrier_free': false,
    'night_view': false,
    'karaoke': false,
    'lunch': false,
    'midnight': false,
    'pet': false,
    'child': false,
  };
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
  List<Map<String, String>> _prefectures = const [];
  Map<String, List<Map<String, String>>> _citiesByPrefecture = const {};
  Map<String, Map<String, double>> _coordinatesByCityCode = const {};

  static const _inputFillColor = Color(0xFFF3F3F3);
  static const _inputTextColor = Color(0xFF013C17);
  static const _inputWidth = 300.0;
  static const _prefectureCodesByRegion = <String, List<String>>{
    '北海道': ['01'],
    '東北': ['02', '03', '04', '05', '06', '07'],
    '関東': ['08', '09', '10', '11', '12', '13', '14'],
    '中部': ['15', '16', '17', '18', '19', '20', '21', '22', '23'],
    '近畿': ['24', '25', '26', '27', '28', '29', '30'],
    '中国': ['31', '32', '33', '34', '35'],
    '四国': ['36', '37', '38', '39'],
    '九州・沖縄': ['40', '41', '42', '43', '44', '45', '46', '47'],
  };
  @override
  void dispose() {
    _keywordController.dispose();
    _api.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadLocationMasters();
  }

  Future<void> _loadLocationMasters() async {
    final prefectureJson =
        await rootBundle.loadString('assets/master/prefectures.json');
    final cityJson = await rootBundle.loadString('assets/master/cities.json');
    final coordinateJson =
        await rootBundle.loadString('assets/master/city_coordinates.json');
    final prefectures = (jsonDecode(prefectureJson) as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map((item) => {
              'code': item['code'] as String,
              'name': item['name'] as String,
            })
        .toList(growable: false);
    final cities = (jsonDecode(cityJson) as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map((item) => {
              'prefCode': item['prefCode'] as String,
              'cityCode': item['cityCode'] as String,
              'name': item['name'] as String,
            })
        .toList(growable: false);
    final coordinates = (jsonDecode(coordinateJson) as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map((item) => {
              'cityCode': item['cityCode'] as String,
              'latitude': (item['latitude'] as num).toDouble(),
              'longitude': (item['longitude'] as num).toDouble(),
            });
    final citiesByPrefecture = <String, List<Map<String, String>>>{};
    for (final city in cities) {
      citiesByPrefecture.putIfAbsent(city['prefCode']!, () => []).add(city);
    }
    if (mounted) {
      setState(() {
        _prefectures = prefectures;
        _citiesByPrefecture = citiesByPrefecture;
        _coordinatesByCityCode = {
          for (final coordinate in coordinates)
            coordinate['cityCode'] as String: {
              'latitude': coordinate['latitude'] as double,
              'longitude': coordinate['longitude'] as double,
            },
        };
      });
    }
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
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      final placemark = placemarks.isEmpty ? null : placemarks.first;
      final location = placemark == null
          ? null
          : [
              placemark.administrativeArea,
              placemark.locality ?? placemark.subAdministrativeArea,
            ].whereType<String>().where((value) => value.isNotEmpty).join(':');
      if (mounted) {
        setState(() {
          _position = position;
          _currentLocation =
              location == null || location.isEmpty ? '現在地を取得済み' : location;
        });
        _showMessage('現在地を取得しました。');
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _search() async {
    Position? position = _useCurrentLocation ? _position : null;
    if (_useCurrentLocation && position == null) {
      _showMessage('位置情報が指定されていません');
      return;
    }
    if (!_useCurrentLocation) {
      final cityCode = _selectedCityCode;
      if (_selectedRegion == null ||
          _selectedPrefecture == null ||
          cityCode == null ||
          cityCode.isEmpty) {
        _showMessage('地方、都道府県、市区を選択してください。');
        return;
      }
      final coordinates = _coordinatesByCityCode[cityCode];
      if (coordinates == null) {
        _showMessage('選択した市町村の位置情報がありません。');
        return;
      }
      position = Position(
        latitude: coordinates['latitude']!,
        longitude: coordinates['longitude']!,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          api: _api,
          keyword: _keywordController.text,
          range: _range,
          position: position,
          prefectureCode: null,
          cityCode: null,
          conditions: _conditions,
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showLocationDialog() async {
    String? selectedRegion = _selectedRegion;
    String? selectedPrefecture = _selectedPrefecture;
    String? selectedCityCode = _selectedCityCode;

    Future<String?> choose(
      BuildContext dialogContext,
      String title,
      List<DropdownMenuEntry<String>> entries,
    ) {
      return showDialog<String>(
        context: dialogContext,
        builder: (context) => SimpleDialog(
          title: Text(title),
          children: entries
              .map(
                (entry) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, entry.value),
                  child: Text(entry.label),
                ),
              )
              .toList(growable: false),
        ),
      );
    }

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                readOnly: true,
                controller: TextEditingController(
                  text: selectedRegion ?? '',
                ),
                decoration: const InputDecoration(labelText: '地方'),
                onTap: () async {
                  final value = await choose(
                    context,
                    '地方を選択',
                    _prefectureCodesByRegion.keys
                        .map((region) => DropdownMenuEntry(
                              value: region,
                              label: region,
                            ))
                        .toList(growable: false),
                  );
                  if (value != null) {
                    setDialogState(() {
                      selectedRegion = value;
                      selectedPrefecture = null;
                      selectedCityCode = null;
                    });
                  }
                },
              ),
              TextField(
                readOnly: true,
                controller: TextEditingController(
                  text: _prefectures
                      .where((item) => item['code'] == selectedPrefecture)
                      .map((item) => item['name'])
                      .firstOrNull,
                ),
                decoration: const InputDecoration(labelText: '都道府県'),
                onTap: selectedRegion == null
                    ? null
                    : () async {
                        final value = await choose(
                          context,
                          '都道府県を選択',
                          _prefectures
                              .where((prefecture) =>
                                  _prefectureCodesByRegion[selectedRegion]
                                      ?.contains(prefecture['code']) ??
                                  false)
                              .map((prefecture) => DropdownMenuEntry(
                                    value: prefecture['code']!,
                                    label: prefecture['name']!,
                                  ))
                              .toList(growable: false),
                        );
                        if (value != null) {
                          setDialogState(() {
                            selectedPrefecture = value;
                            selectedCityCode = null;
                          });
                        }
                      },
              ),
              TextField(
                readOnly: true,
                controller: TextEditingController(
                  text: (_citiesByPrefecture[selectedPrefecture] ?? [])
                      .where((city) => city['cityCode'] == selectedCityCode)
                      .map((city) => city['name'])
                      .firstOrNull,
                ),
                decoration: const InputDecoration(labelText: '市区'),
                onTap: selectedPrefecture == null
                    ? null
                    : () async {
                        final value = await choose(
                          context,
                          '市区を選択',
                          (_citiesByPrefecture[selectedPrefecture] ?? [])
                              .map((city) => DropdownMenuEntry(
                                    value: city['cityCode']!,
                                    label: city['name']!,
                                  ))
                              .toList(growable: false),
                        );
                        if (value != null) {
                          setDialogState(() => selectedCityCode = value);
                        }
                      },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: selectedCityCode == null
                  ? null
                  : () {
                      setState(() {
                        _selectedRegion = selectedRegion;
                        _selectedPrefecture = selectedPrefecture;
                        _selectedCityCode = selectedCityCode;
                      });
                      Navigator.pop(context);
                    },
              child: const Text('適用'),
            ),
          ],
        ),
      ),
    );
  }

  String get _selectedLocationLabel {
    final prefecture = _prefectures
        .where((item) => item['code'] == _selectedPrefecture)
        .map((item) => item['name'])
        .firstOrNull;
    final city = (_citiesByPrefecture[_selectedPrefecture] ?? [])
        .where((item) => item['cityCode'] == _selectedCityCode)
        .map((item) => item['name'])
        .firstOrNull;
    if (_selectedRegion == null || prefecture == null || city == null) {
      return '地方・都道府県・市区を選択';
    }
    return '$_selectedRegion・$prefecture・$city';
  }

  Future<void> _showConditionDialog() async {
    final draft = Map<String, bool>.from(_conditions);
    const groups = <String, List<String>>{
      '設備・空間': ['wifi', 'private_room', 'tatami', 'barrier_free'],
      '飲食サービス': ['free_drink', 'free_food', 'lunch', 'midnight'],
      'エンタメ': ['night_view', 'karaoke'],
      '支払い・家族向け': ['card', 'pet', 'child'],
    };
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            content: SizedBox(
              width: _inputWidth,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: groups.entries.map((group) {
                    return Column(
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
                          alignment: WrapAlignment.start,
                          spacing: 8,
                          runSpacing: 4,
                          children: group.value.map((condition) {
                            return FilterChip(
                              label: Text(_conditionLabels[condition]!),
                              selected: draft[condition]!,
                              showCheckmark: false,
                              selectedColor:
                                  const Color.fromARGB(255, 0, 197, 69),
                              onSelected: (selected) => setDialogState(
                                () => draft[condition] = selected,
                              ),
                            );
                          }).toList(growable: false),
                        ),
                      ],
                    );
                  }).toList(growable: false),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () {
                  setState(() => _conditions
                    ..clear()
                    ..addAll(draft));
                  Navigator.of(context).pop();
                },
                child: const Text('適用'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF38EF7D),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(20),
          children: [
            Transform.translate(
              offset: const Offset(0, -50),
              child: const Text(
                'Gourmet Vote',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Jua',
                  fontSize: 50,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: SizedBox(
                width: _inputWidth,
                child: TextField(
                  controller: _keywordController,
                  textAlign: TextAlign.left,
                  style: const TextStyle(color: _inputTextColor),
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: _inputFillColor,
                    labelText: 'キーワード',
                    hintText: '店名、料理名、エリアなど',
                    border: OutlineInputBorder(
                      borderSide: BorderSide(width: 5, color: Colors.black),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: SizedBox(
                width: _inputWidth,
                child: GestureDetector(
                  onTap: _showConditionDialog,
                  child: const InputDecorator(
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: _inputFillColor,
                      labelText: '条件絞り込み',
                      border: OutlineInputBorder(),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('選択してください'),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: SizedBox(
                width: _inputWidth,
                child: DropdownMenu<int>(
                  initialSelection: _range,
                  expandedInsets: EdgeInsets.zero,
                  label: const Text('検索範囲'),
                  textStyle: const TextStyle(color: _inputTextColor),
                  inputDecorationTheme: const InputDecorationTheme(
                    filled: true,
                    fillColor: _inputFillColor,
                  ),
                  dropdownMenuEntries: const [
                    DropdownMenuEntry(value: 1, label: '500m以内'),
                    DropdownMenuEntry(value: 2, label: '1km以内'),
                    DropdownMenuEntry(value: 3, label: '3km以内'),
                    DropdownMenuEntry(value: 4, label: '5km以内'),
                  ],
                  onSelected: (value) => setState(() => _range = value ?? 3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: SizedBox(
                width: _inputWidth,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('現在地を使用'),
                  value: _useCurrentLocation,
                  onChanged: (value) =>
                      setState(() => _useCurrentLocation = value),
                ),
              ),
            ),
            if (!_useCurrentLocation) ...[
              Center(
                child: SizedBox(
                  width: _inputWidth,
                  child: GestureDetector(
                    onTap: _showLocationDialog,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: _inputFillColor,
                        labelText: '検索地点',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        _selectedLocationLabel,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (_useCurrentLocation) ...[
              const SizedBox(height: 16),
              Center(
                child: SizedBox(
                  width: _inputWidth,
                  child: OutlinedButton.icon(
                    onPressed: _locating ? null : _getLocation,
                    icon: _locating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: Text(_currentLocation ?? '現在地を取得'),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 40),
            Center(
              child: SizedBox(
                width: _inputWidth,
                child: FilledButton.icon(
                  onPressed: _search,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(60),
                  ),
                  icon: const Icon(Icons.search, size: 28),
                  label: const Text(
                    '検索する',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
