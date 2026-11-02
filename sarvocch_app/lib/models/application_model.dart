class ApprovalLogModel {
  final int id;
  final int applicationId;
  final String stage; // Submitted, Under Review, Approved, Sanctioned, Disbursed, Rejected
  final String byUser;
  final String byRole;
  final double amount;
  final String remarks;
  final String at;

  ApprovalLogModel({
    required this.id,
    required this.applicationId,
    required this.stage,
    required this.byUser,
    required this.byRole,
    required this.amount,
    required this.remarks,
    required this.at,
  });

  factory ApprovalLogModel.fromMap(Map<String, dynamic> map) {
    return ApprovalLogModel(
      id: map['id'] as int,
      applicationId: map['application_id'] as int,
      stage: map['stage'] as String,
      byUser: (map['by_user'] ?? '') as String,
      byRole: (map['by_role'] ?? '') as String,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      remarks: (map['remarks'] ?? '') as String,
      at: (map['at'] ?? '') as String,
    );
  }
}

class ApplicationModel {
  final int id;
  final int customerId;
  final int productId;
  final double amount;
  final int tenure;
  final double rate;
  final String purpose;
  final double income;
  final String occupation;
  final String? employer;
  final String? coName;
  final String? coPhone;
  final String? coRelation;
  final double? coIncome;
  final String status; // submitted, under_review, approved, sanctioned, disbursed, rejected
  final int agentId;
  final String branch;
  final String created;
  final String? remarks;
  final String? docs;

  // Joined fields for easy display
  final String? customerName;
  final String? customerPhone;
  final String? productName;

  // Cash flow & Risk Analysis
  final double? incomeTotal;
  final double? expenseTotal;
  final double? netSaving;
  final double? emiEstimated;

  ApplicationModel({
    required this.id,
    required this.customerId,
    required this.productId,
    required this.amount,
    required this.tenure,
    required this.rate,
    required this.purpose,
    required this.income,
    required this.occupation,
    this.employer,
    this.coName,
    this.coPhone,
    this.coRelation,
    this.coIncome,
    required this.status,
    required this.agentId,
    required this.branch,
    required this.created,
    this.remarks,
    this.docs,
    this.customerName,
    this.customerPhone,
    this.productName,
    this.incomeTotal,
    this.expenseTotal,
    this.netSaving,
    this.emiEstimated,
  });

  factory ApplicationModel.fromMap(Map<String, dynamic> map) {
    return ApplicationModel(
      id: map['id'] as int,
      customerId: map['customer_id'] as int,
      productId: map['product_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      tenure: map['tenure'] as int,
      rate: (map['rate'] as num).toDouble(),
      purpose: (map['purpose'] ?? '') as String,
      income: (map['income'] as num?)?.toDouble() ?? 0.0,
      occupation: (map['occupation'] ?? '') as String,
      employer: map['employer'] as String?,
      coName: map['co_name'] as String?,
      coPhone: map['co_phone'] as String?,
      coRelation: map['co_relation'] as String?,
      coIncome: (map['co_income'] as num?)?.toDouble(),
      status: (map['status'] ?? 'submitted') as String,
      agentId: (map['agent_id'] as int?) ?? 1,
      branch: (map['branch'] ?? '') as String,
      created: (map['created'] ?? '') as String,
      remarks: map['remarks'] as String?,
      docs: map['docs'] as String?,
      customerName: map['customer_name'] as String?,
      customerPhone: map['customer_phone'] as String?,
      productName: map['product_name'] as String?,
      incomeTotal: (map['income_total'] as num?)?.toDouble(),
      expenseTotal: (map['expense_total'] as num?)?.toDouble(),
      netSaving: (map['net_saving'] as num?)?.toDouble(),
      emiEstimated: (map['emi_estimated'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'product_id': productId,
      'amount': amount,
      'tenure': tenure,
      'rate': rate,
      'purpose': purpose,
      'income': income,
      'occupation': occupation,
      'employer': employer,
      'co_name': coName,
      'co_phone': coPhone,
      'co_relation': coRelation,
      'co_income': coIncome,
      'status': status,
      'agent_id': agentId,
      'branch': branch,
      'created': created,
      'remarks': remarks,
      'docs': docs,
    };
  }

  String get statusDisplay {
    switch (status) {
      case 'submitted':
        return 'Submitted';
      case 'under_review':
        return 'Under Review';
      case 'approved':
        return 'Approved';
      case 'sanctioned':
        return 'Sanctioned';
      case 'disbursed':
        return 'Disbursed';
      case 'rejected':
        return 'Rejected';
      default:
        return status.toUpperCase();
    }
  }
}
