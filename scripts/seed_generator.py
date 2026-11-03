#!/usr/bin/env python3
"""
SARVOOCCH Microfinance Platform — Synthetic Data Generator
Generates realistic, interconnected, financially consistent test datasets.
Profiles:
  - small:  100 customers, 200 loans, 1,000 payment events
  - medium: 5,000 customers, 10,000 loans, 100,000 payment events
  - large:  50,000 customers, 100,000 loans, 1,000,000 payment events
"""

import argparse
import os
import random
import sqlite3
import sys
from datetime import date, datetime, timedelta

SCHEMA = """
CREATE TABLE IF NOT EXISTS users(id INTEGER PRIMARY KEY, username TEXT UNIQUE, pw TEXT, name TEXT, role TEXT,
  branch TEXT, phone TEXT, customer_id INTEGER, lat REAL, lng REAL, loc_at TEXT, must_change INTEGER DEFAULT 0);
CREATE TABLE IF NOT EXISTS employees(id INTEGER PRIMARY KEY, user_id INTEGER, name TEXT, designation TEXT, branch TEXT,
  manager_id INTEGER, phone TEXT, email TEXT, joined TEXT, status TEXT, bg_check TEXT, docs TEXT, salary REAL);
CREATE TABLE IF NOT EXISTS customers(id INTEGER PRIMARY KEY, name TEXT, phone TEXT, dob TEXT, address TEXT, branch TEXT,
  agent_id INTEGER, stage TEXT, aadhaar TEXT, pan TEXT, voter TEXT, kyc_status TEXT DEFAULT 'pending',
  wa_verified INTEGER DEFAULT 0, wa_otp TEXT, created TEXT);
CREATE TABLE IF NOT EXISTS comm_logs(id INTEGER PRIMARY KEY, customer_id INTEGER, channel TEXT, note TEXT, by_name TEXT, at TEXT);
CREATE TABLE IF NOT EXISTS products(id INTEGER PRIMARY KEY, name TEXT, rate REAL, min_amt REAL, max_amt REAL,
  min_tenure INTEGER, max_tenure INTEGER, method TEXT, fee_pct REAL, active INTEGER DEFAULT 1);
CREATE TABLE IF NOT EXISTS applications(id INTEGER PRIMARY KEY, customer_id INTEGER, product_id INTEGER, amount REAL,
  tenure INTEGER, rate REAL, purpose TEXT, income REAL, occupation TEXT, employer TEXT, co_name TEXT, co_phone TEXT,
  co_relation TEXT, co_income REAL, status TEXT, agent_id INTEGER, branch TEXT, created TEXT, remarks TEXT, docs TEXT);
CREATE TABLE IF NOT EXISTS loans(id INTEGER PRIMARY KEY, application_id INTEGER, customer_id INTEGER, product_id INTEGER,
  principal REAL, rate REAL, tenure INTEGER, method TEXT, emi REAL, start_date TEXT, status TEXT, closure_date TEXT,
  branch TEXT, agent_id INTEGER);
CREATE TABLE IF NOT EXISTS schedule(id INTEGER PRIMARY KEY, loan_id INTEGER, no INTEGER, due_date TEXT, emi REAL,
  principal REAL, interest REAL, balance REAL, paid INTEGER DEFAULT 0, paid_on TEXT);
CREATE TABLE IF NOT EXISTS payments(id INTEGER PRIMARY KEY, loan_id INTEGER, schedule_id INTEGER, amount REAL,
  channel TEXT, ref TEXT, at TEXT);
CREATE TABLE IF NOT EXISTS mandates(id INTEGER PRIMARY KEY, loan_id INTEGER, mtype TEXT, bank TEXT, acct_last4 TEXT,
  status TEXT, created TEXT);
CREATE TABLE IF NOT EXISTS tasks(id INTEGER PRIMARY KEY, title TEXT, customer_id INTEGER, ttype TEXT, lat REAL, lng REAL,
  due_date TEXT, officer_id INTEGER, status TEXT DEFAULT 'open', collected REAL DEFAULT 0, notes TEXT, done_at TEXT);
CREATE TABLE IF NOT EXISTS attendance(id INTEGER PRIMARY KEY, user_id INTEGER, day TEXT, in_time TEXT, out_time TEXT,
  lat REAL, lng REAL);
CREATE TABLE IF NOT EXISTS branches(id INTEGER PRIMARY KEY, name TEXT UNIQUE, code TEXT, address TEXT, phone TEXT,
  head_name TEXT, lat REAL, lng REAL, radius_m INTEGER DEFAULT 2000, active INTEGER DEFAULT 1);
CREATE TABLE IF NOT EXISTS holidays(day TEXT PRIMARY KEY, name TEXT);
CREATE TABLE IF NOT EXISTS settings(key TEXT PRIMARY KEY, value TEXT);
CREATE TABLE IF NOT EXISTS att_requests(id INTEGER PRIMARY KEY, user_id INTEGER, branch TEXT, day TEXT, in_time TEXT, out_time TEXT,
  reason TEXT, status TEXT DEFAULT 'pending', approver_role TEXT, approver_id INTEGER, requested_at TEXT, decided_by TEXT, decided_at TEXT, remarks TEXT);
CREATE TABLE IF NOT EXISTS leaves(id INTEGER PRIMARY KEY, user_id INTEGER, from_d TEXT, to_d TEXT, reason TEXT,
  status TEXT DEFAULT 'pending');
CREATE TABLE IF NOT EXISTS perf(id INTEGER PRIMARY KEY, user_id INTEGER, period TEXT, rating INTEGER, notes TEXT, by_name TEXT);
CREATE TABLE IF NOT EXISTS sync_log(id INTEGER PRIMARY KEY, uuid TEXT UNIQUE, user_id INTEGER, payload TEXT,
  captured_at TEXT, synced_at TEXT);
CREATE TABLE IF NOT EXISTS kyc_forms(id INTEGER PRIMARY KEY, customer_id INTEGER UNIQUE, created_by INTEGER, created_at TEXT,
  updated_at TEXT, form_date TEXT, center_no TEXT, group_no TEXT, guardian_type TEXT, guardian_name TEXT, education TEXT,
  religion TEXT, category TEXT, house_no TEXT, village TEXT, post_office TEXT, district TEXT, state TEXT, pincode TEXT,
  family TEXT, house_type TEXT, land_ha REAL, livestock TEXT, bank_name TEXT, bank_acct TEXT, passbook_name TEXT,
  poverty_line TEXT, dist_center_m REAL, dist_branch_km REAL, relative_in_center TEXT, relative_name TEXT,
  annual_income REAL, other_loans INTEGER, current_debt REAL, repay_freq TEXT, photo TEXT, h_name TEXT, h_father TEXT,
  h_dob TEXT, h_address TEXT, h_photo TEXT, consent_given INTEGER DEFAULT 0, consent_date TEXT,
  declaration INTEGER DEFAULT 0, bureau_consent INTEGER DEFAULT 0, address_verified INTEGER DEFAULT 0,
  verified_by TEXT, verified_on TEXT, verify_remarks TEXT, signed_copy TEXT,
  co_name TEXT, co_phone TEXT, co_relation TEXT, co_income REAL);
CREATE TABLE IF NOT EXISTS app_extra(application_id INTEGER PRIMARY KEY, prev_loans TEXT, insurance_wanted TEXT,
  insurance_for TEXT, docs_deposited TEXT, docs_other TEXT, inc_agri REAL, inc_business REAL, inc_job REAL, inc_other REAL,
  exp_basic REAL, exp_education REAL, exp_festival REAL, exp_health REAL, exp_emi REAL, exp_other REAL, group_rec REAL,
  center_rec REAL, loan_cycle INTEGER, requested_amt REAL, income_total REAL, expense_total REAL, net_saving REAL,
  declaration INTEGER DEFAULT 0);
CREATE TABLE IF NOT EXISTS approvals(id INTEGER PRIMARY KEY, application_id INTEGER, stage TEXT, by_user TEXT, by_role TEXT,
  amount REAL, remarks TEXT, at TEXT);
CREATE TABLE IF NOT EXISTS pregrt(id INTEGER PRIMARY KEY, branch TEXT, center_no TEXT, group_no TEXT, village TEXT,
  district TEXT, form_date TEXT, pso_name TEXT, pso_empid TEXT, bm_name TEXT, bm_empid TEXT, leader_knows_duties TEXT,
  notes TEXT, agent_id INTEGER, status TEXT DEFAULT 'draft', created_at TEXT, verified_by TEXT, verified_on TEXT,
  review_remarks TEXT);
CREATE TABLE IF NOT EXISTS pregrt_members(id INTEGER PRIMARY KEY, pregrt_id INTEGER, sno INTEGER, customer_id INTEGER,
  name TEXT, husband_name TEXT, age INTEGER, voter_id TEXT, aadhaar4 TEXT, family_in_group TEXT, house_type TEXT,
  land_ha REAL, livestock TEXT, annual_income REAL, family_size INTEGER, category TEXT, loan_amount REAL, purpose TEXT,
  frequency TEXT, instalments INTEGER, c_meeting INTEGER, c_joint INTEGER, c_fee INTEGER, c_rate INTEGER,
  c_insurance INTEGER, c_company INTEGER, c_group INTEGER);
"""

