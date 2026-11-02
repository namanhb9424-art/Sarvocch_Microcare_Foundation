class CloudPlanTier {
  final String tierName;
  final double priceMonthlyUsd;
  final double priceMonthlyInr;
  final String billingPeriod;
  final String storageGb;
  final String readWriteQuota;
  final String egressGb;
  final String concurrency;
  final List<String> highlights;
  final bool isRecommended;

  CloudPlanTier({
    required this.tierName,
    required this.priceMonthlyUsd,
    required this.priceMonthlyInr,
    this.billingPeriod = 'month',
    required this.storageGb,
    required this.readWriteQuota,
    required this.egressGb,
    required this.concurrency,
    required this.highlights,
    this.isRecommended = false,
  });
}

class CloudDatabaseQuoteModel {
  final String id;
  final String providerName;
  final String category; // SQL, NoSQL, BaaS, Serverless
  final String logoIcon;
  final String tagLine;
  final String suitability; // Why it fits SARVOOCCH microfinance portal
  final String syncArchitecture; // How website + mobile app connect
  final String defaultEndpointTemplate;
  final List<CloudPlanTier> plans;

  CloudDatabaseQuoteModel({
    required this.id,
    required this.providerName,
    required this.category,
    required this.logoIcon,
    required this.tagLine,
    required this.suitability,
    required this.syncArchitecture,
    required this.defaultEndpointTemplate,
    required this.plans,
  });
}
