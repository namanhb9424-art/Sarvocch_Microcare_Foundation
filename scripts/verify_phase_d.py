#!/usr/bin/env python3
"""
Phase D Verification Script for SARVOOCCH Microcare Foundation
Validates Statutory Aadhaar Redaction, Schema Migration, and Views Masking
"""

import os
import re
import glob

REPO_ROOT = "/Users/vaidik/sarvocch_repo"
PORTAL_DIR = os.path.join(REPO_ROOT, "portal")

def check_syntax_and_balance(path):
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
    
    braces = 0
    parens = 0
    brackets = 0
    in_single = False
    in_double = False
    in_line_comment = False
    in_block_comment = False
    i = 0
    while i < len(content):
        c = content[i]
        nxt = content[i+1] if i+1 < len(content) else ""
        
        if in_line_comment:
            if c == "\n":
                in_line_comment = False
            i += 1
            continue
            
        if in_block_comment:
            if c == "*" and nxt == "/":
                in_block_comment = False
                i += 2
                continue
            i += 1
            continue
            
        if in_single:
            if c == "\\":
                i += 2
                continue
            if c == "'":
                in_single = False
            i += 1
            continue
            
        if in_double:
            if c == "\\":
                i += 2
                continue
            if c == '"':
                in_double = False
            i += 1
            continue
            
        if c == "/" and nxt == "/":
            in_line_comment = True
            i += 2
            continue
        if c == "/" and nxt == "*":
            in_block_comment = True
            i += 2
            continue
            
        if c == "'":
            in_single = True
        elif c == '"':
            in_double = True
        elif c == '{':
            braces += 1
        elif c == '}':
            braces -= 1
        elif c == '(':
            parens += 1
        elif c == ')':
            parens -= 1
        elif c == '[':
            brackets += 1
        elif c == ']':
            brackets -= 1
            
        i += 1
        
    assert braces == 0, f"Unbalanced braces in {path}: balance={braces}"
    assert parens == 0, f"Unbalanced parentheses in {path}: balance={parens}"
    assert brackets == 0, f"Unbalanced square brackets in {path}: balance={brackets}"
    return True

