<div class="d-flex justify-content-between align-items-center mb-4">
  <div>
    <h3 class="fw-bold mb-0 text-teal"><i class="bi bi-building me-2"></i>Branch Network & Geofence Boundaries</h3>
    <div class="text-muted small">SARVOOCCH Microcare Foundation · Branch Operations Hubs</div>
  </div>
  <?php if (can('admin')): ?>
    <button class="btn btn-primary btn-sm" data-bs-toggle="modal" data-bs-target="#newBranchModal">
      <i class="bi bi-plus-circle me-1"></i> Add New Branch
    </button>
  <?php endif; ?>
</div>

<div class="card shadow-sm border-0">
  <div class="table-responsive">
    <table class="table table-hover align-middle mb-0">
      <thead class="table-light small text-uppercase">
        <tr>
          <th>Branch Code</th>
          <th>Branch Name</th>
          <th>Operating Address</th>
          <th>Helpline / Contact</th>
          <th class="text-center">Staff Count</th>
          <th class="text-center">Active Loans</th>
          <th class="text-center">Action</th>
        </tr>
      </thead>
      <tbody>
        <?php foreach ($branches as $b): ?>
          <tr>
            <td><span class="badge bg-teal text-white"><?= htmlspecialchars($b['code']) ?></span></td>
            <td class="fw-semibold">
              <a href="<?= url('/branches/' . $b['id'] . '/details') ?>" class="text-dark text-decoration-none">
                <?= htmlspecialchars($b['name']) ?>
              </a>
              <?php if (str_contains($b['name'], 'Pipariya')): ?>
                <span class="badge bg-warning text-dark ms-1">MFI Hub</span>
              <?php endif; ?>
            </td>
            <td class="text-muted small"><?= htmlspecialchars($b['address'] ?: 'Official Location') ?></td>
            <td><?= htmlspecialchars($b['phone'] ?: '-') ?></td>
            <td class="text-center"><?= $b['staff_count'] ?></td>
            <td class="text-center fw-bold text-teal"><?= $b['active_loans'] ?></td>
            <td class="text-center">
              <a href="<?= url('/branches/' . $b['id'] . '/details') ?>" class="btn btn-sm btn-outline-primary py-0">View Details</a>
            </td>
          </tr>
        <?php endforeach; ?>
      </tbody>
    </table>
  </div>
</div>

<!-- Modal: New Branch -->
<div class="modal fade" id="newBranchModal" tabindex="-1">
  <div class="modal-dialog">
    <form method="post" action="<?= url('/branches') ?>" class="modal-content">
      <?= csrf_field() ?>
      <div class="modal-header">
        <h6 class="modal-title fw-bold">Configure New Branch Hub</h6>
        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
      </div>
      <div class="modal-body small">
        <div class="row g-2 mb-2">
          <div class="col-8">
            <label class="form-label fw-semibold mb-0">Branch Name *</label>
            <input type="text" name="name" class="form-control form-control-sm" required placeholder="e.g. Hoshangabad Branch">
          </div>
          <div class="col-4">
            <label class="form-label fw-semibold mb-0">Code *</label>
            <input type="text" name="code" class="form-control form-control-sm text-uppercase" required placeholder="HGB">
          </div>
        </div>
        <div class="mb-2">
          <label class="form-label fw-semibold mb-0">Address</label>
          <textarea name="address" class="form-control form-control-sm" rows="2" placeholder="Full postal address..."></textarea>
        </div>
        <div class="row g-2 mb-2">
          <div class="col-6">
            <label class="form-label fw-semibold mb-0">Contact Phone</label>
            <input type="tel" name="phone" class="form-control form-control-sm" placeholder="10-digit mobile">
          </div>
          <div class="col-6">
            <label class="form-label fw-semibold mb-0">Branch Manager / Head</label>
            <input type="text" name="head_name" class="form-control form-control-sm" placeholder="Manager Name">
          </div>
        </div>
        <div class="row g-2 mb-2">
          <div class="col-6">
            <label class="form-label fw-semibold mb-0">Latitude</label>
            <input type="text" name="lat" class="form-control form-control-sm" placeholder="22.7387">
          </div>
          <div class="col-6">
            <label class="form-label fw-semibold mb-0">Longitude</label>
            <input type="text" name="lng" class="form-control form-control-sm" placeholder="78.3563">
          </div>
        </div>
      </div>
      <div class="modal-footer">
        <button type="submit" class="btn btn-primary btn-sm">Save Branch Hub</button>
      </div>
    </form>
  </div>
</div>
