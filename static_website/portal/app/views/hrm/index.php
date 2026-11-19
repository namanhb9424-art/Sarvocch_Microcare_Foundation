<div class="d-flex justify-content-between align-items-center mb-4">
  <div>
    <h3 class="fw-bold mb-0 text-teal"><i class="bi bi-briefcase me-2"></i>Human Resource Management</h3>
    <div class="text-muted small">SARVOOCCH Microcare Foundation · Leaves, Sanctions & Staff Performance</div>
  </div>
  <button class="btn btn-primary btn-sm" data-bs-toggle="modal" data-bs-target="#leaveModal">
    <i class="bi bi-calendar-plus me-1"></i> Apply For Leave
  </button>
</div>

<div class="row g-4">
  <!-- Leaves Register -->
  <div class="col-12 col-lg-7">
    <div class="card shadow-sm border-0 mb-4">
      <div class="card-header bg-white py-3">
        <h6 class="fw-bold mb-0 text-dark"><i class="bi bi-calendar2-week me-1 text-teal"></i>Staff Leave Requests</h6>
      </div>
      <div class="table-responsive">
        <table class="table table-hover align-middle mb-0 small">
          <thead class="table-light">
            <tr>
              <th>Employee</th>
              <th>Period</th>
              <th>Reason</th>
              <th>Status</th>
              <?php if (can('manager') || can('admin')): ?><th>Decision</th><?php endif; ?>
            </tr>
          </thead>
          <tbody>
            <?php foreach ($leaves as $l): ?>
              <tr>
                <td class="fw-semibold"><?= htmlspecialchars($l['employee_name'] ?? $user['name']) ?></td>
                <td><?= fmt_date($l['from_d']) ?> to <?= fmt_date($l['to_d']) ?></td>
                <td><?= htmlspecialchars($l['reason']) ?></td>
                <td><span class="badge bg-<?= ($l['status'] === 'approved') ? 'success' : (($l['status'] === 'rejected') ? 'danger' : 'warning text-dark') ?> text-capitalize"><?= $l['status'] ?></span></td>
                <?php if (can('manager') || can('admin')): ?>
                  <td>
                    <?php if ($l['status'] === 'pending'): ?>
                      <form method="post" action="<?= url('/hrm/leave/' . $l['id'] . '/approve') ?>" class="d-inline">
                        <?= csrf_field() ?>
                        <button class="btn btn-sm btn-success py-0">Approve</button>
                      </form>
                      <form method="post" action="<?= url('/hrm/leave/' . $l['id'] . '/reject') ?>" class="d-inline">
                        <?= csrf_field() ?>
                        <button class="btn btn-sm btn-outline-danger py-0">Reject</button>
                      </form>
                    <?php endif; ?>
                  </td>
                <?php endif; ?>
              </tr>
            <?php endforeach; ?>
            <?php if (empty($leaves)): ?>
              <tr><td colspan="5" class="text-center text-muted py-3">No leave applications registered.</td></tr>
            <?php endif; ?>
          </tbody>
        </table>
      </div>
    </div>
  </div>

  <!-- Performance Reviews -->
  <div class="col-12 col-lg-5">
    <div class="card shadow-sm border-0 mb-4">
      <div class="card-header bg-white py-3 d-flex justify-content-between align-items-center">
        <h6 class="fw-bold mb-0 text-dark"><i class="bi bi-star me-1 text-warning"></i>Performance Ratings</h6>
        <?php if (can('manager') || can('admin')): ?>
          <button class="btn btn-sm btn-outline-teal" data-bs-toggle="modal" data-bs-target="#perfModal">+ Add Review</button>
        <?php endif; ?>
      </div>
      <div class="card-body p-3 small" style="max-height: 300px; overflow-y: auto;">
        <?php foreach ($perf as $p): ?>
          <div class="p-2 border-bottom">
            <div class="d-flex justify-content-between fw-semibold">
              <span><?= htmlspecialchars($p['employee_name']) ?></span>
              <span class="text-warning"><?= str_repeat('★', $p['rating']) ?></span>
            </div>
            <div class="text-muted" style="font-size: 0.75rem;">Period: <?= htmlspecialchars($p['period']) ?> by <?= htmlspecialchars($p['by_name']) ?></div>
            <div class="mt-1"><?= htmlspecialchars($p['notes']) ?></div>
          </div>
        <?php endforeach; ?>
      </div>
    </div>
  </div>
</div>

<!-- Modal: Apply Leave -->
<div class="modal fade" id="leaveModal" tabindex="-1">
  <div class="modal-dialog">
    <form method="post" action="<?= url('/hrm/leave') ?>" class="modal-content">
      <?= csrf_field() ?>
      <div class="modal-header">
        <h6 class="modal-title fw-bold">Submit Leave Application</h6>
        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
      </div>
      <div class="modal-body small">
        <div class="row g-2 mb-2">
          <div class="col-6">
            <label class="form-label fw-semibold">From Date *</label>
            <input type="date" name="from_d" class="form-control form-control-sm" required value="<?= date('Y-m-d') ?>">
          </div>
          <div class="col-6">
            <label class="form-label fw-semibold">To Date *</label>
            <input type="date" name="to_d" class="form-control form-control-sm" required value="<?= date('Y-m-d') ?>">
          </div>
        </div>
        <div class="mb-2">
          <label class="form-label fw-semibold">Reason for Leave *</label>
          <textarea name="reason" class="form-control form-control-sm" rows="3" required placeholder="Personal reason, family emergency..."></textarea>
        </div>
      </div>
      <div class="modal-footer">
        <button type="submit" class="btn btn-primary btn-sm">Submit Leave Request</button>
      </div>
    </form>
  </div>
</div>

<!-- Modal: Add Performance Review -->
<div class="modal fade" id="perfModal" tabindex="-1">
  <div class="modal-dialog">
    <form method="post" action="<?= url('/hrm/perf') ?>" class="modal-content">
      <?= csrf_field() ?>
      <div class="modal-header">
        <h6 class="modal-title fw-bold">Record Staff Performance Review</h6>
        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
      </div>
      <div class="modal-body small">
        <div class="mb-2">
          <label class="form-label fw-semibold">Select Employee *</label>
          <select name="user_id" class="form-select form-select-sm" required>
            <?php foreach ($employees as $e): ?>
              <option value="<?= $e['user_id'] ?>"><?= htmlspecialchars($e['name']) ?> (<?= htmlspecialchars($e['branch']) ?>)</option>
            <?php endforeach; ?>
          </select>
        </div>
        <div class="row g-2 mb-2">
          <div class="col-6">
            <label class="form-label fw-semibold">Review Period</label>
            <input type="text" name="period" class="form-control form-control-sm" value="<?= date('M Y') ?>">
          </div>
          <div class="col-6">
            <label class="form-label fw-semibold">Rating (1 to 5 Stars)</label>
            <select name="rating" class="form-select form-select-sm">
              <option value="5">5 - Excellent (100% Recovery)</option>
              <option value="4">4 - Very Good</option>
              <option value="3">3 - Satisfactory</option>
              <option value="2">2 - Needs Improvement</option>
              <option value="1">1 - Unsatisfactory</option>
            </select>
          </div>
        </div>
        <div class="mb-2">
          <label class="form-label fw-semibold">Evaluation Notes</label>
          <textarea name="notes" class="form-control form-control-sm" rows="2" placeholder="Exceeded monthly center meeting targets..."></textarea>
        </div>
      </div>
      <div class="modal-footer">
        <button type="submit" class="btn btn-primary btn-sm">Save Rating</button>
      </div>
    </form>
  </div>
</div>
