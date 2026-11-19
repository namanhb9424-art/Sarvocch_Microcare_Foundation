<div class="container py-5 text-center">
  <div class="display-1 text-danger fw-bold">403</div>
  <h2 class="h4 mb-3">Access Denied</h2>
  <p class="text-muted"><?= htmlspecialchars($msg ?? 'Your role does not have authorization to view this module.') ?></p>
  <a href="<?= url('/') ?>" class="btn btn-outline-secondary mt-2"><i class="bi bi-arrow-left me-1"></i> Back to Safety</a>
</div>
