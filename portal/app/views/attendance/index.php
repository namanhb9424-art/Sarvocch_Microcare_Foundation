<div class="d-flex justify-content-between align-items-center mb-4">
  <div>
    <h3 class="fw-bold mb-0 text-teal"><i class="bi bi-clock-history me-2"></i>Attendance & Shift Records</h3>
    <div class="text-muted small">SARVOOCCH Microcare Foundation · Staff Punch Register</div>
  </div>
  <button class="btn btn-primary btn-sm" data-bs-toggle="modal" data-bs-target="#reqModal">
    <i class="bi bi-pencil-square me-1"></i> Attendance Regularization Request
  </button>
</div>

<div class="row g-4 mb-4">
  <!-- Today Punch Status -->
  <div class="col-12 col-md-4">
    <div class="card shadow-sm border-0 border-top border-teal border-3 h-100">
      <div class="card-body p-4 text-center">
        <h6 class="text-muted text-uppercase fw-semibold mb-2">Today: <?= date('d M Y') ?></h6>
        <div class="display-6 fw-bold text-dark my-2" id="clockBox"><?= date('H:i') ?></div>
        
        <?php if (!$todayRecord): ?>
          <span class="badge bg-warning text-dark mb-3">Not Punched IN Yet</span>
          <form method="post" action="<?= url('/attendance/punch') ?>">
            <?= csrf_field() ?>
            <button type="submit" class="btn btn-success w-100 fw-semibold"><i class="bi bi-box-arrow-in-right me-1"></i> Punch IN Now</button>
          </form>
        <?php elseif (!$todayRecord['out_time']): ?>
          <div class="text-success small mb-3"><i class="bi bi-check-circle"></i> In at: <strong><?= $todayRecord['in_time'] ?></strong></div>
          <form method="post" action="<?= url('/attendance/punch') ?>">
            <?= csrf_field() ?>
            <button type="submit" class="btn btn-warning w-100 fw-semibold text-dark"><i class="bi bi-box-arrow-right me-1"></i> Punch OUT Now</button>
          </form>
        <?php else: ?>
          <div class="alert alert-success small mb-0">
            Shift completed!<br>
            In: <strong><?= $todayRecord['in_time'] ?></strong> | Out: <strong><?= $todayRecord['out_time'] ?></strong>
          </div>
        <?php endif; ?>
      </div>
    </div>
  </div>

  <!-- Past 30 Days Register -->
  <div class="col-12 col-md-8">
    <div class="card shadow-sm border-0 h-100">
      <div class="card-header bg-white py-3">
        <h6 class="fw-bold mb-0 text-dark">My Recent Attendance History</h6>
      </div>
      <div class="table-responsive">
        <table class="table table-hover align-middle mb-0 small">
          <thead class="table-light">
            <tr>
              <th>Date</th>
              <th>In Time</th>
              <th>Out Time</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            <?php foreach ($myAttendance as $a): ?>
              <tr>
                <td class="fw-semibold"><?= fmt_date($a['day']) ?></td>
                <td><?= $a['in_time'] ?: '-' ?></td>
                <td><?= $a['out_time'] ?: '-' ?></td>
                <td>
                  <?php if ($a['in_time'] && $a['out_time']): ?>
                    <span class="badge bg-success">Present</span>
                  <?php else: ?>
                    <span class="badge bg-warning text-dark">In Progress</span>
                  <?php endif; ?>
                </td>
              </tr>
            <?php endforeach; ?>
            <?php if (empty($myAttendance)): ?>
              <tr><td colspan="4" class="text-center text-muted py-3">No attendance entries recorded yet.</td></tr>
            <?php endif; ?>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</div>

<!-- Regularization Requests Table -->
<div class="card shadow-sm border-0 mb-4">
  <div class="card-header bg-white py-3">
    <h6 class="fw-bold mb-0 text-dark">Attendance Regularization Requests</h6>
  </div>
  <div class="table-responsive">
    <table class="table table-hover align-middle mb-0 small">
      <thead class="table-light">
        <tr>
          <th>User</th>
          <th>Date</th>
          <th>Adjusted Timings</th>
          <th>Reason</th>
          <th>Status</th>
          <?php if (can('manager') || can('admin')): ?><th>Action</th><?php endif; ?>
        </tr>
      </thead>
      <tbody>
        <?php foreach ($requests as $r): ?>
          <tr>
            <td class="fw-semibold"><?= htmlspecialchars($r['user_name'] ?? $user['name']) ?></td>
            <td><?= fmt_date($r['day']) ?></td>
            <td><?= $r['in_time'] ?> - <?= $r['out_time'] ?></td>
            <td><?= htmlspecialchars($r['reason']) ?></td>
            <td><span class="badge bg-<?= ($r['status'] === 'approved') ? 'success' : (($r['status'] === 'rejected') ? 'danger' : 'warning text-dark') ?> text-capitalize"><?= $r['status'] ?></span></td>
            <?php if (can('manager') || can('admin')): ?>
              <td>
                <?php if ($r['status'] === 'pending'): ?>
                  <form method="post" action="<?= url('/attendance/request/' . $r['id'] . '/approve') ?>" class="d-inline">
                    <?= csrf_field() ?>
                    <button class="btn btn-sm btn-success py-0">Approve</button>
                  </form>
                  <form method="post" action="<?= url('/attendance/request/' . $r['id'] . '/reject') ?>" class="d-inline">
                    <?= csrf_field() ?>
                    <button class="btn btn-sm btn-outline-danger py-0">Reject</button>
                  </form>
                <?php else: ?>
                  <span class="text-muted small">Decided by <?= htmlspecialchars($r['decided_by'] ?: 'Admin') ?></span>
                <?php endif; ?>
              </td>
            <?php endif; ?>
          </tr>
        <?php endforeach; ?>
        <?php if (empty($requests)): ?>
          <tr><td colspan="6" class="text-center text-muted py-3">No regularization requests pending.</td></tr>
        <?php endif; ?>
      </tbody>
    </table>
  </div>
</div>

<!-- Modal: Regularization Request -->
<div class="modal fade" id="reqModal" tabindex="-1">
  <div class="modal-dialog">
    <form method="post" action="<?= url('/attendance/request') ?>" class="modal-content">
      <?= csrf_field() ?>
      <div class="modal-header">
        <h6 class="modal-title fw-bold">Regularize Attendance</h6>
        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
      </div>
      <div class="modal-body small">
        <div class="mb-3">
          <label class="form-label fw-semibold">Attendance Date *</label>
          <input type="date" name="day" class="form-control form-control-sm" required value="<?= date('Y-m-d') ?>">
        </div>
        <div class="row g-2 mb-3">
          <div class="col-6">
            <label class="form-label fw-semibold">In Time</label>
            <input type="time" name="in_time" class="form-control form-control-sm" value="09:30">
          </div>
          <div class="col-6">
            <label class="form-label fw-semibold">Out Time</label>
            <input type="time" name="out_time" class="form-control form-control-sm" value="18:30">
          </div>
        </div>
        <div class="mb-3">
          <label class="form-label fw-semibold">Reason for Manual Adjustment *</label>
          <textarea name="reason" class="form-control form-control-sm" rows="2" required placeholder="Network outage at Pipariya center..."></textarea>
        </div>
      </div>
      <div class="modal-footer">
        <button type="submit" class="btn btn-primary btn-sm">Submit Request</button>
      </div>
    </form>
  </div>
</div>

<script>
setInterval(() => {
  const d = new Date();
  document.getElementById('clockBox').innerText = d.toTimeString().substring(0,5);
}, 1000);
</script>
