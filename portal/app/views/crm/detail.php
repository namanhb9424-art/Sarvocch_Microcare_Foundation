<div class="d-flex justify-content-between align-items-center mb-4">
  <div>
    <h3 class="fw-bold mb-0 text-teal"><?= htmlspecialchars($c['name']) ?></h3>
    <div class="text-muted small">Customer ID: #<?= $c['id'] ?> · Branch: <?= htmlspecialchars($c['branch']) ?></div>
  </div>
  <div class="d-flex gap-2">
    <a href="<?= url('/crm/' . $c['id'] . '/kyc-form') ?>" class="btn btn-teal text-white btn-sm" style="background-color: #0f766e;">
      <i class="bi bi-person-vcard me-1"></i> Edit KYC Form
    </a>
    <a href="<?= url('/crm/' . $c['id'] . '/kyc-form/print') ?>" target="_blank" class="btn btn-outline-secondary btn-sm">
      <i class="bi bi-printer me-1"></i> Print KYC Dossier
    </a>
    <form method="post" action="<?= url('/crm/' . $c['id'] . '/login') ?>" class="d-inline">
      <?= csrf_field() ?>
      <button type="submit" class="btn btn-outline-primary btn-sm">
        <i class="bi bi-key me-1"></i> <?= $portalUser ? 'Reset Portal Password' : 'Create Portal Access' ?>
      </button>
    </form>
  </div>
</div>

