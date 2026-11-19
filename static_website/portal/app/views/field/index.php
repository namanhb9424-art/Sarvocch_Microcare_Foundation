<div class="d-flex justify-content-between align-items-center mb-4">
  <div>
    <h3 class="fw-bold mb-0 text-teal"><i class="bi bi-geo-alt me-2"></i>Field Operations & Collection Routes</h3>
    <div class="text-muted small">SARVOOCCH Microcare Foundation · Agent Task Clusters & GPS Attendance</div>
  </div>
  <div class="d-flex gap-2">
    <?php if (!$att): ?>
      <button class="btn btn-success btn-sm" onclick="punchNow()"><i class="bi bi-box-arrow-in-right me-1"></i> Punch In (Field)</button>
    <?php elseif (!$att['out_time']): ?>
      <button class="btn btn-warning btn-sm text-dark" onclick="punchNow()"><i class="bi bi-box-arrow-right me-1"></i> Punch Out</button>
    <?php else: ?>
      <span class="badge bg-secondary">Shift Done (<?= $att['in_time'] ?> - <?= $att['out_time'] ?>)</span>
    <?php endif; ?>
  </div>
</div>

<!-- Task Clustering Summary -->
<div class="row g-3 mb-4">
  <div class="col-12 col-md-4">
    <div class="card shadow-sm border-0 border-start border-teal border-4 h-100">
      <div class="card-body p-3">
        <div class="text-muted small text-uppercase fw-semibold">Open Field Visits</div>
        <div class="fs-4 fw-bold mt-1 text-teal"><?= count($tasks) ?> Tasks</div>
        <div class="small text-muted">Organized into <?= count($clusters) ?> Route Clusters</div>
      </div>
    </div>
  </div>

  <div class="col-12 col-md-8">
    <div class="card shadow-sm border-0 h-100">
      <div class="card-body p-3">
        <div class="small fw-bold text-dark mb-2">Route Optimization Clusters (Within 3km Proximity)</div>
        <div class="d-flex flex-wrap gap-2">
          <?php foreach ($clusters as $cl): ?>
            <span class="badge bg-light text-dark border p-2">
              <i class="bi bi-pin-map-fill text-danger me-1"></i> <?= htmlspecialchars($cl['name']) ?>: <strong><?= count($cl['tasks']) ?> visits</strong>
            </span>
          <?php endforeach; ?>
        </div>
      </div>
    </div>
  </div>
</div>

<!-- Tasks Table -->
<div class="card shadow-sm border-0 mb-4">
  <div class="card-header bg-white py-3">
    <h6 class="fw-bold mb-0 text-dark">Scheduled Field Visits & Collections</h6>
  </div>
  <div class="table-responsive">
    <table class="table table-hover align-middle mb-0 small">
      <thead class="table-light">
        <tr>
          <th>Task Title</th>
          <th>Borrower</th>
          <th>Address</th>
          <th>Due Date</th>
          <th>Status</th>
          <th class="text-center">Action</th>
        </tr>
      </thead>
      <tbody>
        <?php foreach ($tasks as $t): ?>
          <tr>
            <td class="fw-semibold"><?= htmlspecialchars($t['title']) ?></td>
            <td><?= htmlspecialchars($t['customer_name'] ?: 'Unassigned') ?> (<?= htmlspecialchars($t['phone'] ?: '') ?>)</td>
            <td class="text-muted"><?= htmlspecialchars($t['address'] ?: 'Local Center') ?></td>
            <td><?= fmt_date($t['due_date']) ?></td>
            <td><span class="badge bg-<?= ($t['status'] === 'done') ? 'success' : 'warning text-dark' ?>"><?= ucfirst($t['status']) ?></span></td>
            <td class="text-center">
              <?php if ($t['status'] === 'open'): ?>
                <button class="btn btn-sm btn-outline-success py-0" data-bs-toggle="modal" data-bs-target="#doneModal<?= $t['id'] ?>">Mark Done</button>

                <!-- Modal -->
                <div class="modal fade" id="doneModal<?= $t['id'] ?>" tabindex="-1">
                  <div class="modal-dialog">
                    <form method="post" action="<?= url('/field/task/' . $t['id'] . '/done') ?>" class="modal-content text-start">
                      <?= csrf_field() ?>
                      <div class="modal-header">
                        <h6 class="modal-title fw-bold">Complete Task: <?= htmlspecialchars($t['title']) ?></h6>
                        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                      </div>
                      <div class="modal-body">
                        <div class="mb-3">
                          <label class="form-label small fw-semibold">Amount Collected (₹)</label>
                          <input type="number" name="collected" class="form-control" value="0">
                        </div>
                        <div class="mb-3">
                          <label class="form-label small fw-semibold">Field Observation Notes</label>
                          <textarea name="notes" class="form-control" rows="2" placeholder="Borrower met at center..."></textarea>
                        </div>
                      </div>
                      <div class="modal-footer">
                        <button type="submit" class="btn btn-success btn-sm">Submit Completion</button>
                      </div>
                    </form>
                  </div>
                </div>
              <?php else: ?>
                <span class="text-success small fw-semibold">Collected <?= inr($t['collected']) ?></span>
              <?php endif; ?>
            </td>
          </tr>
        <?php endforeach; ?>
        <?php if (empty($tasks)): ?>
          <tr><td colspan="6" class="text-center text-muted py-3">No field visits scheduled today.</td></tr>
        <?php endif; ?>
      </tbody>
    </table>
  </div>
</div>

<form id="punchForm" method="post" action="<?= url('/field/attendance') ?>" style="display: none;">
  <?= csrf_field() ?>
  <input type="hidden" name="lat" id="pLat">
  <input type="hidden" name="lng" id="pLng">
</form>

<script>
function punchNow() {
  if (navigator.geolocation) {
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        document.getElementById('pLat').value = pos.coords.latitude;
        document.getElementById('pLng').value = pos.coords.longitude;
        document.getElementById('punchForm').submit();
      },
      (err) => {
        document.getElementById('punchForm').submit();
      }
    );
  } else {
    document.getElementById('punchForm').submit();
  }
}
</script>