FIRST_NAMES = [
    "Sunita", "Shashi", "Radha", "Urmila", "Pooja", "Rekha", "Kavita", "Anita",
    "Geeta", "Mamta", "Suman", "Meena", "Aarti", "Lata", "Seema", "Kamla",
    "Manju", "Sharda", "Santosh", "Saroj", "Prem", "Pushpa", "Maya", "Kiran",
    "Ravi", "Manoj", "Suresh", "Ramesh", "Mukesh", "Rajesh", "Dinesh", "Anil"
]

LAST_NAMES = [
    "Verma", "Sharma", "Yadav", "Patel", "Chouhan", "Tiwari", "Mishra", "Joshi",
    "Malviya", "Thakur", "Solanki", "Sen", "Parihar", "Gupta", "Bairagi", "Ahirwar"
]

BRANCHES = [
    ("Indore - Vijay Nagar", "IND-01", "Scheme 54, Vijay Nagar, Indore", "9826011111", "Meera Manager", 22.7533, 75.8937),
    ("Indore - Rajwada", "IND-02", "MG Road, Rajwada, Indore", "9826022222", "Vikram Rathore", 22.7196, 75.8577),
    ("Ujjain - Freeganj", "UJJ-01", "Freeganj Main Road, Ujjain", "9826033333", "Rajendra Joshi", 23.1765, 75.7885),
    ("Bhopal - MP Nagar", "BHO-01", "Zone-II, MP Nagar, Bhopal", "9826044444", "Suresh Malviya", 23.2324, 77.4270),
    ("Dewas - Station Road", "DEW-01", "Station Road, Dewas", "9826055555", "Kamal Solanki", 22.9676, 76.0534),
]

