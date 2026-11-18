import '../services/currency_amount.dart';

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
      emi: CurrencyAmount.readStoredValue(map, 'emi_paise', 'emi'),
      principal: CurrencyAmount.readStoredValue(
        map,
        'principal_paise',
        'principal',
      ),
      interest: CurrencyAmount.readStoredValue(
        map,
        'interest_paise',
        'interest',
      ),
      balance: CurrencyAmount.readStoredValue(map, 'balance_paise', 'balance'),
      paid: (map['paid'] as int?) ?? 0,
      paidOn: map['paid_on'] as String?,
    );
  }
}

class PaymentModel {
  final int id;
  final int loanId;
  final int? scheduleId;
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
      scheduleId: map['schedule_id'] as int?,
      amount: CurrencyAmount.readStoredValue(map, 'amount_paise', 'amount'),
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
  final int principalPaise;
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
  final int paidTotalPaise;
  final double outstanding;
  final int outstandingPaise;
  final String? nextDueDate;
  final double? nextDueAmount;
  final int? nextDueAmountPaise;
  final bool hasOverdue;

  LoanModel({
    required this.id,
    required this.applicationId,
    required this.customerId,
    required this.productId,
    required this.principal,
    required this.principalPaise,
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
    this.paidTotalPaise = 0,
    this.outstanding = 0,
    this.outstandingPaise = 0,
    this.nextDueDate,
    this.nextDueAmount,
    this.nextDueAmountPaise,
    this.hasOverdue = false,
  });

  factory LoanModel.fromMap(Map<String, dynamic> map) {
    return LoanModel(
      id: map['id'] as int,
      applicationId: map['application_id'] as int,
      customerId: map['customer_id'] as int,
      productId: map['product_id'] as int,
      principalPaise: CurrencyAmount.readStoredMinorUnits(
        map,
        'principal_paise',
        'principal',
      ),
      principal: CurrencyAmount.fromMinorUnits(
        CurrencyAmount.readStoredMinorUnits(
          map,
          'principal_paise',
          'principal',
        ),
      ),
      rate: (map['rate'] as num).toDouble(),
      tenure: map['tenure'] as int,
      method: (map['method'] ?? 'reducing') as String,
      emi: CurrencyAmount.readStoredValue(map, 'emi_paise', 'emi'),
      startDate: map['start_date'] as String,
      status: (map['status'] ?? 'active') as String,
      closureDate: map['closure_date'] as String?,
      branch: (map['branch'] ?? '') as String,
      agentId: (map['agent_id'] as int?) ?? 0,
      customerName: map['customer_name'] as String?,
      customerPhone: map['customer_phone'] as String?,
      productName: map['product_name'] as String?,
      paidCount: (map['paid_count'] as int?) ?? 0,
      totalCount: (map['total_count'] as int?) ?? 0,
      paidTotalPaise:
          (map['paid_total_paise'] as num?)?.toInt() ??
          CurrencyAmount.readStoredMinorUnits(
            map,
            'paid_total_paise',
            'paid_total',
          ),
      paidTotal: CurrencyAmount.fromMinorUnits(
        (map['paid_total_paise'] as num?)?.toInt() ??
            CurrencyAmount.readStoredMinorUnits(
              map,
              'paid_total_paise',
              'paid_total',
            ),
      ),
      outstandingPaise:
          (map['outstanding_paise'] as num?)?.toInt() ??
          CurrencyAmount.readStoredMinorUnits(
            map,
            'outstanding_paise',
            'outstanding',
          ),
      outstanding: CurrencyAmount.fromMinorUnits(
        (map['outstanding_paise'] as num?)?.toInt() ??
            CurrencyAmount.readStoredMinorUnits(
              map,
              'outstanding_paise',
              'outstanding',
            ),
      ),
      nextDueDate: map['next_due_date'] as String?,
      nextDueAmountPaise:
          (map['next_due_amount_paise'] as num?)?.toInt() ??
          (map['next_due_amount'] == null
              ? null
              : CurrencyAmount.toMinorUnits(
                  (map['next_due_amount'] as num).toDouble(),
                )),
      nextDueAmount: (map['next_due_amount_paise'] as num?) != null
          ? CurrencyAmount.fromMinorUnits(
              (map['next_due_amount_paise'] as num).toInt(),
            )
          : (map['next_due_amount'] as num?)?.toDouble(),
      hasOverdue: (map['has_overdue'] as int? ?? 0) == 1,
    );
  }
}
