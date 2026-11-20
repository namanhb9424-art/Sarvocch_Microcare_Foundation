<?php
/**
 * SARVOOCCH Microcare Foundation - KYC & Customer Dossier Controller
 */

if (!defined('SARVOOCCH_APP')) exit;

class KycController {
    public function verifyList(): void {
        need('kyc');
        $u = current_user();
        $customers = ($u['role'] !== 'admin')
            ? q("SELECT c.*, k.id as kyc_form_id FROM customers c LEFT JOIN kyc_forms k ON c.id=k.customer_id WHERE c.branch=? ORDER BY c.id DESC LIMIT 100", [$u['branch'] ?? ''])
            : q("SELECT c.*, k.id as kyc_form_id FROM customers c LEFT JOIN kyc_forms k ON c.id=k.customer_id ORDER BY c.id DESC LIMIT 100");
        view('kyc/verify', ['customers' => $customers]);
    }

    public function newForm(): void {
        need('kycform', 'kyc');
        view('kyc/form', [
            'c' => null,
            'kyc' => null,
            'isNew' => true
        ]);
    }

    public function form(int $cid): void {
        need('kycform', 'kyc');
        $c = q("SELECT * FROM customers WHERE id=?", [$cid], true);
        if (!$c) {
            flash("Customer not found.", "danger");
            redirect(url('/crm'));
        }
        assert_branch_access($c['branch']);
        $kyc = q("SELECT * FROM kyc_forms WHERE customer_id=?", [$cid], true);

        view('kyc/form', [
            'c' => $c,
            'kyc' => $kyc,
            'isNew' => false
        ]);
    }

