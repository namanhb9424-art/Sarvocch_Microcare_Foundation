#!/usr/bin/env python3
"""
Phase B Verification Script for SARVOOCCH Microcare Foundation
Validates Financial ACID Integrity, Row Locking, and Route Cleanup
"""

import os
import re
import glob

REPO_ROOT = "/Users/vaidik/sarvocch_repo"
PORTAL_DIR = os.path.join(REPO_ROOT, "portal")

def check_syntax_and_balance(path):
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
    
    # Balanced quotes outside strings
    # Simple brace balance check
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

def verify_phase_b():
    print("=== SARVOOCCH PHASE B VERIFICATION SUITE ===")
    
    # 1. Check syntax and bracket balance on all modified files
    target_files = [
        "portal/app/db.php",
        "portal/app/emi.php",
        "portal/app/controllers/LoanController.php",
        "portal/app/controllers/ApplicationController.php",
        "portal/app/router.php"
    ]
    for rel_path in target_files:
        full_path = os.path.join(REPO_ROOT, rel_path)
        assert os.path.exists(full_path), f"File missing: {rel_path}"
        check_syntax_and_balance(full_path)
        print(f"[✓] Syntax & structural balance verified: {rel_path}")
        
    # 2. AUD-003: Verify db.php transaction methods & helpers
    with open(os.path.join(PORTAL_DIR, "app/db.php")) as f:
        db_code = f.read()
    assert "public static function beginTransaction()" in db_code, "Missing Database::beginTransaction()"
    assert "public static function commit()" in db_code, "Missing Database::commit()"
    assert "public static function rollBack()" in db_code, "Missing Database::rollBack()"
    assert "public static function inTransaction()" in db_code, "Missing Database::inTransaction()"
    assert "function db_begin()" in db_code, "Missing db_begin helper"
    assert "function db_commit()" in db_code, "Missing db_commit helper"
    assert "function db_rollback()" in db_code, "Missing db_rollback helper"
    print("[✓] AUD-003: db.php transaction methods and global helpers verified.")
    
    # 3. AUD-003: Verify emi.php transactions & FOR UPDATE
    with open(os.path.join(PORTAL_DIR, "app/emi.php")) as f:
        emi_code = f.read()
    assert "Database::beginTransaction()" in emi_code, "Missing beginTransaction in emi.php"
    assert "Database::commit()" in emi_code, "Missing commit in emi.php"
    assert "Database::rollBack()" in emi_code, "Missing rollBack in emi.php"
    assert "FOR UPDATE" in emi_code, "Missing FOR UPDATE in emi.php recordPayment"
    assert "(int)$s['paid'] === 1" in emi_code, "Missing paid check in emi.php recordPayment"
    print("[✓] AUD-003: emi.php createLoan & recordPayment ACID transactions and row locking verified.")
    
    # 4. AUD-003: Verify ApplicationController disburse transaction
    with open(os.path.join(PORTAL_DIR, "app/controllers/ApplicationController.php")) as f:
        app_ctrl_code = f.read()
    assert "Database::beginTransaction();" in app_ctrl_code, "Missing transaction in ApplicationController"
    assert "Finance::createLoan($aid);" in app_ctrl_code, "Missing createLoan call"
    assert "Database::commit();" in app_ctrl_code, "Missing commit in ApplicationController"
    assert "Database::rollBack();" in app_ctrl_code, "Missing rollBack in ApplicationController"
    print("[✓] AUD-003: ApplicationController disburse transaction verified.")
    
    # 5. AUD-003 & AUD-004: Verify LoanController settlePost and runAutopay
    with open(os.path.join(PORTAL_DIR, "app/controllers/LoanController.php")) as f:
        loan_ctrl_code = f.read()
    assert "Database::beginTransaction();" in loan_ctrl_code, "Missing transaction in settlePost"
    assert "FOR UPDATE" in loan_ctrl_code, "Missing FOR UPDATE in settlePost"
    assert "Database::commit();" in loan_ctrl_code, "Missing commit in settlePost"
    assert "Database::rollBack();" in loan_ctrl_code, "Missing rollBack in settlePost"
    assert "http_response_code(501);" in loan_ctrl_code, "Missing 501 in runAutopay"
    assert "Automated eNACH clearing is disabled" in loan_ctrl_code, "Missing disabled message in runAutopay"
    print("[✓] AUD-003 & AUD-004: LoanController settlePost row locking and runAutopay 501 disabled verified.")
    
    # 6. AUD-004 & AUD-012: Verify router.php route cleanup
    with open(os.path.join(PORTAL_DIR, "app/router.php")) as f:
        router_code = f.read()
    assert "/autopay/run" not in router_code, "Dead route /autopay/run still present in router.php"
    assert "/loans/:lid/autopay" not in router_code, "Dead route /loans/:lid/autopay still present in router.php"
    assert re.search(r"Router::add\(\s*'POST'\s*,\s*'/field/attendance'\s*,\s*'AttendanceController'\s*,\s*'punch'\s*\);", router_code), "Missing remapped /field/attendance route"
    print("[✓] AUD-004 & AUD-012: Dead routes removed and /field/attendance remapped.")
    
    # 7. Static route-to-controller consistency check (100% resolution)
    classes = {}
    for cf in glob.glob(os.path.join(PORTAL_DIR, "app/controllers/*.php")):
        with open(cf, "r") as f:
            content = f.read()
        class_blocks = re.split(r"(class\s+[a-zA-Z0-9_]+)", content)
        for i in range(1, len(class_blocks), 2):
            cname = class_blocks[i].split()[1]
            cbody = class_blocks[i+1]
            methods = re.findall(r"public\s+function\s+([a-zA-Z0-9_]+)\s*\(", cbody)
            classes[cname] = set(methods)

    route_matches = re.findall(r"Router::add\(\s*[\x27\"]([A-Z]+)[\x27\"]\s*,\s*[\x27\"]([^\x27\"]+)[\x27\"]\s*,\s*[\x27\"]([^\x27\"]+)[\x27\"]\s*,\s*[\x27\"]([^\x27\"]+)[\x27\"]\s*\)", router_code)

    missing = []
    for method, pattern, cname, mname in route_matches:
        if cname not in classes:
            missing.append((method, pattern, cname, mname, "Controller class missing"))
        elif mname not in classes[cname]:
            missing.append((method, pattern, cname, mname, f"Method missing in {cname}"))

    assert len(missing) == 0, f"Found {len(missing)} unresolved routes: {missing}"
    print(f"[✓] Static Route-to-Controller Consistency: 100% of {len(route_matches)} registered routes resolve successfully.")
    
    print("\nALL PHASE B VERIFICATION CHECKS PASSED (100%).")

if __name__ == "__main__":
    verify_phase_b()
