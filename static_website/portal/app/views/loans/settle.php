<div class="row justify-content-center">
  <div class="col-12 col-md-6">
    <div class="card shadow-sm border-0 border-top border-warning border-4">
      <div class="card-header bg-white py-3">
        <h5 class="fw-bold mb-0 text-dark"><i class="bi bi-check-all me-2 text-warning"></i>Loan Early Closure / Full Settlement</h5>
      </div>
      <div class="card-body p-4">
        <?php if ($q): ?>
          <div class="alert alert-light border mb-4">
            <h6 class="fw-bold text-dark">Pre-Closure Settlement Quotation</h6>
            <div class="d-flex justify-content-between my-2">
              <span>Outstanding Principal:</span>
              <strong><?= inr($q['principal']) ?></strong>
            </div>
            <div class="d-flex justify-content-between my-2">
              <span>Next Instalment Interest:</span>
              <strong><?= inr($q['interest']) ?></strong>
            </div>
            <div class="d-flex justify-content-between my-2 text-success">
              <span>Future Interest Waived:</span>
              <strong>- <?= inr($q['saved']) ?></strong>
            </div>
            <hr>
            <div class="d-flex justify-content-between fs-5 fw-bold text-teal">
              <span>Net Settlement Amount:</span>
              <span><?= inr($q['total']) ?></span>
            </div>
          </div>

          <form method="post" action="<?= url('/loans/' . $l['id'] . '/settle') ?>" onsubmit="return confirm('Execute full loan pre-closure? This action closes the loan.')">
            <?= csrf_field() ?>

            <div class="mb-3">
              <label class="form-label small fw-semibold">Settlement Payment Mode</label>
              <select name="channel" class="form-select">
                <option value="CASH">Cash Deposit</option>
                <option value="NEFT">Bank Transfer (NEFT/RTGS)</option>
                <option value="UPI">Direct UPI Transfer</option>
              </select>
            </div>

            <div class="mb-4">
              <label class="form-label small fw-semibold">Bank / UTR Reference</label>
              <input type="text" name="ref" class="form-control" placeholder="Enter transaction reference">
            </div>

            <div class="d-flex justify-content-between">
              <a href="<?= url('/loans/' . $l['id']) ?>" class="btn btn-outline-secondary">Cancel</a>
              <button type="submit" class="btn btn-warning px-4 fw-semibold text-dark">Execute Settlement & Close Loan</button>
            </div>
          </form>
        <?php else: ?>
          <div class="alert alert-info">Loan is already closed or has no balance.</div>
          <a href="<?= url('/loans/' . $l['id']) ?>" class="btn btn-primary">Back to Loan</a>
        <?php endif; ?>
      </div>
    </div>
  </div>
</div>
