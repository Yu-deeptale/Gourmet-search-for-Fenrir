class Shop {
  const Shop({
    required this.id,
    required this.name,
    required this.address,
    required this.access,
    required this.catchPhrase,
    required this.budget,
    required this.photoUrl,
    required this.lat,
    required this.lng,
    required this.mapUrl,
  });

  final String id;
  final String name;
  final String address;
  final String access;
  final String catchPhrase;
  final String budget;
  final String photoUrl;
  final double? lat;
  final double? lng;
  final String mapUrl;

  factory Shop.fromJson(Map<String, dynamic> json) {
    final photo = json['photo'] as Map<String, dynamic>? ?? {};
    final urls = photo['pc'] as Map<String, dynamic>? ?? {};
    final lat = double.tryParse('${json['lat'] ?? ''}');
    final lng = double.tryParse('${json['lng'] ?? ''}');
    return Shop(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? '店舗名不明'}',
      address: '${json['address'] ?? '住所不明'}',
      access: '${json['access'] ?? ''}',
      catchPhrase: '${json['catch'] ?? ''}',
      budget: (json['budget'] as Map<String, dynamic>?)?['name']?.toString() ?? '',
      photoUrl: '${urls['l'] ?? urls['m'] ?? ''}',
      lat: lat,
      lng: lng,
      mapUrl: '${json['urls']?['pc'] ?? ''}',
    );
  }
}
