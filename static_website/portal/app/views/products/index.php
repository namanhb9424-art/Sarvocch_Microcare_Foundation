<div class="d-flex justify-content-between align-items-center mb-4">
  <div>
    <h3 class="fw-bold mb-0 text-teal"><i class="bi bi-box-seam me-2"></i>Microfinance Loan Products Catalog</h3>
    <div class="text-muted small">SARVOOCCH Microcare Foundation · Regulated Lending Schemes</div>
  </div>
  <?php if (can('admin')): ?>
    <button class="btn btn-primary btn-sm" data-bs-toggle="modal" data-bs-target="#newProdModal">
      <i class="bi bi-plus-circle me-1"></i> Add Loan Scheme
    </button>
  <?php endif; ?>
</div>

<div class="row g-4">
  <?php foreach ($products as $p): ?>
    <div class="col-12 col-md-4">
      <div class="card shadow-sm border-0 border-top border-teal border-3 h-100">
        <div class="card-body p-4">
          <div class="d-flex justify-content-between align-items-center mb-2">
            <h5 class="fw-bold text-dark mb-0"><?= htmlspecialchars($p['name']) ?></h5>
            <span class="badge bg-success">Active</span>
          </div>

          <div class="fs-4 fw-bold text-teal my-2"><?= $p['rate'] ?>% <small class="text-muted fs-6">p.a.</small></div>
          <div class="small text-muted mb-3">Interest Method: <strong class="text-dark"><?= ucfirst($p['method']) ?> Balance</strong></div>

          <table class="table table-sm border-0 small mb-0">
            <tr><td class="text-muted">Min Sanction:</td><td class="fw-bold"><?= inr($p['min_amt']) ?></td></tr>
            <tr><td class="text-muted">Max Sanction:</td><td class="fw-bold"><?= inr($p['max_amt']) ?></td></tr>
            <tr><td class="text-muted">Tenure Range:</td><td class="fw-bold"><?= $p['min_tenure'] ?> to <?= $p['max_tenure'] ?> Months</td></tr>
            <tr><td class="text-muted">Processing Fee:</td><td class="fw-bold"><?= $p['fee_pct'] ?>% + 18% GST</td></tr>
          </table>
        </div>
      </div>
    </div>
  <?php endforeach; ?>
</div>

<!-- Modal: New Product -->
<div class="modal fade" id="newProdModal" tabindex="-1">
  <div class="modal-dialog">
    <form method="post" action="<?= url('/products') ?>" class="modal-content">
      <?= csrf_field() ?>
      <div class="modal-header">
        <h6 class="modal-title fw-bold">Define Microcredit Product</h6>
        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
      </div>
      <div class="modal-body small">
        <div class="mb-2">
          <label class="form-label fw-semibold mb-0">Product Name *</label>
          <input type="text" name="name" class="form-control form-control-sm" required placeholder="e.g. Sarvoocch Mahila Pragati">
        </div>
        <div class="row g-2 mb-2">
          <div class="col-6">
            <label class="form-label fw-semibold mb-0">Interest Rate (% p.a.) *</label>
            <input type="number" step="0.1" name="rate" class="form-control form-control-sm" value="24.0" required>
          </div>
          <div class="col-6">
            <label class="form-label fw-semibold mb-0">Calculation Method</label>
            <select name="method" class="form-select form-select-sm">
              <option value="reducing">Reducing Balance</option>
              <option value="flat">Flat Rate</option>
            </select>
          </div>
        </div>
        <div class="row g-2 mb-2">
          <div class="col-6">
            <label class="form-label fw-semibold mb-0">Min Amount (₹)</label>
            <input type="number" name="min_amt" class="form-control form-control-sm" value="10000">
          </div>
          <div class="col-6">
            <label class="form-label fw-semibold mb-0">Max Amount (₹)</label>
            <input type="number" name="max_amt" class="form-control form-control-sm" value="50000">
          </div>
        </div>
        <div class="row g-2 mb-2">
          <div class="col-6">
            <label class="form-label fw-semibold mb-0">Min Tenure (Mos)</label>
            <input type="number" name="min_tenure" class="form-control form-control-sm" value="12">
          </div>
          <div class="col-6">
            <label class="form-label fw-semibold mb-0">Max Tenure (Mos)</label>
            <input type="number" name="max_tenure" class="form-control form-control-sm" value="24">
          </div>
        </div>
        <div class="mb-2">
          <label class="form-label fw-semibold mb-0">Processing Fee (%)</label>
          <input type="number" step="0.1" name="fee_pct" class="form-control form-control-sm" value="1.5">
        </div>
      </div>
      <div class="modal-footer">
        <button type="submit" class="btn btn-primary btn-sm">Save Scheme</button>
      </div>
    </form>
  </div>
</div>
