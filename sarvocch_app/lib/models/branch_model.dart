class BranchModel {
  final int id;
  final String name;
  final String code;
  final String address;
  final String phone;
  final String headName;
  final double lat;
  final double lng;
  final int radiusM;
  final int active;

  BranchModel({
    required this.id,
    required this.name,
    required this.code,
    required this.address,
    required this.phone,
    required this.headName,
    required this.lat,
    required this.lng,
    this.radiusM = 2000,
    this.active = 1,
  });

  factory BranchModel.fromMap(Map<String, dynamic> map) {
    return BranchModel(
      id: map['id'] as int,
      name: map['name'] as String,
      code: (map['code'] ?? '') as String,
      address: (map['address'] ?? '') as String,
      phone: (map['phone'] ?? '') as String,
      headName: (map['head_name'] ?? '') as String,
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      radiusM: (map['radius_m'] as int?) ?? 2000,
      active: (map['active'] as int?) ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'address': address,
      'phone': phone,
      'head_name': headName,
      'lat': lat,
      'lng': lng,
      'radius_m': radiusM,
      'active': active,
    };
  }
}
