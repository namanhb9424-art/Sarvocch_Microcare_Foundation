<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Repayment Receipt - <?= htmlspecialchars($p['ref'] ?: 'RCP-' . $p['id']) ?></title>
  <link rel="stylesheet" href="<?= asset('/static/style.css') ?>">
  <style>
    body { font-family: 'Plus Jakarta Sans', Arial, sans-serif; background: #f8fafc; color: #1e293b; padding: 24px; }
    .receipt-box { max-width: 680px; margin: 0 auto; background: #fff; padding: 32px; border: 1px solid #cbd5e1; border-radius: 8px; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05); }
    .header-logo { width: 64px; height: auto; }
    .title-banner { background: #0f766e; color: #fff; padding: 6px 12px; font-weight: 700; font-size: 14px; text-transform: uppercase; letter-spacing: 0.5px; border-radius: 4px; text-align: center; }
    .info-table td { padding: 6px 10px; font-size: 13px; }
    .amount-highlight { font-size: 20px; font-weight: 800; color: #0f766e; }
    @media print {
      body { background: #fff; padding: 0; }
      .receipt-box { border: none; box-shadow: none; padding: 0; }
      .no-print { display: none !important; }
    }
  </style>
</head>
<body>

<div class="receipt-box">
  <div class="d-flex justify-content-between align-items-center mb-2 no-print">
    <button onclick="window.print()" class="btn btn-primary btn-sm"><i class="bi bi-printer me-1"></i> Print / Save as PDF</button>
    <button onclick="window.close()" class="btn btn-outline-secondary btn-sm">Close</button>
  </div>

  <div class="d-flex align-items-center justify-content-between border-bottom pb-3 mb-3">
    <div>
      <h4 class="fw-bold mb-0 text-teal" style="color: #0f766e; font-size: 20px;">SARVOOCCH MICROCARE FOUNDATION</h4>
      <div class="text-muted" style="font-size: 11px;">Section 8 Non-Profit Microfinance Institution · CIN: <code>U88900MP2026NPL084139</code></div>
      <div class="text-muted" style="font-size: 11px;">Shop No. 10A/GF, Sagar High Street, Ayodhya Bypass, Bhopal, MP - 462041</div>
    </div>
    <img src="<?= asset('/LOGO_1.jpg') ?>" alt="Logo" class="header-logo rounded" style="max-height: 54px;" onerror="this.style.display='none'">
  </div>

  <div class="title-banner mb-3">
    Official Repayment Receipt / ऋण अदायगी पावती
  </div>

  <table class="table table-bordered info-table mb-3">
    <tbody>
      <tr>
        <td class="bg-light fw-bold" style="width: 25%;">Receipt No</td>
        <td style="width: 35%; font-family: monospace; font-weight: bold;"><?= htmlspecialchars($p['ref'] ?: 'RCP-' . $p['id']) ?></td>
        <td class="bg-light fw-bold" style="width: 20%;">Date & Time</td>
        <td style="width: 20%;"><?= htmlspecialchars(substr($p['at'], 0, 16)) ?></td>
      </tr>
      <tr>
        <td class="bg-light fw-bold">Loan Account No</td>
        <td class="fw-bold text-teal"><?= htmlspecialchars($l['loan_no'] ?? ('SMF-LN-' . $l['id'])) ?></td>
        <td class="bg-light fw-bold">Branch</td>
        <td><?= htmlspecialchars($l['branch']) ?></td>
      </tr>
      <tr>
        <td class="bg-light fw-bold">Borrower Name</td>
        <td class="fw-bold" colspan="3"><?= htmlspecialchars($l['customer_name']) ?> (<?= htmlspecialchars($l['phone'] ?? '-') ?>)</td>
      </tr>
      <tr>
        <td class="bg-light fw-bold">Product</td>
        <td><?= htmlspecialchars($l['product_name']) ?></td>
        <td class="bg-light fw-bold">Payment Mode</td>
        <td><span class="badge bg-secondary"><?= strtoupper($p['channel']) ?></span></td>
      </tr>
      <tr>
        <td class="bg-light fw-bold">Instalment No</td>
        <td><?= $s ? ('Instalment #' . $s['no']) : 'Ad-hoc Collection / Settlement' ?></td>
        <td class="bg-light fw-bold">Transaction Ref</td>
        <td style="font-family: monospace; font-size: 11px;"><?= htmlspecialchars($p['ref'] ?: 'CASH-REC') ?></td>
      </tr>
    </tbody>
  </table>

  <div class="p-3 border rounded bg-light mb-3">
    <div class="d-flex justify-content-between align-items-center">
      <div>
        <span class="text-muted small d-block">Amount Received / प्राप्त राशि</span>
        <div class="amount-highlight"><?= inr($p['amount']) ?></div>
      </div>
      <div class="text-end">
        <span class="text-muted small d-block">Remaining Principal Balance / शेष ऋण</span>
        <div class="fw-bold fs-6 text-dark"><?= inr($outstanding) ?></div>
      </div>
    </div>
  </div>

  <div class="d-flex justify-content-between align-items-end pt-3 mt-4 border-top">
    <div>
      <?php
        $verifyUrl = "https://sarvocchfinance.com/portal/loans/" . $l['id'];
        $qrCodeUrl = PaymentGatewayService::getQrCodeUrl($verifyUrl, 80);
      ?>
      <img src="<?= $qrCodeUrl ?>" alt="Verification QR" style="width: 72px; height: 72px; border: 1px solid #cbd5e1; padding: 2px;" class="rounded">
      <div class="text-muted mt-1" style="font-size: 9px;">Scan to verify receipt online</div>
    </div>

    <div class="text-end">
      <div style="height: 40px;"></div>
      <div class="border-top pt-1" style="min-width: 180px;">
        <strong style="font-size: 12px;">Authorised Signatory</strong>
        <div class="text-muted" style="font-size: 10px;">Sarvocch Microcare Foundation</div>
      </div>
    </div>
  </div>

  <div class="text-center text-muted mt-3" style="font-size: 10px;">
    This is an authentic computer-generated official receipt. Printed on <?= date('d M Y, h:i A') ?>.
  </div>
</div>

</body>
</html>
