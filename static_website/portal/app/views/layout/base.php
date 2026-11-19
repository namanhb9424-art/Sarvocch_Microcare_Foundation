<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title><?= htmlspecialchars($title ?? 'Portal') ?> · SARVOOCCH Microcare Foundation</title>
<link rel="manifest" href="<?= url('/static/manifest.json') ?>">
<meta name="theme-color" content="#0f766e">
<link rel="icon" type="image/png" sizes="32x32" href="<?= url('/static/icons/favicon-32.png') ?>">
<link rel="apple-touch-icon" href="<?= url('/static/icons/apple-touch-icon.png') ?>">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-title" content="SARVOOCCH">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<?php if ($user): ?><meta name="uid" content="<?= $user['id'] ?>"><?php endif; ?>
<meta name="csrf-token" content="<?= csrf_token() ?>">
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css" rel="stylesheet">
<link href="<?= url('/static/style.css') ?>" rel="stylesheet">
</head>
<body>
<?php if ($user): ?>
<nav class="navbar topbar px-3">
  <button class="btn btn-sm btn-light d-lg-none" data-bs-toggle="offcanvas" data-bs-target="#side"><i class="bi bi-list fs-5"></i></button>
  <a class="navbar-brand text-white fw-bold ms-2" href="<?= url('/') ?>">
    <i class="bi bi-bank2"></i>
    <span class="d-none d-sm-inline">SARVOOCCH Microcare Foundation</span>
    <span class="d-sm-none">SARVOOCCH</span>
  </a>
  <span id="netpill" class="badge bg-success ms-auto me-3">Online</span>
  <span class="text-white small d-none d-md-inline me-3">
    <?= htmlspecialchars($user['name']) ?> · <span class="badge bg-light text-dark text-uppercase"><?= str_replace('_', ' ', $user['role']) ?></span>
  </span>
  <a href="<?= url('/change-password') ?>" class="btn btn-sm btn-outline-light me-2" title="Change password">
    <i class="bi bi-key"></i><span class="d-none d-md-inline"> Password</span>
  </a>
  <a href="<?= url('/logout') ?>" class="btn btn-sm btn-outline-light">Logout</a>
</nav>

<div class="offcanvas-lg offcanvas-start sidebar" tabindex="-1" id="side">
  <div class="offcanvas-header d-lg-none">
    <h5 class="offcanvas-title">Menu</h5>
    <button class="btn-close" data-bs-dismiss="offcanvas" data-bs-target="#side"></button>
  </div>
  <div class="offcanvas-body p-0">
    <div class="list-group list-group-flush w-100">
      <?php 
      $currentUri = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH);
      foreach ($nav as [$m, $label, $ep, $icon]): 
          $itemUrl = url('/' . $ep);
          $isActive = (rtrim($currentUri, '/') === rtrim($itemUrl, '/'));
      ?>
        <a class="list-group-item list-group-item-action <?= $isActive ? 'active' : '' ?>" href="<?= $itemUrl ?>">
          <i class="bi bi-<?= $icon ?> me-2"></i><?= $label ?>
        </a>
      <?php endforeach; ?>
    </div>
  </div>
</div>

<main class="content p-3 p-lg-4">
<?php else: ?>
<main class="p-3">
<?php endif; ?>

  <?php foreach (get_flashed_messages() as $f): ?>
    <div class="alert alert-<?= $f['cat'] ?> alert-dismissible fade show" role="alert">
      <?= htmlspecialchars($f['msg']) ?>
      <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    </div>
  <?php endforeach; ?>

  <?= $childContent ?? '' ?>

</main>

<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
<script src="<?= url('/static/app.js') ?>"></script>
</body>
</html>
