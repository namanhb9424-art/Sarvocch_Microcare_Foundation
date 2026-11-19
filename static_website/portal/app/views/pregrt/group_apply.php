<div class="d-flex justify-content-between align-items-center mb-4">
  <div>
    <h3 class="fw-bold mb-0 text-teal"><i class="bi bi-file-earmark-plus me-2"></i>Batch Generate Loan Applications</h3>
    <div class="text-muted small">Pre-GRT Group #<?= $g['id'] ?> · Center <?= htmlspecialchars($g['center_no']) ?> / Group <?= htmlspecialchars($g['group_no']) ?></div>
  </div>
  <a href="<?= url('/pregrt/' . $g['id']) ?>" class="btn btn-outline-secondary btn-sm">Back</a>
</div>

<div class="card shadow-sm border-0 mb-4">
  <div class="card-header bg-white py-3">
    <h6 class="fw-bold mb-0">Select Product Scheme for Batch Applications</h6>
  </div>
  <form method="post" action="<?= url('/pregrt/' . $g['id'] . '/apply') ?>" class="card-body p-4" onsubmit="return confirm('Generate loan applications for all group members simultaneously?')">
    <?= csrf_field() ?>

    <div class="mb-4">
      <label class="form-label small fw-semibold">Loan Product *</label>
      <select name="product_id" class="form-select">
        <?php foreach ($products as $p): ?>
          <option value="<?= $p['id'] ?>">
            <?= htmlspecialchars($p['name']) ?> (<?= $p['rate'] ?>% p.a., <?= ucfirst($p['method']) ?>)
          </option>
        <?php endforeach; ?>
      </select>
    </div>

    <div class="alert alert-info small mb-4">
      <strong>Batch Action Confirmation:</strong><br>
      This will create individual customer profiles and submit <?= count($members) ?> loan applications to the underwriting pipeline in one click.
    </div>

    <div class="table-responsive mb-4">
      <table class="table table-bordered table-sm small">
        <thead class="table-light">
          <tr>
            <th>#</th>
            <th>Member Name</th>
            <th>Spouse</th>
            <th>Loan Amount</th>
            <th>Purpose</th>
          </tr>
        </thead>
        <tbody>
          <?php foreach ($members as $m): ?>
            <tr>
              <td><?= $m['sno'] ?></td>
              <td class="fw-semibold"><?= htmlspecialchars($m['name']) ?></td>
              <td><?= htmlspecialchars($m['husband_name']) ?></td>
              <td class="fw-bold text-teal"><?= inr($m['loan_amount']) ?></td>
              <td><?= htmlspecialchars($m['purpose']) ?></td>
            </tr>
          <?php endforeach; ?>
        </tbody>
      </table>
    </div>

    <button type="submit" class="btn btn-teal text-white w-100 py-2 fw-semibold" style="background-color: #0f766e;">
      <i class="bi bi-check-circle me-1"></i> Confirm & Generate All <?= count($members) ?> Loan Applications
    </button>
  </form>
</div>
