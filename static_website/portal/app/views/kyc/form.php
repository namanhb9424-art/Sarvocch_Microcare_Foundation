<div class="d-flex justify-content-between align-items-center mb-4">
  <div>
    <h3 class="fw-bold mb-0 text-teal"><i class="bi bi-person-vcard me-2"></i><?= !empty($isNew) ? 'New Customer KYC Onboarding Form' : 'Edit Customer KYC Dossier' ?></h3>
    <div class="text-muted small">SARVOOCCH Microcare Foundation · Bilingual MFI Borrower Registration / ग्राहक विवरण प्रपत्र</div>
  </div>
  <?php if (!empty($c['id'])): ?>
    <a href="<?= url('/crm/' . $c['id']) ?>" class="btn btn-outline-secondary btn-sm"><i class="bi bi-arrow-left me-1"></i> Back to Profile</a>
  <?php endif; ?>
</div>

<form method="post" action="<?= !empty($isNew) ? url('/kyc-form/new') : url('/crm/' . $c['id'] . '/kyc-form') ?>" enctype="multipart/form-data">
  <?= csrf_field() ?>

  <!-- 1. Basic & Personal Details -->
  <div class="card shadow-sm border-0 mb-4">
    <div class="card-header bg-white py-3">
      <h6 class="fw-bold mb-0 text-dark">1. व्यक्तिगत विवरण / Borrower Personal Information</h6>
    </div>
    <div class="card-body p-3">
      <div class="row g-3">
        <div class="col-12 col-md-4">
          <label class="form-label small fw-semibold">Borrower Name / ग्राहक का नाम *</label>
          <input type="text" name="name" class="form-control" required value="<?= htmlspecialchars($c['name'] ?? '') ?>">
        </div>
        <div class="col-12 col-md-4">
          <label class="form-label small fw-semibold">Mobile Number / मोबाइल नंबर *</label>
          <input type="tel" name="phone" class="form-control" required value="<?= htmlspecialchars($c['phone'] ?? '') ?>">
        </div>
        <div class="col-12 col-md-4">
          <label class="form-label small fw-semibold">Date of Birth / जन्म तिथि</label>
          <input type="date" name="dob" class="form-control" value="<?= htmlspecialchars($c['dob'] ?? '') ?>">
        </div>

        <div class="col-12 col-md-4">
          <label class="form-label small fw-semibold">Aadhaar Number / आधार नंबर (12 Digits)</label>
          <input type="text" name="aadhaar" class="form-control" maxlength="12" placeholder="123456789012" value="<?= htmlspecialchars($c['aadhaar'] ?? '') ?>">
        </div>
        <div class="col-12 col-md-4">
          <label class="form-label small fw-semibold">PAN Card / पैन नंबर</label>
          <input type="text" name="pan" class="form-control text-uppercase" maxlength="10" placeholder="ABCDE1234F" value="<?= htmlspecialchars($c['pan'] ?? '') ?>">
        </div>
        <div class="col-12 col-md-4">
          <label class="form-label small fw-semibold">Voter ID / मतदाता पहचान पत्र</label>
          <input type="text" name="voter" class="form-control text-uppercase" placeholder="ABC1234567" value="<?= htmlspecialchars($c['voter'] ?? '') ?>">
        </div>

        <div class="col-12 col-md-4">
          <label class="form-label small fw-semibold">Branch Assignment / शाखा</label>
          <select name="branch" class="form-select">
            <?php foreach (Database::getBranches() as $b): ?>
              <option value="<?= htmlspecialchars($b) ?>" <?= (($c['branch'] ?? '') === $b) ? 'selected' : '' ?>><?= htmlspecialchars($b) ?></option>
            <?php endforeach; ?>
          </select>
        </div>
        <div class="col-12 col-md-4">
          <label class="form-label small fw-semibold">Center Number / केंद्र संख्या</label>
          <input type="text" name="center_no" class="form-control" placeholder="C01" value="<?= htmlspecialchars($kyc['center_no'] ?? '') ?>">
        </div>
        <div class="col-12 col-md-4">
          <label class="form-label small fw-semibold">Group Number / समूह संख्या</label>
          <input type="text" name="group_no" class="form-control" placeholder="G01" value="<?= htmlspecialchars($kyc['group_no'] ?? '') ?>">
        </div>

        <div class="col-12 col-md-3">
          <label class="form-label small fw-semibold">Guardian / अभिभावक प्रकार</label>
          <select name="guardian_type" class="form-select">
            <option value="Husband" <?= (($kyc['guardian_type'] ?? '') === 'Husband') ? 'selected' : '' ?>>Husband / पति</option>
            <option value="Father" <?= (($kyc['guardian_type'] ?? '') === 'Father') ? 'selected' : '' ?>>Father / पिता</option>
          </select>
        </div>
        <div class="col-12 col-md-3">
          <label class="form-label small fw-semibold">Guardian Name / अभिभावक का नाम</label>
          <input type="text" name="guardian_name" class="form-control" value="<?= htmlspecialchars($kyc['guardian_name'] ?? '') ?>">
        </div>
        <div class="col-12 col-md-3">
          <label class="form-label small fw-semibold">Education / शिक्षा</label>
          <select name="education" class="form-select">
            <option value="Middle" <?= (($kyc['education'] ?? '') === 'Middle') ? 'selected' : '' ?>>Middle (up to 8th)</option>
            <option value="Primary" <?= (($kyc['education'] ?? '') === 'Primary') ? 'selected' : '' ?>>Primary (up to 5th)</option>
            <option value="Secondary" <?= (($kyc['education'] ?? '') === 'Secondary') ? 'selected' : '' ?>>Secondary (10th)</option>
            <option value="Illiterate" <?= (($kyc['education'] ?? '') === 'Illiterate') ? 'selected' : '' ?>>Illiterate / असाक्षर</option>
          </select>
        </div>
        <div class="col-12 col-md-3">
          <label class="form-label small fw-semibold">Social Category / वर्ग</label>
          <select name="category" class="form-select">
            <option value="General" <?= (($kyc['category'] ?? '') === 'General') ? 'selected' : '' ?>>General</option>
            <option value="OBC" <?= (($kyc['category'] ?? '') === 'OBC') ? 'selected' : '' ?>>OBC</option>
            <option value="SC" <?= (($kyc['category'] ?? '') === 'SC') ? 'selected' : '' ?>>SC</option>
            <option value="ST" <?= (($kyc['category'] ?? '') === 'ST') ? 'selected' : '' ?>>ST</option>
          </select>
        </div>
      </div>
    </div>
  </div>

  <!-- 2. Address Details -->
  <div class="card shadow-sm border-0 mb-4">
    <div class="card-header bg-white py-3">
      <h6 class="fw-bold mb-0 text-dark">2. आवासीय पता / Residential Address Details</h6>
    </div>
    <div class="card-body p-3">
      <div class="row g-3">
        <div class="col-12 col-md-3">
          <label class="form-label small fw-semibold">House No / मकान सं.</label>
          <input type="text" name="house_no" class="form-control" value="<?= htmlspecialchars($kyc['house_no'] ?? '') ?>">
        </div>
        <div class="col-12 col-md-3">
          <label class="form-label small fw-semibold">Village or Mohalla / ग्राम / मोहल्ला</label>
          <input type="text" name="village" class="form-control" value="<?= htmlspecialchars($kyc['village'] ?? '') ?>">
        </div>
        <div class="col-12 col-md-3">
          <label class="form-label small fw-semibold">Post Office / डाकघर</label>
          <input type="text" name="post_office" class="form-control" value="<?= htmlspecialchars($kyc['post_office'] ?? '') ?>">
        </div>
        <div class="col-12 col-md-3">
          <label class="form-label small fw-semibold">District / जिला</label>
          <input type="text" name="district" class="form-control" value="<?= htmlspecialchars($kyc['district'] ?? 'Narmadapuram') ?>">
        </div>
        <div class="col-12 col-md-4">
          <label class="form-label small fw-semibold">State / राज्य</label>
          <input type="text" name="state" class="form-control" value="<?= htmlspecialchars($kyc['state'] ?? 'Madhya Pradesh') ?>">
        </div>
        <div class="col-12 col-md-4">
          <label class="form-label small fw-semibold">Pincode / पिन कोड</label>
          <input type="text" name="pincode" class="form-control" maxlength="6" value="<?= htmlspecialchars($kyc['pincode'] ?? '') ?>">
        </div>
        <div class="col-12 col-md-4">
          <label class="form-label small fw-semibold">Distance to Branch (km) / शाखा से दूरी</label>
          <input type="number" step="0.1" name="dist_branch_km" class="form-control" value="<?= htmlspecialchars($kyc['dist_branch_km'] ?? '5.0') ?>">
        </div>
      </div>
    </div>
  </div>

  <!-- 3. Socio-Economic & Bank Details -->
  <div class="card shadow-sm border-0 mb-4">
    <div class="card-header bg-white py-3">
      <h6 class="fw-bold mb-0 text-dark">3. सामाजिक, आर्थिक एवं बैंक विवरण / Socio-Economic & Bank Info</h6>
    </div>
    <div class="card-body p-3">
      <div class="row g-3">
        <div class="col-12 col-md-3">
          <label class="form-label small fw-semibold">House Type / मकान का प्रकार</label>
          <select name="house_type" class="form-select">
            <option value="Pucca" <?= (($kyc['house_type'] ?? '') === 'Pucca') ? 'selected' : '' ?>>Pucca / पक्का</option>
            <option value="Semi-Pucca" <?= (($kyc['house_type'] ?? '') === 'Semi-Pucca') ? 'selected' : '' ?>>Semi-Pucca / अर्ध-पक्का</option>
            <option value="Kaccha" <?= (($kyc['house_type'] ?? '') === 'Kaccha') ? 'selected' : '' ?>>Kaccha / कच्चा</option>
          </select>
        </div>
        <div class="col-12 col-md-3">
          <label class="form-label small fw-semibold">Land Owned (Hectares) / कृषि भूमि</label>
          <input type="number" step="0.01" name="land_ha" class="form-control" value="<?= htmlspecialchars($kyc['land_ha'] ?? '0.00') ?>">
        </div>
        <div class="col-12 col-md-3">
          <label class="form-label small fw-semibold">Livestock / पशुधन विवरण</label>
          <input type="text" name="livestock" class="form-control" placeholder="e.g. 2 Cows, 1 Buffalo" value="<?= htmlspecialchars($kyc['livestock'] ?? '') ?>">
        </div>
        <div class="col-12 col-md-3">
          <label class="form-label small fw-semibold">Annual Household Income (₹) *</label>
          <input type="number" name="annual_income" class="form-control" placeholder="Capped at Rs 3,00,000" value="<?= htmlspecialchars($kyc['annual_income'] ?? '150000') ?>">
        </div>

        <div class="col-12 col-md-4">
          <label class="form-label small fw-semibold">Bank Name / बैंक का नाम</label>
          <input type="text" name="bank_name" class="form-control" placeholder="e.g. State Bank of India" value="<?= htmlspecialchars($kyc['bank_name'] ?? '') ?>">
        </div>
        <div class="col-12 col-md-4">
          <label class="form-label small fw-semibold">Bank Account Number / खाता संख्या</label>
          <input type="text" name="bank_acct" class="form-control" value="<?= htmlspecialchars($kyc['bank_acct'] ?? '') ?>">
        </div>
        <div class="col-12 col-md-4">
          <label class="form-label small fw-semibold">Name as per Passbook / पासबुक अनुसार नाम</label>
          <input type="text" name="passbook_name" class="form-control" value="<?= htmlspecialchars($kyc['passbook_name'] ?? '') ?>">
        </div>
      </div>
    </div>
  </div>

  <!-- 4. Husband / Co-Borrower Details -->
  <div class="card shadow-sm border-0 mb-4">
    <div class="card-header bg-white py-3">
      <h6 class="fw-bold mb-0 text-dark">4. सह-उधारकर्ता / पति का विवरण / Co-Borrower or Spouse</h6>
    </div>
    <div class="card-body p-3">
      <div class="row g-3">
        <div class="col-12 col-md-4">
          <label class="form-label small fw-semibold">Spouse / Co-Borrower Name</label>
          <input type="text" name="co_name" class="form-control" value="<?= htmlspecialchars($kyc['co_name'] ?? '') ?>">
        </div>
        <div class="col-12 col-md-4">
          <label class="form-label small fw-semibold">Relationship</label>
          <select name="co_relation" class="form-select">
            <option value="Husband">Husband / पति</option>
            <option value="Son">Son / पुत्र</option>
            <option value="Father">Father / पिता</option>
          </select>
        </div>
        <div class="col-12 col-md-4">
          <label class="form-label small fw-semibold">Co-Borrower Monthly Income (₹)</label>
          <input type="number" name="co_income" class="form-control" value="<?= htmlspecialchars($kyc['co_income'] ?? '0') ?>">
        </div>
      </div>
    </div>
  </div>

  <!-- 5. Document Uploads & Biometrics -->
  <div class="card shadow-sm border-0 mb-4">
    <div class="card-header bg-white py-3">
      <h6 class="fw-bold mb-0 text-dark">5. दस्तावेज़ एवं छायाचित्र / Document & Photo Uploads</h6>
    </div>
    <div class="card-body p-3">
      <div class="row g-3">
        <div class="col-12 col-md-4">
          <label class="form-label small fw-semibold">Customer Photo / ग्राहक का फोटो (JPG/PNG)</label>
          <input type="file" name="photo" class="form-control" accept="image/*">
          <?php if (!empty($kyc['photo'])): ?>
            <div class="mt-1 small text-success"><i class="bi bi-check-circle"></i> File on record</div>
          <?php endif; ?>
        </div>
        <div class="col-12 col-md-4">
          <label class="form-label small fw-semibold">Spouse Photo / पति का फोटो (JPG/PNG)</label>
          <input type="file" name="h_photo" class="form-control" accept="image/*">
          <?php if (!empty($kyc['h_photo'])): ?>
            <div class="mt-1 small text-success"><i class="bi bi-check-circle"></i> File on record</div>
          <?php endif; ?>
        </div>
        <div class="col-12 col-md-4">
          <label class="form-label small fw-semibold">Physical Signed Dossier Copy (PDF/JPG)</label>
          <input type="file" name="signed_copy" class="form-control" accept=".pdf,image/*">
          <?php if (!empty($kyc['signed_copy'])): ?>
            <div class="mt-1 small text-success"><i class="bi bi-check-circle"></i> File on record</div>
          <?php endif; ?>
        </div>
      </div>
    </div>
  </div>

  <!-- 6. Statutory Declarations -->
  <div class="card shadow-sm border-0 mb-4">
    <div class="card-header bg-white py-3">
      <h6 class="fw-bold mb-0 text-dark">6. वैधानिक घोषणा एवं सहमति / Statutory Declarations</h6>
    </div>
    <div class="card-body p-3">
      <div class="form-check mb-2">
        <input class="form-check-input" type="checkbox" name="consent_given" value="1" id="cConsent" <?= (!empty($kyc['consent_given'])) ? 'checked' : 'checked' ?>>
        <label class="form-check-label small" for="cConsent">
          <strong>Borrower Consent:</strong> I hereby declare that all information furnished is authentic and I voluntarily apply for loan under Sarvoocch Microcare Foundation's JLG framework.
        </label>
      </div>

      <div class="form-check mb-2">
        <input class="form-check-input" type="checkbox" name="bureau_consent" value="1" id="cBureau" <?= (!empty($kyc['bureau_consent'])) ? 'checked' : 'checked' ?>>
        <label class="form-check-label small" for="cBureau">
          <strong>Credit Bureau Consent (CIC):</strong> I authorize SARVOOCCH to pull and submit my credit history records to licensed credit bureaus (Equifax, CRIF High Mark, CIBIL).
        </label>
      </div>

      <div class="form-check mb-2">
        <input class="form-check-input" type="checkbox" name="address_verified" value="1" id="cAddr" <?= (!empty($kyc['address_verified'])) ? 'checked' : 'checked' ?>>
        <label class="form-check-label small" for="cAddr">
          <strong>Field Officer Physical Verification:</strong> Field Officer certifies that physical house verification and interaction with family was conducted.
        </label>
      </div>
    </div>
  </div>

  <div class="d-flex justify-content-end gap-2 mb-5">
    <button type="submit" class="btn btn-teal text-white px-5 py-2 fw-semibold" style="background-color: #0f766e;">
      <i class="bi bi-save me-1"></i> Save KYC Dossier
    </button>
  </div>
</form>
