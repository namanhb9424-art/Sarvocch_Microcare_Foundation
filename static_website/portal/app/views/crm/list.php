<div class="d-flex justify-content-between align-items-center mb-3">
  <div>
    <h3 class="fw-bold mb-0 text-teal"><i class="bi bi-people me-2"></i>CRM & Customer Register</h3>
    <div class="text-muted small">SARVOOCCH Microcare Foundation · Borrower Pipeline</div>
  </div>
  <button class="btn btn-primary btn-sm" data-bs-toggle="modal" data-bs-target="#newLeadModal">
    <i class="bi bi-person-plus me-1"></i> Register New Customer Lead
  </button>
</div>

<!-- Filters -->
<div class="card shadow-sm border-0 mb-3">
  <div class="card-body p-3">
    <form method="get" action="<?= url('/crm') ?>" class="row g-2 align-items-end">
      <div class="col-6 col-md-3">
        <label class="form-label small mb-0">Branch</label>
        <select name="branch" class="form-select form-select-sm">
          <option value="">All Branches</option>
          <?php foreach (Database::getBranches() as $b): ?>
            <option value="<?= htmlspecialchars($b) ?>" <?= ($filters['branch'] === $b) ? 'selected' : '' ?>><?= htmlspecialchars($b) ?></option>
          <?php endforeach; ?>
        </select>
      </div>

      <div class="col-6 col-md-3">
        <label class="form-label small mb-0">Pipeline Stage</label>
        <select name="stage" class="form-select form-select-sm">
          <option value="">All Stages</option>
          <option value="lead" <?= ($filters['stage'] === 'lead') ? 'selected' : '' ?>>Lead</option>
          <option value="in_verification" <?= ($filters['stage'] === 'in_verification') ? 'selected' : '' ?>>In Verification</option>
          <option value="kyc_done" <?= ($filters['stage'] === 'kyc_done') ? 'selected' : '' ?>>KYC Complete</option>
          <option value="loan_active" <?= ($filters['stage'] === 'loan_active') ? 'selected' : '' ?>>Loan Active</option>
        </select>
      </div>

      <div class="col-8 col-md-4">
        <label class="form-label small mb-0">Search Customer / Mobile / Aadhaar</label>
        <input type="text" name="q" value="<?= htmlspecialchars($filters['q']) ?>" class="form-control form-control-sm" placeholder="Name or 10-digit mobile...">
      </div>

      <div class="col-4 col-md-2 d-flex gap-1">
        <button type="submit" class="btn btn-sm btn-primary flex-fill">Filter</button>
        <a href="<?= url('/crm') ?>" class="btn btn-sm btn-outline-secondary">Reset</a>
      </div>
    </form>
  </div>
</div>

<!-- Customers Table -->
<div class="card shadow-sm border-0">
  <div class="table-responsive">
    <table class="table table-hover align-middle mb-0">
      <thead class="table-light small text-uppercase">
        <tr>
          <th>ID</th>
          <th>Customer Name</th>
          <th>Mobile</th>
          <th>Branch</th>
          <th>Agent / PSO</th>
          <th>Stage</th>
          <th>KYC Status</th>
          <th class="text-center">Action</th>
        </tr>
      </thead>
      <tbody>
        <?php foreach ($customers as $c): ?>
          <tr>
            <td>#<?= $c['id'] ?></td>
            <td class="fw-semibold">
              <a href="<?= url('/crm/' . $c['id']) ?>" class="text-teal text-decoration-none">
                <?= htmlspecialchars($c['name']) ?>
              </a>
            </td>
            <td><?= htmlspecialchars($c['phone'] ?: '-') ?></td>
            <td><span class="badge bg-light text-dark border"><?= htmlspecialchars($c['branch'] ?: '-') ?></span></td>
            <td><?= htmlspecialchars($c['agent_name'] ?: 'Unassigned') ?></td>
            <td><span class="badge bg-secondary text-capitalize"><?= str_replace('_', ' ', $c['stage']) ?></span></td>
            <td>
              <?php if ($c['kyc_status'] === 'verified'): ?>
                <span class="badge bg-success"><i class="bi bi-shield-check me-1"></i>Verified</span>
              <?php else: ?>
                <span class="badge bg-warning text-dark">Pending</span>
              <?php endif; ?>
            </td>
            <td class="text-center">
              <a href="<?= url('/crm/' . $c['id']) ?>" class="btn btn-sm btn-outline-primary py-0">View Profile</a>
            </td>
          </tr>
        <?php endforeach; ?>
        <?php if (empty($customers)): ?>
          <tr><td colspan="8" class="text-center text-muted py-4">No borrower profiles found matching criteria.</td></tr>
        <?php endif; ?>
      </tbody>
    </table>
  </div>
</div>

<!-- Modal: New Lead -->
<div class="modal fade" id="newLeadModal" tabindex="-1">
  <div class="modal-dialog">
    <form method="post" action="<?= url('/crm/new') ?>" class="modal-content">
      <?= csrf_field() ?>
      <div class="modal-header">
        <h5 class="modal-title fw-bold">Register New Customer Lead</h5>
        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
      </div>
      <div class="modal-body">
        <div class="mb-3">
          <label class="form-label small fw-semibold">Customer Full Name *</label>
          <input type="text" name="name" class="form-control" required placeholder="e.g. Sunita Devi">
        </div>
        <div class="mb-3">
          <label class="form-label small fw-semibold">Mobile Number *</label>
          <input type="tel" name="phone" class="form-control" required placeholder="10-digit mobile number">
        </div>
        <div class="mb-3">
          <label class="form-label small fw-semibold">Date of Birth</label>
          <input type="date" name="dob" class="form-control">
        </div>
        <div class="mb-3">
          <label class="form-label small fw-semibold">Operational Branch</label>
          <select name="branch" class="form-select">
            <?php foreach (Database::getBranches() as $b): ?>
              <option value="<?= htmlspecialchars($b) ?>"><?= htmlspecialchars($b) ?></option>
            <?php endforeach; ?>
          </select>
        </div>
        <div class="mb-3">
          <label class="form-label small fw-semibold">Village / Locality Address</label>
          <textarea name="address" class="form-control" rows="2" placeholder="Village, Tehsil, District..."></textarea>
        </div>
      </div>
      <div class="modal-footer">
        <button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Cancel</button>
        <button type="submit" class="btn btn-primary">Create Customer</button>
      </div>
    </form>
  </div>
</div>