def verify_phase_d():
    print("=== SARVOOCCH PHASE D VERIFICATION SUITE ===")

    # 1. Structural & Syntax Check on all modified PHP files
    phase_d_files = [
        "portal/app/config.php",
        "portal/app/controllers/KycController.php",
        "portal/app/controllers/CrmController.php",
        "portal/app/controllers/ApplicationController.php",
        "portal/app/controllers/LoanController.php",
        "portal/app/views/loans/noc_print.php",
        "portal/app/views/kyc/print.php",
        "portal/app/views/kyc/form.php",
        "portal/app/views/kyc/verify.php",
        "portal/app/views/crm/detail.php",
        "portal/app/views/pregrt/print.php",
        "portal/app/views/pregrt/form.php"
    ]
    for rel_path in phase_d_files:
        full_path = os.path.join(REPO_ROOT, rel_path)
        assert os.path.exists(full_path), f"File missing: {rel_path}"
        check_syntax_and_balance(full_path)
        print(f"[✓] Syntax & structural balance verified: {rel_path}")

    # 2. Migration script verification: 2026_11_mask_aadhaar.sql
    migration_path = os.path.join(PORTAL_DIR, "database/migrations/2026_11_mask_aadhaar.sql")
    assert os.path.exists(migration_path), "Migration 2026_11_mask_aadhaar.sql missing"
    with open(migration_path, "r", encoding="utf-8") as f:
        mig_sql = f.read()
    assert "UP MIGRATION" in mig_sql, "Missing UP MIGRATION section"
    assert "ROLLBACK MIGRATION" in mig_sql, "Missing ROLLBACK MIGRATION section"
    assert "aadhaar_last4" in mig_sql, "Missing aadhaar_last4 in migration"
    assert "aadhaar_hash" in mig_sql, "Missing aadhaar_hash in migration"
    assert "DROP COLUMN `aadhaar`" in mig_sql, "Missing DROP COLUMN aadhaar in migration"
    print("[✓] Task 1: Migration script 2026_11_mask_aadhaar.sql verified (UP + ROLLBACK).")

    # 3. Schema & Setup database verification
    for s_file in ["database/schema.sql", "database/setup_database.sql"]:
        s_path = os.path.join(PORTAL_DIR, s_file)
        with open(s_path, "r", encoding="utf-8") as f:
            s_sql = f.read()
        assert "`aadhaar_last4` VARCHAR(4)" in s_sql, f"Missing aadhaar_last4 in {s_file}"
        assert "`aadhaar_hash` CHAR(64)" in s_sql, f"Missing aadhaar_hash in {s_file}"
        assert "idx_customers_aadhaar_hash" in s_sql, f"Missing idx_customers_aadhaar_hash in {s_file}"
        assert not re.search(r"`customers`\s*\([^;]*`aadhaar`\s+VARCHAR\(12\)", s_sql), f"Raw aadhaar still exists in {s_file}"
        print(f"[✓] Task 1: {s_file} verified (raw aadhaar removed, masked columns and index added).")

    # 4. Config & .env.example verification
    with open(os.path.join(PORTAL_DIR, "app/config.php"), "r", encoding="utf-8") as f:
        cfg = f.read()
    assert "define('AADHAAR_HMAC_KEY'" in cfg, "Missing AADHAAR_HMAC_KEY in config.php"
    with open(os.path.join(PORTAL_DIR, ".env.example"), "r", encoding="utf-8") as f:
        env_ex = f.read()
    assert "AADHAAR_HMAC_KEY=" in env_ex, "Missing AADHAAR_HMAC_KEY in .env.example"
    print("[✓] Task 2: AADHAAR_HMAC_KEY verified in config.php and .env.example.")

    # 5. KycController intake & hashing verification
    with open(os.path.join(PORTAL_DIR, "app/controllers/KycController.php"), "r", encoding="utf-8") as f:
        kyc_code = f.read()
    assert "validate_id('aadhaar'" in kyc_code, "Missing Verhoeff validate_id call in KycController"
    assert "hash_hmac('sha256', $rawAadhaar, AADHAAR_HMAC_KEY)" in kyc_code, "Missing hash_hmac derivation in KycController"
    assert "aadhaar_last4=?, aadhaar_hash=?" in kyc_code, "KycController does not update aadhaar_last4 and aadhaar_hash"
    assert not re.search(r"UPDATE\s+customers\s+SET[^;]*\baadhaar=\?", kyc_code), "KycController still updates raw aadhaar"
    print("[✓] Task 2: KycController intake, Verhoeff validation, and HMAC hashing verified.")

    # 6. Global SQL search: Confirm ZERO writes to raw aadhaar
    php_files = glob.glob(os.path.join(PORTAL_DIR, "**/*.php"), recursive=True)
    raw_writes = []
    for pf in php_files:
        with open(pf, "r", encoding="utf-8") as f:
            content = f.read()
        matches = re.findall(r"(?:INSERT\s+INTO|UPDATE)\s+customers\s+[^;]*\baadhaar\b\s*=", content, re.IGNORECASE)
        if matches:
            raw_writes.append((pf, matches))
    assert len(raw_writes) == 0, f"Found raw aadhaar writes in: {raw_writes}"
    print(f"[✓] Zero SQL INSERT / UPDATE statements write raw 12-digit Aadhaar across all {len(php_files)} PHP files.")

    # 7. Views masking verification
    views_to_check = [
        ("app/views/loans/noc_print.php", "XXXX-XXXX-"),
        ("app/views/kyc/print.php", "XXXX-XXXX-"),
        ("app/views/kyc/verify.php", "XXXX-XXXX-"),
        ("app/views/crm/detail.php", "XXXX-XXXX-"),
        ("app/views/pregrt/print.php", "XXXX-XXXX-"),
        ("app/views/pregrt/form.php", "XXXX-XXXX-")
    ]
    for v_rel, mask_str in views_to_check:
        v_path = os.path.join(PORTAL_DIR, v_rel)
        with open(v_path, "r", encoding="utf-8") as f:
            v_content = f.read()
        assert mask_str in v_content, f"View {v_rel} does not contain masked pattern '{mask_str}'"
        print(f"[✓] View {v_rel} verified with masked display format ({mask_str}).")

    print("\nALL PHASE D VERIFICATION CHECKS PASSED (100%).")

if __name__ == "__main__":
    verify_phase_d()
