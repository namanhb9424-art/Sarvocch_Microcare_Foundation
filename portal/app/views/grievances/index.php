<div class="d-flex justify-content-between align-items-center mb-3">
  <div>
    <h3 class="fw-bold mb-0 text-teal"><i class="bi bi-shield-exclamation me-2"></i>Grievance Redressal Register</h3>
    <div class="text-muted small">SARVOOCCH Microcare Foundation · Customer Complaint & Fair Practice Code Tracking</div>
  </div>
</div>

<div class="card shadow-sm border-0 mb-3">
  <div class="card-body p-3">
    <form method="get" action="<?= url('/grievances') ?>" class="row g-2 align-items-end">
      <div class="col-6 col-md-4">
        <label class="form-label small mb-0">Status</label>
        <select name="status" class="form-select form-select-sm">
          <option value="">All Statuses</option>
          <option value="open" <?= ($status === 'open') ? 'selected' : '' ?>>Open</option>
          <option value="in_progress" <?= ($status === 'in_progress') ? 'selected' : '' ?>>In Progress</option>
          <option value="resolved" <?= ($status === 'resolved') ? 'selected' : '' ?>>Resolved</option>
          <option value="rejected" <?= ($status === 'rejected') ? 'selected' : '' ?>>Rejected</option>
        </select>
      </div>
      <div class="col-6 col-md-4">
        <label class="form-label small mb-0">Branch</label>
        <select name="branch" class="form-select form-select-sm">
          <option value="">All Branches</option>
          <?php foreach ($branches as $b): ?>
            <option value="<?= htmlspecialchars($b['name']) ?>" <?= ($selected_branch === $b['name']) ? 'selected' : '' ?>><?= htmlspecialchars($b['name']) ?></option>
          <?php endforeach; ?>
        </select>
      </div>
      <div class="col-12 col-md-4 d-flex gap-1">
        <button type="submit" class="btn btn-sm btn-primary flex-fill"><i class="bi bi-funnel me-1"></i>Filter</button>
        <a href="<?= url('/grievances') ?>" class="btn btn-sm btn-outline-secondary">Reset</a>
      </div>
    </form>
  </div>
</div>

<div class="card shadow-sm border-0">
  <div class="table-responsive">
    <table class="table table-hover align-middle mb-0">
      <thead class="table-light small text-uppercase">
        <tr>
          <th>Ticket #</th>
          <th>Complainant</th>
          <th>Mobile</th>
          <th>Category</th>
          <th>Branch</th>
          <th>Status</th>
          <th>Date Filed</th>
          <th>Action</th>
        </tr>
      </thead>
      <tbody>
        <?php if (empty($grievances)): ?>
          <tr><td colspan="8" class="text-center text-muted py-4">No grievance complaints filed. All customer communications in good order.</td></tr>
        <?php else: ?>
          <?php foreach ($grievances as $g): ?>
            <tr>
              <td class="fw-bold">#<?= htmlspecialchars($g['ticket_no'] ?? $g['id']) ?></td>
              <td><?= htmlspecialchars($g['name']) ?></td>
              <td><i class="bi bi-telephone text-muted me-1"></i><?= htmlspecialchars($g['phone']) ?></td>
              <td><span class="badge bg-secondary"><?= htmlspecialchars($g['category']) ?></span></td>
              <td><?= htmlspecialchars($g['branch'] ?? 'Bhopal Head Office') ?></td>
              <td>
                <?php
                  $badgeClass = match($g['status'] ?? 'open') {
                    'open' => 'bg-danger',
                    'in_progress' => 'bg-warning text-dark',
                    'resolved' => 'bg-success',
                    default => 'bg-secondary'
                  };
                ?>
                <span class="badge <?= $badgeClass ?>"><?= strtoupper(htmlspecialchars($g['status'] ?? 'open')) ?></span>
              </td>
              <td class="small text-muted"><?= htmlspecialchars(substr($g['created_at'] ?? '', 0, 16)) ?></td>
              <td>
                <a href="<?= url('/grievances/' . $g['id']) ?>" class="btn btn-sm btn-outline-primary">
                  <i class="bi bi-eye me-1"></i>Investigate
                </a>
              </td>
            </tr>
          <?php endforeach; ?>
        <?php endif; ?>
      </tbody>
    </table>
  </div>
</div>
