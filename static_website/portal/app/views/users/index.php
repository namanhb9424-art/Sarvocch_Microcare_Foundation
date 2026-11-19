<div class="d-flex justify-content-between align-items-center mb-4">
  <div>
    <h3 class="fw-bold mb-0 text-teal"><i class="bi bi-key me-2"></i>User Access & Role Permissions</h3>
    <div class="text-muted small">SARVOOCCH Microcare Foundation · Role-Based Security Controls (RBAC)</div>
  </div>
</div>

<div class="card shadow-sm border-0">
  <div class="table-responsive">
    <table class="table table-hover align-middle mb-0">
      <thead class="table-light small text-uppercase">
        <tr>
          <th>User ID</th>
          <th>Username</th>
          <th>Full Name</th>
          <th>Current Role</th>
          <th>Branch Assignment</th>
          <th>Mobile</th>
          <th class="text-center">Modify Role</th>
        </tr>
      </thead>
      <tbody>
        <?php foreach ($users as $u): ?>
          <tr>
            <td>#<?= $u['id'] ?></td>
            <td class="fw-bold"><code><?= htmlspecialchars($u['username']) ?></code></td>
            <td><?= htmlspecialchars($u['name']) ?></td>
            <td>
              <span class="badge bg-teal text-white text-uppercase" style="background-color: #0f766e;"><?= str_replace('_', ' ', $u['role']) ?></span>
            </td>
            <td><span class="badge bg-light text-dark border"><?= htmlspecialchars($u['branch'] ?: 'Global') ?></span></td>
            <td><?= htmlspecialchars($u['phone'] ?: '-') ?></td>
            <td class="text-center">
              <form method="post" action="<?= url('/users/' . $u['id'] . '/role') ?>" class="d-inline-flex gap-1">
                <?= csrf_field() ?>
                <select name="role" class="form-select form-select-sm" style="width: 140px;">
                  <?php foreach ($roles as $r): ?>
                    <option value="<?= $r ?>" <?= ($u['role'] === $r) ? 'selected' : '' ?>><?= ucfirst(str_replace('_', ' ', $r)) ?></option>
                  <?php endforeach; ?>
                </select>
                <button type="submit" class="btn btn-sm btn-outline-primary py-0">Change</button>
              </form>
            </td>
          </tr>
        <?php endforeach; ?>
      </tbody>
    </table>
  </div>
</div>
