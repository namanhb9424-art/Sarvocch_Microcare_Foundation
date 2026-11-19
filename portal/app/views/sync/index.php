<div class="d-flex justify-content-between align-items-center mb-4">
  <div>
    <h3 class="fw-bold mb-0 text-teal"><i class="bi bi-arrow-repeat me-2"></i>Offline Sync & Queue Audit</h3>
    <div class="text-muted small">SARVOOCCH Microcare Foundation · Field SQLite Mobile Synchronization Logs</div>
  </div>
</div>

<div class="card shadow-sm border-0">
  <div class="table-responsive">
    <table class="table table-hover align-middle mb-0 small">
      <thead class="table-light">
        <tr>
          <th>Sync UUID</th>
          <th>Agent</th>
          <th>Captured Time</th>
          <th>Synced At</th>
          <th>Payload Size</th>
        </tr>
      </thead>
      <tbody>
        <?php foreach ($logs as $l): ?>
          <tr>
            <td><code><?= htmlspecialchars($l['uuid']) ?></code></td>
            <td class="fw-semibold"><?= htmlspecialchars($l['agent_name'] ?: 'Field Officer') ?></td>
            <td><?= fmt_date($l['captured_at']) ?></td>
            <td><?= fmt_date($l['synced_at']) ?></td>
            <td><?= strlen($l['payload'] ?? '') ?> bytes</td>
          </tr>
        <?php endforeach; ?>
        <?php if (empty($logs)): ?>
          <tr><td colspan="5" class="text-center text-muted py-4">No offline sync batches registered yet.</td></tr>
        <?php endif; ?>
      </tbody>
    </table>
  </div>
</div>