    public function saveForm(?int $cid = null): void {
        csrf_verify();
        need('kycform', 'kyc');
        $u = current_user();

        $name = trim($_POST['name'] ?? '');
        $phone = trim($_POST['phone'] ?? '');
        $branch = ($u['role'] !== 'admin') ? ($u['branch'] ?? 'Bhopal Head Office') : ($_POST['branch'] ?? ($u['branch'] ?? 'Bhopal Head Office'));

        if ($cid !== null) {
            $c = q("SELECT branch FROM customers WHERE id=?", [$cid], true);
            if (!$c) {
                flash("Customer not found.", "danger");
                redirect(url('/crm'));
            }
            assert_branch_access($c['branch']);
        } else {
            // Create customer record first
            if (empty($name) || empty($phone)) {
                flash("Customer Name and Phone are required.", "danger");
                redirect(url('/kyc-form/new'));
            }
            $cid = ex("INSERT INTO customers (name, phone, branch, agent_id, stage, created) VALUES (?, ?, ?, ?, 'lead', NOW())",
                [$name, $phone, $branch, $u['id']]);
        }

        // Handle document photo uploads
        $photoName = null;
        if (!empty($_FILES['photo']['name'])) {
            try {
                $photoName = safe_upload($_FILES['photo'], 'cust_' . $cid, true);
            } catch (Exception $e) {
                flash("Photo upload note: " . $e->getMessage(), "warning");
            }
        }

        $hPhotoName = null;
        if (!empty($_FILES['h_photo']['name'])) {
            try {
                $hPhotoName = safe_upload($_FILES['h_photo'], 'spouse_' . $cid, true);
            } catch (Exception $e) {
                flash("Spouse photo note: " . $e->getMessage(), "warning");
            }
        }

        $signedCopy = null;
        if (!empty($_FILES['signed_copy']['name'])) {
            try {
                $signedCopy = safe_upload($_FILES['signed_copy'], 'dossier_' . $cid, false);
            } catch (Exception $e) {
                flash("Signed dossier upload note: " . $e->getMessage(), "warning");
            }
        }

        // KYC Form Fields
        $fDate = $_POST['form_date'] ?: date('Y-m-d');
        $centerNo = $_POST['center_no'] ?? '';
        $groupNo = $_POST['group_no'] ?? '';
        $guardianType = $_POST['guardian_type'] ?? '';
        $guardianName = $_POST['guardian_name'] ?? '';
        $education = $_POST['education'] ?? '';
        $religion = $_POST['religion'] ?? '';
        $category = $_POST['category'] ?? '';
        $houseNo = $_POST['house_no'] ?? '';
        $village = $_POST['village'] ?? '';
        $postOffice = $_POST['post_office'] ?? '';
        $district = $_POST['district'] ?? '';
        $state = $_POST['state'] ?? 'Madhya Pradesh';
        $pincode = $_POST['pincode'] ?? '';
        $houseType = $_POST['house_type'] ?? '';
        $landHa = (float)($_POST['land_ha'] ?? 0);
        $livestock = $_POST['livestock'] ?? '';
        $bankName = $_POST['bank_name'] ?? '';
        $bankAcct = $_POST['bank_acct'] ?? '';
        $passbookName = $_POST['passbook_name'] ?? '';
        $povertyLine = $_POST['poverty_line'] ?? 'APL';
        $distCenter = (float)($_POST['dist_center_m'] ?? 0);
        $distBranch = (float)($_POST['dist_branch_km'] ?? 0);
        $relativeCenter = $_POST['relative_in_center'] ?? 'No';
        $relativeName = $_POST['relative_name'] ?? '';
        $annualIncome = (float)($_POST['annual_income'] ?? 0);
        $otherLoans = (int)($_POST['other_loans'] ?? 0);
        $currentDebt = (float)($_POST['current_debt'] ?? 0);
        $repayFreq = $_POST['repay_freq'] ?? 'Monthly';
        $hName = $_POST['h_name'] ?? '';
        $hFather = $_POST['h_father'] ?? '';
        $hDob = $_POST['h_dob'] ?: null;
        $hAddress = $_POST['h_address'] ?? '';
        $consentGiven = !empty($_POST['consent_given']) ? 1 : 0;
        $consentDate = !empty($_POST['consent_given']) ? date('Y-m-d') : null;
        $declaration = !empty($_POST['declaration']) ? 1 : 0;
        $bureauConsent = !empty($_POST['bureau_consent']) ? 1 : 0;
        $addrVerified = !empty($_POST['address_verified']) ? 1 : 0;

        $coName = $_POST['co_name'] ?? '';
        $coPhone = $_POST['co_phone'] ?? '';
        $coRelation = $_POST['co_relation'] ?? '';
        $coIncome = (float)($_POST['co_income'] ?? 0);

        // Update core customer row
        $aadhaar = preg_replace('/\s+/', '', $_POST['aadhaar'] ?? '');
        $pan = strtoupper(trim($_POST['pan'] ?? ''));
        $voter = strtoupper(trim($_POST['voter'] ?? ''));
        $dob = $_POST['dob'] ?: null;

        ex("UPDATE customers SET name=?, phone=?, dob=?, address=?, branch=?, aadhaar=?, pan=?, voter=? WHERE id=?",
            [$name, $phone, $dob, $village . ', ' . $district, $branch, $aadhaar ?: null, $pan ?: null, $voter ?: null, $cid]);

        // Insert or Update kyc_forms
        $existing = q("SELECT id, photo, h_photo, signed_copy FROM kyc_forms WHERE customer_id=?", [$cid], true);
        if ($existing) {
            $photoToKeep = $photoName ?: $existing['photo'];
            $hPhotoToKeep = $hPhotoName ?: $existing['h_photo'];
            $signedToKeep = $signedCopy ?: $existing['signed_copy'];

            ex("UPDATE kyc_forms SET form_date=?, center_no=?, group_no=?, guardian_type=?, guardian_name=?, education=?, " .
               "religion=?, category=?, house_no=?, village=?, post_office=?, district=?, state=?, pincode=?, house_type=?, " .
               "land_ha=?, livestock=?, bank_name=?, bank_acct=?, passbook_name=?, poverty_line=?, dist_center_m=?, dist_branch_km=?, " .
               "relative_in_center=?, relative_name=?, annual_income=?, other_loans=?, current_debt=?, repay_freq=?, " .
               "photo=?, h_name=?, h_father=?, h_dob=?, h_address=?, h_photo=?, consent_given=?, consent_date=?, declaration=?, " .
               "bureau_consent=?, address_verified=?, signed_copy=?, co_name=?, co_phone=?, co_relation=?, co_income=?, updated_at=NOW() " .
               "WHERE customer_id=?",
               [
                   $fDate, $centerNo, $groupNo, $guardianType, $guardianName, $education, $religion, $category,
                   $houseNo, $village, $postOffice, $district, $state, $pincode, $houseType, $landHa, $livestock,
                   $bankName, $bankAcct, $passbookName, $povertyLine, $distCenter, $distBranch, $relativeCenter,
                   $relativeName, $annualIncome, $otherLoans, $currentDebt, $repayFreq, $photoToKeep, $hName, $hFather,
                   $hDob, $hAddress, $hPhotoToKeep, $consentGiven, $consentDate, $declaration, $bureauConsent,
                   $addrVerified, $signedToKeep, $coName, $coPhone, $coRelation, $coIncome, $cid
               ]
            );
        } else {
            ex("INSERT INTO kyc_forms (customer_id, created_by, form_date, center_no, group_no, guardian_type, guardian_name, " .
               "education, religion, category, house_no, village, post_office, district, state, pincode, house_type, land_ha, " .
               "livestock, bank_name, bank_acct, passbook_name, poverty_line, dist_center_m, dist_branch_km, relative_in_center, " .
               "relative_name, annual_income, other_loans, current_debt, repay_freq, photo, h_name, h_father, h_dob, h_address, " .
               "h_photo, consent_given, consent_date, declaration, bureau_consent, address_verified, signed_copy, co_name, " .
               "co_phone, co_relation, co_income, created_at) VALUES (" . str_repeat('?, ', 46) . "?)",
               [
                   $cid, $u['id'], $fDate, $centerNo, $groupNo, $guardianType, $guardianName, $education, $religion,
                   $category, $houseNo, $village, $postOffice, $district, $state, $pincode, $houseType, $landHa,
                   $livestock, $bankName, $bankAcct, $passbookName, $povertyLine, $distCenter, $distBranch,
                   $relativeCenter, $relativeName, $annualIncome, $otherLoans, $currentDebt, $repayFreq, $photoName,
                   $hName, $hFather, $hDob, $hAddress, $hPhotoName, $consentGiven, $consentDate, $declaration,
                   $bureauConsent, $addrVerified, $signedCopy, $coName, $coPhone, $coRelation, $coIncome, date('Y-m-d H:i:s')
               ]
            );
        }

        flash("KYC Dossier for " . htmlspecialchars($name) . " saved successfully.", "success");
        redirect(url('/crm/' . $cid));
    }

    public function printForm(int $cid): void {
        need('kycform', 'kyc');
        $c = q("SELECT * FROM customers WHERE id=?", [$cid], true);
        if (!$c) {
            flash("Customer not found.", "danger");
            redirect(url('/crm'));
        }
        assert_branch_access($c['branch']);
        $kyc = q("SELECT * FROM kyc_forms WHERE customer_id=?", [$cid], true);

        view('kyc/print', [
            'c' => $c,
            'k' => $kyc,
            'noLayout' => true
        ]);
    }
}