OCCUPATIONS = [
    "Tailoring & Garments", "Dairy & Livestock", "Grocery Kirana Store",
    "Vegetable & Fruit Vending", "Pottery & Handicrafts", "Tea & Snacks Stall",
    "Beauty Parlour & Henna", "Embroidery & Zari Work", "Bangle Making"
]

def generate_aadhaar():
    return f"XXXXXXXX{random.randint(1000, 9999)}"

def generate_pan():
    letters = "".join(random.choices("ABCDEFGHJKLMNPQRSTUVWXYZ", k=5))
    digits = f"{random.randint(1000, 9999)}"
    last = random.choice("ABCDEFGHJKLMNPQRSTUVWXYZ")
    return f"{letters}{digits}{last}"

def generate_phone(idx):
    base = 9826000000 + (idx % 9000000)
    return str(base)

def build_dataset(db_path, profile="small", seed_val=42):
    random.seed(seed_val)

    if profile == "small":
        num_customers = 100
        num_loans = 200
    elif profile == "medium":
        num_customers = 5000
        num_loans = 10000
    elif profile == "large":
        num_customers = 50000
        num_loans = 100000
    else:
        raise ValueError(f"Unknown profile {profile}")

    print(f"[*] Initializing SARVOOCCH synthetic generator: profile={profile}")
    print(f"[*] Target customers: {num_customers:,} | Target loans: {num_loans:,}")
    print(f"[*] Target database: {db_path}")

    conn = sqlite3.connect(db_path)
    cur = conn.cursor()

    cur.execute("PRAGMA synchronous = OFF")
    cur.execute("PRAGMA journal_mode = MEMORY")

    if SCHEMA:
        cur.executescript(SCHEMA)

    # Ensure branches exist
    for b in BRANCHES:
        cur.execute("""
            INSERT OR IGNORE INTO branches(name, code, address, phone, head_name, lat, lng, radius_m, active)
            VALUES (?, ?, ?, ?, ?, ?, ?, 2000, 1)
        """, b)

    # Products check
    prods = cur.execute("SELECT id, rate, min_amt, max_amt, method FROM products WHERE active=1").fetchall()
    if not prods:
        cur.execute("INSERT INTO products(name, rate, min_amt, max_amt, min_tenure, max_tenure, method, active) VALUES ('General Micro Loan', 18.0, 10000, 60000, 6, 24, 'reducing', 1)")
        cur.execute("INSERT INTO products(name, rate, min_amt, max_amt, min_tenure, max_tenure, method, active) VALUES ('Women Enterprise Loan', 16.0, 20000, 100000, 12, 36, 'flat', 1)")
        prods = cur.execute("SELECT id, rate, min_amt, max_amt, method FROM products WHERE active=1").fetchall()

    today = date.today()

    # Generate Customers
    print(f"[*] Generating {num_customers:,} customers in batches...")
    cust_batch = []
    for i in range(1, num_customers + 1):
        fn = random.choice(FIRST_NAMES)
        ln = random.choice(LAST_NAMES)
        name = f"{fn} {ln}"
        phone = generate_phone(i)
        b_name = random.choice(BRANCHES)[0]
        dob = (today - timedelta(days=random.randint(20 * 365, 50 * 365))).isoformat()
        stage = random.choice(["lead", "kyc_done", "active", "closed"])
        aadhaar = generate_aadhaar()
        pan = generate_pan()
        agent_id = random.randint(1, 4)

        cust_batch.append((name, phone, dob, f"House {random.randint(1, 200)}, {b_name.split(' - ')[0]}", b_name, agent_id, stage, aadhaar, pan, "MP09" + str(random.randint(100000, 999999)), "verified", 1))

        if len(cust_batch) >= 1000:
            cur.executemany("""
                INSERT INTO customers(name, phone, dob, address, branch, agent_id, stage, aadhaar, pan, voter, kyc_status, wa_verified)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, cust_batch)
            cust_batch.clear()

    if cust_batch:
        cur.executemany("""
            INSERT INTO customers(name, phone, dob, address, branch, agent_id, stage, aadhaar, pan, voter, kyc_status, wa_verified)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, cust_batch)
        cust_batch.clear()

    cust_ids = [r[0] for r in cur.execute("SELECT id FROM customers").fetchall()]

    # Generate Loans, Schedules, and Payments
    print(f"[*] Generating {num_loans:,} loans with repayment schedules & payments...")
    loan_count = 0
    payment_events = 0

    for i in range(1, num_loans + 1):
        cid = random.choice(cust_ids)
        prod = random.choice(prods)
        pid, rate, min_a, max_a, method = prod
        principal = float(random.randint(int(min_a / 1000), int(max_a / 1000)) * 1000)
        tenure = random.choice([12, 18, 24])
        b_name = random.choice(BRANCHES)[0]
        start_d = today - timedelta(days=random.randint(30, 365))
        status = random.choice(["active", "active", "active", "closed"])

        # EMI calculation
        if method == "flat":
            emi = round((principal + (principal * rate / 100 * tenure / 12)) / tenure, 2)
        else:
            r = rate / 1200
            emi = round(principal * r * ((1 + r) ** tenure) / (((1 + r) ** tenure) - 1), 2)

        cur.execute("""
            INSERT INTO loans(application_id, customer_id, product_id, principal, rate, tenure, method, emi, start_date, status, branch, agent_id)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (i, cid, pid, principal, rate, tenure, method, emi, start_d.isoformat(), status, b_name, random.randint(1, 4)))

        lid = cur.lastrowid
        loan_count += 1

        # Schedule and payments
        bal = principal
        for m_idx in range(1, tenure + 1):
            due = start_d + timedelta(days=m_idx * 30)
            if due.weekday() == 5:  # Saturday
                due += timedelta(days=2)
            elif due.weekday() == 6:  # Sunday
                due += timedelta(days=1)

            interest = round(bal * rate / 1200, 2) if method == "reducing" else round(principal * rate / 100 / 12, 2)
            prin = round(emi - interest, 2) if m_idx < tenure else bal
            bal = max(0.0, round(bal - prin, 2))

            paid = 1 if (status == "closed" or (status == "active" and due < today and random.random() > 0.15)) else 0
            paid_on = due.isoformat() if paid else None

            cur.execute("""
                INSERT INTO schedule(loan_id, no, due_date, emi, principal, interest, balance, paid, paid_on)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (lid, m_idx, due.isoformat(), emi, prin, interest, bal, paid, paid_on))

            sid = cur.lastrowid

            if paid:
                cur.execute("""
                    INSERT INTO payments(loan_id, schedule_id, amount, channel, ref, at)
                    VALUES (?, ?, ?, ?, ?, ?)
                """, (lid, sid, emi, random.choice(["upi", "field_cash", "branch_counter"]), f"TXN{random.randint(1000000, 9999999)}", due.isoformat() + "T11:00:00"))
                payment_events += 1

    conn.commit()
    conn.close()

    print(f"[✓] Synthesis Complete: {num_customers:,} customers, {loan_count:,} loans, {payment_events:,} payments persisted.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="SARVOOCCH Synthetic Data Generator")
    parser.add_argument("--profile", choices=["small", "medium", "large"], default="small")
    parser.add_argument("--db-path", default="/Users/vaidik/sarvocch_repo/instance/sarvocch.db")
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    build_dataset(args.db_path, profile=args.profile, seed_val=args.seed)
