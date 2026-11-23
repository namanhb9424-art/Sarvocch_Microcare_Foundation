<div class="d-flex justify-content-between align-items-center mb-3">
  <div>
    <h3 class="fw-bold mb-0 text-teal"><i class="bi bi-shield-check me-2"></i>Grievance Investigation #<?= htmlspecialchars($grievance['ticket_no'] ?? $grievance['id']) ?></h3>
    <div class="text-muted small">SARVOOCCH Microcare Foundation · Grievance Redressal Audit Trail</div>
  </div>
  <a href="<?= url('/grievances') ?>" class="btn btn-outline-secondary btn-sm">
    <i class="bi bi-arrow-left me-1"></i> Back to Register
  </a>
</div>

<div class="row g-3">
  <div class="col-12 col-lg-7">
    <div class="card shadow-sm border-0 mb-3">
      <div class="card-header bg-white fw-bold py-3">
        <i class="bi bi-file-text me-2"></i>Complaint Specifics
      </div>
      <div class="card-body">
        <div class="row g-2 mb-3">
          <div class="col-sm-6">
            <span class="text-muted small d-block">Complainant Name</span>
            <strong><?= htmlspecialchars($grievance['name']) ?></strong>
          </div>
          <div class="col-sm-6">
            <span class="text-muted small d-block">Contact Phone</span>
            <strong><?= htmlspecialchars($grievance['phone']) ?></strong>
          </div>
          <div class="col-sm-6">
            <span class="text-muted small d-block">Category</span>
            <span class="badge bg-secondary"><?= htmlspecialchars($grievance['category']) ?></span>
          </div>
          <div class="col-sm-6">
            <span class="text-muted small d-block">Branch</span>
            <strong><?= htmlspecialchars($grievance['branch'] ?? 'Bhopal Head Office') ?></strong>
          </div>
          <div class="col-12">
            <span class="text-muted small d-block">Submission Timestamp</span>
            <span><?= htmlspecialchars($grievance['created_at']) ?></span>
          </div>
        </div>

        <div class="p-3 bg-light rounded border">
          <label class="form-label small fw-bold text-muted text-uppercase mb-1">Detailed Grievance Narrative:</label>
          <p class="mb-0 text-dark"><?= nl2br(htmlspecialchars($grievance['details'])) ?></p>
        </div>
      </div>
    </div>
  </div>

  <div class="col-12 col-lg-5">
    <div class="card shadow-sm border-0">
      <div class="card-header bg-white fw-bold py-3">
        <i class="bi bi-pencil-square me-2"></i>GRO Investigation & Action
      </div>
      <div class="card-body">
        <form method="post" action="<?= url('/grievances/' . $grievance['id'] . '/update') ?>">
          <?= csrf_field() ?>
          
          <div class="mb-3">
            <label class="form-label small fw-bold">Investigation Status</label>
            <select name="status" class="form-select">
              <option value="open" <?= ($grievance['status'] === 'open') ? 'selected' : '' ?>>Open / Awaiting Review</option>
              <option value="in_progress" <?= ($grievance['status'] === 'in_progress') ? 'selected' : '' ?>>In Progress / Field Enquiry</option>
              <option value="resolved" <?= ($grievance['status'] === 'resolved') ? 'selected' : '' ?>>Resolved & Customer Informed</option>
              <option value="rejected" <?= ($grievance['status'] === 'rejected') ? 'selected' : '' ?>>Rejected / Non-actionable</option>
            </select>
          </div>

          <div class="mb-3">
            <label class="form-label small fw-bold">Assigned Investigation Officer</label>
            <select name="assigned_to" class="form-select">
              <option value="">Unassigned</option>
              <?php foreach ($staff as $s): ?>
                <option value="<?= $s['id'] ?>" <?= ($grievance['assigned_to'] == $s['id']) ? 'selected' : '' ?>><?= htmlspecialchars($s['name']) ?></option>
              <?php endforeach; ?>
            </select>
          </div>

          <div class="mb-3">
            <label class="form-label small fw-bold">Resolution Notes / Action Taken</label>
            <textarea name="resolution_notes" rows="4" class="form-control" placeholder="Describe findings, communication with borrower, or corrective measures..."><?= htmlspecialchars($grievance['resolution_notes'] ?? '') ?></textarea>
          </div>

          <button type="submit" class="btn btn-primary w-100">
            <i class="bi bi-check2-circle me-1"></i> Save Audit Decision
          </button>
        </form>
      </div>
    </div>
  </div>
</div>
