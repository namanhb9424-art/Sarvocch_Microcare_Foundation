<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Sign In · SARVOOCCH Microcare Foundation</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css" rel="stylesheet">
<link href="<?= url('/static/style.css') ?>" rel="stylesheet">
<style>
  body { background: linear-gradient(135deg, #0f766e 0%, #042f2e 100%); min-height: 100vh; display: flex; align-items: center; justify-content: center; }
  .login-card { max-width: 440px; width: 100%; border-radius: 12px; box-shadow: 0 10px 25px rgba(0,0,0,0.3); }
</style>
</head>
<body>
<div class="container p-3">
  <div class="card login-card mx-auto border-0">
    <div class="card-body p-4 p-md-5">
      <div class="text-center mb-4">
        <div class="text-teal mb-2"><i class="bi bi-bank2 fs-1"></i></div>
        <h4 class="fw-bold mb-1">SARVOOCCH</h4>
        <div class="text-muted small">Microcare Foundation · Portal</div>
      </div>

      <?php foreach (get_flashed_messages() as $f): ?>
        <div class="alert alert-<?= $f['cat'] ?> alert-dismissible fade show" role="alert">
          <?= htmlspecialchars($f['msg']) ?>
          <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        </div>
      <?php endforeach; ?>

      <form method="post" action="<?= url('/login' . (!empty($_GET['next']) ? '?next=' . urlencode($_GET['next']) : '')) ?>">
        <?= csrf_field() ?>
        <div class="mb-3">
          <label class="form-label small fw-semibold">Username</label>
          <div class="input-group">
            <span class="input-group-text"><i class="bi bi-person"></i></span>
            <input type="text" name="username" class="form-control" required autofocus placeholder="Username / Emp ID">
          </div>
        </div>

        <div class="mb-4">
          <label class="form-label small fw-semibold">Password</label>
          <div class="input-group">
            <span class="input-group-text"><i class="bi bi-lock"></i></span>
            <input type="password" name="password" class="form-control" required placeholder="••••••••">
          </div>
        </div>

        <button type="submit" class="btn btn-primary w-100 py-2 fw-semibold">Sign In to Portal</button>
      </form>

      <?php if (!empty($demoEnabled) && !empty($demo)): ?>
        <div class="mt-4 pt-3 border-top">
          <div class="text-muted small fw-semibold mb-2">Development Demo Roles:</div>
          <div class="d-flex flex-wrap gap-1">
            <?php foreach ($demo as [$u, $p, $r]): ?>
              <button type="button" class="btn btn-sm btn-outline-secondary" onclick="fillCreds('<?= $u ?>','<?= $p ?>')"><?= $r ?></button>
            <?php endforeach; ?>
          </div>
        </div>
        <script>
          function fillCreds(u, p) {
            document.querySelector('input[name="username"]').value = u;
            document.querySelector('input[name="password"]').value = p;
          }
        </script>
      <?php endif; ?>

      <div class="text-center mt-4 text-muted" style="font-size: 0.75rem;">
        CIN: U88900MP2026NPL084139 · Section 8 Microfinance<br>
        <a href="https://sarvocchfinance.com" class="text-muted text-decoration-none">← Return to Public Website</a>
      </div>
    </div>
  </div>
</div>
</body>
</html>
