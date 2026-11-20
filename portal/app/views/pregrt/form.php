<div class="d-flex justify-content-between align-items-center mb-4">
  <div>
    <h3 class="fw-bold mb-0 text-teal">
      <i class="bi bi-people-fill me-2"></i>
      <?= $group ? 'Pre-GRT Group #' . $group['id'] . ' · Center ' . htmlspecialchars($group['center_no']) . ' / Group ' . htmlspecialchars($group['group_no']) : 'New Pre-GRT Group Assessment Form' ?>
    </h3>
    <div class="text-muted small">SARVOOCCH Microcare Foundation · JLG Discipline & Group Cohesion Audit</div>
  </div>
  <div class="d-flex gap-2">
    <?php if ($group): ?>
      <?php if ($group['status'] === 'verified'): ?>
        <a href="<?= url('/pregrt/' . $group['id'] . '/apply') ?>" class="btn btn-teal text-white btn-sm" style="background-color: #0f766e;">
          <i class="bi bi-file-earmark-plus me-1"></i> Apply Group Loans
        </a>
      <?php endif; ?>
      <a href="<?= url('/pregrt/' . $group['id'] . '/print') ?>" target="_blank" class="btn btn-outline-secondary btn-sm">
        <i class="bi bi-printer me-1"></i> Print Verification Register
      </a>
    <?php endif; ?>
    <a href="<?= url('/pregrt') ?>" class="btn btn-outline-secondary btn-sm">Back</a>
  </div>
</div>

<?php if (!$group): ?>
  <!-- Create New Group -->
  <div class="card shadow-sm border-0 mb-4">
    <div class="card-header bg-white py-3">
      <h6 class="fw-bold mb-0 text-dark">Group General Information</h6>
    </div>
    <form method="post" action="<?= url('/pregrt/new') ?>" class="card-body p-4">
      <?= csrf_field() ?>
      <div class="row g-3">
        <div class="col-12 col-md-3">
          <label class="form-label small fw-semibold">Branch Location *</label>
          <select name="branch" class="form-select">
            <?php foreach (Database::getBranches() as $b): ?>
              <option value="<?= htmlspecialchars($b) ?>"><?= htmlspecialchars($b) ?></option>
            <?php endforeach; ?>
          </select>
        </div>
        <div class="col-12 col-md-3">
          <label class="form-label small fw-semibold">Center Number *</label>
          <input type="text" name="center_no" class="form-control" required placeholder="C01">
        </div>
        <div class="col-12 col-md-3">
          <label class="form-label small fw-semibold">Group Number *</label>
          <input type="text" name="group_no" class="form-control" required placeholder="G01">
        </div>
        <div class="col-12 col-md-3">
          <label class="form-label small fw-semibold">Assessment Date</label>
          <input type="date" name="form_date" class="form-control" value="<?= date('Y-m-d') ?>">
        </div>

        <div class="col-12 col-md-4">
          <label class="form-label small fw-semibold">Village / Mohalla *</label>
          <input type="text" name="village" class="form-control" required placeholder="Village Name">
        </div>
        <div class="col-12 col-md-4">
          <label class="form-label small fw-semibold">District</label>
          <input type="text" name="district" class="form-control" value="Narmadapuram">
        </div>
        <div class="col-12 col-md-4">
          <label class="form-label small fw-semibold">Field Officer (PSO Name)</label>
          <input type="text" name="pso_name" class="form-control" value="<?= htmlspecialchars($user['name'] ?? '') ?>">
        </div>
      </div>
      <div class="mt-4 text-end">
        <button type="submit" class="btn btn-primary px-4 fw-semibold">Create Pre-GRT Group & Add Members</button>
      </div>
    </form>
  </div>
