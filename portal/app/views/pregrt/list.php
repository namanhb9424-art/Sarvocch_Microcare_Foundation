<div class="d-flex justify-content-between align-items-center mb-4">
  <div>
    <h3 class="fw-bold mb-0 text-teal"><i class="bi bi-people-fill me-2"></i>Pre-GRT Group Assessment Register</h3>
    <div class="text-muted small">SARVOOCCH Microcare Foundation · Joint Liability Group (JLG) Verification / समूह सत्यापन</div>
  </div>
  <a href="<?= url('/pregrt/new') ?>" class="btn btn-primary btn-sm">
    <i class="bi bi-plus-circle me-1"></i> New Pre-GRT Group
  </a>
</div>

<div class="card shadow-sm border-0">
  <div class="table-responsive">
    <table class="table table-hover align-middle mb-0">
      <thead class="table-light small text-uppercase">
        <tr>
          <th>Group Ref #</th>
          <th>Branch</th>
          <th>Center / Group No</th>
          <th>Village / Location</th>
          <th class="text-center">Members</th>
          <th>Field Officer (PSO)</th>
          <th>Status</th>
          <th class="text-center">Action</th>
        </tr>
      </thead>
      <tbody>
        <?php foreach ($groups as $g): ?>
          <tr>
            <td><strong>#<?= $g['id'] ?></strong></td>
            <td><span class="badge bg-light text-dark border"><?= htmlspecialchars($g['branch']) ?></span></td>
            <td class="fw-semibold">Center <?= htmlspecialchars($g['center_no']) ?> · Group <?= htmlspecialchars($g['group_no']) ?></td>
            <td><?= htmlspecialchars($g['village'] ?: '-') ?></td>
            <td class="text-center"><span class="badge bg-teal text-white"><?= $g['member_count'] ?> Members</span></td>
            <td><?= htmlspecialchars($g['pso_name'] ?: '-') ?></td>
            <td>
              <?php
              $badge = match($g['status']) {
                  'verified' => 'bg-success',
                  'submitted' => 'bg-info text-dark',
                  'rejected' => 'bg-danger',
                  default => 'bg-secondary'
              };
              ?>
              <span class="badge <?= $badge ?> text-capitalize"><?= $g['status'] ?></span>
            </td>
            <td class="text-center">
              <a href="<?= url('/pregrt/' . $g['id']) ?>" class="btn btn-sm btn-outline-primary py-0">Manage Group</a>
              <a href="<?= url('/pregrt/' . $g['id'] . '/print') ?>" target="_blank" class="btn btn-sm btn-outline-secondary py-0">Print</a>
            </td>
          </tr>
        <?php endforeach; ?>
        <?php if (empty($groups)): ?>
          <tr><td colspan="8" class="text-center text-muted py-4">No Pre-GRT group assessments found.</td></tr>
        <?php endif; ?>
      </tbody>
    </table>
  </div>
</div>
