import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/loan_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_drawer.dart';

class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loanProv = context.watch<LoanProvider>();
    final products = loanProv.products;
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      appBar: const CustomAppBar(title: 'Loan Products'),
      drawer: const CustomDrawer(currentRoute: '/products'),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final p = products[index];

          Color badgeColor;
          if (p.name.contains('Business')) {
            badgeColor = AppTheme.tealPrimary;
          } else if (p.name.contains('Income')) {
            badgeColor = Colors.indigo;
          } else {
            badgeColor = Colors.amber.shade800;
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 14),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: badgeColor.withOpacity(0.12),
                            child: Icon(Icons.inventory_2, color: badgeColor, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                              Text(
                                '${p.rate}% Interest (${p.method.toUpperCase()} BALANCE)',
                                style: TextStyle(color: badgeColor, fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.successLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('ACTIVE', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w700, fontSize: 10)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: AppTheme.border, height: 1),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Loan Amount Range', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          Text('${currency.format(p.minAmt)} - ${currency.format(p.maxAmt)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tenure Limits', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          Text('${p.minTenure} to ${p.maxTenure} Months', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Processing Fee', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          Text('${p.feePct}% + 18% GST', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
