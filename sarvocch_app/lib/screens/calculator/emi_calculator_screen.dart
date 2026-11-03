import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_drawer.dart';

class EmiCalculatorScreen extends StatefulWidget {
  const EmiCalculatorScreen({super.key});

  @override
  State<EmiCalculatorScreen> createState() => _EmiCalculatorScreenState();
}

class _EmiCalculatorScreenState extends State<EmiCalculatorScreen> {
  double _principal = 40000;
  double _rate = 18.0;
  int _tenure = 12;
  String _method = 'reducing'; // 'reducing' or 'flat'
  final double _feePct = 2.0;
  final double _gstRate = 18.0;

  final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  double get _emi {
    if (_method == 'flat') {
      return ((_principal + (_principal * _rate / 100 * _tenure / 12)) / _tenure);
    }
    final r = _rate / 1200;
    if (r == 0) return _principal / _tenure;
    return (_principal * r * pow(1 + r, _tenure) / (pow(1 + r, _tenure) - 1));
  }

  double get _totalPayable => _emi * _tenure;
  double get _totalInterest => max(0, _totalPayable - _principal);

  // Matching fee_split in Flask
  double get _fee => (_principal * _feePct / 100);
  double get _cgst => (_fee * _gstRate / 200);
  double get _sgst => (_fee * _gstRate / 200);
  double get _totalFee => _fee + _cgst + _sgst;
  double get _netDisbursal => _principal - _totalFee;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'EMI & Fee Calculator'),
      drawer: const CustomDrawer(currentRoute: '/calculator'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Calculated EMI Result Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.tealPrimary, AppTheme.tealDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    'MONTHLY INSTALMENT (EMI)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white70, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    currency.format(_emi),
                    style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildBannerStat('Principal', currency.format(_principal)),
                      _buildBannerStat('Total Interest', currency.format(_totalInterest)),
                      _buildBannerStat('Total Repayment', currency.format(_totalPayable)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Controls Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Calculation Method Toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Calculation Method', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'reducing', label: Text('Reducing')),
                            ButtonSegment(value: 'flat', label: Text('Flat')),
                          ],
                          selected: {_method},
                          onSelectionChanged: (set) => setState(() => _method = set.first),
                          style: SegmentedButton.styleFrom(
                            selectedBackgroundColor: AppTheme.tealPrimary,
                            selectedForegroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Principal Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Loan Amount (Principal):', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(currency.format(_principal), style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.tealPrimary, fontSize: 16)),
                      ],
                    ),
                    Slider(
                      value: _principal,
                      min: 2000,
                      max: 100000,
                      divisions: 49,
                      activeColor: AppTheme.tealPrimary,
                      onChanged: (val) => setState(() => _principal = val),
                    ),

                    const SizedBox(height: 10),

                    // Rate Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Interest Rate (p.a.):', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text('${_rate.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.tealPrimary, fontSize: 16)),
                      ],
                    ),
                    Slider(
                      value: _rate,
                      min: 10,
                      max: 30,
                      divisions: 40,
                      activeColor: AppTheme.tealPrimary,
                      onChanged: (val) => setState(() => _rate = val),
                    ),

                    const SizedBox(height: 10),

                    // Tenure Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tenure (Months):', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text('$_tenure Months', style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.tealPrimary, fontSize: 16)),
                      ],
                    ),
                    Slider(
                      value: _tenure.toDouble(),
                      min: 3,
                      max: 24,
                      divisions: 21,
                      activeColor: AppTheme.tealPrimary,
                      onChanged: (val) => setState(() => _tenure = val.toInt()),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Processing Fee & GST Breakdown Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PROCESSING FEE & GST SPLIT (FEE_SPLIT)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 12),
                    _feeRow('Processing Fee (2.0%)', currency.format(_fee)),
                    _feeRow('CGST (9.0%)', currency.format(_cgst)),
                    _feeRow('SGST (9.0%)', currency.format(_sgst)),
                    const Divider(color: AppTheme.border, height: 16),
                    _feeRow('Total Deductions', currency.format(_totalFee), isBold: true),
                    _feeRow('Net Amount Disbursed into Bank', currency.format(_netDisbursal), isHighlight: true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
      ],
    );
  }

  Widget _feeRow(String label, String value, {bool isBold = false, bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold || isHighlight ? FontWeight.w700 : FontWeight.w500,
              color: isHighlight ? AppTheme.tealPrimary : AppTheme.textPrimary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: isBold || isHighlight ? FontWeight.w800 : FontWeight.w600,
              color: isHighlight ? AppTheme.tealPrimary : AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
