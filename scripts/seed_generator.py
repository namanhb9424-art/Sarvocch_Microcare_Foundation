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
