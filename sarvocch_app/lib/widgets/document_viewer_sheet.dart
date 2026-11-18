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

  static void show(
    BuildContext context, {
    required DocumentType type,
    required Map<String, dynamic> data,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                  child: const Icon(
                    Icons.print,
                    size: 18,
                    color: AppTheme.tealPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _getTitle(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.download, color: AppTheme.tealPrimary),
                  tooltip: 'Export PDF Document',
                  onPressed: type == DocumentType.loanPassbook
                      ? () async {
                          try {
                            final bytes = await PdfService.generatePassbookCard(
                              data: data,
                            );
                            await PdfService.printOrShareDocument(
                              title: _getTitle()
                                  .replaceAll(' ', '_')
                                  .replaceAll('/', '_'),
                              bytes: bytes,
                            );
                          } catch (_) {
                            debugPrint('Passbook export unavailable.');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Passbook export needs a saved loan schedule.',
                                  ),
                                ),
                              );
                            }
                          }
                        }
                      : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'PDF export is disabled until the organization approves its official document content.',
                              ),
                            ),
                          );
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
        return 'Customer Summary / ग्राहक विवरण';
      case DocumentType.kycDossier:
        return 'Bilingual KYC Dossier / केवाईसी प्रपत्र';
      case DocumentType.preGrtCertificate:
        return 'Pre-GRT Review Summary / समूह समीक्षा';
    }
  }

  Widget _buildDocumentContent(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Local record preview; official issue templates are not configured.
          Center(
            child: Column(
              children: [
                Image.asset('assets/icon/app_logo.png', width: 48, height: 48),
                const SizedBox(height: 6),
                const Text(
                  'SARVOOCCH Microcare Foundation',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: AppTheme.tealPrimary,
                  ),
                ),
                const Text(
                  'सर्वोच्च माइक्रोकेयर फाउंडेशन',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.tealSurface,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _getTitle().toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.tealDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Divider(thickness: 1.5),
          const SizedBox(height: 10),
          const Text(
            'LOCAL RECORD PREVIEW · NOT AN OFFICIAL OR SIGNED DOCUMENT',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.warning,
            ),
          ),
          const SizedBox(height: 10),

          if (type == DocumentType.loginSlip) ...[
            _docRow('Customer Name', _value(data['name'])),
            _docRow(
              'Customer ID',
              data['id'] == null ? 'Not recorded' : 'CUST-${data['id']}',
            ),
            _docRow('Registered Mobile', _value(data['phone'])),
            _docRow('Branch Office', _value(data['branch'])),
            _docRow('Portal Access', 'Not configured'),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              color: Colors.amber.shade50,
              child: const Text(
                'Customer portal credentials are not generated by this app. An administrator must create and link an account before access is available.',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.brown,
                ),
              ),
            ),
          ] else if (type == DocumentType.loanPassbook) ...[
            _docRow(
              'Loan Account No',
              data['id'] == null ? 'Not recorded' : 'LN-${data['id']}',
            ),
            _docRow('Borrower Name', _value(data['customer_name'])),
            _docRow('Loan Product', _value(data['product_name'])),
            _docRow('Principal', _money(data['principal'], currency)),
            _docRow(
              'Interest Rate (p.a.)',
              data['rate'] == null
                  ? 'Not recorded'
                  : '${data['rate']}% (${_value(data['method'])})',
            ),
            _docRow('Installment Amount', _money(data['emi'], currency)),
            _docRow('Disbursement Date', _value(data['start_date'])),
            _docRow(
              'Total Tenure',
              data['tenure'] == null
                  ? 'Not recorded'
                  : '${data['tenure']} installments',
            ),
          ] else if (type == DocumentType.kycDossier) ...[
            _docRow('Applicant Name', _value(data['name'])),
            _docRow('Aadhaar Reference', _value(data['aadhaar'])),
            _docRow('PAN Reference', _value(data['pan'])),
            _docRow(
              'Center & Group Code',
              '${_value(data['center_no'])} • ${_value(data['group_no'])}',
            ),
            _docRow('Husband / Co-Applicant', _value(data['husband_name'])),
            _docRow('KYC Review Status', _value(data['kyc_status'])),
            _docRow(
              'Annual Household Income',
              _money(data['annual_income'], currency),
            ),
            _docRow('Consent Status', _value(data['consent_status'])),
          ] else if (type == DocumentType.preGrtCertificate) ...[
            _docRow(
              'Center & Group No',
              '${_value(data['center_no'])} • ${_value(data['group_no'])}',
            ),
            _docRow(
              'Village & District',
              '${_value(data['village'])}, ${_value(data['district'])}',
            ),
            _docRow('Operating Branch', _value(data['branch'])),
            _docRow(
              'Field Officer',
              '${_value(data['pso_name'])} (${_value(data['pso_empid'])})',
            ),
            _docRow('Review Status', _value(data['status'])),
            _docRow('Reviewed By', _value(data['verified_by'])),
            _docRow('Review Date', _value(data['verified_on'])),
          ],

          const SizedBox(height: 18),
          const Text(
            'No signatures, issuer checks, or external account data are captured in this preview.',
            style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  String _value(dynamic value) {
    final result = value?.toString().trim() ?? '';
    return result.isEmpty ? 'Not recorded' : result;
  }

  String _money(dynamic value, NumberFormat currency) {
    if (value is! num) return 'Not recorded';
    return currency.format(value);
  }

  Widget _docRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 11.5,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
