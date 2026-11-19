<div class="container py-5 text-center">
  <div class="display-1 text-teal fw-bold">404</div>
  <h2 class="h4 mb-3">Page Not Found</h2>
  <p class="text-muted">The requested path <code><?= htmlspecialchars($uri ?? '') ?></code> does not exist on the portal.</p>
  <a href="<?= url('/') ?>" class="btn btn-primary mt-2"><i class="bi bi-house me-1"></i> Return to Portal Home</a>
</div>
