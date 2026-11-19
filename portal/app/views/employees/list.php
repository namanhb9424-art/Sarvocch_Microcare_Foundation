<div class="d-flex justify-content-between align-items-center mb-4">
  <div>
    <h3 class="fw-bold mb-0 text-teal"><i class="bi bi-person-badge me-2"></i>Staff & Employee Directory</h3>
    <div class="text-muted small">SARVOOCCH Microcare Foundation · Field Officers & Branch Staff Roster</div>
  </div>
  <?php if (can('admin')): ?>
    <button class="btn btn-primary btn-sm" data-bs-toggle="modal" data-bs-target="#newEmpModal">
      <i class="bi bi-person-plus me-1"></i> Add New Employee
    </button>
  <?php endif; ?>
</div>

<div class="card shadow-sm border-0">
  <div class="table-responsive">
    <table class="table table-hover align-middle mb-0">
      <thead class="table-light small text-uppercase">
        <tr>
          <th>Emp ID</th>
          <th>Name</th>
          <th>Designation</th>
          <th>Branch</th>
          <th>Portal Login</th>
          <th>Status</th>
          <th class="text-center">Action</th>
        </tr>
      </thead>
      <tbody>
        <?php foreach ($employees as $e): ?>
          <tr>
            <td><strong>EMP<?= sprintf('%04d', $e['id']) ?></strong></td>
            <td class="fw-semibold">
              <?= htmlspecialchars($e['name']) ?>
              <div class="text-muted small"><?= htmlspecialchars($e['phone'] ?: '') ?></div>
            </td>
            <td><?= htmlspecialchars($e['designation'] ?: 'Field Officer') ?></td>
            <td><span class="badge bg-light text-dark border"><?= htmlspecialchars($e['branch'] ?: '-') ?></span></td>
            <td>
              <code><?= htmlspecialchars($e['username'] ?: 'no login') ?></code>
              <span class="badge bg-secondary ms-1"><?= htmlspecialchars($e['role'] ?: 'field_agent') ?></span>
            </td>
            <td><span class="badge bg-<?= ($e['status'] === 'active') ? 'success' : 'danger' ?> text-capitalize"><?= $e['status'] ?></span></td>
            <td class="text-center">
              <a href="<?= url('/employees/' . $e['id'] . '/print') ?>" target="_blank" class="btn btn-sm btn-outline-secondary py-0">Dossier</a>
            </td>
          </tr>
        <?php endforeach; ?>
        <?php if (empty($employees)): ?>
          <tr><td colspan="7" class="text-center text-muted py-4">No employees registered yet.</td></tr>
        <?php endif; ?>
      </tbody>
    </table>
  </div>
</div>

<!-- Modal: New Employee -->
<div class="modal fade" id="newEmpModal" tabindex="-1">
  <div class="modal-dialog">
    <form method="post" action="<?= url('/employees/new') ?>" class="modal-content">
      <?= csrf_field() ?>
      <div class="modal-header">
        <h6 class="modal-title fw-bold">Register Employee & Create Portal Access</h6>
        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
      </div>
      <div class="modal-body small">
        <div class="mb-2">
          <label class="form-label fw-semibold mb-0">Full Name *</label>
          <input type="text" name="name" class="form-control form-control-sm" required placeholder="e.g. Ramesh Sharma">
        </div>
        <div class="mb-2">
          <label class="form-label fw-semibold mb-0">Designation *</label>
          <input type="text" name="designation" class="form-control form-control-sm" value="Field Officer / PSO">
        </div>
        <div class="row g-2 mb-2">
          <div class="col-6">
            <label class="form-label fw-semibold mb-0">Branch *</label>
            <select name="branch" class="form-select form-select-sm">
              <?php foreach ($branches as $b): ?>
                <option value="<?= htmlspecialchars($b) ?>"><?= htmlspecialchars($b) ?></option>
              <?php endforeach; ?>
            </select>
          </div>
          <div class="col-6">
            <label class="form-label fw-semibold mb-0">System Role</label>
            <select name="role" class="form-select form-select-sm">
              <option value="field_agent">Field Agent</option>
              <option value="manager">Manager</option>
              <option value="underwriter">Underwriter</option>
            </select>
          </div>
        </div>
        <div class="row g-2 mb-2">
          <div class="col-6">
            <label class="form-label fw-semibold mb-0">Mobile Number *</label>
            <input type="tel" name="phone" class="form-control form-control-sm" required placeholder="10-digit mobile">
          </div>
          <div class="col-6">
            <label class="form-label fw-semibold mb-0">Monthly Salary (₹)</label>
            <input type="number" name="salary" class="form-control form-control-sm" value="22000">
          </div>
        </div>
        <div class="mb-2">
          <label class="form-label fw-semibold mb-0">Email Address</label>
          <input type="email" name="email" class="form-control form-control-sm" placeholder="employee@sarvocchfinance.com">
        </div>
      </div>
      <div class="modal-footer">
        <button type="submit" class="btn btn-primary btn-sm">Create Employee & Login</button>
      </div>
    </form>
  </div>
</div>
