class PreGrtMemberModel {
  final int id;
  final int pregrtId;
  final int sno;
  final int? customerId;
  final String name;
  final String husbandName;
  final int age;
  final String voterId;
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
    required this.voterId,
    this.aadhaar4 = '',
    this.familyInGroup = 'no',
    this.houseType = 'pucca',
    this.landHa = 0.0,
    this.livestock = '',
    this.annualIncome = 180000.0,
    this.familySize = 4,
    this.category = 'OBC',
    required this.loanAmount,
    required this.purpose,
    this.frequency = 'monthly',
    this.instalments = 12,
    this.cMeeting = 1,
    this.cJoint = 1,
    this.cFee = 1,
    this.cRate = 1,
    this.cInsurance = 1,
    this.cCompany = 1,
    this.cGroup = 1,
  });

  factory PreGrtMemberModel.fromMap(Map<String, dynamic> map) {
    return PreGrtMemberModel(
      id: map['id'] as int,
      pregrtId: map['pregrt_id'] as int,
      sno: (map['sno'] as int?) ?? 1,
      customerId: map['customer_id'] as int?,
      name: map['name'] as String,
      husbandName: (map['husband_name'] ?? '') as String,
      age: (map['age'] as int?) ?? 30,
      voterId: (map['voter_id'] ?? '') as String,
      aadhaar4: (map['aadhaar4'] ?? '') as String,
      familyInGroup: (map['family_in_group'] ?? 'no') as String,
      houseType: (map['house_type'] ?? 'pucca') as String,
      landHa: (map['land_ha'] as num?)?.toDouble() ?? 0.0,
      livestock: (map['livestock'] ?? '') as String,
      annualIncome: (map['annual_income'] as num?)?.toDouble() ?? 180000.0,
      familySize: (map['family_size'] as int?) ?? 4,
      category: (map['category'] ?? 'OBC') as String,
      loanAmount: (map['loan_amount'] as num?)?.toDouble() ?? 20000.0,
      purpose: (map['purpose'] ?? '') as String,
      frequency: (map['frequency'] ?? 'monthly') as String,
      instalments: (map['instalments'] as int?) ?? 12,
      cMeeting: (map['c_meeting'] as int?) ?? 1,
      cJoint: (map['c_joint'] as int?) ?? 1,
      cFee: (map['c_fee'] as int?) ?? 1,
      cRate: (map['c_rate'] as int?) ?? 1,
      cInsurance: (map['c_insurance'] as int?) ?? 1,
      cCompany: (map['c_company'] as int?) ?? 1,
      cGroup: (map['c_group'] as int?) ?? 1,
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

  factory PreGrtModel.fromMap(Map<String, dynamic> map, {List<PreGrtMemberModel> members = const []}) {
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
      agentId: (map['agent_id'] as int?) ?? 1,
      status: (map['status'] ?? 'draft') as String,
      createdAt: (map['created_at'] ?? '') as String,
      verifiedBy: map['verified_by'] as String?,
      verifiedOn: map['verified_on'] as String?,
      reviewRemarks: map['review_remarks'] as String?,
      members: members,
    );
  }
}
