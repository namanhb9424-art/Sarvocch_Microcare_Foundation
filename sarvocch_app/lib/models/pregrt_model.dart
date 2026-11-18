import '../services/currency_amount.dart';

class PreGrtMemberModel {
  final int id;
  final int pregrtId;
  final int sno;
  final int? customerId;
  final String name;
  final String husbandName;
  final int age;
  final String voterIdLast4;
  final String aadhaar4;
  final String familyInGroup;
  final String houseType;
  final double landHa;
  final String livestock;
  final double annualIncome;
  final int familySize;
  final String category;
  final double loanAmount;
  final String purpose;
  final String frequency;
  final int instalments;
  final int cMeeting;
  final int cJoint;
  final int cFee;
  final int cRate;
  final int cInsurance;
  final int cCompany;
  final int cGroup;

  PreGrtMemberModel({
    required this.id,
    required this.pregrtId,
    required this.sno,
    this.customerId,
    required this.name,
    required this.husbandName,
    required this.age,
    required this.voterIdLast4,
    this.aadhaar4 = '',
    this.familyInGroup = 'no',
    this.houseType = '',
    this.landHa = 0.0,
    this.livestock = '',
    this.annualIncome = 0.0,
    this.familySize = 0,
    this.category = '',
    required this.loanAmount,
    required this.purpose,
    this.frequency = 'monthly',
    this.instalments = 0,
    this.cMeeting = 0,
    this.cJoint = 0,
    this.cFee = 0,
    this.cRate = 0,
    this.cInsurance = 0,
    this.cCompany = 0,
    this.cGroup = 0,
  });

  factory PreGrtMemberModel.fromMap(Map<String, dynamic> map) {
    return PreGrtMemberModel(
      id: map['id'] as int,
      pregrtId: map['pregrt_id'] as int,
      sno: (map['sno'] as int?) ?? 0,
      customerId: map['customer_id'] as int?,
      name: map['name'] as String,
      husbandName: (map['husband_name'] ?? '') as String,
      age: (map['age'] as int?) ?? 0,
      voterIdLast4: _lastFour(map['voter_id']?.toString() ?? ''),
      aadhaar4: (map['aadhaar4'] ?? '') as String,
      familyInGroup: (map['family_in_group'] ?? 'no') as String,
      houseType: (map['house_type'] ?? '') as String,
      landHa: (map['land_ha'] as num?)?.toDouble() ?? 0.0,
      livestock: (map['livestock'] ?? '') as String,
      annualIncome: map['annual_income_paise'] is num
          ? CurrencyAmount.readStoredValue(
              map,
              'annual_income_paise',
              'annual_income',
            )
          : (map['annual_income'] as num?)?.toDouble() ?? 0.0,
      familySize: (map['family_size'] as int?) ?? 0,
      category: (map['category'] ?? '') as String,
      loanAmount: map['loan_amount_paise'] is num
          ? CurrencyAmount.readStoredValue(
              map,
              'loan_amount_paise',
              'loan_amount',
            )
          : (map['loan_amount'] as num?)?.toDouble() ?? 0.0,
      purpose: (map['purpose'] ?? '') as String,
      frequency: (map['frequency'] ?? '') as String,
      instalments: (map['instalments'] as int?) ?? 0,
      cMeeting: (map['c_meeting'] as int?) ?? 0,
      cJoint: (map['c_joint'] as int?) ?? 0,
      cFee: (map['c_fee'] as int?) ?? 0,
      cRate: (map['c_rate'] as int?) ?? 0,
      cInsurance: (map['c_insurance'] as int?) ?? 0,
      cCompany: (map['c_company'] as int?) ?? 0,
      cGroup: (map['c_group'] as int?) ?? 0,
    );
  }

  static String _lastFour(String value) {
    final normalized = value.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    return normalized.substring(
      normalized.length > 4 ? normalized.length - 4 : 0,
    );
  }

  bool get allCgtPassed =>
      cMeeting == 1 &&
      cJoint == 1 &&
      cFee == 1 &&
      cRate == 1 &&
      cInsurance == 1 &&
      cCompany == 1 &&
      cGroup == 1;
}

class PreGrtModel {
  final int id;
  final String branch;
  final String centerNo;
  final String groupNo;
  final String village;
  final String district;
  final String formDate;
  final String psoName;
  final String psoEmpid;
  final String bmName;
  final String bmEmpid;
  final String leaderKnowsDuties;
  final String notes;
  final int agentId;
  final String status; // draft, submitted, verified, returned
  final String createdAt;
  final String? verifiedBy;
  final String? verifiedOn;
  final String? reviewRemarks;
  final List<PreGrtMemberModel> members;

  PreGrtModel({
    required this.id,
    required this.branch,
    required this.centerNo,
    required this.groupNo,
    required this.village,
    required this.district,
    required this.formDate,
    required this.psoName,
    required this.psoEmpid,
    required this.bmName,
    required this.bmEmpid,
    required this.leaderKnowsDuties,
    required this.notes,
    required this.agentId,
    required this.status,
    required this.createdAt,
    this.verifiedBy,
    this.verifiedOn,
    this.reviewRemarks,
    this.members = const [],
  });

  factory PreGrtModel.fromMap(
    Map<String, dynamic> map, {
    List<PreGrtMemberModel> members = const [],
  }) {
    return PreGrtModel(
      id: map['id'] as int,
      branch: (map['branch'] ?? '') as String,
      centerNo: (map['center_no'] ?? '') as String,
      groupNo: (map['group_no'] ?? '') as String,
      village: (map['village'] ?? '') as String,
      district: (map['district'] ?? '') as String,
      formDate: (map['form_date'] ?? '') as String,
      psoName: (map['pso_name'] ?? '') as String,
      psoEmpid: (map['pso_empid'] ?? '') as String,
      bmName: (map['bm_name'] ?? '') as String,
      bmEmpid: (map['bm_empid'] ?? '') as String,
      leaderKnowsDuties: (map['leader_knows_duties'] ?? 'yes') as String,
      notes: (map['notes'] ?? '') as String,
      agentId: (map['agent_id'] as int?) ?? 0,
      status: (map['status'] ?? 'draft') as String,
      createdAt: (map['created_at'] ?? '') as String,
      verifiedBy: map['verified_by'] as String?,
      verifiedOn: map['verified_on'] as String?,
      reviewRemarks: map['review_remarks'] as String?,
      members: members,
    );
  }
}
