class ScheduleItemModel {
  final int id;
  final int loanId;
  final int no;
  final String dueDate;
  final double emi;
  final double principal;
  final double interest;
  final double balance;
  final int paid; // 0 or 1
  final String? paidOn;

  ScheduleItemModel({
    required this.id,
    required this.loanId,
    required this.no,
    required this.dueDate,
    required this.emi,
    required this.principal,
    required this.interest,
    required this.balance,
    required this.paid,
    this.paidOn,
  });

  factory ScheduleItemModel.fromMap(Map<String, dynamic> map) {
    return ScheduleItemModel(
      id: map['id'] as int,
      loanId: map['loan_id'] as int,
      no: map['no'] as int,
      dueDate: map['due_date'] as String,
      emi: (map['emi'] as num).toDouble(),
      principal: (map['principal'] as num).toDouble(),
      interest: (map['interest'] as num).toDouble(),
      balance: (map['balance'] as num).toDouble(),
      paid: (map['paid'] as int?) ?? 0,
      paidOn: map['paid_on'] as String?,
    );
  }
}

class PaymentModel {
  final int id;
  final int loanId;
  final int scheduleId;
  final double amount;
  final String channel; // upi, cash, card, autopay
  final String ref;
  final String at;

  PaymentModel({
    required this.id,
    required this.loanId,
    required this.scheduleId,
    required this.amount,
    required this.channel,
    required this.ref,
    required this.at,
  });

  factory PaymentModel.fromMap(Map<String, dynamic> map) {
    return PaymentModel(
      id: map['id'] as int,
      loanId: map['loan_id'] as int,
      scheduleId: map['schedule_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      channel: (map['channel'] ?? 'upi') as String,
      ref: (map['ref'] ?? '') as String,
      at: (map['at'] ?? '') as String,
    );
  }
}

class LoanModel {
  final int id;
  final int applicationId;
  final int customerId;
  final int productId;
  final double principal;
  final double rate;
  final int tenure;
  final String method;
  final double emi;
  final String startDate;
  final String status; // active, closed, overdue
  final String? closureDate;
  final String branch;
  final int agentId;

  // Joined display attributes
  final String? customerName;
  final String? customerPhone;
  final String? productName;
  final int paidCount;
  final int totalCount;
  final double paidTotal;
  final double outstanding;
  final String? nextDueDate;
  final double? nextDueAmount;
  final bool hasOverdue;

  LoanModel({
    required this.id,
    required this.applicationId,
    required this.customerId,
    required this.productId,
    required this.principal,
    required this.rate,
    required this.tenure,
    required this.method,
    required this.emi,
    required this.startDate,
    required this.status,
    this.closureDate,
    required this.branch,
    required this.agentId,
    this.customerName,
    this.customerPhone,
    this.productName,
    this.paidCount = 0,
    this.totalCount = 0,
    this.paidTotal = 0,
    this.outstanding = 0,
    this.nextDueDate,
    this.nextDueAmount,
    this.hasOverdue = false,
  });

  factory LoanModel.fromMap(Map<String, dynamic> map) {
    return LoanModel(
      id: map['id'] as int,
      applicationId: map['application_id'] as int,
      customerId: map['customer_id'] as int,
      productId: map['product_id'] as int,
      principal: (map['principal'] as num).toDouble(),
      rate: (map['rate'] as num).toDouble(),
      tenure: map['tenure'] as int,
      method: (map['method'] ?? 'reducing') as String,
      emi: (map['emi'] as num).toDouble(),
      startDate: map['start_date'] as String,
      status: (map['status'] ?? 'active') as String,
      closureDate: map['closure_date'] as String?,
      branch: (map['branch'] ?? '') as String,
      agentId: (map['agent_id'] as int?) ?? 1,
      customerName: map['customer_name'] as String?,
      customerPhone: map['customer_phone'] as String?,
      productName: map['product_name'] as String?,
      paidCount: (map['paid_count'] as int?) ?? 0,
      totalCount: (map['total_count'] as int?) ?? 0,
      paidTotal: (map['paid_total'] as num?)?.toDouble() ?? 0.0,
      outstanding: (map['outstanding'] as num?)?.toDouble() ?? 0.0,
      nextDueDate: map['next_due_date'] as String?,
      nextDueAmount: (map['next_due_amount'] as num?)?.toDouble(),
      hasOverdue: (map['has_overdue'] as int? ?? 0) == 1,
    );
  }
}