<?php else: ?>
  <!-- Existing Group Details & Member Management -->
  <div class="row g-4">
    <!-- Group Members Table -->
    <div class="col-12 col-lg-8">
      <div class="card shadow-sm border-0 mb-4">
        <div class="card-header bg-white py-3 d-flex justify-content-between align-items-center">
          <h6 class="fw-bold mb-0 text-dark"><i class="bi bi-people me-1 text-teal"></i>Joint Liability Group Members (<?= count($members) ?> / 10 Max)</h6>
        </div>
        <div class="table-responsive">
          <table class="table table-hover align-middle mb-0 small">
            <thead class="table-light">
              <tr>
                <th>#</th>
                <th>Member Name</th>
                <th>Husband Name</th>
                <th>Age</th>
                <th>Aadhaar</th>
                <th class="text-end">Requested (₹)</th>
                <th>Purpose</th>
              </tr>
            </thead>
            <tbody>
              <?php foreach ($members as $m): ?>
                <tr>
                  <td><strong><?= $m['sno'] ?></strong></td>
                  <td class="fw-semibold"><?= htmlspecialchars($m['name']) ?></td>
                  <td><?= htmlspecialchars($m['husband_name'] ?: '-') ?></td>
                  <td><?= $m['age'] ?> yrs</td>
                  <td>XXXX-XXXX-<?= htmlspecialchars($m['aadhaar4'] ?: '0000') ?></td>
                  <td class="text-end fw-bold text-teal"><?= inr($m['loan_amount']) ?></td>
                  <td><?= htmlspecialchars($m['purpose'] ?: 'Dairy') ?></td>
                </tr>
              <?php endforeach; ?>
              <?php if (empty($members)): ?>
                <tr><td colspan="7" class="text-center text-muted py-3">No members added yet. Use form on the right.</td></tr>
              <?php endif; ?>
            </tbody>
          </table>
        </div>
      </div>

      <!-- Branch Manager Verification Box -->
      <?php if (can('manager') || can('underwriter') || can('admin')): ?>
        <div class="card shadow-sm border-0">
          <div class="card-header bg-white py-3">
            <h6 class="fw-bold mb-0 text-dark">Branch Manager Verification Decision</h6>
          </div>
          <form method="post" action="<?= url('/pregrt/' . $group['id'] . '/review') ?>" class="card-body p-3">
            <?= csrf_field() ?>
            <div class="mb-3">
              <label class="form-label small fw-semibold">BM Review Remarks / Observations on Group Discipline</label>
              <textarea name="review_remarks" class="form-control form-control-sm" rows="2" placeholder="Members demonstrate good peer-guarantee understanding..."><?= htmlspecialchars($group['review_remarks'] ?? '') ?></textarea>
            </div>
            <div class="d-flex gap-2">
              <button type="submit" name="decision" value="verified" class="btn btn-success btn-sm flex-fill fw-semibold">
                <i class="bi bi-check-circle me-1"></i> Pass Pre-GRT (Verified)
              </button>
              <button type="submit" name="decision" value="rejected" class="btn btn-outline-danger btn-sm flex-fill">
                <i class="bi bi-x-circle me-1"></i> Reject Group
              </button>
            </div>
          </form>
        </div>
      <?php endif; ?>
    </div>

    <!-- Add Member Form -->
    <div class="col-12 col-lg-4">
      <div class="card shadow-sm border-0 border-top border-teal border-3">
        <div class="card-header bg-white py-3">
          <h6 class="fw-bold mb-0 text-dark">+ Add Group Member</h6>
        </div>
        <form method="post" action="<?= url('/pregrt/' . $group['id']) ?>" class="card-body p-3 small">
          <?= csrf_field() ?>
          <input type="hidden" name="action" value="add_member">

          <div class="mb-2">
            <label class="form-label fw-semibold mb-0">Member Full Name *</label>
            <input type="text" name="m_name" class="form-control form-control-sm" required placeholder="e.g. Geeta Bai">
          </div>

          <div class="mb-2">
            <label class="form-label fw-semibold mb-0">Husband Name *</label>
            <input type="text" name="m_husband" class="form-control form-control-sm" required placeholder="Husband Name">
          </div>

          <div class="row g-2 mb-2">
            <div class="col-6">
              <label class="form-label fw-semibold mb-0">Age</label>
              <input type="number" name="m_age" class="form-control form-control-sm" value="30">
            </div>
            <div class="col-6">
              <label class="form-label fw-semibold mb-0">Aadhaar (Last 4)</label>
              <input type="text" name="m_aadhaar4" maxlength="4" class="form-control form-control-sm" placeholder="1234">
            </div>
          </div>

          <div class="mb-2">
            <label class="form-label fw-semibold mb-0">Annual Household Income (₹)</label>
            <input type="number" name="m_income" class="form-control form-control-sm" value="140000">
          </div>

          <div class="mb-2">
            <label class="form-label fw-semibold mb-0">Requested Loan Amount (₹)</label>
            <input type="number" name="m_amount" class="form-control form-control-sm" value="30000" step="5000">
          </div>

          <div class="mb-3">
            <label class="form-label fw-semibold mb-0">Loan Purpose</label>
            <input type="text" name="m_purpose" class="form-control form-control-sm" value="Dairy Livestock">
          </div>

          <button type="submit" class="btn btn-teal text-white w-100 btn-sm py-2 fw-semibold" style="background-color: #0f766e;">
            <i class="bi bi-person-plus me-1"></i> Add Member to Register
          </button>
        </form>
      </div>
    </div>
  </div>
<?php endif; ?>
