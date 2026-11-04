class CommLogModel {
  final int id;
  final int customerId;
  final String channel; // call, visit, whatsapp, sms
  final String note;
  final String byName;
  final String at;

  CommLogModel({
    required this.id,
    required this.customerId,
    required this.channel,
    required this.note,
    required this.byName,
    required this.at,
  });

  factory CommLogModel.fromMap(Map<String, dynamic> map) {
    return CommLogModel(
      id: map['id'] as int,
      customerId: map['customer_id'] as int,
      channel: (map['channel'] ?? 'call') as String,
      note: (map['note'] ?? '') as String,
      byName: (map['by_name'] ?? '') as String,
      at: (map['at'] ?? '') as String,
    );
  }
}

class CustomerModel {
  final int id;
  final String name;
  final String phone;
  final String dob;
  final String address;
  final String branch;
  final int agentId;
  final String stage; // lead, prospect, customer
  final String? aadhaar;
  final String? pan;
  final String? voter;
  final String kycStatus; // pending, verified, rejected
  final int waVerified;
  final String created;

  // Optional embedded or related KYC Form details
  final String? centerNo;
  final String? groupNo;
  final String? guardianType;
  final String? guardianName;
  final String? education;
  final String? religion;
  final String? category;
  final String? houseType;
  final double? landHa;
  final String? livestock;
  final String? bankName;
  final String? bankAcct;
  final String? passbookName;
  final String? povertyLine;
  final double? distCenterM;
  final double? distBranchKm;
  final String? relativeInCenter;
  final String? relativeName;
  final double? annualIncome;
  final int? otherLoans;
  final double? currentDebt;
  final String? repayFreq;
  final String? photo;
  final String? husbandName;
  final String? husbandFather;
  final String? husbandDob;
  final String? husbandAddress;
  final String? husbandPhoto;
  final int? consentGiven;
  final String? consentDate;
  final int? declaration;
  final int? bureauConsent;
  final int? addressVerified;
  final String? verifiedBy;
  final String? verifiedOn;
  final String? verifyRemarks;
  final String? signedCopy;
  final String? coName;
  final String? coPhone;
  final String? coRelation;
  final double? coIncome;
  final String? family;

  CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.dob,
    required this.address,
    required this.branch,
    required this.agentId,
    required this.stage,
    this.aadhaar,
    this.pan,
    this.voter,
    this.kycStatus = 'pending',
    this.waVerified = 0,
    required this.created,
    this.centerNo,
    this.groupNo,
    this.guardianType,
    this.guardianName,
    this.education,
    this.religion,
    this.category,
    this.houseType,
    this.landHa,
    this.livestock,
    this.bankName,
    this.bankAcct,
    this.passbookName,
    this.povertyLine,
    this.distCenterM,
    this.distBranchKm,
    this.relativeInCenter,
    this.relativeName,
    this.annualIncome,
    this.otherLoans,
    this.currentDebt,
    this.repayFreq,
    this.photo,
    this.husbandName,
    this.husbandFather,
    this.husbandDob,
    this.husbandAddress,
    this.husbandPhoto,
    this.consentGiven,
    this.consentDate,
    this.declaration,
    this.bureauConsent,
    this.addressVerified,
    this.verifiedBy,
    this.verifiedOn,
    this.verifyRemarks,
    this.signedCopy,
    this.coName,
    this.coPhone,
    this.coRelation,
    this.coIncome,
    this.family,
  });

  factory CustomerModel.fromMap(Map<String, dynamic> map) {
    return CustomerModel(
      id: map['id'] as int,
      name: map['name'] as String,
      phone: (map['phone'] ?? '') as String,
      dob: (map['dob'] ?? '') as String,
      address: (map['address'] ?? '') as String,
      branch: (map['branch'] ?? '') as String,
      agentId: (map['agent_id'] as int?) ?? 1,
      stage: (map['stage'] ?? 'lead') as String,
      aadhaar: map['aadhaar'] as String?,
      pan: map['pan'] as String?,
      voter: map['voter'] as String?,
      kycStatus: (map['kyc_status'] ?? 'pending') as String,
      waVerified: (map['wa_verified'] as int?) ?? 0,
      created: (map['created'] ?? '') as String,
      centerNo: map['center_no'] as String?,
      groupNo: map['group_no'] as String?,
      guardianType: map['guardian_type'] as String?,
      guardianName: map['guardian_name'] as String?,
      education: map['education'] as String?,
      religion: map['religion'] as String?,
      category: map['category'] as String?,
      houseType: map['house_type'] as String?,
      landHa: (map['land_ha'] as num?)?.toDouble(),
      livestock: map['livestock'] as String?,
      bankName: map['bank_name'] as String?,
      bankAcct: map['bank_acct'] as String?,
      passbookName: map['passbook_name'] as String?,
      povertyLine: map['poverty_line'] as String?,
      distCenterM: (map['dist_center_m'] as num?)?.toDouble(),
      distBranchKm: (map['dist_branch_km'] as num?)?.toDouble(),
      relativeInCenter: map['relative_in_center'] as String?,
      relativeName: map['relative_name'] as String?,
      annualIncome: (map['annual_income'] as num?)?.toDouble(),
      otherLoans: map['other_loans'] as int?,
      currentDebt: (map['current_debt'] as num?)?.toDouble(),
      repayFreq: map['repay_freq'] as String?,
      photo: map['photo'] as String?,
      husbandName: map['h_name'] as String?,
      husbandFather: map['h_father'] as String?,
      husbandDob: map['h_dob'] as String?,
      husbandAddress: map['h_address'] as String?,
      husbandPhoto: map['h_photo'] as String?,
      consentGiven: map['consent_given'] as int?,
      consentDate: map['consent_date'] as String?,
      declaration: map['declaration'] as int?,
      bureauConsent: map['bureau_consent'] as int?,
      addressVerified: map['address_verified'] as int?,
      verifiedBy: map['verified_by'] as String?,
      verifiedOn: map['verified_on'] as String?,
      verifyRemarks: map['verify_remarks'] as String?,
      signedCopy: map['signed_copy'] as String?,
      coName: map['co_name'] as String?,
      coPhone: map['co_phone'] as String?,
      coRelation: map['co_relation'] as String?,
      coIncome: (map['co_income'] as num?)?.toDouble(),
      family: map['family'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'dob': dob,
      'address': address,
      'branch': branch,
      'agent_id': agentId,
      'stage': stage,
      'aadhaar': aadhaar,
      'pan': pan,
      'voter': voter,
      'kyc_status': kycStatus,
      'wa_verified': waVerified,
      'created': created,
    };
  }
}
