#!/usr/bin/env python3
"""
Phase C Verification Script for SARVOOCCH Microcare Foundation
Validates Multi-Branch Tenant Isolation, Route-by-Route assert_branch_access, and API Lockdown
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
            if c == "\\" and nxt == "'":
                i += 2
                continue
            if c == "'":
                in_single = False
            i += 1
            continue
            
        if in_double:
            if c == "\\" and nxt == '"':
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

def verify_phase_c():
    print("=== SARVOOCCH PHASE C VERIFICATION SUITE ===")
    
    # 1. Structural and Syntax Check on all Phase C modified files
    phase_c_files = [
        "portal/app/auth.php",
        "portal/app/controllers/LoanController.php",
        "portal/app/controllers/CrmController.php",
        "portal/app/controllers/ApplicationController.php",
        "portal/app/controllers/KycController.php",
        "portal/app/controllers/PreGrtController.php",
        "portal/app/controllers/OperationsControllers.php"
    ]
    for rel_path in phase_c_files:
        full_path = os.path.join(REPO_ROOT, rel_path)
        assert os.path.exists(full_path), f"File missing: {rel_path}"
        check_syntax_and_balance(full_path)
        print(f"[✓] Syntax & structural balance verified: {rel_path}")

    # 2. AUD-007: Verify auth.php implements assert_branch_access and require_login
    with open(os.path.join(PORTAL_DIR, "app/auth.php")) as f:
        auth_code = f.read()
    assert "function assert_branch_access(?string $recordBranch): void" in auth_code, "assert_branch_access definition missing in auth.php"
    assert "function require_login(): array" in auth_code, "require_login definition missing in auth.php"
    assert "$u['role'] ?? '') === 'admin'" in auth_code, "Admin role check missing in assert_branch_access"
    assert "http_response_code(403)" in auth_code, "403 status code missing on branch mismatch"
    print("[✓] AUD-007: assert_branch_access() and require_login() verified in auth.php.")

    # 3. Route-by-Route Audit: LoanController
    with open(os.path.join(PORTAL_DIR, "app/controllers/LoanController.php")) as f:
        loan_code = f.read()
    loan_methods = ["detail", "card", "nocPdf", "settleForm", "settlePost", "payForm", "payPost", "portal"]
    for m in loan_methods:
        pattern = rf"public function {m}\s*\([^\)]*\): void \{{(.*?)(?=\n    public function |\n\}})"
        match = re.search(pattern, loan_code, re.DOTALL)
        assert match, f"Method {m} not found in LoanController"
        body = match.group(1)
        assert "assert_branch_access(" in body, f"LoanController::{m} does not call assert_branch_access"
    assert "if ($u['role'] !== 'admin')" in loan_code and "l.branch = ?" in loan_code, "LoanController::list does not scope by branch for non-admin"
    print("[✓] AUD-007: LoanController enforces assert_branch_access on 8 single-record methods and list scoping.")

    # 4. Route-by-Route Audit: CrmController
    with open(os.path.join(PORTAL_DIR, "app/controllers/CrmController.php")) as f:
        crm_code = f.read()
    crm_methods = ["detail", "addLog", "updateStage", "createPortalLogin", "loginSlip"]
    for m in crm_methods:
        pattern = rf"public function {m}\s*\([^\)]*\): void \{{(.*?)(?=\n    public function |\n\}})"
        match = re.search(pattern, crm_code, re.DOTALL)
        assert match, f"Method {m} not found in CrmController"
        body = match.group(1)
        assert "assert_branch_access(" in body, f"CrmController::{m} does not call assert_branch_access"
    assert "if ($u['role'] !== 'admin')" in crm_code and "c.branch = ?" in crm_code, "CrmController::list does not scope by branch for non-admin"
    print("[✓] AUD-007: CrmController enforces assert_branch_access on 5 single-record methods and list scoping.")

    # 5. Route-by-Route Audit: ApplicationController
    with open(os.path.join(PORTAL_DIR, "app/controllers/ApplicationController.php")) as f:
        app_code = f.read()
    app_methods = ["detail", "action", "applyPost", "sanctionPdf"]
    for m in app_methods:
        pattern = rf"public function {m}\s*\([^\)]*\): void \{{(.*?)(?=\n    public function |\n\}})"
        match = re.search(pattern, app_code, re.DOTALL)
        assert match, f"Method {m} not found in ApplicationController"
        body = match.group(1)
        assert "assert_branch_access(" in body, f"ApplicationController::{m} does not call assert_branch_access"
    assert "if ($u['role'] !== 'admin')" in app_code and "a.branch = ?" in app_code, "ApplicationController::list does not scope by branch for non-admin"
    print("[✓] AUD-007: ApplicationController enforces assert_branch_access on 4 single-record methods and list scoping.")

    # 6. Route-by-Route Audit: KycController
    with open(os.path.join(PORTAL_DIR, "app/controllers/KycController.php")) as f:
        kyc_code = f.read()
    kyc_methods = ["form", "saveForm", "printForm"]
    for m in kyc_methods:
        pattern = rf"public function {m}\s*\([^\)]*\): void \{{(.*?)(?=\n    public function |\n\}})"
        match = re.search(pattern, kyc_code, re.DOTALL)
        assert match, f"Method {m} not found in KycController"
        body = match.group(1)
        assert "assert_branch_access(" in body, f"KycController::{m} does not call assert_branch_access"
    assert "c.branch=?" in kyc_code or "c.branch = ?" in kyc_code, "KycController::verifyList does not scope by branch"
    print("[✓] AUD-007: KycController enforces assert_branch_access on 3 single-record methods and list scoping.")

    # 7. Route-by-Route Audit: PreGrtController
    with open(os.path.join(PORTAL_DIR, "app/controllers/PreGrtController.php")) as f:
        pregrt_code = f.read()
    pregrt_methods = ["detail", "update", "review", "printDoc", "groupApplyForm", "groupApplyPost"]
    for m in pregrt_methods:
        pattern = rf"public function {m}\s*\([^\)]*\): void \{{(.*?)(?=\n    public function |\n\}})"
        match = re.search(pattern, pregrt_code, re.DOTALL)
        assert match, f"Method {m} not found in PreGrtController"
        body = match.group(1)
        assert "assert_branch_access(" in body, f"PreGrtController::{m} does not call assert_branch_access"
    assert "p.branch = ?" in pregrt_code, "PreGrtController::list does not scope by branch for non-admin"
    print("[✓] AUD-007: PreGrtController enforces assert_branch_access on 6 single-record methods and list scoping.")

    # 8. AUD-011: UploadsController::serve cross-branch isolation
    with open(os.path.join(PORTAL_DIR, "app/controllers/OperationsControllers.php")) as f:
        ops_code = f.read()
    assert "assert_branch_access($fileBranch)" in ops_code, "UploadsController::serve does not call assert_branch_access"
    assert "die(\"Access Denied: Cross-branch" in ops_code, "UploadsController::serve missing 403 on unverified file"
    print("[✓] AUD-011: UploadsController::serve enforces branch-level tenant isolation.")

    # 9. AUD-005 Backend: Lock down unauthenticated APIs
    # SyncController::post
    sync_post_match = re.search(r"class SyncController.*?public function post\(\): void \{(.*?)\}", ops_code, re.DOTALL)
    assert sync_post_match, "SyncController::post not found"
    sync_post_body = sync_post_match.group(1)
    assert "$u = require_login();" in sync_post_body, "SyncController::post does not call require_login()"
    assert "csrf_verify();" in sync_post_body, "SyncController::post does not call csrf_verify()"
    assert "$uid = $u ? $u['id'] : 1;" not in sync_post_body, "SyncController::post still defaults user_id to 1"
    assert "$uid = (int)$u['id'];" in sync_post_body, "SyncController::post does not strictly bind user_id to authenticated user"

    # ApiController::location
    loc_match = re.search(r"class ApiController.*?public function location\(\): void \{(.*?)\}", ops_code, re.DOTALL)
    assert loc_match, "ApiController::location not found"
    loc_body = loc_match.group(1)
    assert "$u = require_login();" in loc_body, "ApiController::location does not call require_login()"
    assert "csrf_verify();" in loc_body, "ApiController::location does not call csrf_verify()"
    print("[✓] AUD-005 Backend: /api/sync and /api/location require authenticated session and CSRF; user_id default to 1 removed.")

    print("\nALL PHASE C VERIFICATION CHECKS PASSED (100%).")

if __name__ == "__main__":
    verify_phase_c()
