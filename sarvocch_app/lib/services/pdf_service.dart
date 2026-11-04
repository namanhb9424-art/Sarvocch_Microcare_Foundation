import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  static final PdfService _instance = PdfService._internal();
  factory PdfService() => _instance;
  PdfService._internal();

  /// Generate and share / print a document
  static Future<void> printOrShareDocument({
    required String title,
    required Uint8List bytes,
  }) async {
    await Printing.sharePdf(bytes: bytes, filename: '$title.pdf');
  }

  /// Generate official Loan Sanction Letter PDF
  static Future<Uint8List> generateSanctionLetter({
    required String loanId,
    required String customerName,
    required String customerId,
    required String phone,
    required String branch,
    required double amount,
    required double rate,
    required int tenure,
    required double emi,
    required String purpose,
    required String sanctionDate,
    String? coBorrower,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'SARVOOCCH MICROCARE FOUNDATION',
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '(CIN: U65999MP2023NPL000000 · Section 8 Microfinance Institution)',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                    ),
                    pw.Text(
                      'Regd. Office: Gorakhpur / Indore · Helpline: +91 98765 43210 · support@sarvoocch.org',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.teal50,
                        border: pw.Border.all(color: PdfColors.teal700, width: 0.5),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Text(
                        'LOAN SANCTION LETTER (RIN SWIKRITI PATRA)',
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Divider(thickness: 1, color: PdfColors.teal800),
              pw.SizedBox(height: 10),

              // Reference details
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Ref: SMF/SANCTION/$loanId', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Date: $sanctionDate', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.SizedBox(height: 10),

              // Salutation
              pw.Text('To,', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Ms. / Mrs. $customerName (Customer ID: $customerId)', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Text('Mobile: +91 $phone', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Operating Branch: $branch', style: const pw.TextStyle(fontSize: 9)),
              if (coBorrower != null && coBorrower.isNotEmpty)
                pw.Text('Co-Borrower / Guarantor: $coBorrower', style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 12),

              pw.Text(
                'Dear Madam,\nWe are pleased to inform you that your application for micro-credit financial assistance has been approved by the Credit Committee under Joint Liability Group (JLG) scheme as per details given below:',
                style: const pw.TextStyle(fontSize: 9.5, lineSpacing: 2),
              ),
              pw.SizedBox(height: 12),

              // Sanction Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                children: [
                  _pdfTableRow('Sanctioned Loan Account No', 'LN-$loanId', isHeader: false),
                  _pdfTableRow('Principal Loan Amount', 'Rs. ${amount.toStringAsFixed(0)} /-', isHeader: false),
                  _pdfTableRow('Loan Purpose', purpose, isHeader: false),
                  _pdfTableRow('Rate of Interest (p.a.)', '$rate% per annum (Reducing Balance)', isHeader: false),
                  _pdfTableRow('Repayment Tenure', '$tenure Equated Monthly Installments (EMIs)', isHeader: false),
                  _pdfTableRow('Monthly Installment (EMI)', 'Rs. ${emi.toStringAsFixed(0)} /- per month', isHeader: false),
                  _pdfTableRow('Processing Fee (1.5% + GST)', 'Rs. ${(amount * 0.015).toStringAsFixed(0)} /-', isHeader: false),
                  _pdfTableRow('Credit Life Insurance Premium', 'Included as per opted scheme', isHeader: false),
                ],
              ),
              pw.SizedBox(height: 14),

              // Terms & Conditions
              pw.Text('Key Terms & Regulatory Disclosures (RBI MFI Master Direction 2022):', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Bullet(text: 'No pre-payment penalty shall be levied for early repayment of this microfinance loan.', style: const pw.TextStyle(fontSize: 8.5)),
              pw.Bullet(text: 'Repayments must be remitted strictly during designated Centre Meetings or through official digital modes.', style: const pw.TextStyle(fontSize: 8.5)),
              pw.Bullet(text: 'Credit performance and repayment track record are reported monthly to Credit Information Bureaus (CIBIL/Equifax/CRIF).', style: const pw.TextStyle(fontSize: 8.5)),
              pw.Bullet(text: 'Grievance Redressal: Call toll-free 1800-SARVOOCCH or email grievance@sarvoocch.org.', style: const pw.TextStyle(fontSize: 8.5)),

              pw.Spacer(),

              // Signatures
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(width: 140, height: 1, color: PdfColors.grey600),
                      pw.SizedBox(height: 4),
                      pw.Text('Signature / Thumb of Borrower', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Text('(I accept all terms & conditions)', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(width: 140, height: 1, color: PdfColors.grey600),
                      pw.SizedBox(height: 4),
                      pw.Text('For SARVOOCCH Microcare', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Authorized Branch Officer', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generate Loan Passbook Card PDF
  static Future<Uint8List> generatePassbookCard({
    required Map<String, dynamic> data,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text('SARVOOCCH MICROCARE FOUNDATION', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
                    pw.Text('MEMBER LOAN PASSBOOK (RIN PASSBOOK)', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Branch: ${data['branch'] ?? 'Indore - Vijay Nagar'}', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Divider(thickness: 1, color: PdfColors.teal900),
              pw.SizedBox(height: 10),

              // Borrower & Loan Summary
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Borrower: ${data['customer_name'] ?? data['name'] ?? 'Sunita Verma'}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Loan A/C: LN-${data['id'] ?? '001'}', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('Center No: ${data['center_no'] ?? 'C-101'} - Group: ${data['group_no'] ?? 'G-A'}', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Sanctioned: Rs. ${data['principal'] ?? data['amount'] ?? 40000}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Rate: ${data['rate'] ?? 18}% p.a. - Tenure: ${data['tenure'] ?? 12} Mos', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('Monthly EMI: Rs. ${data['emi'] ?? 3667}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 14),

              // Installment Schedule Header
              pw.Text('REPAYMENT LEDGER (KIST BHUGTAN BYORA)', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),

              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _tableCell('#', isHeader: true),
                      _tableCell('Due Date', isHeader: true),
                      _tableCell('EMI (Rs.)', isHeader: true),
                      _tableCell('Paid Date', isHeader: true),
                      _tableCell('Amount Paid', isHeader: true),
                      _tableCell('Officer Sign', isHeader: true),
                    ],
                  ),
                  for (int i = 1; i <= 12; i++)
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: i <= 3 ? PdfColors.teal50 : null),
                      children: [
                        _tableCell('$i'),
                        _tableCell('2026-${(i + 4).toString().padLeft(2, '0')}-10'),
                        _tableCell('${data['emi'] ?? 3667}'),
                        _tableCell(i <= 3 ? '2026-${(i + 4).toString().padLeft(2, '0')}-09' : '-'),
                        _tableCell(i <= 3 ? '${data['emi'] ?? 3667}' : '-'),
                        _tableCell(i <= 3 ? 'VERIFIED' : ''),
                      ],
                    ),
                ],
              ),

              pw.Spacer(),
              pw.Center(
                child: pw.Text(
                  'Keep this passbook card safe. Always insist on an instant SMS/receipt for every installment payment.',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generate Pre-GRT Certificate PDF
  static Future<Uint8List> generatePreGrtCertificate({
    required Map<String, dynamic> data,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text('SARVOOCCH MICROCARE FOUNDATION', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
                    pw.SizedBox(height: 4),
                    pw.Text('PRE-GRT APPRAISAL & COMPLIANCE CERTIFICATE', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.Text('(Poorv-GRT Mulyankan evam Anupalan Pramanpatra)', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),
              pw.Divider(thickness: 1, color: PdfColors.teal800),
              pw.SizedBox(height: 10),

              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                children: [
                  _pdfTableRow('Center & Group Code', 'Center ${data['center_no']} - Group ${data['group_no']}'),
                  _pdfTableRow('Village / Town & District', '${data['village']}, ${data['district']}'),
                  _pdfTableRow('Branch Office', data['branch'] ?? 'Indore - Vijay Nagar'),
                  _pdfTableRow('Primary S.O. / Field Officer', '${data['pso_name']} (${data['pso_empid']})'),
                  _pdfTableRow('7 CGT Discipline Points Verified', 'COMPLIANT & PASSED'),
                  _pdfTableRow('Continuous Attendance Check', '100% Present in 3-day CGT'),
                  _pdfTableRow('Joint Liability Understanding', 'VERIFIED & RECORDED'),
                  _pdfTableRow('Certification Approved By', '${data['verified_by'] ?? "Meera Manager"} (Branch Manager)'),
                  _pdfTableRow('Certification Date', data['verified_on'] ?? '2026-09-02'),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'This is to certify that all members of the aforementioned Group have undergone compulsory continuous group training (CGT) and understand the mutual cross-guarantee obligations under Sarvoocch Microcare JLG rules.',
                style: const pw.TextStyle(fontSize: 9, lineSpacing: 2),
              ),
              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(width: 140, height: 1, color: PdfColors.grey600),
                      pw.SizedBox(height: 4),
                      pw.Text('Field Officer (S.O.) Signature', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(width: 140, height: 1, color: PdfColors.grey600),
                      pw.SizedBox(height: 4),
                      pw.Text('Branch Manager Seal & Signature', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generate No Objection Certificate (NOC) PDF
  static Future<Uint8List> generateNocCertificate({
    required String loanId,
    required String customerName,
    required String customerId,
    required String branch,
    required String closureDate,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text('SARVOOCCH MICROCARE FOUNDATION', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
                    pw.SizedBox(height: 4),
                    pw.Text('NO OBJECTION & LOAN CLOSURE CERTIFICATE', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.Text('(Rin Bebaki evam Anapatti Pramanpatra)', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),
              pw.Divider(thickness: 1, color: PdfColors.teal800),
              pw.SizedBox(height: 16),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Ref: SMF/NOC/$loanId', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Closure Date: $closureDate', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.SizedBox(height: 16),

              pw.Text('TO WHOMSOEVER IT MAY CONCERN', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),

              pw.Text(
                'This is to certify that Ms. / Mrs. $customerName (Customer ID: $customerId), residing at $branch operating jurisdiction, had availed a microfinance credit facility under Loan Account Number LN-$loanId from SARVOOCCH Microcare Foundation.\n\n'
                'We hereby confirm that the aforesaid loan has been FULLY REPAID together with all applicable interest and dues. As on $closureDate, there is ZERO OUTSTANDING balance against this loan account.\n\n'
                'SARVOOCCH Microcare Foundation has NO OBJECTION to the borrower availing credit facilities from any other Bank, NBFC or MFI. The borrower bears a satisfactory repayment track record.',
                style: const pw.TextStyle(fontSize: 10, lineSpacing: 2),
              ),
              pw.SizedBox(height: 24),

              pw.Text('Loan Account Details for Reference:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                children: [
                  _pdfTableRow('Loan Account No', 'LN-$loanId'),
                  _pdfTableRow('Borrower Name', customerName),
                  _pdfTableRow('Customer CIF', customerId),
                  _pdfTableRow('Account Status', 'CLOSED (Zero Outstanding)'),
                  _pdfTableRow('Issuing Branch', branch),
                ],
              ),

              pw.Spacer(),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(width: 160, height: 1, color: PdfColors.grey600),
                    pw.SizedBox(height: 4),
                    pw.Text('For SARVOOCCH Microcare Foundation', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Authorized Officer / Branch Manager', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                    pw.Text('Official Seal & Signature', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.TableRow _pdfTableRow(String label, String value, {bool isHeader = false}) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            label,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            value,
            style: pw.TextStyle(fontSize: 9, fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal),
          ),
        ),
      ],
    );
  }

  static pw.Widget _tableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
}
