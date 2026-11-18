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

  /// Generate Loan Passbook Card PDF
  static Future<Uint8List> generatePassbookCard({
    required Map<String, dynamic> data,
  }) async {
    final rawSchedule = data['schedule'];
    if (rawSchedule is! List || rawSchedule.isEmpty) {
      throw ArgumentError('A saved installment schedule is required.');
    }
    final schedule = rawSchedule.whereType<Map>().toList(growable: false);
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => [
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text(
                  'SARVOOCCH MICROCARE',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.teal900,
                  ),
                ),
                pw.Text(
                  'LOCAL LOAN SCHEDULE SUMMARY',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Record preview only · Not an official statement or receipt',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Divider(thickness: 1, color: PdfColors.teal900),
          pw.SizedBox(height: 10),
          pw.Text('Borrower: ${_pdfValue(data['customer_name'])}'),
          pw.Text('Loan account: ${_pdfValue(data['id'])}'),
          pw.Text('Branch: ${_pdfValue(data['branch'])}'),
          pw.Text('Product: ${_pdfValue(data['product_name'])}'),
          pw.Text('Principal: Rs. ${_pdfMoney(data['principal'])}'),
          pw.Text(
            'Rate: ${_pdfValue(data['rate'])}% p.a. (${_pdfValue(data['method'])})',
          ),
          pw.Text(
            'Installment: Rs. ${_pdfMoney(data['emi'])} · Tenure: ${_pdfValue(data['tenure'])}',
          ),
          pw.Text('Start date: ${_pdfValue(data['start_date'])}'),
          pw.SizedBox(height: 14),
          pw.Text(
            'SCHEDULE AND PAYMENT STATUS',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(28),
              1: const pw.FlexColumnWidth(1.2),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1),
              4: const pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _tableCell('#', isHeader: true),
                  _tableCell('Due date', isHeader: true),
                  _tableCell('Due (Rs.)', isHeader: true),
                  _tableCell('Paid on', isHeader: true),
                  _tableCell('Paid (Rs.)', isHeader: true),
                ],
              ),
              for (final row in schedule)
                pw.TableRow(
                  children: [
                    _tableCell(_pdfValue(row['no'])),
                    _tableCell(_pdfValue(row['due_date'])),
                    _tableCell(_pdfMoney(row['emi'])),
                    _tableCell(_pdfValue(row['paid_on'])),
                    _tableCell(
                      (row['paid'] == 1 || row['paid'] == true)
                          ? _pdfMoney(row['emi'])
                          : '—',
                    ),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Payment status shown from the local device record. Confirm it against the organization’s ledger before relying on this copy.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  /// Create a printable copy from one immutable local payment row.
  /// It is explicitly identified as a device record, not an official receipt.
  static Future<Uint8List> generateCollectionRecord({
    required Map<String, dynamic> data,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(42),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    'SARVOOCCH MICROCARE',
                    style: pw.TextStyle(
                      fontSize: 17,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.teal900,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'LOCAL COLLECTION RECORD',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Device copy · Confirm against the organization ledger',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Divider(color: PdfColors.teal900),
            pw.SizedBox(height: 14),
            _receiptRow('Reference', _pdfValue(data['reference'])),
            _receiptRow('Recorded at', _pdfValue(data['recorded_at'])),
            _receiptRow('Borrower', _pdfValue(data['customer_name'])),
            _receiptRow('Loan account', _pdfValue(data['loan_id'])),
            _receiptRow('Branch', _pdfValue(data['branch'])),
            _receiptRow('Product', _pdfValue(data['product_name'])),
            _receiptRow('Installment', _pdfValue(data['installment'])),
            _receiptRow('Payment mode', _pdfValue(data['channel'])),
            pw.SizedBox(height: 12),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.teal700),
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Amount recorded',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'Rs. ${_pdfMoney(data['amount'])}',
                    style: pw.TextStyle(
                      fontSize: 17,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.teal900,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 22),
            pw.Text(
              'This copy was generated from the payment record stored on this device. It does not confirm bank settlement or replace the organization’s official receipt and ledger reconciliation.',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ],
        ),
      ),
    );
    return pdf.save();
  }

  static String _pdfValue(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? 'Not recorded' : text;
  }

  static String _pdfMoney(dynamic value) {
    if (value is! num) return 'Not recorded';
    return value.toStringAsFixed(2);
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

  static pw.Widget _receiptRow(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 6),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 112,
          child: pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}
