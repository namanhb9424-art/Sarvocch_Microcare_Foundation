<div class="d-flex justify-content-between align-items-center mb-4">
  <div>
    <h3 class="fw-bold mb-0 text-teal"><i class="bi bi-gear me-2"></i>Platform Configuration & Bank Holidays</h3>
    <div class="text-muted small">SARVOOCCH Microcare Foundation · Admin Business Rules & Compliance Controls</div>
  </div>
</div>

<div class="row g-4">
  <!-- Business Rules -->
  <div class="col-12 col-lg-6">
    <div class="card shadow-sm border-0 h-100">
      <div class="card-header bg-white py-3">
        <h6 class="fw-bold mb-0 text-dark">Business Rules & Lending Constraints</h6>
      </div>
      <form method="post" action="<?= url('/settings') ?>" class="card-body p-4">
        <?= csrf_field() ?>
        <input type="hidden" name="action" value="save">

        <?php foreach ($defs as [$key, $label, $default, $kind]): ?>
          <div class="mb-3">
            <label class="form-label small fw-semibold"><?= htmlspecialchars($label) ?></label>
            <input type="number" step="<?= ($kind === 'int') ? '1' : '0.01' ?>" name="<?= $key ?>" class="form-control form-control-sm" value="<?= htmlspecialchars((string)($cfg[$key] ?? $default)) ?>">
          </div>
        <?php endforeach; ?>

        <div class="mt-4">
          <button type="submit" class="btn btn-teal text-white w-100 py-2 fw-semibold" style="background-color: #0f766e;">
            <i class="bi bi-save me-1"></i> Save Platform Parameters
          </button>
        </div>
      </form>
    </div>
  </div>

  <!-- Holidays Calendar -->
  <div class="col-12 col-lg-6">
    <div class="card shadow-sm border-0 h-100">
      <div class="card-header bg-white py-3">
        <h6 class="fw-bold mb-0 text-dark">Public & Banking Holidays (EMI Dates Skip These)</h6>
      </div>
      <div class="card-body p-4">
        <form method="post" action="<?= url('/settings') ?>" class="row g-2 mb-3">
          <?= csrf_field() ?>
          <input type="hidden" name="action" value="add_holiday">
          <div class="col-5">
            <input type="date" name="day" class="form-control form-control-sm" required>
          </div>
          <div class="col-5">
            <input type="text" name="name" class="form-control form-control-sm" placeholder="Holiday Name" required>
          </div>
          <div class="col-2">
            <button type="submit" class="btn btn-primary btn-sm w-100">Add</button>
          </div>
        </form>

        <div class="table-responsive" style="max-height: 350px; overflow-y: auto;">
          <table class="table table-hover align-middle mb-0 small">
            <thead class="table-light">
              <tr>
                <th>Date</th>
                <th>Holiday Name</th>
                <th class="text-end">Action</th>
              </tr>
            </thead>
            <tbody>
              <?php foreach ($holidays as $h): ?>
                <tr>
                  <td class="fw-semibold"><?= fmt_date($h['day']) ?></td>
                  <td><?= htmlspecialchars($h['name']) ?></td>
                  <td class="text-end">
                    <form method="post" action="<?= url('/settings') ?>" class="d-inline">
                      <?= csrf_field() ?>
                      <input type="hidden" name="action" value="del_holiday">
                      <input type="hidden" name="day" value="<?= $h['day'] ?>">
                      <button class="btn btn-sm btn-outline-danger py-0">Remove</button>
                    </form>
                  </td>
                </tr>
              <?php endforeach; ?>
              <?php if (empty($holidays)): ?>
                <tr><td colspan="3" class="text-center text-muted py-3">No holidays configured. Standard weekends apply.</td></tr>
              <?php endif; ?>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  </div>

  <!-- Regulatory Compliance & Disaster Recovery -->
  <div class="col-12 mt-4">
    <div class="card shadow-sm border-0">
      <div class="card-header bg-white py-3 d-flex justify-content-between align-items-center">
        <div>
          <h6 class="fw-bold mb-0 text-dark"><i class="bi bi-shield-check me-2 text-teal"></i>Regulatory Data Safeguards & One-Click Backup</h6>
          <small class="text-muted">Direct SQL Dump for RBI Inspection, Offsite Archival & Disaster Recovery</small>
        </div>
        <a href="<?= url('/settings/backup.sql') ?>" class="btn btn-teal text-white btn-sm px-3" style="background-color: #0f766e;">
          <i class="bi bi-download me-1"></i> Download Database Backup (.sql)
        </a>
      </div>
      <div class="card-body p-4 small">
        <div class="row g-3">
          <div class="col-md-4">
            <div class="p-3 bg-light rounded border">
              <div class="text-muted mb-1" style="font-size: 0.75rem;">HOSTINGER ENGINE</div>
              <div class="fw-bold fs-6 text-dark"><?= strtoupper(Database::getConnection()->getAttribute(PDO::ATTR_DRIVER_NAME)) ?> Dual-Mode</div>
              <div class="text-success mt-1" style="font-size: 0.75rem;"><i class="bi bi-check-circle-fill me-1"></i>Connection Healthy</div>
            </div>
          </div>
          <div class="col-md-4">
            <div class="p-3 bg-light rounded border">
              <div class="text-muted mb-1" style="font-size: 0.75rem;">RBI AUDIT RETENTION</div>
              <div class="fw-bold fs-6 text-dark">8 Years Statutory</div>
              <div class="text-muted mt-1" style="font-size: 0.75rem;">Full payments & schedule audit trail</div>
            </div>
          </div>
          <div class="col-md-4">
            <div class="p-3 bg-light rounded border">
              <div class="text-muted mb-1" style="font-size: 0.75rem;">SYSTEM SECURITY</div>
              <div class="fw-bold fs-6 text-dark">Strict CSRF & Bcrypt</div>
              <div class="text-muted mt-1" style="font-size: 0.75rem;">Bilingual KFS & NPCI Dynamic UPI</div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</div>
