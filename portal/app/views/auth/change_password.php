<div class="row justify-content-center">
  <div class="col-12 col-md-6 col-lg-5">
    <div class="card shadow-sm border-0">
      <div class="card-body p-4">
        <h4 class="card-title fw-bold mb-3"><i class="bi bi-key me-2 text-teal"></i>Change Password</h4>
        
        <?php if (!empty($forced)): ?>
          <div class="alert alert-warning small">
            <i class="bi bi-exclamation-triangle-fill me-1"></i>
            For account security, you must set a new private password before proceeding.
          </div>
        <?php endif; ?>

        <form method="post" action="<?= url('/change-password') ?>">
          <?= csrf_field() ?>
          
          <div class="mb-3">
            <label class="form-label small fw-semibold">Current Password</label>
            <input type="password" name="old" class="form-control" required autofocus>
          </div>

          <div class="mb-3">
            <label class="form-label small fw-semibold">New Password</label>
            <input type="password" name="new" class="form-control" required placeholder="Min 8 chars, letters and digits">
            <div class="form-text small">At least 8 characters with a mix of letters and numbers.</div>
          </div>

          <div class="mb-4">
            <label class="form-label small fw-semibold">Confirm New Password</label>
            <input type="password" name="confirm" class="form-control" required placeholder="Repeat new password">
          </div>

          <div class="d-flex justify-content-between align-items-center">
            <?php if (empty($forced)): ?>
              <a href="<?= url('/') ?>" class="btn btn-outline-secondary">Cancel</a>
            <?php else: ?>
              <span></span>
            <?php endif; ?>
            <button type="submit" class="btn btn-primary px-4">Update Password</button>
          </div>
        </form>
      </div>
    </div>
  </div>
</div>
