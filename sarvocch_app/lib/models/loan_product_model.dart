class LoanProductModel {
  final int id;
  final String name;
  final double rate;
  final double minAmt;
  final double maxAmt;
  final int minTenure;
  final int maxTenure;
  final String method; // 'reducing' or 'flat'
  final double feePct;
  final int active;

  LoanProductModel({
    required this.id,
    required this.name,
    required this.rate,
    required this.minAmt,
    required this.maxAmt,
    required this.minTenure,
    required this.maxTenure,
    required this.method,
    required this.feePct,
    this.active = 1,
  });

  factory LoanProductModel.fromMap(Map<String, dynamic> map) {
    return LoanProductModel(
      id: map['id'] as int,
      name: map['name'] as String,
      rate: (map['rate'] as num).toDouble(),
      minAmt: (map['min_amt'] as num).toDouble(),
      maxAmt: (map['max_amt'] as num).toDouble(),
      minTenure: (map['min_tenure'] as int?) ?? 6,
      maxTenure: (map['max_tenure'] as int?) ?? 24,
      method: (map['method'] ?? 'reducing') as String,
      feePct: (map['fee_pct'] as num).toDouble(),
      active: (map['active'] as int?) ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'rate': rate,
      'min_amt': minAmt,
      'max_amt': maxAmt,
      'min_tenure': minTenure,
      'max_tenure': maxTenure,
      'method': method,
      'fee_pct': feePct,
      'active': active,
    };
  }
}
