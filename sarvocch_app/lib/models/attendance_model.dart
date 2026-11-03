class AttendanceRecordModel {
  final int id;
  final int userId;
  final String day;
  final String? inTime;
  final String? outTime;
  final double? lat;
  final double? lng;

  AttendanceRecordModel({
    required this.id,
    required this.userId,
    required this.day,
    this.inTime,
    this.outTime,
    this.lat,
    this.lng,
  });

  factory AttendanceRecordModel.fromMap(Map<String, dynamic> map) {
    return AttendanceRecordModel(
      id: map['id'] as int,
      userId: map['user_id'] as int,
      day: map['day'] as String,
      inTime: map['in_time'] as String?,
      outTime: map['out_time'] as String?,
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
    );
  }
}

class AttendanceRequestModel {
  final int id;
  final int userId;
  final String branch;
  final String day;
  final String inTime;
  final String outTime;
  final String reason;
  final String status; // pending, approved, rejected
  final String approverRole;
  final int approverId;
  final String requestedAt;
  final String? decidedBy;
  final String? decidedAt;
  final String? remarks;
  final String? userName;

  AttendanceRequestModel({
    required this.id,
    required this.userId,
    required this.branch,
    required this.day,
    required this.inTime,
    required this.outTime,
    required this.reason,
    this.status = 'pending',
    required this.approverRole,
    required this.approverId,
    required this.requestedAt,
    this.decidedBy,
    this.decidedAt,
    this.remarks,
    this.userName,
  });

  factory AttendanceRequestModel.fromMap(Map<String, dynamic> map) {
    return AttendanceRequestModel(
      id: map['id'] as int,
      userId: map['user_id'] as int,
      branch: (map['branch'] ?? '') as String,
      day: map['day'] as String,
      inTime: map['in_time'] as String,
      outTime: map['out_time'] as String,
      reason: (map['reason'] ?? '') as String,
      status: (map['status'] ?? 'pending') as String,
      approverRole: (map['approver_role'] ?? 'manager') as String,
      approverId: (map['approver_id'] as int?) ?? 1,
      requestedAt: (map['requested_at'] ?? '') as String,
      decidedBy: map['decided_by'] as String?,
      decidedAt: map['decided_at'] as String?,
      remarks: map['remarks'] as String?,
      userName: map['user_name'] as String?,
    );
  }
}
