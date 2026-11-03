import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/pdf_service.dart';
import '../theme/app_theme.dart';

enum DocumentType { loanPassbook, loginSlip, kycDossier, preGrtCertificate }

class DocumentViewerSheet extends StatelessWidget {
  final DocumentType type;
  final Map<String, dynamic> data;

  const DocumentViewerSheet({
    super.key,
    required this.type,
    required this.data,
  });

  static void show(BuildContext context, {required DocumentType type, required Map<String, dynamic> data}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DocumentViewerSheet(type: type, data: data),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.tealSurface,
                  child: const Icon(Icons.print, size: 18, color: AppTheme.tealPrimary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _getTitle(),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.download, color: AppTheme.tealPrimary),
                  tooltip: 'Export PDF Document',
                  onPressed: () async {
                    try {
                      final bytes = type == DocumentType.loanPassbook
                          ? await PdfService.generatePassbookCard(data: data)
                          : type == DocumentType.preGrtCertificate
                              ? await PdfService.generatePreGrtCertificate(data: data)
                              : await PdfService.generateSanctionLetter(
                                  loanId: '${data['id'] ?? "001"}',
                                  customerName: data['customer_name'] ?? data['name'] ?? 'Sunita Verma',
                                  customerId: '${data['customer_id'] ?? data['id'] ?? "001"}',
                                  phone: (data['phone'] ?? '9876543210').toString(),
                                  branch: (data['branch'] ?? 'Indore - Vijay Nagar').toString(),
                                  amount: (data['principal'] ?? data['amount'] ?? 40000 as num).toDouble(),
                                  rate: (data['rate'] ?? 18 as num).toDouble(),
                                  tenure: ((data['tenure'] ?? 12) as num).toInt(),
                                  emi: (data['emi'] ?? 3667 as num).toDouble(),
                                  purpose: (data['purpose'] ?? 'Microenterprise expansion').toString(),
                                  sanctionDate: (data['start_date'] ?? '2026-05-10').toString(),
                                );
                      await PdfService.printOrShareDocument(
                        title: _getTitle().replaceAll(' ', '_').replaceAll('/', '_'),
                        bytes: bytes,
                      );
                    } catch (e) {
                      debugPrint('PDF export error: $e');
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Scrollable Document Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildDocumentContent(context),
            ),
          ),
        ],
      ),
    );
  }

  String _getTitle() {
    switch (type) {
      case DocumentType.loanPassbook:
        return 'Loan Passbook / ऋण कार्ड';
      case DocumentType.loginSlip:
        return 'Customer Login Slip / लॉगिन पर्ची';
      case DocumentType.kycDossier:
        return 'Bilingual KYC Dossier / केवाईसी प्रपत्र';
      case DocumentType.preGrtCertificate:
        return 'Pre-GRT Certificate / प्री-जीआरटी प्रमाणपत्र';
    }
  }

  Widget _buildDocumentContent(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Official Header
          Center(
            child: Column(
              children: [
                Image.asset('assets/icon/app_logo.png', width: 48, height: 48),
                const SizedBox(height: 6),
                const Text(
                  'SARVOOCCH Microcare Foundation',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.tealPrimary),
                ),
                const Text(
                  'सर्वोच्च माइक्रोकेयर फाउंडेशन',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.tealSurface,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _getTitle().toUpperCase(),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.tealDark),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Divider(thickness: 1.5),
          const SizedBox(height: 10),

          if (type == DocumentType.loginSlip) ...[
            _docRow('Borrower Full Name', data['name'] ?? 'Sunita Verma'),
            _docRow('Customer ID / CIF', 'CUST-${data['id'] ?? "001"}'),
            _docRow('Registered Mobile', '+91 ${data['phone'] ?? "9876543210"}'),
            _docRow('Branch Office', data['branch'] ?? 'Indore - Vijay Nagar'),
            _docRow('Default Portal Username', 'cust${data['id'] ?? "1"}'),
            _docRow('Temporary Access PIN', 'cust123'),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              color: Colors.amber.shade50,
              child: const Text(
                'महत्वपूर्ण: कृपया अपना पिन किसी के साथ साझा न करें। पोर्टल पर पहली बार लॉग इन करने के बाद अपना पासवर्ड बदल लें।',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.brown),
              ),
            ),
          ] else if (type == DocumentType.loanPassbook) ...[
            _docRow('Loan Account No', 'LN-${data['id'] ?? "001"}'),
            _docRow('Borrower Name', data['customer_name'] ?? 'Sunita Verma'),
            _docRow('Loan Product Scheme', data['product_name'] ?? 'General Micro Loan'),
            _docRow('Sanctioned Principal', currency.format(data['principal'] ?? 40000)),
            _docRow('Interest Rate (p.a.)', '${data['rate'] ?? 18}% (${data['method'] ?? "reducing"})'),
            _docRow('Monthly EMI Amount', currency.format(data['emi'] ?? 3667)),
            _docRow('Disbursement Date', data['start_date'] ?? '2026-05-10'),
            _docRow('Total Tenure', '${data['tenure'] ?? 12} Monthly Installments'),
          ] else if (type == DocumentType.kycDossier) ...[
            _docRow('Applicant Name', data['name'] ?? 'Sunita Verma'),
            _docRow('Aadhaar Reference', 'XXXXXXXX1234 (Verified)'),
            _docRow('PAN Card Ref', data['pan'] ?? 'ABCDE1234F'),
            _docRow('Center & Group Code', 'Center ${data['center_no'] ?? "C-101"} • Group ${data['group_no'] ?? "G-A"}'),
            _docRow('Husband / Co-Applicant', data['husband_name'] ?? 'Ramesh Verma'),
            _docRow('Residence Standard', 'Pucca / Own House (Physically Verified)'),
            _docRow('Annual Household Income', '₹2,16,000 / year'),
            _docRow('Husband Written Consent', 'YES (Formal RBI JLG Guarantee Signed)'),
          ] else if (type == DocumentType.preGrtCertificate) ...[
            _docRow('Center & Group No', 'Center ${data['center_no']} • Group ${data['group_no']}'),
            _docRow('Village & District', '${data['village']}, ${data['district']}'),
            _docRow('Operating Branch', data['branch'] ?? 'Indore - Vijay Nagar'),
            _docRow('Field Officer (PSO)', '${data['pso_name']} (${data['pso_empid']})'),
            _docRow('7 CGT Discipline Points', 'VERIFIED & PASSED'),
            _docRow('Approved By', '${data['verified_by'] ?? "Meera Manager"} (Branch Manager)'),
            _docRow('Verification Date', data['verified_on'] ?? '2026-09-02'),
          ],

          const SizedBox(height: 30),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 30),
                  Text('__________________________', style: TextStyle(color: Colors.grey)),
                  Text('Borrower Signature / Thumb', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(height: 30),
                  Text('__________________________', style: TextStyle(color: Colors.grey)),
                  Text('Authorised Signatory', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  Text('SARVOOCCH Microcare', style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _docRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5, color: AppTheme.textSecondary)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }
}