<div class="row g-4">
  <!-- Profile Summary -->
  <div class="col-12 col-lg-4">
    <div class="card shadow-sm border-0 mb-4">
      <div class="card-header bg-white py-3">
        <h6 class="fw-bold mb-0 text-dark">Profile Details</h6>
      </div>
      <div class="card-body p-3">
        <div class="mb-2"><strong>Mobile:</strong> <?= htmlspecialchars($c['phone'] ?: '-') ?></div>
        <div class="mb-2"><strong>Date of Birth:</strong> <?= fmt_date($c['dob']) ?></div>
        <div class="mb-2"><strong>Address:</strong> <?= htmlspecialchars($c['address'] ?: '-') ?></div>
        <div class="mb-2"><strong>Aadhaar:</strong> <?= $c['aadhaar'] ? '•••• •••• ' . substr($c['aadhaar'], -4) : 'Pending' ?></div>
        <div class="mb-2"><strong>PAN Card:</strong> <?= htmlspecialchars($c['pan'] ?: 'Pending') ?></div>
        <div class="mb-2"><strong>KYC Status:</strong> <span class="badge bg-<?= ($c['kyc_status'] === 'verified') ? 'success' : 'warning text-dark' ?>"><?= ucfirst($c['kyc_status']) ?></span></div>
        <div class="mb-3"><strong>Assigned Officer:</strong> <?= htmlspecialchars($c['agent_name'] ?: 'Unassigned') ?></div>

        <form method="post" action="<?= url('/crm/' . $c['id'] . '/stage') ?>" class="pt-2 border-top">
          <?= csrf_field() ?>
          <label class="form-label small fw-semibold">Update Pipeline Stage</label>
          <div class="input-group input-group-sm">
            <select name="stage" class="form-select">
              <option value="lead" <?= ($c['stage'] === 'lead') ? 'selected' : '' ?>>Lead</option>
              <option value="in_verification" <?= ($c['stage'] === 'in_verification') ? 'selected' : '' ?>>In Verification</option>
              <option value="kyc_done" <?= ($c['stage'] === 'kyc_done') ? 'selected' : '' ?>>KYC Done</option>
              <option value="loan_active" <?= ($c['stage'] === 'loan_active') ? 'selected' : '' ?>>Loan Active</option>
            </select>
            <button type="submit" class="btn btn-outline-secondary">Update</button>
          </div>
        </form>
      </div>
    </div>

    <!-- Communication Log -->
    <div class="card shadow-sm border-0">
      <div class="card-header bg-white py-3">
        <h6 class="fw-bold mb-0 text-dark">Interaction History</h6>
      </div>
      <div class="card-body p-3">
        <form method="post" action="<?= url('/crm/' . $c['id'] . '/log') ?>" class="mb-3">
          <?= csrf_field() ?>
          <div class="input-group input-group-sm mb-2">
            <select name="channel" class="form-select" style="max-width: 100px;">
              <option>Call</option>
              <option>Visit</option>
              <option>Center</option>
              <option>WhatsApp</option>
            </select>
            <input type="text" name="note" class="form-control" placeholder="Add interaction note..." required>
            <button type="submit" class="btn btn-primary">Log</button>
          </div>
        </form>

        <div class="small" style="max-height: 250px; overflow-y: auto;">
          <?php foreach ($logs as $l): ?>
            <div class="p-2 border-bottom">
              <div class="d-flex justify-content-between text-muted" style="font-size: 0.75rem;">
                <span class="badge bg-light text-dark border"><?= $l['channel'] ?></span>
                <span><?= fmt_date($l['at']) ?></span>
              </div>
              <div class="mt-1"><?= htmlspecialchars($l['note']) ?></div>
              <div class="text-muted" style="font-size: 0.7rem;">by <?= htmlspecialchars($l['by_name']) ?></div>
            </div>
          <?php endforeach; ?>
        </div>
      </div>
    </div>
  </div>

  <!-- Applications and Loans -->
  <div class="col-12 col-lg-8">
    <!-- Active Loans -->
    <div class="card shadow-sm border-0 mb-4">
      <div class="card-header bg-white py-3">
        <h6 class="fw-bold mb-0 text-dark"><i class="bi bi-cash-coin me-1 text-teal"></i>Active Loans</h6>
      </div>
      <div class="table-responsive">
        <table class="table table-hover align-middle mb-0 small">
          <thead class="table-light">
            <tr>
              <th>Loan #</th>
              <th>Product</th>
              <th class="text-end">Principal</th>
              <th class="text-end">Monthly EMI</th>
              <th>Status</th>
              <th class="text-center">Action</th>
            </tr>
          </thead>
          <tbody>
            <?php foreach ($loans as $l): ?>
              <tr>
                <td><strong>#<?= $l['id'] ?></strong></td>
                <td><?= htmlspecialchars($l['product_name']) ?></td>
                <td class="text-end fw-semibold"><?= inr($l['principal']) ?></td>
                <td class="text-end fw-bold text-teal"><?= inr($l['emi']) ?></td>
                <td><span class="badge bg-<?= ($l['status'] === 'active') ? 'success' : 'secondary' ?>"><?= ucfirst($l['status']) ?></span></td>
                <td class="text-center">
                  <a href="<?= url('/loans/' . $l['id']) ?>" class="btn btn-sm btn-outline-primary py-0">View Loan</a>
                </td>
              </tr>
            <?php endforeach; ?>
            <?php if (empty($loans)): ?>
              <tr><td colspan="6" class="text-center text-muted py-3">No active loans found for this customer.</td></tr>
            <?php endif; ?>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Loan Applications -->
    <div class="card shadow-sm border-0">
      <div class="card-header bg-white py-3 d-flex justify-content-between align-items-center">
        <h6 class="fw-bold mb-0 text-dark"><i class="bi bi-file-earmark-text me-1 text-teal"></i>Loan Applications</h6>
        <a href="<?= url('/apply') ?>" class="btn btn-sm btn-outline-teal">+ New Application</a>
      </div>
      <div class="table-responsive">
        <table class="table table-hover align-middle mb-0 small">
          <thead class="table-light">
            <tr>
              <th>App #</th>
              <th>Product</th>
              <th class="text-end">Requested</th>
              <th>Tenure</th>
              <th>Status</th>
              <th class="text-center">Action</th>
            </tr>
          </thead>
          <tbody>
            <?php foreach ($applications as $a): ?>
              <tr>
                <td>#<?= $a['id'] ?></td>
                <td><?= htmlspecialchars($a['product_name']) ?></td>
                <td class="text-end fw-semibold"><?= inr($a['amount']) ?></td>
                <td><?= $a['tenure'] ?> Mos</td>
                <td><span class="badge bg-secondary text-capitalize"><?= $a['status'] ?></span></td>
                <td class="text-center">
                  <a href="<?= url('/applications/' . $a['id']) ?>" class="btn btn-sm btn-outline-secondary py-0">View</a>
                </td>
              </tr>
            <?php endforeach; ?>
            <?php if (empty($applications)): ?>
              <tr><td colspan="6" class="text-center text-muted py-3">No applications submitted yet.</td></tr>
            <?php endif; ?>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</div>
