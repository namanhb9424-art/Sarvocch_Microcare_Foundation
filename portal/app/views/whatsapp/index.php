<div class="d-flex justify-content-between align-items-center mb-4">
  <div>
    <h3 class="fw-bold mb-0 text-teal"><i class="bi bi-whatsapp me-2 text-success"></i>WhatsApp Borrower Notifications</h3>
    <div class="text-muted small">SARVOOCCH Microcare Foundation · Automated Payment Reminders & Verification</div>
  </div>
</div>

<div class="card shadow-sm border-0">
  <div class="table-responsive">
    <table class="table table-hover align-middle mb-0">
      <thead class="table-light small text-uppercase">
        <tr>
          <th>Customer Name</th>
          <th>Mobile</th>
          <th>Branch</th>
          <th>WhatsApp Status</th>
          <th class="text-center">Dispatch Notification</th>
        </tr>
      </thead>
      <tbody>
        <?php foreach ($customers as $c): ?>
          <tr>
            <td class="fw-semibold"><?= htmlspecialchars($c['name']) ?></td>
            <td><?= htmlspecialchars($c['phone'] ?: '-') ?></td>
            <td><?= htmlspecialchars($c['branch'] ?: '-') ?></td>
            <td>
              <?php if ($c['wa_verified']): ?>
                <span class="badge bg-success"><i class="bi bi-check-circle me-1"></i>Verified</span>
              <?php else: ?>
                <span class="badge bg-warning text-dark">Unverified</span>
              <?php endif; ?>
            </td>
            <td class="text-center">
              <form method="post" action="<?= url('/whatsapp/' . $c['id'] . '/send') ?>" class="d-inline-flex gap-1">
                <?= csrf_field() ?>
                <input type="text" name="message" class="form-control form-control-sm" style="width: 250px;" value="Namaste, your SARVOOCCH EMI instalment is due.">
                <button type="submit" class="btn btn-sm btn-success py-0"><i class="bi bi-send me-1"></i>Send</button>
              </form>
            </td>
          </tr>
        <?php endforeach; ?>
      </tbody>
    </table>
  </div>
</div>
