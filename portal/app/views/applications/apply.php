<div class="d-flex justify-content-between align-items-center mb-4">
  <div>
    <h3 class="fw-bold mb-0 text-teal"><i class="bi bi-file-earmark-plus me-2"></i>New Loan Application</h3>
    <div class="text-muted small">SARVOOCCH Microcare Foundation · Grassroots Microfinance Application</div>
  </div>
  <a href="<?= url('/applications') ?>" class="btn btn-outline-secondary btn-sm">Back</a>
</div>

<form method="post" action="<?= url('/apply') ?>">
  <?= csrf_field() ?>

  <div class="card shadow-sm border-0 mb-4">
    <div class="card-header bg-white py-3">
      <h6 class="fw-bold mb-0 text-dark">Loan Assessment & Product Selection</h6>
    </div>
    <div class="card-body p-4">
      <div class="row g-3">
        <div class="col-12 col-md-6">
          <label class="form-label small fw-semibold">Select Customer / Borrower *</label>
          <select name="customer_id" class="form-select" required>
            <option value="">-- Choose Borrower --</option>
            <?php foreach ($customers as $c): ?>
              <option value="<?= $c['id'] ?>"><?= htmlspecialchars($c['name']) ?> (<?= htmlspecialchars($c['phone']) ?>) - <?= htmlspecialchars($c['branch']) ?></option>
            <?php endforeach; ?>
          </select>
        </div>

        <div class="col-12 col-md-6">
          <label class="form-label small fw-semibold">Loan Product Scheme *</label>
          <select name="product_id" class="form-select" required id="prodSelect">
            <?php foreach ($products as $p): ?>
              <option value="<?= $p['id'] ?>" data-rate="<?= $p['rate'] ?>" data-min="<?= $p['min_amt'] ?>" data-max="<?= $p['max_amt'] ?>">
                <?= htmlspecialchars($p['name']) ?> (<?= $p['rate'] ?>% p.a., Max ₹<?= number_format($p['max_amt']) ?>)
              </option>
            <?php endforeach; ?>
          </select>
        </div>

        <div class="col-12 col-md-4">
          <label class="form-label small fw-semibold">Sanction Amount (₹) *</label>
          <input type="number" name="amount" id="loanAmt" class="form-control" required value="30000" min="5000" step="1000">
        </div>

        <div class="col-12 col-md-4">
          <label class="form-label small fw-semibold">Tenure (Months) *</label>
          <select name="tenure" class="form-select" id="loanTenure">
            <option value="12">12 Months (1 Year)</option>
            <option value="18">18 Months (1.5 Years)</option>
            <option value="24" selected>24 Months (2 Years)</option>
            <option value="36">36 Months (3 Years)</option>
          </select>
        </div>

        <div class="col-12 col-md-4">
          <label class="form-label small fw-semibold">Branch Location</label>
          <select name="branch" class="form-select">
            <?php foreach (Database::getBranches() as $b): ?>
              <option value="<?= htmlspecialchars($b) ?>"><?= htmlspecialchars($b) ?></option>
            <?php endforeach; ?>
          </select>
        </div>

        <div class="col-12 col-md-6">
          <label class="form-label small fw-semibold">Loan Purpose / व्यवसाय उद्देश्य</label>
          <input type="text" name="purpose" class="form-control" placeholder="Dairy, Kirana Store, Vegetable Vending..." value="Livestock Dairy Expansion">
        </div>

        <div class="col-12 col-md-6">
          <label class="form-label small fw-semibold">Monthly Household Income (₹)</label>
          <input type="number" name="income" class="form-control" placeholder="e.g. 18000" value="18000">
        </div>

        <div class="col-12 col-md-4">
          <label class="form-label small fw-semibold">Co-Borrower Name</label>
          <input type="text" name="co_name" class="form-control" placeholder="Husband or Son name">
        </div>

        <div class="col-12 col-md-4">
          <label class="form-label small fw-semibold">Co-Borrower Mobile</label>
          <input type="tel" name="co_phone" class="form-control" placeholder="10-digit mobile">
        </div>

        <div class="col-12 col-md-4">
          <label class="form-label small fw-semibold">Co-Borrower Relationship</label>
          <select name="co_relation" class="form-select">
            <option value="Husband">Husband / पति</option>
            <option value="Son">Son / पुत्र</option>
            <option value="Father">Father / पिता</option>
          </select>
        </div>
      </div>
    </div>
    <div class="card-footer bg-light p-3 d-flex justify-content-end">
      <button type="submit" class="btn btn-teal text-white px-4 fw-semibold" style="background-color: #0f766e;">
        <i class="bi bi-send me-1"></i> Submit Loan Application
      </button>
    </div>
  </div>
</form>
