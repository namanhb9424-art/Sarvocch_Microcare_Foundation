<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>KYC Dossier - <?= htmlspecialchars($c['name']) ?></title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<style>
  body { background: #fff; font-size: 11px; color: #000; }
  .sheet { max-width: 820px; margin: auto; padding: 20px; }
  .photo-box { width: 100px; height: 120px; border: 1px dashed #666; display: flex; align-items: center; justify-content: center; text-align: center; }
  .lbl { width: 25%; font-weight: bold; background: #f8fafc; }
  @media print { .no-print { display: none !important; } .sheet { padding: 0; } }
</style>
</head>
<body>
<div class="sheet">
  <div class="no-print d-flex justify-content-between mb-3 pb-2 border-bottom">
    <button onclick="window.print()" class="btn btn-primary btn-sm">Print Dossier</button>
    <a href="<?= url('/crm/' . $c['id']) ?>" class="btn btn-outline-secondary btn-sm">Back</a>
  </div>

  <!-- Header -->
  <div class="d-flex justify-content-between align-items-center mb-2 pb-2 border-bottom">
    <div>
      <h4 class="fw-bold mb-0 text-teal">SARVOOCCH MICROCARE FOUNDATION</h4>
      <div class="small text-muted">CIN: U88900MP2026NPL084139 · Section 8 Microfinance Institution</div>
      <div class="small">Regd. Office: Sagar High Street, Ayodhya Bypass, Bhopal - 462041</div>
    </div>
    <div class="text-end">
      <div class="fw-bold fs-6">KYC DOSSIER / ग्राहक विवरण प्रपत्र</div>
      <div class="small">Customer ID: <strong>#<?= $c['id'] ?></strong></div>
      <div class="small">Branch: <strong><?= htmlspecialchars($c['branch'] ?? '') ?></strong></div>
    </div>
  </div>

  <div class="row mb-3">
    <div class="col-8">
      <table class="table table-bordered table-sm mb-0">
        <tr><td class="lbl">Borrower Name</td><td><?= htmlspecialchars($c['name']) ?></td><td class="lbl">Date of Birth</td><td><?= fmt_date($c['dob']) ?></td></tr>
        <tr><td class="lbl">Mobile Number</td><td><?= htmlspecialchars($c['phone']) ?></td><td class="lbl">Marital Status</td><td>Married</td></tr>
        <tr><td class="lbl">Aadhaar (Last 4)</td><td>XXXX-XXXX-<?= htmlspecialchars($c['aadhaar_last4'] ?? '0000') ?></td><td class="lbl">PAN Card</td><td><?= htmlspecialchars($c['pan'] ?: '-') ?></td></tr>
        <tr><td class="lbl">Center & Group</td><td>Center <?= htmlspecialchars($k['center_no'] ?? '-') ?> / Group <?= htmlspecialchars($k['group_no'] ?? '-') ?></td><td class="lbl">Category</td><td><?= htmlspecialchars($k['category'] ?? 'General') ?></td></tr>
        <tr><td class="lbl">Guardian Name</td><td><?= htmlspecialchars($k['guardian_name'] ?? '-') ?> (<?= htmlspecialchars($k['guardian_type'] ?? 'Husband') ?>)</td><td class="lbl">Education</td><td><?= htmlspecialchars($k['education'] ?? '-') ?></td></tr>
      </table>
    </div>
    <div class="col-4 d-flex justify-content-end gap-2">
      <div class="photo-box">
        <?php if (!empty($k['photo'])): ?>
          <img src="<?= url('/uploads/' . $k['photo']) ?>" style="max-width: 100%; max-height: 100%;">
        <?php else: ?>
          Borrower<br>Photo
        <?php endif; ?>
      </div>
      <div class="photo-box">
        <?php if (!empty($k['h_photo'])): ?>
          <img src="<?= url('/uploads/' . $k['h_photo']) ?>" style="max-width: 100%; max-height: 100%;">
        <?php else: ?>
          Spouse<br>Photo
        <?php endif; ?>
      </div>
    </div>
  </div>

  <div class="fw-bold mb-1">Residential & Socio-Economic Assessment</div>
  <table class="table table-bordered table-sm mb-3">
    <tr><td class="lbl">Address</td><td colspan="3"><?= htmlspecialchars($c['address']) ?>, Dist: <?= htmlspecialchars($k['district'] ?? '') ?>, Pincode: <?= htmlspecialchars($k['pincode'] ?? '') ?></td></tr>
    <tr><td class="lbl">House Type</td><td><?= htmlspecialchars($k['house_type'] ?? 'Pucca') ?></td><td class="lbl">Poverty Line</td><td><?= htmlspecialchars($k['poverty_line'] ?? 'APL') ?></td></tr>
    <tr><td class="lbl">Land Owned</td><td><?= $k['land_ha'] ?? '0.00' ?> Hectares</td><td class="lbl">Livestock</td><td><?= htmlspecialchars($k['livestock'] ?? 'None') ?></td></tr>
    <tr><td class="lbl">Household Annual Income</td><td><strong><?= inr($k['annual_income'] ?? 150000) ?></strong></td><td class="lbl">Bank & Acct</td><td><?= htmlspecialchars($k['bank_name'] ?? '-') ?> / <?= htmlspecialchars($k['bank_acct'] ?? '-') ?></td></tr>
  </table>

  <div class="fw-bold mb-1">Borrower Declaration & Consent</div>
  <div class="p-2 border bg-light small mb-3">
    मैं प्रमाणित करती हूँ कि ऊपर दिए गए सभी विवरण सत्य हैं। मैं स्वेच्छा से सर्वोच्‍च माइक्रोकेयर फाउंडेशन के संयुक्त देयता समूह (JLG) ऋण योजना के अंतर्गत आवेदन कर रही हूँ। मैं क्रेडिट ब्यूरो जाँच एवं केंद्र बैठकों के सभी नियमों का पालन करने के लिए सहमत हूँ।
  </div>

  <div class="row text-center mt-5">
    <div class="col-4">
      <div style="height: 35px; border-bottom: 1px solid #000;"></div>
      <div class="small fw-semibold mt-1">Borrower Signature / Thumb</div>
    </div>
    <div class="col-4">
      <div style="height: 35px; border-bottom: 1px solid #000;"></div>
      <div class="small fw-semibold mt-1">Co-Borrower / Spouse Signature</div>
    </div>
    <div class="col-4">
      <div style="height: 35px; border-bottom: 1px solid #000;"></div>
      <div class="small fw-semibold mt-1">Branch Officer Attestation</div>
    </div>
  </div>
</div>
</body>
</html>
