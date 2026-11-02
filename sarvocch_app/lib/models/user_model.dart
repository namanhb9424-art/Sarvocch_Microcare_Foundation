class UserModel {
  final int id;
  final String username;
  final String name;
  final String role; // admin, manager, underwriter, field_agent, customer
  final String branch;
  final String phone;
  final int? customerId;
  final double? lat;
  final double? lng;
  final String? designation;

  UserModel({
    required this.id,
    required this.username,
    required this.name,
    required this.role,
    required this.branch,
    required this.phone,
    this.customerId,
    this.lat,
    this.lng,
    this.designation,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as int,
      username: map['username'] as String,
      name: map['name'] as String,
      role: map['role'] as String,
      branch: (map['branch'] ?? '') as String,
      phone: (map['phone'] ?? '') as String,
      customerId: map['customer_id'] as int?,
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      designation: map['designation'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'name': name,
      'role': role,
      'branch': branch,
      'phone': phone,
      'customer_id': customerId,
      'lat': lat,
      'lng': lng,
    };
  }

  String get roleDisplay {
    switch (role) {
      case 'admin':
        return 'Administrator';
      case 'manager':
        return 'Branch Manager';
      case 'underwriter':
        return 'Credit Underwriter';
      case 'field_agent':
        return 'Field Officer / PSO';
      case 'customer':
        return 'Borrower / Customer';
      default:
        return role.toUpperCase();
    }
  }

  bool can(String module) {
    if (role == 'admin') return true;

    const managerPerms = {
      'dashboard', 'crm', 'kyc', 'apply', 'applications', 'approve',
      'disburse', 'loans', 'payments', 'field', 'employees', 'hrm',
      'whatsapp', 'sync', 'calculator', 'products', 'kycform', 'pregrt', 'attendance'
    };
    const underwriterPerms = {
      'dashboard', 'crm', 'kyc', 'applications', 'approve', 'loans',
      'calculator', 'pregrt', 'attendance'
    };
    const fieldAgentPerms = {
      'crm', 'kyc', 'apply', 'applications', 'field', 'sync',
      'calculator', 'whatsapp', 'payments', 'kycform', 'pregrt', 'attendance'
    };
    const customerPerms = {'portal', 'payments', 'calculator'};

    switch (role) {
      case 'manager':
        return managerPerms.contains(module);
      case 'underwriter':
        return underwriterPerms.contains(module);
      case 'field_agent':
        return fieldAgentPerms.contains(module);
      case 'customer':
        return customerPerms.contains(module);
      default:
        return false;
    }
  }
}
