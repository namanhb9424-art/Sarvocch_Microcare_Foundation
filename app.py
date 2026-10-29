"""
Sarvocch Microcare Foundation - Micro Finance Management Portal (PROTOTYPE)
Flask + SQLite. Zero paid services: KYC, payment gateway, eNACH and WhatsApp are MOCKED.
Run:  pip install -r requirements.txt && python app.py   ->  http://127.0.0.1:5000
"""
import io
import json
import os
import random
import re
import sqlite3
import uuid
from datetime import date, datetime, timedelta
from functools import wraps
from math import asin, cos, radians, sin, sqrt

from flask import (Flask, abort, flash, g, jsonify, redirect, render_template,
                   request, send_file, send_from_directory, session, url_for)
from werkzeug.security import check_password_hash, generate_password_hash
from werkzeug.utils import secure_filename

BASE = os.path.dirname(os.path.abspath(__file__))
# On Vercel the project folder is read-only; only /tmp is writable (and it is temporary).
# DATA_DIR can also be set on any host to point at a persistent disk (e.g. Render disk).
DATA_DIR = os.environ.get("DATA_DIR") or ("/tmp/sarvocch" if os.environ.get("VERCEL") else BASE)
DB_PATH = os.path.join(DATA_DIR, "instance", "sarvocch.db")
UPLOADS = os.path.join(DATA_DIR, "uploads")
os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
os.makedirs(UPLOADS, exist_ok=True)

app = Flask(__name__)
app.config["SECRET_KEY"] = os.environ.get("SECRET_KEY", "dev-only-change-me")
app.config["MAX_CONTENT_LENGTH"] = 16 * 1024 * 1024
ALLOWED_EXT = {"pdf", "png", "jpg", "jpeg"}
DEFAULT_BRANCHES = [  # name, code, address, latitude, longitude (the first three are demo locations: edit them under Branches)
    ("Indore - Vijay Nagar", "IND-VN", "Vijay Nagar, Indore (demo location)", 22.7533, 75.8937),
    ("Indore - Palasia", "IND-PL", "Palasia, Indore (demo location)", 22.7241, 75.8839),
    ("Bhopal - MP Nagar", "BPL-MP", "MP Nagar, Bhopal (demo location)", 23.2332, 77.4340),
    ("Pipariya Branch", "PPR", "Pipariya, Madhya Pradesh", 22.738750457763672, 78.3563461303711),
    ("Bhopal Head Office", "BPL-HO", "Bhopal office", 23.27993, 77.45220)]
BRANCHES = [b[0] for b in DEFAULT_BRANCHES]   # refreshed from the database on every request (admin can add branches)
OTP_DEMO = "123456"

# --------------------------------------------------------------------------- #
# RBAC
# --------------------------------------------------------------------------- #
PERMS = {
    "admin": {"*"},
    "manager": {"dashboard", "crm", "kyc", "apply", "applications", "approve", "disburse", "loans",
                "payments", "field", "employees", "hrm", "whatsapp", "sync", "calculator", "products",
                "kycform", "pregrt", "attendance"},
    "underwriter": {"dashboard", "crm", "kyc", "applications", "approve", "loans", "calculator", "pregrt", "attendance"},
    "field_agent": {"crm", "kyc", "apply", "applications", "field", "sync", "calculator", "whatsapp", "payments",
                    "kycform", "pregrt", "attendance"},
    "customer": {"portal", "payments", "calculator"},
}
ROLES = list(PERMS.keys())
NAV = [  # (module, label, endpoint, icon)
    ("dashboard", "Dashboard", "dashboard", "speedometer2"),
    ("portal", "My Loans", "portal", "wallet2"),
    ("crm", "CRM", "crm", "people"),
    ("kycform", "New Customer (KYC Form)", "kyc_form_new", "person-vcard"),
    ("pregrt", "Pre-GRT (Group Form)", "pregrt_list", "people-fill"),
    ("apply", "New Application", "apply", "file-earmark-plus"),
    ("applications", "Applications", "applications", "files"),
    ("loans", "Loans & EMI", "loans", "cash-coin"),
    ("kyc", "KYC Verify", "kyc", "shield-check"),
    ("calculator", "EMI Calculator", "calculator", "calculator"),
    ("products", "Loan Products", "products", "box-seam"),
    ("field", "Field Operations", "field", "geo-alt"),
    ("sync", "Offline Sync", "sync", "arrow-repeat"),
    ("whatsapp", "WhatsApp", "whatsapp", "whatsapp"),
    ("employees", "Employees", "employees", "person-badge"),
    ("hrm", "HRM", "hrm", "briefcase"),
    ("attendance", "Attendance", "attendance", "clock-history"),
    ("branches", "Branches", "branches", "building"),
    ("settings", "Settings", "settings", "gear"),
    ("users", "Users & Roles", "users", "key"),
]


def can(module):
    u = g.get("user")
    if not u:
        return False
    p = PERMS.get(u["role"], set())
    return "*" in p or module in p


def need(*modules):
    """Allow access if the user's role has ANY of the given modules."""
    def deco(fn):
        @wraps(fn)
        def wrapper(*a, **kw):
            if not g.user:
                return redirect(url_for("login", next=request.path))
            if not any(can(m) for m in modules):
                return render_template("error.html", msg="Your role does not have access to this module."), 403
            return fn(*a, **kw)
        return wrapper
    return deco


# --------------------------------------------------------------------------- #
# DB helpers
# --------------------------------------------------------------------------- #
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


def get_db():
    if "db" not in g:
        g.db = sqlite3.connect(DB_PATH)
        g.db.row_factory = sqlite3.Row
    return g.db


@app.teardown_appcontext
def close_db(_):
    db = g.pop("db", None)
    if db:
        db.close()


def q(sql, args=(), one=False):
    cur = get_db().execute(sql, args)
    rows = cur.fetchall()
    return (rows[0] if rows else None) if one else rows


def ex(sql, args=()):
    db = get_db()
    cur = db.execute(sql, args)
    db.commit()
    return cur.lastrowid


# --------------------------------------------------------------------------- #
# Finance helpers
# --------------------------------------------------------------------------- #
def add_months(d, n):
    m = d.month - 1 + n
    y = d.year + m // 12
    m = m % 12 + 1
    dim = [31, 29 if y % 4 == 0 and (y % 100 != 0 or y % 400 == 0) else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    return date(y, m, min(d.day, dim[m - 1]))


def emi_calc(P, annual, n, method="reducing"):
    if n <= 0:
        return 0.0
    if method == "flat":
        return round((P + P * annual / 100 * n / 12) / n, 2)
    r = annual / 1200
    if r == 0:
        return round(P / n, 2)
    return round(P * r * (1 + r) ** n / ((1 + r) ** n - 1), 2)


def holiday_set():
    try:
        return {r["day"] for r in q("SELECT day FROM holidays")}
    except Exception:
        return set()


def next_working_day(d, hol):
    """EMI dates never fall on a Saturday, Sunday or a listed public holiday: move to the next working day."""
    while d.weekday() >= 5 or d.isoformat() in hol:
        d += timedelta(days=1)
    return d


def build_schedule(P, annual, n, start, method="reducing", holidays=None):
    hol = holidays if holidays is not None else holiday_set()
    rows, bal = [], P
    emi = emi_calc(P, annual, n, method)
    for i in range(1, n + 1):
        if method == "flat":
            interest = round(P * annual / 100 / 12, 2)
            prin = round(P / n, 2)
        else:
            interest = round(bal * annual / 1200, 2)
            prin = round(emi - interest, 2)
        if i == n:
            prin = round(bal, 2)
        this_emi = round(prin + interest, 2)
        bal = round(bal - prin, 2)
        rows.append(dict(no=i, due_date=next_working_day(add_months(start, i), hol).isoformat(), emi=this_emi,
                         principal=prin, interest=interest, balance=max(bal, 0)))
    return emi, rows


def create_loan(app_id, start=None):
    a = q("SELECT * FROM applications WHERE id=?", (app_id,), one=True)
    p = q("SELECT * FROM products WHERE id=?", (a["product_id"],), one=True)
    start = start or date.today()
    emi, rows = build_schedule(a["amount"], a["rate"], a["tenure"], start, p["method"])
    lid = ex("INSERT INTO loans(application_id,customer_id,product_id,principal,rate,tenure,method,emi,start_date,status,"
             "branch,agent_id) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)",
             (app_id, a["customer_id"], a["product_id"], a["amount"], a["rate"], a["tenure"], p["method"], emi,
              start.isoformat(), "active", a["branch"], a["agent_id"]))
    for r in rows:
        ex("INSERT INTO schedule(loan_id,no,due_date,emi,principal,interest,balance) VALUES(?,?,?,?,?,?,?)",
           (lid, r["no"], r["due_date"], r["emi"], r["principal"], r["interest"], r["balance"]))
    return lid


def record_payment(loan_id, sched_id, channel, ref=None, at=None):
    s = q("SELECT * FROM schedule WHERE id=? AND loan_id=?", (sched_id, loan_id), one=True)
    if not s or s["paid"]:
        return None
    at = at or datetime.now().isoformat(timespec="seconds")
    ref = ref or f"{channel.upper()[:3]}{uuid.uuid4().hex[:10].upper()}"
    ex("UPDATE schedule SET paid=1, paid_on=? WHERE id=?", (at[:10], sched_id))
    ex("INSERT INTO payments(loan_id,schedule_id,amount,channel,ref,at) VALUES(?,?,?,?,?,?)",
       (loan_id, sched_id, s["emi"], channel, ref, at))
    left = q("SELECT COUNT(*) c FROM schedule WHERE loan_id=? AND paid=0", (loan_id,), one=True)["c"]
    if left == 0:
        ex("UPDATE loans SET status='closed', closure_date=? WHERE id=?", (at[:10], loan_id))
    return ref


@app.template_global()
def fee_split(amount, fee_pct):
    """Processing fee with GST shown as CGST + SGST (each half of the GST rate)."""
    fee = round(float(amount or 0) * float(fee_pct or 0) / 100, 2)
    half = round(fee * CFG["gst_rate"] / 200, 2)
    return dict(fee=fee, cgst=half, sgst=half, rate=CFG["gst_rate"], half_rate=CFG["gst_rate"] / 2, total=round(fee + 2 * half, 2))


def settlement_quote(lid):
    """Full settlement = principal still outstanding up to date + the interest of the next instalment."""
    unpaid = q("SELECT * FROM schedule WHERE loan_id=? AND paid=0 ORDER BY no", (lid,))
    if not unpaid:
        return None
    principal = round(sum(r["principal"] for r in unpaid), 2)
    nxt = unpaid[0]["interest"]
    return dict(principal=principal, interest=nxt, total=round(principal + nxt, 2), next_no=unpaid[0]["no"], left=len(unpaid),
                next_id=unpaid[0]["id"], saved=round(sum(r["interest"] for r in unpaid[1:]), 2))


def noc_state(loan):
    """NOC is available 15 days after full closure."""
    if loan["status"] != "closed" or not loan["closure_date"]:
        return False, None
    eligible_on = date.fromisoformat(loan["closure_date"]) + timedelta(days=15)
    return date.today() >= eligible_on, eligible_on


# --------------------------------------------------------------------------- #
# Verification helpers (Aadhaar Verhoeff checksum, PAN / Voter ID format)
# --------------------------------------------------------------------------- #
_d = [[0, 1, 2, 3, 4, 5, 6, 7, 8, 9], [1, 2, 3, 4, 0, 6, 7, 8, 9, 5], [2, 3, 4, 0, 1, 7, 8, 9, 5, 6],
      [3, 4, 0, 1, 2, 8, 9, 5, 6, 7], [4, 0, 1, 2, 3, 9, 5, 6, 7, 8], [5, 9, 8, 7, 6, 0, 4, 3, 2, 1],
      [6, 5, 9, 8, 7, 1, 0, 4, 3, 2], [7, 6, 5, 9, 8, 2, 1, 0, 4, 3], [8, 7, 6, 5, 9, 3, 2, 1, 0, 4],
      [9, 8, 7, 6, 5, 4, 3, 2, 1, 0]]
_p = [[0, 1, 2, 3, 4, 5, 6, 7, 8, 9], [1, 5, 7, 6, 2, 8, 3, 0, 9, 4], [5, 8, 0, 3, 7, 9, 6, 1, 4, 2],
      [8, 9, 1, 6, 0, 4, 3, 5, 2, 7], [9, 4, 5, 3, 1, 2, 6, 8, 7, 0], [4, 2, 8, 6, 5, 7, 3, 9, 0, 1],
      [2, 7, 9, 3, 8, 0, 6, 4, 1, 5], [7, 0, 4, 6, 9, 1, 3, 2, 5, 8]]
_inv = [0, 4, 3, 2, 1, 5, 6, 7, 8, 9]


def verhoeff_valid(num):
    c = 0
    for i, ch in enumerate(reversed(num)):
        c = _d[c][_p[i % 8][int(ch)]]
    return c == 0


def verhoeff_check_digit(num):
    c = 0
    for i, ch in enumerate(reversed(num)):
        c = _d[c][_p[(i + 1) % 8][int(ch)]]
    return str(_inv[c])


def make_aadhaar(base11):
    return base11 + verhoeff_check_digit(base11)


def validate_id(kind, number):
    n = (number or "").strip().upper().replace(" ", "")
    if kind == "aadhaar":
        if not re.fullmatch(r"[2-9]\d{11}", n):
            return False, "Aadhaar must be 12 digits and cannot start with 0 or 1."
        if not verhoeff_valid(n):
            return False, "Aadhaar checksum (Verhoeff) failed."
        return True, n
    if kind == "pan":
        if not re.fullmatch(r"[A-Z]{3}[PCHFATBLJG][A-Z]\d{4}[A-Z]", n):
            return False, "PAN format is AAAAA9999A (5 letters, 4 digits, 1 letter)."
        return True, n
    if kind == "voter":
        if not re.fullmatch(r"[A-Z]{3}\d{7}", n):
            return False, "Voter ID (EPIC) format is 3 letters followed by 7 digits."
        return True, n
    return False, "Unknown document type."


# --------------------------------------------------------------------------- #
# Geo helpers (location clustering)
# --------------------------------------------------------------------------- #
def haversine(a, b):
    la1, lo1, la2, lo2 = map(radians, (a[0], a[1], b[0], b[1]))
    h = sin((la2 - la1) / 2) ** 2 + cos(la1) * cos(la2) * sin((lo2 - lo1) / 2) ** 2
    return 6371 * 2 * asin(sqrt(h))


def cluster_tasks(tasks, radius_km=3.0):
    clusters = []
    for t in tasks:
        pt = (t["lat"], t["lng"])
        for c in clusters:
            if haversine(c["center"], pt) <= radius_km:
                c["tasks"].append(t)
                c["center"] = (sum(x["lat"] for x in c["tasks"]) / len(c["tasks"]),
                               sum(x["lng"] for x in c["tasks"]) / len(c["tasks"]))
                break
        else:
            clusters.append({"center": pt, "tasks": [t]})
    for c in clusters:  # nearest-neighbour visiting order + distance
        left, order, cur, dist = list(c["tasks"]), [], None, 0.0
        cur = min(left, key=lambda x: (x["lat"], x["lng"]))
        left.remove(cur)
        order.append(cur)
        while left:
            nxt = min(left, key=lambda x: haversine((cur["lat"], cur["lng"]), (x["lat"], x["lng"])))
            dist += haversine((cur["lat"], cur["lng"]), (nxt["lat"], nxt["lng"]))
            left.remove(nxt)
            order.append(nxt)
            cur = nxt
        c["tasks"], c["distance"] = order, round(dist, 1)
    clusters.sort(key=lambda c: -len(c["tasks"]))
    for i, c in enumerate(clusters, 1):
        c["name"] = f"Zone {chr(64 + i)}"
    return clusters


# --------------------------------------------------------------------------- #
# App plumbing
# --------------------------------------------------------------------------- #
SETTING_DEFS = [  # key, label, default, kind
    ("min_age", "Minimum borrower age (years)", 18, "int"),
    ("max_age", "Maximum borrower age (years)", 55, "int"),
    ("group_min", "Minimum members in a group", 2, "int"),
    ("group_max", "Maximum members in a group", 5, "int"),
    ("income_limit", "Household monthly income limit (Rs) - confirm the exact figure with the client", 25000, "num"),
    ("emi_pct", "Maximum EMI as % of household monthly income", 60, "num"),
    ("gst_rate", "GST rate on the processing fee (%), shown as half CGST + half SGST", 18, "num"),
    ("att_hours", "Minimum hours worked before punch-out is allowed", 8, "num")]
CFG = {k: d for k, _, d, _ in SETTING_DEFS}


def refresh_config():
    """Reload the admin-editable settings and the branch list (done per request so every worker sees changes)."""
    global MIN_AGE, MAX_AGE, PREGRT_MIN, PREGRT_MAX
    try:
        vals = {r["key"]: r["value"] for r in q("SELECT key,value FROM settings")}
        names = [r["name"] for r in q("SELECT name FROM branches WHERE active=1 ORDER BY id")]
    except sqlite3.Error:
        return
    for key, _, default, kind in SETTING_DEFS:
        try:
            v = float(vals.get(key, default))
        except (TypeError, ValueError):
            v = float(default)
        CFG[key] = int(v) if kind == "int" else v
    if names:
        BRANCHES[:] = names
    MIN_AGE, MAX_AGE, PREGRT_MIN, PREGRT_MAX = CFG["min_age"], CFG["max_age"], CFG["group_min"], CFG["group_max"]
    K.update(min_age=MIN_AGE, max_age=MAX_AGE, pregrt_min=PREGRT_MIN, pregrt_max=PREGRT_MAX,
             income_limit=CFG["income_limit"], gst_rate=CFG["gst_rate"])


@app.before_request
def load_user():
    g.user = None
    if request.endpoint != "static":
        refresh_config()
    uid = session.get("uid")
    if uid:
        g.user = q("SELECT * FROM users WHERE id=?", (uid,), one=True)
    if g.user and g.user["must_change"] and request.endpoint not in ("change_password", "logout", "static", "login"):
        return redirect(url_for("change_password"))


@app.context_processor
def inject():
    nav = [n for n in NAV if can(n[0]) or (n[0] == "users" and g.get("user") and g.user["role"] == "admin")]
    return dict(nav=nav, can=can, today=date.today().isoformat(), BRANCHES=BRANCHES, ROLES=ROLES, K=K, CFG=CFG)


@app.template_filter("inr")
def inr(v):
    v = float(v or 0)
    neg, v = v < 0, abs(v)
    i, d = f"{v:.2f}".split(".")
    if len(i) > 3:
        head, tail = i[:-3], i[-3:]
        head = re.sub(r"(\d)(?=(\d\d)+$)", r"\1,", head)
        i = head + "," + tail
    return ("-" if neg else "") + "₹" + i + "." + d


@app.template_filter("dt")
def fmt_date(v):
    try:
        return date.fromisoformat(str(v)[:10]).strftime("%d %b %Y")
    except Exception:
        return v or "-"


def scope_agent():
    """Field agents only see their own records."""
    return g.user["id"] if g.user and g.user["role"] == "field_agent" else None


def get_filters():
    return dict(branch=request.args.get("branch", ""), agent=request.args.get("agent", ""),
                dfrom=request.args.get("dfrom", ""), dto=request.args.get("dto", ""))


def agents_list():
    return q("SELECT id,name,branch FROM users WHERE role='field_agent' ORDER BY name")


# --------------------------------------------------------------------------- #
# Auth
# --------------------------------------------------------------------------- #
@app.route("/")
def index():
    if not g.user:
        return redirect(url_for("login"))
    # land each role on a page it is allowed to open (field agents have no dashboard: they start at Field Operations)
    if g.user["role"] == "customer":
        return redirect(url_for("portal"))
    for mod, endpoint in (("dashboard", "dashboard"), ("field", "field"), ("crm", "crm")):
        if can(mod):
            return redirect(url_for(endpoint))
    return redirect(url_for("calculator"))


@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        u = q("SELECT * FROM users WHERE username=?", (request.form["username"].strip(),), one=True)
        if u and check_password_hash(u["pw"], request.form["password"]):
            session.clear()
            session["uid"] = u["id"]
            nxt = request.args.get("next", "")
            if nxt.startswith("/") and not nxt.startswith("//"):  # only same-site paths (no open redirect)
                return redirect(nxt)
            return redirect(url_for("index"))
        flash("Invalid username or password.", "danger")
    demo = [("admin", "admin123", "Admin"), ("manager1", "manager123", "Manager"), ("uw1", "uw123", "Underwriter"),
            ("agent1", "agent123", "Field Agent"), ("cust1", "cust123", "Customer")]
    return render_template("login.html", demo=demo)


@app.route("/change-password", methods=["GET", "POST"])
def change_password():
    if not g.user:
        return redirect(url_for("login"))
    if request.method == "POST":
        old, new, again = (request.form.get(k, "") for k in ("old", "new", "again"))
        if not check_password_hash(g.user["pw"], old):
            flash("Current password is wrong.", "danger")
        elif len(new) < 8 or not re.search(r"[A-Za-z]", new) or not re.search(r"\d", new):
            flash("New password must be at least 8 characters and contain letters and digits.", "danger")
        elif new != again:
            flash("The two new passwords do not match.", "danger")
        elif new == old:
            flash("Choose a password different from the current one.", "danger")
        else:
            ex("UPDATE users SET pw=?, must_change=0 WHERE id=?", (generate_password_hash(new), g.user["id"]))
            flash("Password changed.", "success")
            return redirect(url_for("index"))
    return render_template("change_password.html", forced=bool(g.user["must_change"]))


def ensure_customer_login(cid, reset=False):
    """Create (or reset) the customer's portal login. Returns (username, temporary_password or None if it already existed)."""
    c = q("SELECT * FROM customers WHERE id=?", (cid,), one=True)
    u = q("SELECT * FROM users WHERE customer_id=? AND role='customer'", (cid,), one=True)
    if u and not reset:
        return u["username"], None
    temp = "".join(random.SystemRandom().choice("ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789") for _ in range(8))
    temp = temp[:7] + random.SystemRandom().choice("23456789")  # always contains a digit
    if u:
        ex("UPDATE users SET pw=?, must_change=1 WHERE id=?", (generate_password_hash(temp), u["id"]))
        return u["username"], temp
    uname = c["phone"]
    if q("SELECT 1 FROM users WHERE username=?", (uname,), one=True):
        uname = cust_code(cid).lower()
    ex("INSERT INTO users(username,pw,name,role,branch,phone,customer_id,must_change) VALUES(?,?,?,?,?,?,?,1)",
       (uname, generate_password_hash(temp), c["name"], "customer", c["branch"], c["phone"], cid))
    return uname, temp


@app.route("/crm/<int:cid>/login", methods=["POST"])
@need("disburse")
def customer_login_create(cid):
    get_customer_or_404(cid)
    uname, temp = ensure_customer_login(cid, reset=True)
    session["slip"] = dict(cid=cid, user=uname, pw=temp)
    flash("A new temporary password was generated. Print or note it now - it is shown only once.", "success")
    return redirect(url_for("login_slip", cid=cid))


@app.route("/crm/<int:cid>/login-slip")
@need("disburse")
def login_slip(cid):
    sl = session.pop("slip", None)
    if not sl or sl.get("cid") != cid:
        flash("The login slip is shown only once, right after the login is created. Use 'Reset customer login' to make a new one.", "warning")
        return redirect(url_for("crm_detail", cid=cid))
    return render_template("login_slip.html", c=get_customer_or_404(cid), sl=sl)


@app.route("/logout")
def logout():
    session.clear()
    return redirect(url_for("login"))


# --------------------------------------------------------------------------- #
# 8. Dashboard with Branch / Agent / Date filters
# --------------------------------------------------------------------------- #
def loan_where(f, alias="l"):
    w, a = [], []
    if f["branch"]:
        w.append(f"{alias}.branch=?"); a.append(f["branch"])
    if f["agent"]:
        w.append(f"{alias}.agent_id=?"); a.append(f["agent"])
    sa = scope_agent()
    if sa:
        w.append(f"{alias}.agent_id=?"); a.append(sa)
    return w, a


@app.route("/dashboard")
@need("dashboard")
def dashboard():
    f = get_filters()
    w, a = loan_where(f, "l")
    wl = (" AND " + " AND ".join(w)) if w else ""
    dfrom, dto = f["dfrom"] or "0000-01-01", f["dto"] or "9999-12-31"
    cw, ca = [], []
    if f["branch"]:
        cw.append("branch=?"); ca.append(f["branch"])
    if f["agent"]:
        cw.append("agent_id=?"); ca.append(f["agent"])
    if scope_agent():
        cw.append("agent_id=?"); ca.append(scope_agent())
    cwl = (" AND " + " AND ".join(cw)) if cw else ""
    k = {}
    k["customers"] = q(f"SELECT COUNT(*) c FROM customers WHERE stage='customer' AND substr(created,1,10) BETWEEN ? AND ?{cwl}",
                       [dfrom, dto] + ca, one=True)["c"]
    k["leads"] = q(f"SELECT COUNT(*) c FROM customers WHERE stage!='customer' AND substr(created,1,10) BETWEEN ? AND ?{cwl}",
                   [dfrom, dto] + ca, one=True)["c"]
    k["active_loans"] = q(f"SELECT COUNT(*) c FROM loans l WHERE status='active' AND start_date BETWEEN ? AND ?{wl}",
                          [dfrom, dto] + a, one=True)["c"]
    k["disbursed"] = q(f"SELECT COALESCE(SUM(principal),0) s FROM loans l WHERE start_date BETWEEN ? AND ?{wl}",
                       [dfrom, dto] + a, one=True)["s"]
    k["outstanding"] = q(f"SELECT COALESCE(SUM(s.principal),0) s FROM schedule s JOIN loans l ON l.id=s.loan_id "
                         f"WHERE s.paid=0{wl}", a, one=True)["s"]
    k["collected"] = q(f"SELECT COALESCE(SUM(p.amount),0) s FROM payments p JOIN loans l ON l.id=p.loan_id "
                       f"WHERE substr(p.at,1,10) BETWEEN ? AND ?{wl}", [dfrom, dto] + a, one=True)["s"]
    k["overdue"] = q(f"SELECT COUNT(*) c FROM schedule s JOIN loans l ON l.id=s.loan_id "
                     f"WHERE s.paid=0 AND s.due_date<?{wl}", [date.today().isoformat()] + a, one=True)["c"]
    by_branch = q(f"SELECT l.branch b, COALESCE(SUM(s.principal),0) v, COUNT(DISTINCT l.id) n FROM schedule s JOIN loans l ON l.id=s.loan_id "
                  f"WHERE s.paid=0{wl} GROUP BY l.branch", a)
    app_where = ["substr(created,1,10) BETWEEN ? AND ?"] + cw
    by_status = q(f"SELECT status, COUNT(*) c, COALESCE(SUM(amount),0) v FROM applications WHERE {' AND '.join(app_where)} GROUP BY status",
                  [dfrom, dto] + ca)
    by_agent = q(f"SELECT u.name n, COALESCE(SUM(p.amount),0) v, COUNT(*) c FROM payments p JOIN loans l ON l.id=p.loan_id "
                 f"JOIN users u ON u.id=l.agent_id WHERE substr(p.at,1,10) BETWEEN ? AND ?{wl} GROUP BY u.name",
                 [dfrom, dto] + a)
    map_pts = []
    if g.user["role"] == "admin":
        for b in q("SELECT id, name, code, lat, lng FROM branches WHERE active=1 AND lat IS NOT NULL AND lng IS NOT NULL"):
            o = q("SELECT COALESCE(SUM(s.principal),0) v, COUNT(DISTINCT l.id) n FROM schedule s JOIN loans l ON l.id=s.loan_id "
                  "WHERE s.paid=0 AND l.branch=?", (b["name"],), one=True)
            map_pts.append(dict(id=b["id"], name=b["name"], code=b["code"] or "", lat=b["lat"], lng=b["lng"], out=o["v"], loans=o["n"],
                                url=url_for("branch_detail", bid=b["id"])))
    return render_template("dashboard.html", k=k, f=f, agents=agents_list(), map_pts=map_pts,
                           by_branch=[dict(r) for r in by_branch], by_status=[dict(r) for r in by_status],
                           by_agent=[dict(r) for r in by_agent])


# --------------------------------------------------------------------------- #
# 3. Calculator + Loan products (tenure / interest / EMI configuration)
# --------------------------------------------------------------------------- #
@app.route("/calculator")
@need("calculator")
def calculator():
    prods = q("SELECT * FROM products WHERE active=1")
    P = float(request.args.get("amount", 50000) or 0)
    rate = float(request.args.get("rate", 18) or 0)
    n = int(request.args.get("tenure", 12) or 1)
    method = request.args.get("method", "reducing")
    emi, rows = build_schedule(P, rate, n, date.today(), method)
    total = round(sum(r["emi"] for r in rows), 2)
    return render_template("calculator.html", prods=prods, P=P, rate=rate, n=n, method=method, emi=emi,
                           rows=rows, total=total, interest=round(total - P, 2))


@app.route("/api/emi")
def api_emi():
    try:
        P, r, n = float(request.args["amount"]), float(request.args["rate"]), int(request.args["tenure"])
    except (KeyError, ValueError):
        return jsonify(error="amount, rate, tenure required"), 400
    m = request.args.get("method", "reducing")
    return jsonify(emi=emi_calc(P, r, n, m), total=round(emi_calc(P, r, n, m) * n, 2))


@app.route("/products", methods=["GET", "POST"])
@need("products")
def products():
    if request.method == "POST":
        f = request.form
        try:
            vals = (f["name"].strip(), float(f["rate"]), float(f["min_amt"]), float(f["max_amt"]),
                    int(f["min_tenure"]), int(f["max_tenure"]), f["method"], float(f["fee_pct"]))
            assert vals[0] and vals[2] < vals[3] and vals[4] <= vals[5] and 0 <= vals[1] <= 60
        except Exception:
            flash("Please check the values (min < max, rate 0-60).", "danger")
            return redirect(url_for("products"))
        flags = (1 if f.get("admin_only") else 0, 1 if f.get("group_only") else 0)
        if f.get("id"):
            ex("UPDATE products SET name=?,rate=?,min_amt=?,max_amt=?,min_tenure=?,max_tenure=?,method=?,fee_pct=?,active=?,"
               "admin_only=?,group_only=? WHERE id=?", vals + (1 if f.get("active") else 0,) + flags + (f["id"],))
            flash("Product updated.", "success")
        else:
            ex("INSERT INTO products(name,rate,min_amt,max_amt,min_tenure,max_tenure,method,fee_pct,admin_only,group_only) "
               "VALUES(?,?,?,?,?,?,?,?,?,?)", vals + flags)
            flash("Product added.", "success")
        return redirect(url_for("products"))
    return render_template("products.html", prods=q("SELECT * FROM products"))


# --------------------------------------------------------------------------- #
# 7. CRM
# --------------------------------------------------------------------------- #
@app.route("/crm")
@need("crm")
def crm():
    f = get_filters()
    stage, term = request.args.get("stage", ""), request.args.get("q", "").strip()
    w, a = ["1=1"], []
    if f["branch"]:
        w.append("c.branch=?"); a.append(f["branch"])
    if f["agent"]:
        w.append("c.agent_id=?"); a.append(f["agent"])
    if scope_agent():
        w.append("c.agent_id=?"); a.append(scope_agent())
    if stage:
        w.append("c.stage=?"); a.append(stage)
    if term:
        w.append("(c.name LIKE ? OR c.phone LIKE ?)"); a += [f"%{term}%"] * 2
    rows = q(f"SELECT c.*, u.name agent_name, (SELECT status FROM applications WHERE customer_id=c.id ORDER BY id DESC LIMIT 1) app_status "
             f"FROM customers c LEFT JOIN users u ON u.id=c.agent_id WHERE {' AND '.join(w)} ORDER BY c.id DESC", a)
    return render_template("crm.html", rows=rows, f=f, stage=stage, term=term, agents=agents_list())


@app.route("/crm/new", methods=["POST"])
@need("crm")
def crm_new():
    f = request.form
    name, phone = f["name"].strip(), f["phone"].strip()
    if not name or not re.fullmatch(r"[6-9]\d{9}", phone):
        flash("Name and a valid 10-digit Indian mobile number are required.", "danger")
        return redirect(url_for("crm"))
    agent = scope_agent() or (f.get("agent_id") or None)
    cid = ex("INSERT INTO customers(name,phone,dob,address,branch,agent_id,stage,created) VALUES(?,?,?,?,?,?,?,?)",
             (name, phone, f.get("dob") or None, f.get("address", ""), f.get("branch") or g.user["branch"], agent,
              f.get("stage", "lead"), datetime.now().isoformat(timespec="seconds")))
    flash("Customer / lead added.", "success")
    return redirect(url_for("crm_detail", cid=cid))


@app.route("/crm/<int:cid>")
@need("crm")
def crm_detail(cid):
    c = q("SELECT c.*, u.name agent_name FROM customers c LEFT JOIN users u ON u.id=c.agent_id WHERE c.id=?", (cid,), one=True)
    if not c or (scope_agent() and c["agent_id"] != scope_agent()):
        abort(404)
    return render_template("crm_detail.html", c=c,
                           apps=q("SELECT a.*, p.name pname FROM applications a JOIN products p ON p.id=a.product_id WHERE customer_id=? ORDER BY a.id DESC", (cid,)),
                           loans=q("SELECT * FROM loans WHERE customer_id=?", (cid,)),
                           kycf=q("SELECT * FROM kyc_forms WHERE customer_id=?", (cid,), one=True),
                           has_login=bool(q("SELECT 1 FROM users WHERE customer_id=? AND role='customer'", (cid,), one=True)),
                           logs=q("SELECT * FROM comm_logs WHERE customer_id=? ORDER BY id DESC", (cid,)))


@app.route("/crm/<int:cid>/log", methods=["POST"])
@need("crm")
def crm_log(cid):
    get_customer_or_404(cid)
    f, errs = request.form, []
    note, ch = f.get("note", "").strip()[:500], f.get("channel", "call")
    if ch not in ("call", "visit", "whatsapp", "sms", "email"):
        ch = "call"
    cdir = outcome = follow = None
    mins = None
    if ch == "call":
        cdir = f.get("call_dir") if f.get("call_dir") in ("incoming", "outgoing") else "outgoing"
        outcome = f.get("outcome") if f.get("outcome") in CALL_OUTCOMES else "Connected"
        mins = to_num(f.get("duration_min", ""), "Call duration (minutes)", errs, hi=600, integer=True)
    if f.get("follow_up"):
        fd = parse_date(f.get("follow_up"))
        if not fd or fd < date.today():
            errs.append("Follow-up date must be today or later.")
        else:
            follow = fd.isoformat()
    if not note:
        errs.append("Write a short note about the conversation.")
    if errs:
        for e in errs:
            flash(e, "danger")
    else:
        ex("INSERT INTO comm_logs(customer_id,channel,note,by_name,at,call_dir,duration_min,outcome,follow_up) VALUES(?,?,?,?,?,?,?,?,?)",
           (cid, ch, note, g.user["name"], datetime.now().isoformat(timespec="seconds"), cdir, mins, outcome, follow))
        flash("Communication logged.", "success")
    return redirect(url_for("crm_detail", cid=cid))


@app.route("/crm/<int:cid>/stage", methods=["POST"])
@need("crm")
def crm_stage(cid):
    if request.form["stage"] in ("lead", "prospect", "customer", "closed"):
        ex("UPDATE customers SET stage=? WHERE id=?", (request.form["stage"], cid))
    return redirect(url_for("crm_detail", cid=cid))


# --------------------------------------------------------------------------- #
# 2. KYC verification (Aadhaar / PAN / Voter ID)  -- MOCK, no paid API
# --------------------------------------------------------------------------- #
@app.route("/kyc")
@need("kyc")
def kyc():
    w, a = "", ()
    if scope_agent():
        w, a = "WHERE agent_id=?", (scope_agent(),)
    return render_template("kyc.html", customers=q(f"SELECT id,name,aadhaar,pan,voter,kyc_status FROM customers {w} ORDER BY name", a),
                           otp=OTP_DEMO, sample_aadhaar=make_aadhaar("23456789012"))


@app.route("/api/kyc/verify", methods=["POST"])
@need("kyc")
def api_kyc_verify():
    d = request.get_json(force=True, silent=True) or {}
    kind, number = d.get("type"), d.get("number", "")
    ok, res = validate_id(kind, number)
    if not ok:
        return jsonify(ok=False, message=res), 200
    if kind == "aadhaar":
        if not d.get("otp"):
            return jsonify(ok=True, need_otp=True, message=f"Format valid. (MOCK) OTP sent to the linked mobile. Demo OTP: {OTP_DEMO}")
        if d["otp"] != OTP_DEMO:
            return jsonify(ok=False, message="Wrong OTP.")
    cid = d.get("customer_id")
    if cid:
        col = {"aadhaar": "aadhaar", "pan": "pan", "voter": "voter"}[kind]
        stored = ("XXXXXXXX" + res[-4:]) if kind == "aadhaar" else res
        ex(f"UPDATE customers SET {col}=? WHERE id=?", (stored, cid))
        c = q("SELECT aadhaar,pan,voter FROM customers WHERE id=?", (cid,), one=True)
        if c["aadhaar"] and (c["pan"] or c["voter"]):
            ex("UPDATE customers SET kyc_status='verified' WHERE id=?", (cid,))
    return jsonify(ok=True, verified=True, message=f"{kind.upper()} verified (mock government response: MATCH).")


# --------------------------------------------------------------------------- #
# 6. Application form
# --------------------------------------------------------------------------- #
def save_upload(file, prefix):
    if not file or not file.filename:
        return None
    ext = file.filename.rsplit(".", 1)[-1].lower()
    if ext not in ALLOWED_EXT:
        raise ValueError(f"{file.filename}: only PDF/JPG/PNG allowed")
    name = f"{prefix}_{uuid.uuid4().hex[:8]}_{secure_filename(file.filename)}"
    file.save(os.path.join(UPLOADS, name))
    return name


@app.route("/applications")
@need("applications")
def applications():
    f = get_filters()
    status = request.args.get("status", "")
    w, a = ["substr(a.created,1,10) BETWEEN ? AND ?"], [f["dfrom"] or "0000-01-01", f["dto"] or "9999-12-31"]
    if f["branch"]:
        w.append("a.branch=?"); a.append(f["branch"])
    if f["agent"]:
        w.append("a.agent_id=?"); a.append(f["agent"])
    if scope_agent():
        w.append("a.agent_id=?"); a.append(scope_agent())
    if status:
        w.append("a.status=?"); a.append(status)
    rows = q(f"SELECT a.*, c.name cname, p.name pname, u.name agent_name FROM applications a JOIN customers c ON c.id=a.customer_id "
             f"JOIN products p ON p.id=a.product_id LEFT JOIN users u ON u.id=a.agent_id WHERE {' AND '.join(w)} ORDER BY a.id DESC", a)
    return render_template("applications.html", rows=rows, f=f, status=status, agents=agents_list())


def load_app(aid):
    r = q("SELECT a.*, c.name cname, c.phone cphone, c.dob, c.address, c.kyc_status, p.name pname, p.fee_pct, p.method "
          "FROM applications a JOIN customers c ON c.id=a.customer_id JOIN products p ON p.id=a.product_id WHERE a.id=?",
          (aid,), one=True)
    if not r or (scope_agent() and r["agent_id"] != scope_agent()):
        abort(404)
    return r


@app.route("/applications/<int:aid>")
@need("applications")
def application_detail(aid):
    a = load_app(aid)
    emi = emi_calc(a["amount"], a["rate"], a["tenure"], a["method"])
    x, prev, docs_dep = load_extra(aid)
    kycf = q("SELECT center_no, group_no, other_loans, current_debt FROM kyc_forms WHERE customer_id=?", (a["customer_id"],), one=True)
    flags = []
    if a["kyc_status"] != "verified":
        flags.append("Aadhaar / PAN / Voter ID verification is still pending (needed before approval).")
    if x and emi > x["net_saving"]:
        flags.append(f"The EMI ({emi:,.0f}) is higher than the family's net monthly savings ({x['net_saving']:,.0f}).")
    if any(p_.get("ontime") == "late" for p_ in prev):
        flags.append("A previous loan was repaid late.")
    if kycf and (kycf["other_loans"] or kycf["current_debt"]):
        flags.append(f"The customer has {kycf['other_loans']} other MFI / SHG loan(s), current indebtedness {kycf['current_debt']:,.0f}.")
    grp = q("SELECT id, center_no, group_no FROM pregrt WHERE id=?", (a["group_id"],), one=True) if a["group_id"] else None
    return render_template("application_detail.html", a=a, emi=emi, fee=round(a["amount"] * a["fee_pct"] / 100, 2), grp=grp,
                           docs=json.loads(a["docs"] or "{}"), loan=q("SELECT id FROM loans WHERE application_id=?", (aid,), one=True),
                           x=x, prev=prev, docs_dep=docs_dep, flags=flags, kycf=kycf,
                           approvals=q("SELECT * FROM approvals WHERE application_id=? ORDER BY id", (aid,)))


@app.route("/applications/<int:aid>/action", methods=["POST"])
@need("applications")
def application_action(aid):
    a = load_app(aid)
    act, remarks = request.form["action"], request.form.get("remarks", "").strip()[:300]
    flow = {"review": ("submitted", "under_review", "approve"), "approve": ("under_review", "approved", "approve"),
            "reject": (None, "rejected", "approve"), "sanction": ("approved", "sanctioned", "disburse"),
            "disburse": ("sanctioned", "disbursed", "disburse")}
    if act not in flow:
        abort(400)
    frm, to, perm = flow[act]
    if not can(perm):
        return render_template("error.html", msg="Your role cannot perform this action."), 403
    if frm and a["status"] != frm:
        flash(f"Application must be '{frm}' first.", "danger")
        return redirect(url_for("application_detail", aid=aid))
    if act == "reject" and a["status"] in ("disbursed", "rejected"):
        flash("Cannot reject at this stage.", "danger")
        return redirect(url_for("application_detail", aid=aid))
    if act == "approve" and a["kyc_status"] != "verified":
        flash("KYC must be verified before approval (see KYC Verify).", "danger")
        return redirect(url_for("application_detail", aid=aid))
    amount = a["amount"]
    if act == "approve":  # the approver may sanction a lower amount than requested (as on the paper form)
        raw = (request.form.get("approved_amount") or "").strip()
        if raw:
            errs = []
            amt = to_num(raw, "Approved amount", errs, lo=1, hi=10 ** 7)
            prod = q("SELECT min_amt FROM products WHERE id=?", (a["product_id"],), one=True)
            if amt is None or not (prod["min_amt"] <= amt <= a["amount"]):
                flash(f"Approved amount must be between {prod['min_amt']:,.0f} and the requested {a['amount']:,.0f}.", "danger")
                return redirect(url_for("application_detail", aid=aid))
            if amt != a["amount"]:
                ex("INSERT OR IGNORE INTO app_extra(application_id, requested_amt) VALUES(?,?)", (aid, a["amount"]))
                ex("UPDATE applications SET amount=? WHERE id=?", (amt, aid))
                amount = amt
    ex("UPDATE applications SET status=?, remarks=? WHERE id=?", (to, remarks or a["remarks"], aid))
    ex("INSERT INTO approvals(application_id,stage,by_user,by_role,amount,remarks,at) VALUES(?,?,?,?,?,?,?)",
       (aid, STAGE_LABEL[act], g.user["name"], g.user["role"], amount, remarks, datetime.now().isoformat(timespec="seconds")))
    if act == "disburse":
        create_loan(aid)
        ex("UPDATE customers SET stage='customer' WHERE id=?", (a["customer_id"],))
        uname, temp = ensure_customer_login(a["customer_id"])
        if temp:
            session["slip"] = dict(cid=a["customer_id"], user=uname, pw=temp)
            flash(f"Customer login created: username {uname}. Print the login slip now - the password is shown only once.", "info")
            flash(f"Application #{aid} is now disbursed.", "success")
            return redirect(url_for("login_slip", cid=a["customer_id"]))
    flash(f"Application #{aid} is now {to.replace('_', ' ')}.", "success")
    return redirect(url_for("application_detail", aid=aid))


# ------------------------------ PDFs ---------------------------------------- #
def _pdf_common():
    from reportlab.lib import colors
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
    from reportlab.lib.units import mm
    from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle
    return colors, A4, ParagraphStyle, getSampleStyleSheet, mm, Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle


@app.route("/applications/<int:aid>/sanction.pdf")
@need("applications")
def sanction_pdf(aid):
    """10. Sanction letter - encrypted, opens with customer's DOB as DDMMYYYY."""
    a = load_app(aid)
    if a["status"] not in ("sanctioned", "disbursed"):
        flash("Sanction letter is available once the application is sanctioned.", "danger")
        return redirect(url_for("application_detail", aid=aid))
    from reportlab.lib.pdfencrypt import StandardEncryption
    colors, A4, PS, gss, mm, Paragraph, Doc, Spacer, Table, TS = _pdf_common()
    pw = (a["dob"] or "01-01-2000").split("-")
    password = pw[2] + pw[1] + pw[0] if len(pw) == 3 else "01012000"
    enc = StandardEncryption(userPassword=password, ownerPassword="owner-" + uuid.uuid4().hex, canPrint=1, canModify=0,
                             canCopy=0, canAnnotate=0, strength=128)
    buf = io.BytesIO()
    doc = Doc(buf, pagesize=A4, encrypt=enc, leftMargin=20 * mm, rightMargin=20 * mm, topMargin=20 * mm, bottomMargin=20 * mm,
              title=f"Sarvocch Sanction Letter SL-{aid:05d}")
    st = gss()
    emi = emi_calc(a["amount"], a["rate"], a["tenure"], a["method"])
    fs = fee_split(a["amount"], a["fee_pct"])
    fee = fs["fee"]
    el = [Paragraph("Sarvocch Microcare Foundation", st["Title"]),
          Paragraph("LOAN SANCTION LETTER", st["Heading2"]),
          Paragraph(f"Ref: SL-{aid:05d} &nbsp;&nbsp; Date: {date.today().strftime('%d %b %Y')}", st["Normal"]), Spacer(1, 8),
          Paragraph(f"To,<br/><b>{a['cname']}</b><br/>{a['address'] or ''}<br/>Mobile: {a['cphone']}", st["Normal"]), Spacer(1, 8),
          Paragraph("Dear Customer, we are pleased to sanction your loan on the following terms:", st["Normal"]), Spacer(1, 6)]
    t = Table([["Loan product", a["pname"]], ["Sanctioned amount", f"Rs. {a['amount']:,.2f}"],
               ["Interest rate (p.a.)", f"{a['rate']}% ({a['method']} balance)"], ["Tenure", f"{a['tenure']} months"],
               ["Monthly EMI", f"Rs. {emi:,.2f}"], ["Total repayable", f"Rs. {emi * a['tenure']:,.2f}"]],
              colWidths=[60 * mm, 100 * mm])
    t.setStyle(TS([("GRID", (0, 0), (-1, -1), 0.5, colors.grey), ("BACKGROUND", (0, 0), (0, -1), colors.whitesmoke)]))
    el += [t, Spacer(1, 10), Paragraph("<b>Fee breakdown</b>", st["Heading4"])]
    t2 = Table([["Processing fee (%.1f%%)" % a["fee_pct"], f"Rs. {fee:,.2f}"],
                [f"CGST @{fs['half_rate']:g}%", f"Rs. {fs['cgst']:,.2f}"], [f"SGST @{fs['half_rate']:g}%", f"Rs. {fs['sgst']:,.2f}"],
                ["Total fees (deducted at disbursement)", f"Rs. {fs['total']:,.2f}"],
                ["Net disbursal amount", f"Rs. {a['amount'] - fs['total']:,.2f}"]], colWidths=[100 * mm, 60 * mm])
    t2.setStyle(TS([("GRID", (0, 0), (-1, -1), 0.5, colors.grey)]))
    el += [t2, Spacer(1, 10), Paragraph("<b>Disbursement conditions</b>", st["Heading4"])]
    for c in ["KYC (Aadhaar, PAN/Voter ID) must remain valid at the time of disbursement.",
              "Original income and address proofs must be available for verification.",
              "The first EMI falls due one month after disbursement; late payment attracts penal charges.",
              "This sanction is valid for 30 days from the date of this letter."]:
        el.append(Paragraph("&bull; " + c, st["Normal"]))
    el += [Spacer(1, 16), Paragraph("Authorised Signatory<br/>Sarvocch Microcare Foundation (prototype - not a legal document)", st["Normal"])]
    doc.build(el)
    buf.seek(0)
    return send_file(buf, mimetype="application/pdf", download_name=f"sanction_letter_{aid}.pdf")


@app.route("/loans/<int:lid>/noc.pdf")
@need("loans")
def noc_pdf(lid):
    """11. NOC - generated only 15 days after loan closure."""
    loan = q("SELECT l.*, c.name cname, c.address, p.name pname FROM loans l JOIN customers c ON c.id=l.customer_id "
             "JOIN products p ON p.id=l.product_id WHERE l.id=?", (lid,), one=True) or abort(404)
    ok, on = noc_state(loan)
    if not ok:
        flash("NOC can be generated 15 days after full loan closure" + (f" (eligible on {on.strftime('%d %b %Y')})." if on else "; loan is not closed yet."), "warning")
        return redirect(url_for("loan_detail", lid=lid))
    colors, A4, PS, gss, mm, Paragraph, Doc, Spacer, Table, TS = _pdf_common()
    buf = io.BytesIO()
    doc = Doc(buf, pagesize=A4, leftMargin=25 * mm, rightMargin=25 * mm, topMargin=25 * mm)
    st = gss()
    el = [Paragraph("Sarvocch Microcare Foundation", st["Title"]), Paragraph("NO OBJECTION CERTIFICATE", st["Heading2"]),
          Paragraph(f"Ref: NOC-{lid:05d} &nbsp;&nbsp; Date: {date.today().strftime('%d %b %Y')}", st["Normal"]), Spacer(1, 14),
          Paragraph(f"This is to certify that <b>{loan['cname']}</b> has fully repaid the {loan['pname']} loan "
                    f"(Loan ID {lid}) of Rs. {loan['principal']:,.2f}, closed on {fmt_date(loan['closure_date'])}. "
                    "All internal clearances and reconciliation audits are complete, and the company has no objection "
                    "and no outstanding claims against the borrower in respect of this loan.", st["BodyText"]),
          Spacer(1, 30), Paragraph("Authorised Signatory<br/>(prototype - not a legal document)", st["Normal"])]
    doc.build(el)
    buf.seek(0)
    return send_file(buf, mimetype="application/pdf", download_name=f"noc_loan_{lid}.pdf")


# --------------------------------------------------------------------------- #
# Loans, payments (4), AutoPay (5)
# --------------------------------------------------------------------------- #
@app.route("/loans")
@need("loans")
def loans():
    f = get_filters()
    w, a = loan_where(f, "l")
    wl = ("WHERE " + " AND ".join(w)) if w else ""
    rows = q(f"SELECT l.*, c.name cname, u.name agent_name, "
             f"(SELECT COUNT(*) FROM schedule s WHERE s.loan_id=l.id AND s.paid=0 AND s.due_date<?) overdue, "
             f"(SELECT status FROM mandates m WHERE m.loan_id=l.id AND m.status='active') mandate "
             f"FROM loans l JOIN customers c ON c.id=l.customer_id LEFT JOIN users u ON u.id=l.agent_id {wl} ORDER BY l.id DESC",
             [date.today().isoformat()] + a)
    return render_template("loans.html", rows=rows, f=f, agents=agents_list())


def own_loan_check(loan):
    if g.user["role"] == "customer" and loan["customer_id"] != g.user["customer_id"]:
        abort(404)
    sa = scope_agent()
    if sa and loan["agent_id"] != sa:
        abort(404)


@app.route("/loans/<int:lid>")
@need("loans", "payments")
def loan_detail(lid):
    loan = q("SELECT l.*, c.name cname, p.name pname FROM loans l JOIN customers c ON c.id=l.customer_id "
             "JOIN products p ON p.id=l.product_id WHERE l.id=?", (lid,), one=True) or abort(404)
    own_loan_check(loan)
    ok, on = noc_state(loan)
    return render_template("loan_detail.html", loan=loan, sched=q("SELECT * FROM schedule WHERE loan_id=? ORDER BY no", (lid,)),
                           pays=q("SELECT * FROM payments WHERE loan_id=? ORDER BY id DESC", (lid,)),
                           mandate=q("SELECT * FROM mandates WHERE loan_id=? ORDER BY id DESC", (lid,), one=True),
                           noc_ok=ok, noc_on=on, quote=settlement_quote(lid) if loan["status"] == "active" else None)


@app.route("/portal")
@need("portal")
def portal():
    cid = g.user["customer_id"]
    rows = q("SELECT l.*, (SELECT MIN(due_date) FROM schedule s WHERE s.loan_id=l.id AND s.paid=0) next_due FROM loans l WHERE customer_id=?", (cid,))
    return render_template("portal.html", rows=rows, c=q("SELECT * FROM customers WHERE id=?", (cid,), one=True),
                           apps=q("SELECT a.*, p.name pname FROM applications a JOIN products p ON p.id=a.product_id WHERE customer_id=?", (cid,)))


@app.route("/pay/<int:lid>", methods=["GET", "POST"])
@need("payments")
def pay(lid):
    loan = q("SELECT * FROM loans WHERE id=?", (lid,), one=True) or abort(404)
    own_loan_check(loan)
    nxt = q("SELECT * FROM schedule WHERE loan_id=? AND paid=0 ORDER BY no LIMIT 1", (lid,), one=True)
    if not nxt:
        flash("This loan is fully paid.", "info")
        return redirect(url_for("loan_detail", lid=lid))
    if request.method == "POST":
        ch, f = request.form["channel"], request.form
        if ch == "upi" and not re.fullmatch(r"[\w.\-]{2,}@[a-zA-Z]{2,}", f.get("upi_id", "")):
            flash("Enter a valid UPI ID like name@bank.", "danger")
        elif ch == "card" and not re.fullmatch(r"\d{16}", f.get("card_no", "").replace(" ", "")):
            flash("Enter a 16 digit card number (demo: 4111 1111 1111 1111).", "danger")
        elif ch == "netbanking" and not f.get("bank"):
            flash("Choose a bank.", "danger")
        elif ch == "wallet" and not f.get("wallet"):
            flash("Choose a wallet.", "danger")
        elif ch not in ("upi", "card", "netbanking", "wallet"):
            abort(400)
        else:
            ref = record_payment(lid, nxt["id"], ch)  # MOCK gateway: always succeeds. Card numbers are never stored.
            flash(f"Payment of EMI #{nxt['no']} successful. Reference {ref}", "success")
            return redirect(url_for("loan_detail", lid=lid))
    return render_template("pay.html", loan=loan, nxt=nxt)


@app.route("/loans/<int:lid>/autopay", methods=["POST"])
@need("payments")
def autopay(lid):
    loan = q("SELECT * FROM loans WHERE id=?", (lid,), one=True) or abort(404)
    own_loan_check(loan)
    if request.form.get("action") == "cancel":
        ex("UPDATE mandates SET status='cancelled' WHERE loan_id=?", (lid,))
        flash("AutoPay mandate cancelled.", "info")
    else:
        acct, ifsc = request.form.get("acct", ""), request.form.get("ifsc", "").upper()
        if not re.fullmatch(r"\d{9,18}", acct) or not re.fullmatch(r"[A-Z]{4}0[A-Z0-9]{6}", ifsc):
            flash("Enter a valid account number (9-18 digits) and IFSC (e.g. SBIN0001234).", "danger")
        else:
            ex("UPDATE mandates SET status='cancelled' WHERE loan_id=?", (lid,))
            ex("INSERT INTO mandates(loan_id,mtype,bank,acct_last4,status,created) VALUES(?,?,?,?,?,?)",
               (lid, request.form.get("mtype", "eNACH"), ifsc[:4], acct[-4:], "active", datetime.now().isoformat(timespec="seconds")))
            flash("AutoPay mandate registered (mock eNACH - no real bank call).", "success")
    return redirect(url_for("loan_detail", lid=lid))


@app.route("/autopay/run", methods=["POST"])
@need("loans")
def autopay_run():
    """Demo: simulate the monthly mandate debit run for all active mandates (due or overdue instalments)."""
    n = 0
    for m in q("SELECT m.loan_id FROM mandates m JOIN loans l ON l.id=m.loan_id WHERE m.status='active' AND l.status='active'"):
        s = q("SELECT * FROM schedule WHERE loan_id=? AND paid=0 AND due_date<=? ORDER BY no LIMIT 1",
              (m["loan_id"], (date.today() + timedelta(days=2)).isoformat()), one=True)
        if s and record_payment(m["loan_id"], s["id"], "autopay"):
            n += 1
    flash(f"AutoPay run complete: {n} instalment(s) debited.", "success")
    return redirect(url_for("loans"))


@app.route("/loans/<int:lid>/demo_backdate", methods=["POST"])
@need("loans")
def demo_backdate(lid):
    """Demo helper so the client can see the NOC rule without waiting 15 days."""
    if g.user["role"] != "admin":
        abort(403)
    ex("UPDATE loans SET closure_date=? WHERE id=? AND status='closed'", ((date.today() - timedelta(days=16)).isoformat(), lid))
    flash("Demo: closure date moved back 16 days.", "info")
    return redirect(url_for("loan_detail", lid=lid))


# --------------------------------------------------------------------------- #
# 1 + 9. Field operations: clustering, reminders, attendance, tracking
# --------------------------------------------------------------------------- #
@app.route("/field")
@need("field")
def field():
    day = request.args.get("day", date.today().isoformat())
    radius = float(request.args.get("radius", 3) or 3)
    sa = scope_agent()
    officer = sa or request.args.get("officer") or ""
    w, a = ["t.due_date=?", "t.status='open'"], [day]
    if officer:
        w.append("t.officer_id=?"); a.append(officer)
    tasks = [dict(r) for r in q(f"SELECT t.*, c.name cname, c.phone cphone FROM tasks t LEFT JOIN customers c ON c.id=t.customer_id "
                                f"WHERE {' AND '.join(w)}", a)]
    clusters = cluster_tasks(tasks, radius)
    reminders = []
    for c in clusters:
        if len(c["tasks"]) > 1:
            reminders.append(f"{c['name']}: {len(c['tasks'])} visits within {radius:g} km "
                             f"(~{c['distance']} km route) - do them together: " + ", ".join(t["cname"] or t["title"] for t in c["tasks"]))
    naive = sum(1 for _ in tasks)
    officers = q("SELECT u.id,u.name,u.branch,u.lat,u.lng,u.loc_at, at.in_time, at.out_time, "
                 "(SELECT COALESCE(SUM(collected),0) FROM tasks WHERE officer_id=u.id AND done_at LIKE ?||'%') collected, "
                 "(SELECT COUNT(*) FROM tasks WHERE officer_id=u.id AND due_date=? AND status='open') open_tasks, "
                 "(SELECT COUNT(*) FROM tasks WHERE officer_id=u.id AND done_at LIKE ?||'%') done_tasks "
                 "FROM users u LEFT JOIN attendance at ON at.user_id=u.id AND at.day=? WHERE u.role='field_agent'" + (" AND u.id=?" if sa else ""),
                 [date.today().isoformat(), day, date.today().isoformat(), date.today().isoformat()] + ([sa] if sa else []))
    mine = q("SELECT * FROM attendance WHERE user_id=? AND day=?", (g.user["id"], date.today().isoformat()), one=True)
    return render_template("field.html", clusters=clusters, reminders=reminders, tasks=tasks, officers=officers, day=day,
                           radius=radius, officer=str(officer), mine=mine, naive=naive,
                           customers=q("SELECT id,name FROM customers ORDER BY name"), agents=agents_list())


@app.route("/field/assign", methods=["POST"])
@need("field")
def field_assign():
    f = request.form
    if scope_agent():
        abort(403)
    try:
        lat, lng = float(f["lat"]), float(f["lng"])
        assert -90 <= lat <= 90 and -180 <= lng <= 180
    except Exception:
        flash("Valid latitude / longitude required (tip: right-click a place in Google Maps to copy them).", "danger")
        return redirect(url_for("field"))
    ex("INSERT INTO tasks(title,customer_id,ttype,lat,lng,due_date,officer_id) VALUES(?,?,?,?,?,?,?)",
       (f["title"].strip() or "Visit", f.get("customer_id") or None, f["ttype"], lat, lng, f["due_date"], f["officer_id"]))
    flash("Task assigned.", "success")
    return redirect(url_for("field", day=f["due_date"]))


@app.route("/field/attendance", methods=["POST"])
@need("field")
def field_attendance():
    ok, msg = do_punch(request.form.get("kind", ""), request.form.get("lat"), request.form.get("lng"))
    flash(msg, "success" if ok else "danger")
    return redirect(request.referrer or url_for("field"))



# --------------------------------------------------------------------------- #
# Attendance: punch in / punch out (8 hours + within the branch distance) and regularisation by hierarchy
# --------------------------------------------------------------------------- #
def my_branch(user=None):
    u = user or g.user
    return q("SELECT * FROM branches WHERE name=?", (u["branch"],), one=True)


def _floats(lat, lng):
    try:
        la, lo = float(lat), float(lng)
        if -90 <= la <= 90 and -180 <= lo <= 180:
            return la, lo
    except (TypeError, ValueError):
        pass
    return None, None


def do_punch(kind, lat, lng):
    """Returns (ok, message). Punch-out needs the minimum hours worked AND the phone inside the branch distance."""
    now_dt = datetime.now()
    now, today = now_dt.isoformat(timespec="seconds"), date.today().isoformat()
    la, lo = _floats(lat, lng)
    br = my_branch()
    dist = None
    if la is not None and br and br["lat"] is not None:
        dist = round(haversine((la, lo), (br["lat"], br["lng"])) * 1000)
    rec = q("SELECT * FROM attendance WHERE user_id=? AND day=?", (g.user["id"], today), one=True)
    if kind == "in":
        if rec:
            return False, "You have already punched in today."
        ex("INSERT INTO attendance(user_id,day,in_time,lat,lng,in_dist) VALUES(?,?,?,?,?,?)", (g.user["id"], today, now, la, lo, dist))
        msg = "Punched in."
        if dist is not None and br and dist > br["radius_m"]:
            msg += f" Note: you are {dist / 1000:.1f} km from {br['name']}."
        elif la is None:
            msg += " Location was not shared."
    elif kind == "out":
        if not rec or rec["regularised"] and not rec["in_time"]:
            return False, "Punch in first."
        if rec["out_time"]:
            return False, "You have already punched out today."
        worked = (now_dt - datetime.fromisoformat(rec["in_time"])).total_seconds() / 3600
        need_h = CFG["att_hours"]
        if worked < need_h:
            left = need_h - worked
            return False, (f"Punch-out is allowed after {need_h:g} hours of work. You have worked {worked:.1f} h, "
                           f"{int(left)} h {int(round((left % 1) * 60))} min to go. If you must leave early, send an attendance request.")
        if br and br["lat"] is not None:
            if la is None:
                return False, "Location is needed to punch out. Allow location access in the browser and try again."
            if dist > br["radius_m"]:
                return False, (f"You are {dist / 1000:.2f} km from {br['name']}. Punch-out is allowed only within "
                               f"{br['radius_m'] / 1000:g} km of the branch office. If this is a field day, send an attendance request.")
        ex("UPDATE attendance SET out_time=?, out_lat=?, out_lng=?, out_dist=? WHERE id=?", (now, la, lo, dist, rec["id"]))
        msg = f"Punched out. Hours worked: {worked:.1f}."
    else:
        return False, "Unknown action."
    if la is not None:
        ex("UPDATE users SET lat=?, lng=?, loc_at=? WHERE id=?", (la, lo, now, g.user["id"]))
    return True, msg


def approver_for(user):
    """Hierarchy: the employee's reporting manager decides; managers need the Admin; otherwise fall back on role and branch."""
    if user["role"] == "admin":
        return None, None
    emp = q("SELECT manager_id FROM employees WHERE user_id=?", (user["id"],), one=True)
    if emp and emp["manager_id"]:
        m = q("SELECT u.id, u.role FROM employees e JOIN users u ON u.id=e.user_id WHERE e.id=?", (emp["manager_id"],), one=True)
        if m and m["role"] in ("manager", "admin"):
            return m["id"], m["role"]
    return None, ("admin" if user["role"] == "manager" else "manager")


def can_decide(req_row, requester):
    me = g.user
    if req_row["user_id"] == me["id"]:
        return False
    if me["role"] == "admin":
        return True
    if me["role"] != "manager" or requester["role"] not in ("field_agent", "underwriter"):
        return False
    return req_row["approver_id"] == me["id"] or (not req_row["approver_id"] and requester["branch"] == me["branch"])


def apply_att_change(user_id, day, in_t, out_t, reason):
    rec = q("SELECT id FROM attendance WHERE user_id=? AND day=?", (user_id, day), one=True)
    i_ts, o_ts = (f"{day}T{in_t}:00" if in_t else None), (f"{day}T{out_t}:00" if out_t else None)
    if rec:
        ex("UPDATE attendance SET in_time=?, out_time=?, regularised=1, note=? WHERE id=?", (i_ts, o_ts, reason[:200], rec["id"]))
    else:
        ex("INSERT INTO attendance(user_id,day,in_time,out_time,regularised,note) VALUES(?,?,?,?,1,?)", (user_id, day, i_ts, o_ts, reason[:200]))


@app.route("/attendance")
@need("attendance")
def attendance():
    today = date.today()
    rows = {r["day"]: r for r in q("SELECT * FROM attendance WHERE user_id=? AND day>=?", (g.user["id"], (today - timedelta(days=31)).isoformat()))}
    hist = []
    for i in range(0, 32):
        d = today - timedelta(days=i)
        r = rows.get(d.isoformat())
        hrs = None
        if r and r["in_time"] and r["out_time"]:
            hrs = round((datetime.fromisoformat(r["out_time"]) - datetime.fromisoformat(r["in_time"])).total_seconds() / 3600, 1)
        status = "Present" if r else ("Weekend" if d.weekday() >= 5 else "No record")
        hist.append(dict(day=d.isoformat(), rec=r, hours=hrs, status=status, regularised=bool(r and r["regularised"])))
    mine_req = q("SELECT r.*, a.name approver FROM att_requests r LEFT JOIN users a ON a.id=r.approver_id WHERE r.user_id=? ORDER BY r.id DESC LIMIT 15", (g.user["id"],))
    to_decide, team = [], []
    if g.user["role"] in ("manager", "admin"):
        for r in q("SELECT r.*, u.name uname, u.role urole, u.branch ubranch FROM att_requests r JOIN users u ON u.id=r.user_id WHERE r.status='pending' ORDER BY r.id"):
            if can_decide(r, dict(role=r["urole"], branch=r["ubranch"])):
                to_decide.append(r)
        w, a = ("", []) if g.user["role"] == "admin" else (" AND u.branch=?", [g.user["branch"]])
        team = q("SELECT u.name, u.role, u.branch, at.in_time, at.out_time, at.in_dist, at.out_dist, at.regularised FROM users u "
                 "LEFT JOIN attendance at ON at.user_id=u.id AND at.day=? WHERE u.role!='customer'" + w + " ORDER BY u.branch, u.name",
                 [today.isoformat()] + a)
    br = my_branch()
    ap_id, ap_role = approver_for(g.user)
    ap = q("SELECT name FROM users WHERE id=?", (ap_id,), one=True) if ap_id else None
    return render_template("attendance.html", hist=hist, today_rec=rows.get(today.isoformat()), br=br, hours_needed=CFG["att_hours"],
                           mine_req=mine_req, to_decide=to_decide, team=team, ap_role=ap_role, ap_name=ap["name"] if ap else None)


@app.route("/attendance/punch", methods=["POST"])
@need("attendance")
def attendance_punch():
    ok, msg = do_punch(request.form.get("kind", ""), request.form.get("lat"), request.form.get("lng"))
    flash(msg, "success" if ok else "danger")
    return redirect(url_for("attendance"))


@app.route("/attendance/request", methods=["POST"])
@need("attendance")
def attendance_request():
    f, errs = request.form, []
    day = parse_date(f.get("day", ""))
    if not day or day > date.today() or day < date.today() - timedelta(days=31):
        errs.append("Choose a date within the last 31 days (not in the future).")
    in_t, out_t = f.get("in_time", ""), f.get("out_time", "")
    for lab, t in (("In time", in_t), ("Out time", out_t)):
        if not re.fullmatch(r"([01]\d|2[0-3]):[0-5]\d", t):
            errs.append(f"{lab} is required (HH:MM).")
    if not errs and out_t <= in_t:
        errs.append("Out time must be after the in time.")
    reason = " ".join(f.get("reason", "").split())[:200]
    if len(reason) < 5:
        errs.append("Write the reason (at least 5 letters).")
    if day and q("SELECT 1 FROM att_requests WHERE user_id=? AND day=? AND status='pending'", (g.user["id"], day.isoformat()), one=True):
        errs.append("A request for this date is already waiting for approval.")
    if errs:
        for e in errs:
            flash(e, "danger")
        return redirect(url_for("attendance"))
    now = datetime.now().isoformat(timespec="seconds")
    ap_id, ap_role = approver_for(g.user)
    if g.user["role"] == "admin":      # the top of the hierarchy: applied directly, still recorded
        ex("INSERT INTO att_requests(user_id,branch,day,in_time,out_time,reason,status,approver_role,requested_at,decided_by,decided_at,remarks) "
           "VALUES(?,?,?,?,?,?,?,?,?,?,?,?)", (g.user["id"], g.user["branch"], day.isoformat(), in_t, out_t, reason, "approved", "admin", now, g.user["name"], now, "Admin edit"))
        apply_att_change(g.user["id"], day.isoformat(), in_t, out_t, reason)
        flash("Attendance updated (Admin edits are applied directly and logged).", "success")
    else:
        ex("INSERT INTO att_requests(user_id,branch,day,in_time,out_time,reason,approver_role,approver_id,requested_at) VALUES(?,?,?,?,?,?,?,?,?)",
           (g.user["id"], g.user["branch"], day.isoformat(), in_t, out_t, reason, ap_role, ap_id, now))
        flash(f"Request sent to your {ap_role} for approval.", "success")
    return redirect(url_for("attendance"))


@app.route("/attendance/request/<int:rid>/decide", methods=["POST"])
@need("attendance")
def attendance_decide(rid):
    r = q("SELECT * FROM att_requests WHERE id=?", (rid,), one=True) or abort(404)
    requester = q("SELECT * FROM users WHERE id=?", (r["user_id"],), one=True)
    if not can_decide(r, requester):
        return render_template("error.html", msg="You cannot decide this request. Managers decide for their team, the Admin decides for managers."), 403
    if r["status"] != "pending":
        flash("This request was already decided.", "warning")
        return redirect(url_for("attendance"))
    act, remarks = request.form.get("action"), request.form.get("remarks", "").strip()[:200]
    if act not in ("approve", "reject"):
        abort(400)
    if act == "reject" and not remarks:
        flash("Write the reason for rejecting.", "danger")
        return redirect(url_for("attendance"))
    ex("UPDATE att_requests SET status=?, decided_by=?, decided_at=?, remarks=? WHERE id=?",
       ("approved" if act == "approve" else "rejected", g.user["name"], datetime.now().isoformat(timespec="seconds"), remarks, rid))
    if act == "approve":
        apply_att_change(r["user_id"], r["day"], r["in_time"], r["out_time"], r["reason"])
    flash(f"Request {'approved: attendance updated' if act == 'approve' else 'rejected'}.", "success" if act == "approve" else "info")
    return redirect(url_for("attendance"))


@app.route("/api/location", methods=["POST"])
@need("field")
def api_location():
    d = request.get_json(force=True, silent=True) or {}
    try:
        ex("UPDATE users SET lat=?, lng=?, loc_at=? WHERE id=?",
           (float(d["lat"]), float(d["lng"]), datetime.now().isoformat(timespec="seconds"), g.user["id"]))
    except Exception:
        return jsonify(ok=False), 400
    return jsonify(ok=True)


@app.route("/api/nearby")
@need("field")
def api_nearby():
    """Geo reminder: open tasks within radius of the officer's current position."""
    try:
        lat, lng, r = float(request.args["lat"]), float(request.args["lng"]), float(request.args.get("r", 1.5))
    except (KeyError, ValueError):
        return jsonify(error="lat,lng required"), 400
    w, a = "", []
    if scope_agent():
        w, a = " AND t.officer_id=?", [scope_agent()]
    out = []
    for t in q(f"SELECT t.*, c.name cname FROM tasks t LEFT JOIN customers c ON c.id=t.customer_id WHERE t.status='open' AND t.due_date<=?{w}",
               [date.today().isoformat()] + a):
        d = haversine((lat, lng), (t["lat"], t["lng"]))
        if d <= r:
            out.append(dict(id=t["id"], title=t["title"], customer=t["cname"], km=round(d, 2), type=t["ttype"]))
    out.sort(key=lambda x: x["km"])
    return jsonify(tasks=out)


@app.route("/field/task/<int:tid>/done", methods=["POST"])
@need("field")
def task_done(tid):
    t = q("SELECT * FROM tasks WHERE id=?", (tid,), one=True) or abort(404)
    if scope_agent() and t["officer_id"] != scope_agent():
        abort(403)
    try:
        amt = max(float(request.form.get("collected") or 0), 0)
    except ValueError:
        amt = 0
    ex("UPDATE tasks SET status='done', collected=?, notes=?, done_at=? WHERE id=?",
       (amt, request.form.get("notes", ""), datetime.now().isoformat(timespec="seconds"), tid))
    flash("Visit marked complete.", "success")
    return redirect(request.referrer or url_for("field"))


# --------------------------------------------------------------------------- #
# 15. Offline / online sync (PWA: service worker + local queue -> /api/sync)
# --------------------------------------------------------------------------- #
@app.route("/sync")
@need("sync")
def sync():
    w, a = "", ()
    if scope_agent():
        w, a = "AND officer_id=?", (scope_agent(),)
    tasks = q(f"SELECT t.id,t.title,c.name cname FROM tasks t LEFT JOIN customers c ON c.id=t.customer_id WHERE t.status='open' {w}", a)
    log = q("SELECT s.*, u.name uname FROM sync_log s JOIN users u ON u.id=s.user_id ORDER BY s.id DESC LIMIT 15")
    return render_template("sync.html", tasks=tasks, log=log)


@app.route("/api/sync", methods=["POST"])
@need("sync")
def api_sync():
    items = (request.get_json(force=True, silent=True) or {}).get("items", [])
    accepted, dup, bad = [], [], []
    for it in items[:200]:
        uid = str(it.get("uuid", ""))
        if not re.fullmatch(r"[\w\-]{8,64}", uid):
            bad.append(uid); continue
        if q("SELECT 1 FROM sync_log WHERE uuid=?", (uid,), one=True):
            dup.append(uid); continue  # idempotent: already received
        photo = it.pop("photo", None)
        if photo and photo.startswith("data:image/") and len(photo) < 3_000_000:
            try:
                import base64
                ext = "png" if "png" in photo[:20] else "jpg"
                fn = f"sync_{uid}.{ext}"
                with open(os.path.join(UPLOADS, fn), "wb") as fh:
                    fh.write(base64.b64decode(photo.split(",", 1)[1]))
                it["photo_file"] = fn
            except Exception:
                pass
        try:
            tid, amt = int(it.get("task_id") or 0), max(float(it.get("collected") or 0), 0)
        except (TypeError, ValueError):
            bad.append(uid); continue
        if tid and it.get("mark_done"):
            t = q("SELECT * FROM tasks WHERE id=?", (tid,), one=True)
            if t and (not scope_agent() or t["officer_id"] == scope_agent()):
                ex("UPDATE tasks SET status='done', collected=?, notes=?, done_at=? WHERE id=?",
                   (amt, str(it.get("notes", ""))[:500], str(it.get("captured_at") or datetime.now().isoformat())[:19], tid))
        if it.get("lat") and it.get("lng"):
            try:
                ex("UPDATE users SET lat=?, lng=?, loc_at=? WHERE id=?", (float(it["lat"]), float(it["lng"]), datetime.now().isoformat(timespec="seconds"), g.user["id"]))
            except ValueError:
                pass
        ex("INSERT INTO sync_log(uuid,user_id,payload,captured_at,synced_at) VALUES(?,?,?,?,?)",
           (uid, g.user["id"], json.dumps(it)[:4000], str(it.get("captured_at", "")), datetime.now().isoformat(timespec="seconds")))
        accepted.append(uid)
    return jsonify(accepted=accepted, duplicates=dup, rejected=bad)


@app.route("/sw.js")
def sw():
    resp = send_from_directory(os.path.join(BASE, "static"), "sw.js", mimetype="application/javascript")
    resp.headers["Cache-Control"] = "no-cache"       # browsers must re-check the service worker on every visit
    resp.headers["Service-Worker-Allowed"] = "/"
    return resp


@app.route("/manifest.json")
def manifest():
    icon = lambda f, sz, purpose="any": {"src": f"/static/icons/{f}", "sizes": sz, "type": "image/png", "purpose": purpose}
    data = dict(id="/", name="Sarvocch Microcare Foundation", short_name="Sarvocch", description="Field officer app: visits, collections and offline sync",
                start_url="/?source=pwa", scope="/", display="standalone", orientation="portrait", lang="en",
                background_color="#ffffff", theme_color="#0f766e", categories=["finance", "business"],
                icons=[icon("icon-192.png", "192x192"), icon("icon-512.png", "512x512"),
                       icon("icon-maskable-512.png", "512x512", "maskable")],
                shortcuts=[dict(name="Offline Sync", short_name="Sync", url="/sync", icons=[icon("icon-192.png", "192x192")]),
                           dict(name="Field Operations", short_name="Field", url="/field", icons=[icon("icon-192.png", "192x192")])])
    resp = jsonify(data)
    resp.mimetype = "application/manifest+json"
    return resp


@app.route("/offline")
def offline():
    return render_template("offline.html")


# --------------------------------------------------------------------------- #
# 12. Employee onboarding / 14. HRM / 13. Users & RBAC
# --------------------------------------------------------------------------- #
ONBOARD_DOCS = ["Aadhaar", "PAN", "Education certificates", "Previous employer relieving letter", "Bank details", "Photograph"]


@app.route("/employees")
@need("employees")
def employees():
    rows = q("SELECT e.*, m.name manager_name FROM employees e LEFT JOIN employees m ON m.id=e.manager_id ORDER BY e.id")
    kids = {}
    for r in rows:
        kids.setdefault(r["manager_id"], []).append(r)

    def tree(pid, depth=0):
        out = []
        for r in kids.get(pid, []):
            out.append((depth, r))
            out += tree(r["id"], depth + 1)
        return out
    return render_template("employees.html", rows=rows, org=tree(None), onboard_docs=ONBOARD_DOCS,
                           docs_map={r["id"]: json.loads(r["docs"] or "[]") for r in rows})


@app.route("/employees/new", methods=["POST"])
@need("employees")
def employee_new():
    f = request.form
    if not f["name"].strip() or not re.fullmatch(r"[6-9]\d{9}", f.get("phone", "")):
        flash("Name and valid 10-digit mobile required.", "danger")
        return redirect(url_for("employees"))
    try:
        salary = float(f.get("salary") or 0)
    except ValueError:
        salary = 0
    ex("INSERT INTO employees(name,designation,branch,manager_id,phone,email,joined,status,bg_check,docs,salary) VALUES(?,?,?,?,?,?,?,?,?,?,?)",
       (f["name"].strip(), f["designation"], f["branch"], f.get("manager_id") or None, f["phone"], f.get("email", ""),
        f.get("joined") or date.today().isoformat(), "onboarding", "pending", json.dumps(f.getlist("docs")), salary))
    flash("Employee added - onboarding started.", "success")
    return redirect(url_for("employees"))


@app.route("/employees/<int:eid>/update", methods=["POST"])
@need("employees")
def employee_update(eid):
    f = request.form
    if f.get("bg_check") in ("pending", "in_progress", "cleared", "failed") and f.get("status") in ("onboarding", "active", "exited"):
        ex("UPDATE employees SET bg_check=?, status=?, docs=? WHERE id=?", (f["bg_check"], f["status"], json.dumps(f.getlist("docs")), eid))
        flash("Employee updated.", "success")
    return redirect(url_for("employees"))


@app.route("/hrm")
@need("hrm")
def hrm():
    month = request.args.get("month") or add_months(date.today().replace(day=1), -1).strftime("%Y-%m")
    if not re.fullmatch(r"\d{4}-\d{2}", month):
        month = date.today().strftime("%Y-%m")
    att = q("SELECT u.name, COUNT(a.id) present FROM users u LEFT JOIN attendance a ON a.user_id=u.id AND substr(a.day,1,7)=? "
            "WHERE u.role!='customer' GROUP BY u.id ORDER BY u.name", (month,))
    payroll = []
    for r in att:
        emp = q("SELECT salary FROM employees e JOIN users u ON u.id=e.user_id WHERE u.name=?", (r["name"],), one=True)
        basic = emp["salary"] if emp else 0
        lop = max(0, 26 - r["present"])
        lop_amt = round(basic / 26 * lop, 2)
        hra, pf = round(basic * 0.4, 2), round(basic * 0.12, 2)
        payroll.append(dict(name=r["name"], present=r["present"], basic=basic, hra=hra, pf=pf, lop=lop, lop_amt=lop_amt,
                            net=round(basic + hra - pf - lop_amt, 2)))
    return render_template("hrm.html", month=month, payroll=payroll,
                           leaves=q("SELECT l.*, u.name FROM leaves l JOIN users u ON u.id=l.user_id ORDER BY l.id DESC"),
                           perf=q("SELECT p.*, u.name FROM perf p JOIN users u ON u.id=p.user_id ORDER BY p.id DESC"),
                           staff=q("SELECT id,name FROM users WHERE role!='customer' ORDER BY name"),
                           todays=q("SELECT u.name, a.in_time, a.out_time FROM attendance a JOIN users u ON u.id=a.user_id WHERE a.day=?", (date.today().isoformat(),)))


@app.route("/hrm/leave", methods=["POST"])
@need("hrm")
def leave_apply():
    f = request.form
    if f["from_d"] and f["to_d"] and f["from_d"] <= f["to_d"]:
        ex("INSERT INTO leaves(user_id,from_d,to_d,reason) VALUES(?,?,?,?)", (f["user_id"], f["from_d"], f["to_d"], f.get("reason", "")))
        flash("Leave request submitted.", "success")
    else:
        flash("Check leave dates.", "danger")
    return redirect(url_for("hrm"))


@app.route("/hrm/leave/<int:lid>/<action>", methods=["POST"])
@need("hrm")
def leave_action(lid, action):
    if action in ("approved", "rejected"):
        ex("UPDATE leaves SET status=? WHERE id=?", (action, lid))
    return redirect(url_for("hrm"))


@app.route("/hrm/perf", methods=["POST"])
@need("hrm")
def perf_add():
    f = request.form
    try:
        r = int(f["rating"]); assert 1 <= r <= 5
    except Exception:
        flash("Rating must be 1-5.", "danger")
        return redirect(url_for("hrm"))
    ex("INSERT INTO perf(user_id,period,rating,notes,by_name) VALUES(?,?,?,?,?)", (f["user_id"], f["period"], r, f.get("notes", ""), g.user["name"]))
    flash("Evaluation saved.", "success")
    return redirect(url_for("hrm"))


@app.route("/users")
def users():
    if not g.user or g.user["role"] != "admin":
        return render_template("error.html", msg="Admins only."), 403
    mods = [n for n in NAV if n[0] != "users"] + [("approve", "Approve / reject applications", "", ""), ("disburse", "Sanction & disburse", "", "")]
    return render_template("users.html", rows=q("SELECT * FROM users ORDER BY id"), perms=PERMS, mods=mods)


@app.route("/users/<int:uid>/role", methods=["POST"])
def user_role(uid):
    if not g.user or g.user["role"] != "admin":
        abort(403)
    if request.form["role"] in ROLES and uid != g.user["id"]:
        ex("UPDATE users SET role=? WHERE id=?", (request.form["role"], uid))
        flash("Role updated.", "success")
    else:
        flash("Invalid role (you cannot change your own role).", "danger")
    return redirect(url_for("users"))


# --------------------------------------------------------------------------- #
# 16. WhatsApp channel verification (click-to-chat + OTP simulation)
# --------------------------------------------------------------------------- #
@app.route("/whatsapp")
@need("whatsapp")
def whatsapp():
    w, a = "", ()
    if scope_agent():
        w, a = "WHERE agent_id=?", (scope_agent(),)
    return render_template("whatsapp.html", rows=q(f"SELECT * FROM customers {w} ORDER BY name", a))


@app.route("/whatsapp/<int:cid>/send", methods=["POST"])
@need("whatsapp")
def whatsapp_send(cid):
    otp = f"{random.randint(100000, 999999)}"
    ex("UPDATE customers SET wa_otp=? WHERE id=?", (otp, cid))
    flash("Verification code generated. Use the 'Open WhatsApp' link to send it to the customer.", "success")
    return redirect(url_for("whatsapp", sent=cid))


@app.route("/whatsapp/<int:cid>/verify", methods=["POST"])
@need("whatsapp")
def whatsapp_verify(cid):
    c = q("SELECT * FROM customers WHERE id=?", (cid,), one=True) or abort(404)
    if c["wa_otp"] and request.form.get("otp", "").strip() == c["wa_otp"]:
        ex("UPDATE customers SET wa_verified=1, wa_otp=NULL WHERE id=?", (cid,))
        ex("INSERT INTO comm_logs(customer_id,channel,note,by_name,at) VALUES(?,?,?,?,?)",
           (cid, "whatsapp", "WhatsApp number verified via OTP", g.user["name"], datetime.now().isoformat(timespec="seconds")))
        flash("WhatsApp number verified.", "success")
    else:
        flash("Wrong code.", "danger")
    return redirect(url_for("whatsapp"))


@app.template_global()
def wa_link(c):
    msg = f"Hello {c['name']}, your Sarvocch Microcare Foundation verification code is {c['wa_otp']}. Please reply with this code to confirm your WhatsApp number."
    from urllib.parse import quote
    return f"https://wa.me/91{c['phone']}?text={quote(msg)}"


@app.route("/uploads/<path:name>")
def uploaded(name):
    if not g.user or g.user["role"] == "customer":
        abort(403)
    return send_from_directory(UPLOADS, secure_filename(name))


@app.errorhandler(404)
def e404(_):
    return render_template("error.html", msg="Page not found."), 404


# --------------------------------------------------------------------------- #
# ONBOARDING FORMS (digital versions of the paper forms)
#   A. Customer KYC form  (basic details, family, house, bank, income, declaration)
#   B. Husband information + consent for loan
#   C. Loan application extras (previous loans, cash flow, insurance, documents, approval trail)
#   D. Pre-GRT group form (members + loan understanding checks)
# --------------------------------------------------------------------------- #
from math import isfinite

MIN_AGE, MAX_AGE = 18, 65            # borrower age limits - change to match your policy
PREGRT_MIN, PREGRT_MAX = 5, 10       # members per group - change to match your policy
IMG_EXT = {"jpg", "jpeg", "png"}
PNG_SIG, JPG_SIG = b"\x89PNG\r\n\x1a\n", b"\xff\xd8\xff"

CO_RELATIONS = ["Husband/Son", "Wife", "Other"]
CALL_OUTCOMES = ["Connected", "No answer", "Busy", "Wrong number", "Call back later"]
CATEGORIES = ["General", "OBC", "SC", "ST", "Minority"]
RELIGIONS = ["Hindu", "Muslim", "Christian", "Sikh", "Buddhist", "Jain", "Other"]
EDUCATION = ["Illiterate", "Primary (up to 5th)", "Middle (up to 8th)", "Secondary (10th)", "Senior secondary (12th)",
             "Graduate", "Post-graduate", "Other"]
STATES = ["Andhra Pradesh", "Arunachal Pradesh", "Assam", "Bihar", "Chhattisgarh", "Goa", "Gujarat", "Haryana",
          "Himachal Pradesh", "Jharkhand", "Karnataka", "Kerala", "Madhya Pradesh", "Maharashtra", "Manipur",
          "Meghalaya", "Mizoram", "Nagaland", "Odisha", "Punjab", "Rajasthan", "Sikkim", "Tamil Nadu", "Telangana",
          "Tripura", "Uttar Pradesh", "Uttarakhand", "West Bengal", "Andaman and Nicobar Islands", "Chandigarh",
          "Dadra and Nagar Haveli and Daman and Diu", "Delhi", "Jammu and Kashmir", "Ladakh", "Lakshadweep", "Puducherry"]
HOUSE_TYPES = [("pucca", "Pucca / पक्का"), ("semi_pucca", "Semi-pucca / अर्ध पक्का"), ("kaccha", "Kaccha / कच्चा"),
               ("hut", "Hut / झोपड़ी")]
FREQS = [("weekly", "Weekly / साप्ताहिक"), ("fortnightly", "Fortnightly / द्विसाप्ताहिक"), ("monthly", "Monthly / मासिक")]
DOC_CHOICES = [("aadhaar", "Aadhaar card / आधार कार्ड"), ("voter", "Voter ID / मतदाता पहचान पत्र"),
               ("ration", "Ration card / राशन कार्ड"), ("other", "Other / कोई अन्य")]
INC_FIELDS = [("inc_agri", "Agriculture / कृषि से आय"), ("inc_business", "Business / व्यवसाय से आय"),
              ("inc_job", "Job or profession / नौकरी-पेशा से आय"), ("inc_other", "Other sources / अन्य स्रोतों से आय")]
EXP_FIELDS = [("exp_basic", "Basic needs - food, clothes / मूलभूत आवश्यकताएँ"), ("exp_education", "Education / शिक्षा"),
              ("exp_festival", "Festival & travel / त्योहार एवं परिवहन"), ("exp_health", "Health / स्वास्थ्य"),
              ("exp_emi", "Loan instalments due / ऋण की देय किस्तें"), ("exp_other", "Other / अन्य व्यय")]
PREGRT_CHECKS = [("c_meeting", "Can attend centre meetings / केन्द्र बैठक में भाग"),
                 ("c_joint", "Understands joint liability / सामूहिक दायित्व"),
                 ("c_fee", "Knows processing fee / प्रसंस्करण शुल्क"), ("c_rate", "Knows interest rate / ब्याज दर"),
                 ("c_insurance", "Knows insurance / बीमा"), ("c_company", "Knows company rules / संस्था के नियम"),
                 ("c_group", "Knows group rules / समूह के नियम")]
K = dict(co_relations=CO_RELATIONS, call_outcomes=CALL_OUTCOMES, categories=CATEGORIES, religions=RELIGIONS, education=EDUCATION, states=STATES, house_types=HOUSE_TYPES,
         freqs=FREQS, docs=DOC_CHOICES, inc_fields=INC_FIELDS, exp_fields=EXP_FIELDS, pregrt_checks=PREGRT_CHECKS,
         min_age=MIN_AGE, max_age=MAX_AGE, pregrt_min=PREGRT_MIN, pregrt_max=PREGRT_MAX)
STAGE_LABEL = {"review": "Review started", "approve": "Approved", "reject": "Rejected", "sanction": "Sanctioned",
               "disburse": "Disbursed"}


@app.template_global()
def cust_code(cid):
    return f"SMF-{int(cid):05d}"


@app.template_filter("label")
def label_filter(key, options):
    return dict(options).get(key, key or "-")


def _s(f, k):
    return (f.get(k) or "").strip()


def parse_date(s):
    try:
        return date.fromisoformat(str(s)[:10])
    except (ValueError, TypeError):
        return None


def age_of(dob):
    d = dob if isinstance(dob, date) else parse_date(dob)
    if not d:
        return None
    t = date.today()
    return t.year - d.year - ((t.month, t.day) < (d.month, d.day))


def to_num(raw, label, errs, *, req=False, lo=0.0, hi=None, integer=False):
    """Parse a number from a form field; appends a readable error and returns None when invalid."""
    raw = (raw or "").strip().replace(",", "")
    if raw == "":
        if req:
            errs.append(f"{label} is required.")
        return None
    try:
        v = int(raw) if integer else float(raw)
        if not isfinite(v):
            raise ValueError
    except ValueError:
        errs.append(f"{label} must be a number.")
        return None
    if v < lo or (hi is not None and v > hi):
        errs.append(f"{label} must be between {lo:g} and {hi:g}." if hi is not None else f"{label} cannot be less than {lo:g}.")
        return None
    return v


def check_file(file, label, errs, images_only=True):
    """Validate an upload WITHOUT saving it. Returns the file, None (nothing chosen) or False (invalid, error added)."""
    if not file or not file.filename:
        return None
    ext = file.filename.rsplit(".", 1)[-1].lower() if "." in file.filename else ""
    allowed = IMG_EXT if images_only else ALLOWED_EXT
    if ext not in allowed:
        errs.append(f"{label}: only {'JPG or PNG images' if images_only else 'PDF, JPG or PNG files'} are allowed.")
        return False
    head = file.stream.read(8)
    file.stream.seek(0)
    if not (head.startswith(PNG_SIG) or head.startswith(JPG_SIG) or (not images_only and head.startswith(b"%PDF"))):
        errs.append(f"{label}: the file is not a valid {'image' if images_only else 'PDF/image'}.")
        return False
    return file


def store_file(file, prefix):
    head = file.stream.read(8)
    file.stream.seek(0)
    ext = "png" if head.startswith(PNG_SIG) else ("pdf" if head.startswith(b"%PDF") else "jpg")
    name = f"{prefix}_{uuid.uuid4().hex[:10]}.{ext}"
    file.save(os.path.join(UPLOADS, name))
    return name


def compose_address(d):
    parts = [d.get("house_no"), d.get("village"), d.get("post_office") and f"P.O. {d['post_office']}", d.get("district"),
             d.get("state")]
    s = ", ".join(p for p in parts if p)
    return f"{s} - {d['pincode']}" if d.get("pincode") else s


def get_customer_or_404(cid):
    c = q("SELECT c.*, u.name agent_name FROM customers c LEFT JOIN users u ON u.id=c.agent_id WHERE c.id=?", (cid,), one=True)
    if not c or (scope_agent() and c["agent_id"] != scope_agent()):
        abort(404)
    return c


# ------------------------------ A + B. KYC form ------------------------------ #
KYC_COLS = ["form_date", "center_no", "group_no", "guardian_type", "guardian_name", "education", "religion", "category",
            "house_no", "village", "post_office", "district", "state", "pincode", "family", "house_type", "land_ha",
            "livestock", "bank_name", "bank_acct", "passbook_name", "poverty_line", "dist_center_m", "dist_branch_km",
            "relative_in_center", "relative_name", "annual_income", "other_loans", "current_debt", "repay_freq", "photo",
            "h_name", "h_father", "h_dob", "h_address", "h_photo", "consent_given", "consent_date", "declaration",
            "bureau_consent", "address_verified", "verified_by", "verified_on", "verify_remarks", "signed_copy",
            "co_name", "co_phone", "co_relation", "co_income", "neighbours"]
KYC_CHECKBOXES = ("consent_given", "declaration", "bureau_consent", "address_verified")


def neighbour_rows_from_form(f):
    cols = {k: f.getlist(k) for k in ("nb_name", "nb_phone", "nb_email", "nb_years", "nb_remarks")}
    pick = lambda k, i: (cols[k][i] if i < len(cols[k]) else "").strip()
    return [dict(name=pick("nb_name", i), phone=pick("nb_phone", i), email=pick("nb_email", i), years=pick("nb_years", i),
                 remarks=pick("nb_remarks", i)) for i in range(min(len(cols["nb_name"]), 3))]


def family_rows_from_form(f):
    names, ages, edus, rels, occs = (f.getlist(k) for k in ("fm_name", "fm_age", "fm_edu", "fm_rel", "fm_occ"))
    pick = lambda lst, i: (lst[i] if i < len(lst) else "").strip()
    return [dict(name=pick(names, i), age=pick(ages, i), edu=pick(edus, i), rel=pick(rels, i), occ=pick(occs, i))
            for i in range(min(len(names), 12))]


def parse_kyc_form(f, files, existing=None, cust=None):
    """Validate the KYC form. Returns (kyc_data, customer_data, errors, files_to_store)."""
    errs, d, cd = [], {}, {}
    s = lambda k: _s(f, k)

    # --- applicant (stored on the customer record)
    cd["name"] = " ".join(s("name").split())
    if len(cd["name"]) < 2 or len(cd["name"]) > 80 or re.search(r"\d", cd["name"]):
        errs.append("Applicant name is required (2-80 letters, no digits).")
    cd["phone"] = s("phone")
    if not re.fullmatch(r"[6-9]\d{9}", cd["phone"]):
        errs.append("Mobile number must be 10 digits and start with 6, 7, 8 or 9.")
    else:
        dup = q("SELECT id,name FROM customers WHERE phone=? AND id!=?", (cd["phone"], cust["id"] if cust else 0), one=True)
        if dup:
            errs.append(f"Mobile {cd['phone']} is already registered for {dup['name']} (customer #{dup['id']}).")
    cd["dob"] = s("dob")
    dob = parse_date(cd["dob"])
    if not dob:
        errs.append("Date of birth is required.")
    else:
        a = age_of(dob)
        if not (MIN_AGE <= a <= MAX_AGE):
            errs.append(f"Applicant age must be between {MIN_AGE} and {MAX_AGE} years (the date entered gives {a}).")
    cd["branch"] = s("branch")
    if cd["branch"] not in BRANCHES:
        errs.append("Select a branch.")
    if scope_agent():
        cd["agent_id"] = scope_agent()
    else:
        ag = q("SELECT id FROM users WHERE id=? AND role='field_agent'", (s("agent_id") or 0,), one=True)
        if not ag:
            errs.append("Assign a field officer to this customer.")
        cd["agent_id"] = ag["id"] if ag else None

    # --- form header
    d["form_date"] = s("form_date")
    fd = parse_date(d["form_date"])
    if not fd or fd > date.today():
        errs.append("Form date must be a valid date and cannot be in the future.")
    d["center_no"], d["group_no"] = s("center_no")[:20], s("group_no")[:20]

    # --- guardian, education, religion, category
    d["guardian_type"] = s("guardian_type")
    if d["guardian_type"] not in ("husband", "father"):
        errs.append("Choose whether the name given is the Husband or the Father.")
    d["guardian_name"] = " ".join(s("guardian_name").split())[:80]
    if len(d["guardian_name"]) < 2:
        errs.append("Husband / father name is required.")
    for key, label, opts in (("education", "Educational qualification", EDUCATION), ("religion", "Religion", RELIGIONS),
                             ("category", "Category", CATEGORIES)):
        d[key] = s(key)
        if d[key] not in opts:
            errs.append(f"{label}: please select a value.")

    # --- address
    d["house_no"], d["post_office"] = s("house_no")[:40], s("post_office")[:60]
    d["village"], d["district"], d["state"] = s("village")[:60], s("district")[:60], s("state")
    for key, label in (("village", "Village / town"), ("district", "District")):
        if not d[key]:
            errs.append(f"{label} is required.")
    if d["state"] not in STATES:
        errs.append("State: please select a value.")
    d["pincode"] = s("pincode")
    if not re.fullmatch(r"[1-9]\d{5}", d["pincode"]):
        errs.append("PIN code must be 6 digits.")

    # --- family members
    fam, rows = [], family_rows_from_form(f)
    if len(f.getlist("fm_name")) > 12:
        errs.append("A maximum of 12 family members can be entered.")
    for r in rows:
        if not r["name"]:
            continue
        n = len(fam) + 1
        age = to_num(r["age"], f"Family member {n} age", errs, req=True, hi=110, integer=True)
        if not r["rel"]:
            errs.append(f"Family member {n} ({r['name']}): relation is required.")
        fam.append(dict(name=r["name"][:80], age=age, edu=r["edu"][:40], rel=r["rel"][:30], occ=r["occ"][:40]))
    if not fam:
        errs.append("Add at least one family member (the applicant first).")
    d["family"] = json.dumps(fam)

    # --- house, land, bank, distances
    d["house_type"] = s("house_type")
    if d["house_type"] not in dict(HOUSE_TYPES):
        errs.append("Type of house: please select a value.")
    d["land_ha"] = to_num(s("land_ha"), "Land (hectare)", errs, hi=1000) or 0.0
    d["livestock"] = s("livestock")[:60]
    d["bank_name"], d["passbook_name"] = s("bank_name")[:60], s("passbook_name")[:80]
    d["bank_acct"] = s("bank_acct").replace(" ", "")
    if d["bank_acct"]:
        if not re.fullmatch(r"\d{9,18}", d["bank_acct"]):
            errs.append("Bank account number must be 9 to 18 digits.")
        if not d["bank_name"]:
            errs.append("Enter the bank name for the account number.")
    d["poverty_line"] = s("poverty_line")
    if d["poverty_line"] not in ("BPL", "APL"):
        errs.append("Poverty line: choose BPL or APL.")
    d["dist_center_m"] = to_num(s("dist_center_m"), "Distance from centre meeting place", errs, hi=100000)
    d["dist_branch_km"] = to_num(s("dist_branch_km"), "Distance from branch", errs, hi=1000)
    d["relative_in_center"] = s("relative_in_center")
    if d["relative_in_center"] not in ("yes", "no"):
        errs.append("Say whether the applicant has a relative in the centre (Yes / No).")
    d["relative_name"] = s("relative_name")[:80] if d["relative_in_center"] == "yes" else ""
    if d["relative_in_center"] == "yes" and not d["relative_name"]:
        errs.append("Enter the relative's name.")

    # --- financial information
    d["annual_income"] = to_num(s("annual_income"), "Annual household income", errs, req=True, hi=10 ** 8)
    d["other_loans"] = to_num(s("other_loans"), "Number of other MFI / SHG loans", errs, hi=50, integer=True) or 0
    d["current_debt"] = to_num(s("current_debt"), "Current indebtedness", errs, hi=10 ** 8) or 0.0
    d["repay_freq"] = s("repay_freq")
    if d["repay_freq"] not in dict(FREQS):
        errs.append("Preferred repayment frequency: please select a value.")

    # --- co-applicant (optional; moved here from the loan application)
    d["co_name"] = " ".join(s("co_name").split())[:80]
    d["co_phone"], d["co_relation"] = s("co_phone"), s("co_relation")[:40]
    co_other = s("co_relation_other")[:40]
    d["co_income"] = to_num(s("co_income"), "Co-applicant monthly income", errs, hi=10 ** 7) or 0.0
    if d["co_name"]:
        if re.search(r"\d", d["co_name"]):
            errs.append("Co-applicant name cannot contain digits.")
        if not re.fullmatch(r"[6-9]\d{9}", d["co_phone"]):
            errs.append("Co-applicant needs a valid 10-digit mobile number.")
        elif d["co_phone"] == cd["phone"]:
            errs.append("Co-applicant mobile must be different from the applicant's mobile.")
        if d["co_relation"] not in CO_RELATIONS:
            errs.append("Co-applicant: choose the relation with the applicant (Husband/Son, Wife or Other).")
        elif d["co_relation"] == "Other":
            if not co_other:
                errs.append("Co-applicant: write the relation when you choose Other.")
            else:
                d["co_relation"] = "Other: " + co_other
    else:
        d["co_phone"] = d["co_relation"] = ""
        d["co_income"] = 0.0

    # --- neighbour details (optional; up to 3) for the neighbour-feedback check
    nbs = []
    for r in neighbour_rows_from_form(f):
        if not (r["name"] or r["phone"] or r["email"]):
            continue
        n = len(nbs) + 1
        if len(r["name"]) < 2 or re.search(r"\d", r["name"]):
            errs.append(f"Neighbour {n}: enter the name (letters only).")
        if not re.fullmatch(r"[6-9]\d{9}", r["phone"]):
            errs.append(f"Neighbour {n}: enter a valid 10-digit mobile number.")
        elif r["phone"] == cd["phone"]:
            errs.append(f"Neighbour {n}: the mobile number cannot be the applicant's own.")
        if r["email"] and not re.fullmatch(r"[^@\s]+@[^@\s]+\.[A-Za-z]{2,}", r["email"]):
            errs.append(f"Neighbour {n}: the email address is not valid (it is optional, leave it empty if unknown).")
        yrs = to_num(r["years"], f"Neighbour {n}: years known", errs, hi=100, integer=True)
        nbs.append(dict(name=" ".join(r["name"].split())[:80], phone=r["phone"], email=r["email"][:80], years=yrs,
                        remarks=r["remarks"][:200]))
    d["neighbours"] = json.dumps(nbs)

    # --- husband information + consent (only when the name given above is the husband's)
    todo = {}
    if d["guardian_type"] == "husband":
        d["h_name"] = d["guardian_name"]
        d["h_father"] = s("h_father")[:80]
        d["h_dob"] = s("h_dob")
        hd = parse_date(d["h_dob"])
        if not hd or age_of(hd) < MIN_AGE:
            errs.append(f"Husband's date of birth is required (he must be {MIN_AGE}+ years old).")
        d["h_address"] = compose_address(d) if f.get("h_same_addr") else s("h_address")[:200]
        if not d["h_address"]:
            errs.append("Husband's address is required (or tick 'same as applicant').")
        d["consent_given"] = 1 if f.get("consent_given") else 0
        if not d["consent_given"]:
            errs.append("The husband's consent for the loan must be ticked.")
        d["consent_date"] = (existing["consent_date"] if existing and existing["consent_date"] else date.today().isoformat())
        hp = check_file(files.get("h_photo"), "Husband's photo", errs)
        if hp:
            todo["h_photo"] = hp
    else:
        d.update(h_name="", h_father="", h_dob="", h_address="", consent_given=0, consent_date="")
        d["h_photo"] = ""

    # --- declarations + staff verification
    for key, msg in (("declaration", "Tick the applicant's declaration that the information is complete and correct."),
                     ("bureau_consent", "Tick the consent to share credit information with credit bureaus and insurers."),
                     ("address_verified", "The field officer must confirm the address visit (KYC verification box).")):
        d[key] = 1 if f.get(key) else 0
        if not d[key]:
            errs.append(msg)
    d["verified_by"], d["verified_on"] = g.user["name"], date.today().isoformat()
    d["verify_remarks"] = s("verify_remarks")[:300]

    # --- files (checked now, saved only if everything is valid)
    ph = check_file(files.get("photo"), "Applicant photo", errs)
    if ph is None and not (existing and existing["photo"]):
        errs.append("Applicant photo is required.")
    if ph:
        todo["photo"] = ph
    sc = check_file(files.get("signed_copy"), "Signed form copy", errs, images_only=False)
    if sc:
        todo["signed_copy"] = sc
    for key in ("photo", "h_photo", "signed_copy"):
        d.setdefault(key, existing[key] if existing and existing[key] else "")
    if d["guardian_type"] != "husband":
        d["h_photo"] = ""
    return d, cd, errs, todo


def form_values(src):
    return {k: src.get(k, "") for k in src.keys()}


def kyc_values(cust, k):
    v = dict(k) if k else {}
    if cust:
        v.update(name=cust["name"], phone=cust["phone"], dob=cust["dob"] or "", branch=cust["branch"], agent_id=cust["agent_id"])
    for key in KYC_CHECKBOXES:
        v[key] = "on" if v.get(key) else ""
    v.setdefault("form_date", date.today().isoformat())
    rel = (v.get("co_relation") or "")
    if rel and rel not in CO_RELATIONS:           # saved as "Other: xyz" (or older free text)
        v["co_relation_other"] = rel[7:] if rel.startswith("Other: ") else rel
        v["co_relation"] = "Other"
    v["neigh"] = json.loads(v.get("neighbours") or "[]")
    return v


def render_kyc_form(cust, existing, v, family, errors=False):
    return render_template("kyc_form.html", v=v, family=family, cust=cust, existing=existing, agents=agents_list(), errors=errors)


def _kyc_form_view(cust):
    existing = q("SELECT * FROM kyc_forms WHERE customer_id=?", (cust["id"],), one=True) if cust else None
    if request.method == "POST":
        d, cd, errs, todo = parse_kyc_form(request.form, request.files, existing, cust)
        if errs:
            for e in errs:
                flash(e, "danger")
            flash("Nothing was saved. Please fix the points above (photos have to be chosen again).", "warning")
            fv = form_values(request.form)
            fv["neigh"] = neighbour_rows_from_form(request.form)
            return render_kyc_form(cust, existing, fv, family_rows_from_form(request.form), True)
        for key, fobj in todo.items():
            d[key] = store_file(fobj, key)
        now = datetime.now().isoformat(timespec="seconds")
        address = compose_address(d)
        db = get_db()
        with db:
            if cust is None:
                cid = db.execute("INSERT INTO customers(name,phone,dob,address,branch,agent_id,stage,created) VALUES(?,?,?,?,?,?,?,?)",
                                 (cd["name"], cd["phone"], cd["dob"], address, cd["branch"], cd["agent_id"], "prospect", now)).lastrowid
            else:
                cid = cust["id"]
                db.execute("UPDATE customers SET name=?,phone=?,dob=?,address=?,branch=?,agent_id=? WHERE id=?",
                           (cd["name"], cd["phone"], cd["dob"], address, cd["branch"], cd["agent_id"], cid))
                db.execute("UPDATE customers SET stage='prospect' WHERE id=? AND stage='lead'", (cid,))
            if existing:
                db.execute(f"UPDATE kyc_forms SET {','.join(c + '=?' for c in KYC_COLS)}, updated_at=? WHERE customer_id=?",
                           [d[c] for c in KYC_COLS] + [now, cid])
            else:
                db.execute(f"INSERT INTO kyc_forms(customer_id,created_by,created_at,updated_at,{','.join(KYC_COLS)}) "
                           f"VALUES(?,?,?,?,{','.join('?' * len(KYC_COLS))})",
                           [cid, g.user["id"], now, now] + [d[c] for c in KYC_COLS])
            db.execute("INSERT INTO comm_logs(customer_id,channel,note,by_name,at) VALUES(?,?,?,?,?)",
                       (cid, "visit", "KYC form " + ("updated" if existing else "completed") + " (digital onboarding form)", g.user["name"], now))
        flash("KYC form saved. Next: verify Aadhaar and PAN / Voter ID in 'KYC Verify', record the group's Pre-GRT, "
              "then create the loan application.", "success")
        return redirect(url_for("crm_detail", cid=cid))
    v = kyc_values(cust, existing)
    if existing is None:
        for key, val in dict(state="Madhya Pradesh", branch=g.user["branch"], guardian_type="husband", relative_in_center="no",
                             poverty_line="APL", repay_freq="weekly", other_loans="0", agent_id=scope_agent() or "").items():
            v.setdefault(key, val)
    family = json.loads(existing["family"]) if existing and existing["family"] else []
    return render_kyc_form(cust, existing, v, family)


@app.route("/kyc-form/new", methods=["GET", "POST"])
@need("kycform")
def kyc_form_new():
    return _kyc_form_view(None)


@app.route("/crm/<int:cid>/kyc-form", methods=["GET", "POST"])
@need("kycform")
def kyc_form_edit(cid):
    return _kyc_form_view(get_customer_or_404(cid))


@app.route("/crm/<int:cid>/kyc-form/print")
@need("crm", "kycform")
def kyc_form_print(cid):
    c = get_customer_or_404(cid)
    k = q("SELECT * FROM kyc_forms WHERE customer_id=?", (cid,), one=True)
    if not k:
        flash("The KYC form has not been filled for this customer yet.", "warning")
        return redirect(url_for("crm_detail", cid=cid))
    return render_template("kyc_print.html", c=c, k=k, family=json.loads(k["family"] or "[]"), age=age_of(c["dob"]),
                           neigh=json.loads(k["neighbours"] or "[]"),
                           h_age=age_of(k["h_dob"]) if k["h_dob"] else None)


# ------------------------------ C. Application extras ------------------------------ #
def parse_prev_loans(f, errs):
    cols = {k: f.getlist(k) for k in ("pl_amount", "pl_purpose", "pl_freq", "pl_ontime", "pl_reason", "pl_absence")}
    pick = lambda k, i: (cols[k][i] if i < len(cols[k]) else "").strip()
    rows = []
    for i in range(min(len(cols["pl_amount"]), 6)):
        if not (pick("pl_amount", i) or pick("pl_purpose", i)):
            continue
        n = len(rows) + 1
        amt = to_num(pick("pl_amount", i), f"Previous loan {n}: amount", errs, req=True, lo=1, hi=10 ** 7)
        fr, on = pick("pl_freq", i), pick("pl_ontime", i)
        if fr not in dict(FREQS):
            errs.append(f"Previous loan {n}: choose the repayment frequency.")
        if on not in ("on_time", "late"):
            errs.append(f"Previous loan {n}: say whether instalments were paid on time or late.")
        rows.append(dict(cycle=n, amount=amt, purpose=pick("pl_purpose", i)[:60], freq=fr, ontime=on,
                         reason=pick("pl_reason", i)[:100], absence=pick("pl_absence", i)[:100]))
    return rows


@app.route("/apply", methods=["GET", "POST"])
@need("apply")
def apply():
    w, a = "", ()
    if scope_agent():
        w, a = "WHERE c.agent_id=?", (scope_agent(),)
    customers = q(f"SELECT c.id,c.name,c.phone,c.kyc_status, (SELECT COUNT(*) FROM kyc_forms k WHERE k.customer_id=c.id) has_form, "
                  "(SELECT co_name FROM kyc_forms k WHERE k.customer_id=c.id) co_name, (SELECT co_relation FROM kyc_forms k WHERE k.customer_id=c.id) co_relation, "
                  "(SELECT co_income FROM kyc_forms k WHERE k.customer_id=c.id) co_income, "
                  f"(SELECT COUNT(*) FROM loans l WHERE l.customer_id=c.id)+1 cycle FROM customers c {w} ORDER BY c.name", a)
    prods = q("SELECT * FROM products WHERE active=1 AND group_only=0" + ("" if g.user["role"] == "admin" else " AND admin_only=0"))
    visible = {c["id"] for c in customers}
    prev_map = {}
    for l in q("SELECT l.customer_id, l.principal, p.name pname, "
               "(SELECT COUNT(*) FROM schedule s WHERE s.loan_id=l.id AND ((s.paid=1 AND s.paid_on>s.due_date) OR (s.paid=0 AND s.due_date<?))) late "
               "FROM loans l JOIN products p ON p.id=l.product_id ORDER BY l.start_date", (date.today().isoformat(),)):
        if l["customer_id"] in visible:
            lst = prev_map.setdefault(l["customer_id"], [])
            lst.append(dict(amount=l["principal"], purpose=l["pname"], freq="monthly", ontime="late" if l["late"] else "on_time"))
    ctx = dict(customers=customers, prods=prods, prev_map=prev_map)
    if request.method == "POST":
        f, errs = request.form, []
        s = lambda k: _s(f, k)
        kf = None
        cust = q("SELECT * FROM customers WHERE id=?", (s("customer_id") or 0,), one=True)
        prod = q("SELECT * FROM products WHERE id=?", (s("product_id") or 0,), one=True)
        if prod and prod["group_only"]:
            errs.append(f"{prod['name']} is a group loan: submit it from the verified Pre-GRT group (Pre-GRT > open group > Apply as group).")
            prod = None
        elif prod and prod["admin_only"] and g.user["role"] != "admin":
            errs.append(f"{prod['name']} can be issued by the Admin only.")
            prod = None
        if not cust or cust["id"] not in visible:
            errs.append("Select a customer.")
            cust = None
        elif not (kf := q("SELECT * FROM kyc_forms WHERE customer_id=?", (cust["id"],), one=True)):
            errs.append(f"{cust['name']} has no KYC form yet. Fill the customer KYC form first (CRM > customer > KYC form).")
        if not prod:
            errs.append("Select a loan product.")
        amount = to_num(s("amount"), "Loan amount", errs, req=True, lo=1, hi=10 ** 7) or 0
        tenure = to_num(s("tenure"), "Tenure", errs, req=True, lo=1, hi=120, integer=True) or 0
        if prod and amount and not (prod["min_amt"] <= amount <= prod["max_amt"]):
            errs.append(f"Amount must be between {prod['min_amt']:.0f} and {prod['max_amt']:.0f} for this product.")
        if prod and tenure and not (prod["min_tenure"] <= tenure <= prod["max_tenure"]):
            errs.append(f"Tenure must be {prod['min_tenure']}-{prod['max_tenure']} months.")
        cycle = to_num(s("loan_cycle"), "Loan cycle", errs, req=True, lo=1, hi=50, integer=True) or 1
        # previous loans
        prev = parse_prev_loans(f, errs)
        # cash flow (Mudra Pravah)
        flow = {k: (to_num(s(k), lbl.split(" / ")[0], errs, hi=10 ** 7) or 0.0) for k, lbl in INC_FIELDS + EXP_FIELDS}
        inc_total = round(sum(flow[k] for k, _ in INC_FIELDS), 2)
        exp_total = round(sum(flow[k] for k, _ in EXP_FIELDS), 2)
        net = round(inc_total - exp_total, 2)
        co_name, co_phone, co_rel, co_income = ((kf["co_name"] or ""), (kf["co_phone"] or ""), (kf["co_relation"] or ""),
                                                (kf["co_income"] or 0.0)) if cust and kf else ("", "", "", 0.0)
        if inc_total <= 0:
            errs.append("Enter the monthly income in the cash-flow section (at least one income source).")
        elif net + co_income <= 0:
            errs.append("Monthly expenses are higher than income. Please re-check the figures or add a co-applicant income.")
        if inc_total + co_income > CFG["income_limit"]:
            errs.append(f"Household monthly income {inc_total + co_income:,.0f} is above the eligibility limit of {CFG['income_limit']:,.0f}.")
        if prod and amount and inc_total > 0:
            e = emi_calc(amount, prod["rate"], tenure, prod["method"])
            if e > CFG["emi_pct"] / 100 * (inc_total + co_income):
                errs.append(f"EMI {e:.0f} exceeds {CFG['emi_pct']:.0f}% of household income - reduce the amount or add a co-applicant income.")
        # documents deposited (any two) + insurance + declaration
        docs_dep = [x for x in f.getlist("docs_dep") if x in dict(DOC_CHOICES)]
        if len(set(docs_dep)) < 2:
            errs.append("Tick at least two documents deposited with the application (Aadhaar, Voter ID, Ration card or other).")
        ins = s("insurance_wanted")
        ins_for = s("insurance_for")
        if ins not in ("yes", "no"):
            errs.append("Life insurance: choose Yes or No.")
        elif ins == "yes":
            if ins_for not in ("husband", "self", "both"):
                errs.append("Life insurance: choose whose insurance is wanted (husband / self / both).")
            if not f.get("insurance_ack"):
                errs.append("Tick the life-insurance acknowledgement.")
        else:
            ins_for = ""
        group_rec = to_num(s("group_rec"), "Group leader recommended amount", errs, hi=10 ** 7)
        center_rec = to_num(s("center_rec"), "Centre leader recommended amount", errs, hi=10 ** 7)
        if not f.get("app_declaration"):
            errs.append("Tick the applicant's declaration.")
        files, docs = {}, {}
        for key in ("doc_id", "doc_address", "doc_income", "doc_photo"):
            fo = check_file(request.files.get(key), key.replace("doc_", "").title() + " document", errs, images_only=False)
            if fo:
                files[key] = fo
        if errs:
            for e_ in errs:
                flash(e_, "danger")
            flash("Nothing was saved. Please fix the points above (files have to be chosen again).", "warning")
            return render_template("apply.html", form=f, prev_rows=parse_prev_rows_for_form(f), **ctx)
        for key, fo in files.items():
            docs[key] = store_file(fo, key)
        now = datetime.now().isoformat(timespec="seconds")
        db = get_db()
        with db:
            aid = db.execute(
                "INSERT INTO applications(customer_id,product_id,amount,tenure,rate,purpose,income,occupation,employer,"
                "co_name,co_phone,co_relation,co_income,status,agent_id,branch,created,docs) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                (cust["id"], prod["id"], amount, tenure, prod["rate"], s("purpose")[:100], inc_total, s("occupation")[:60],
                 s("employer")[:60], co_name, co_phone, co_rel, co_income, "submitted",
                 cust["agent_id"] or g.user["id"], cust["branch"], now, json.dumps(docs))).lastrowid
            db.execute("INSERT INTO app_extra(application_id,prev_loans,insurance_wanted,insurance_for,docs_deposited,docs_other,"
                       "inc_agri,inc_business,inc_job,inc_other,exp_basic,exp_education,exp_festival,exp_health,exp_emi,exp_other,"
                       "group_rec,center_rec,loan_cycle,requested_amt,income_total,expense_total,net_saving,declaration) "
                       "VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                       (aid, json.dumps(prev), ins, ins_for, json.dumps(sorted(set(docs_dep))), s("docs_other")[:60],
                        flow["inc_agri"], flow["inc_business"], flow["inc_job"], flow["inc_other"], flow["exp_basic"],
                        flow["exp_education"], flow["exp_festival"], flow["exp_health"], flow["exp_emi"], flow["exp_other"],
                        group_rec, center_rec, cycle, amount, inc_total, exp_total, net, 1))
            db.execute("INSERT INTO approvals(application_id,stage,by_user,by_role,amount,remarks,at) VALUES(?,?,?,?,?,?,?)",
                       (aid, "Submitted", g.user["name"], g.user["role"], amount, "", now))
        emi = emi_calc(amount, prod["rate"], tenure, prod["method"])
        flash(f"Application #{aid} submitted.", "success")
        if emi > net:
            flash(f"Note: the EMI ({emi:.0f}) is higher than the family's net monthly savings ({net:.0f}). "
                  "The underwriter will see this as a risk flag.", "warning")
        return redirect(url_for("application_detail", aid=aid))
    return render_template("apply.html", form={"customer_id": request.args.get("customer_id", ""), "loan_cycle": "",
                                               "insurance_wanted": "no"}, prev_rows=[], **ctx)


def parse_prev_rows_for_form(f):
    keys = ("pl_amount", "pl_purpose", "pl_freq", "pl_ontime", "pl_reason", "pl_absence")
    cols = {k: f.getlist(k) for k in keys}
    n = max((len(v) for v in cols.values()), default=0)
    return [{k[3:]: (cols[k][i] if i < len(cols[k]) else "") for k in keys} for i in range(min(n, 6))]


def load_extra(aid):
    x = q("SELECT * FROM app_extra WHERE application_id=?", (aid,), one=True)
    if not x:
        return None, [], []
    return x, json.loads(x["prev_loans"] or "[]"), json.loads(x["docs_deposited"] or "[]")


# ------------------------------ D. Pre-GRT group form ------------------------------ #
def load_pregrt(pid):
    p = q("SELECT p.*, u.name agent_name FROM pregrt p LEFT JOIN users u ON u.id=p.agent_id WHERE p.id=?", (pid,), one=True)
    if not p or (scope_agent() and p["agent_id"] != scope_agent()):
        abort(404)
    return p


def pregrt_editable(p):
    return can("kycform") and (p is None or p["status"] == "draft")


def parse_pregrt(f, submit):
    errs = []
    s = lambda k: _s(f, k)
    h = dict(branch=s("branch"), center_no=s("center_no")[:20], group_no=s("group_no")[:20], village=s("village")[:60],
             district=s("district")[:60], form_date=s("form_date"), pso_name=s("pso_name")[:60], pso_empid=s("pso_empid")[:20],
             bm_name=s("bm_name")[:60], bm_empid=s("bm_empid")[:20], leader_knows_duties=s("leader_knows_duties"),
             notes=s("notes")[:500])
    if h["branch"] not in BRANCHES:
        errs.append("Select a branch.")
    fd = parse_date(h["form_date"])
    if not fd or fd > date.today():
        errs.append("Date must be a valid date and cannot be in the future.")
    if scope_agent():
        h["agent_id"] = scope_agent()
    else:
        ag = q("SELECT id FROM users WHERE id=? AND role='field_agent'", (s("agent_id") or 0,), one=True)
        if not ag:
            errs.append("Assign a field officer to this group.")
        h["agent_id"] = ag["id"] if ag else None
    if submit:
        for key, label in (("center_no", "Centre no."), ("group_no", "Group no."), ("village", "Village"),
                           ("district", "District"), ("pso_name", "PSO name")):
            if not h[key]:
                errs.append(f"{label} is required to submit.")
        if h["leader_knows_duties"] != "yes":
            errs.append("The group leader must know her duties and responsibilities (select Yes) before submitting.")
    idx_all = re.findall(r"\d+", s("rows"))
    if len(idx_all) > PREGRT_MAX:
        errs.append(f"A group can have at most {PREGRT_MAX} members.")
    members = []
    for i in idx_all[:PREGRT_MAX]:
        g_ = lambda k: (f.get(f"m{i}_{k}") or "").strip()
        if not (g_("name") or g_("loan")):
            continue
        n = len(members) + 1
        lab = f"Member {n}"
        m = dict(sno=n, customer_id=int(g_("customer")) if g_("customer").isdigit() else None,
                 name=" ".join(g_("name").split())[:80], husband_name=" ".join(g_("husband").split())[:80],
                 voter_id=g_("voter").upper().replace(" ", ""), aadhaar4=g_("aadhaar4"), family_in_group=g_("family"),
                 house_type=g_("house"), livestock=g_("livestock")[:60], category=g_("category"), purpose=g_("purpose")[:60],
                 frequency=g_("freq"))
        m["age"] = to_num(g_("age"), f"{lab} age", errs, req=submit, lo=MIN_AGE, hi=MAX_AGE, integer=True)
        m["land_ha"] = to_num(g_("land"), f"{lab} land", errs, hi=1000) or 0.0
        m["annual_income"] = to_num(g_("income"), f"{lab} annual income", errs, hi=10 ** 8)
        m["family_size"] = to_num(g_("famsize"), f"{lab} family size", errs, lo=1, hi=30, integer=True)
        m["loan_amount"] = to_num(g_("loan"), f"{lab} loan amount", errs, req=submit, lo=1, hi=10 ** 7)
        m["instalments"] = to_num(g_("inst"), f"{lab} number of instalments", errs, req=submit, lo=1, hi=60, integer=True)
        for k, _ in PREGRT_CHECKS:
            m[k] = 1 if f.get(f"m{i}_{k}") else 0
        if m["voter_id"] and not re.fullmatch(r"[A-Z]{3}\d{7}", m["voter_id"]):
            errs.append(f"{lab}: Voter ID must be 3 letters followed by 7 digits.")
        if m["aadhaar4"] and not re.fullmatch(r"\d{4}", m["aadhaar4"]):
            errs.append(f"{lab}: enter only the last 4 digits of Aadhaar.")
        if m["family_in_group"] not in ("", "yes", "no"):
            m["family_in_group"] = ""
        if m["house_type"] not in ([""] + [k for k, _ in HOUSE_TYPES]):
            m["house_type"] = ""
        if m["category"] not in ([""] + CATEGORIES):
            m["category"] = ""
        if m["frequency"] not in ([""] + [k for k, _ in FREQS]):
            m["frequency"] = ""
        if submit:
            if not m["name"] or not m["husband_name"]:
                errs.append(f"{lab}: borrower name and husband / father name are required.")
            if not (m["voter_id"] or m["aadhaar4"]):
                errs.append(f"{lab} ({m['name']}): enter the Voter ID or the last 4 digits of Aadhaar.")
            if not m["purpose"]:
                errs.append(f"{lab} ({m['name']}): loan purpose is required.")
            if not m["frequency"]:
                errs.append(f"{lab} ({m['name']}): choose the repayment frequency.")
            missing = [lbl.split(" / ")[0] for k, lbl in PREGRT_CHECKS if not m[k]]
            if missing:
                errs.append(f"{lab} ({m['name']}) has not confirmed: {', '.join(missing)}. Train the member again or remove her from the group.")
        members.append(m)
    if submit:
        if not (PREGRT_MIN <= len(members) <= PREGRT_MAX):
            errs.append(f"A group needs {PREGRT_MIN} to {PREGRT_MAX} members (found {len(members)}).")
        ids = [m["customer_id"] for m in members if m["customer_id"]]
        if len(ids) != len(set(ids)):
            errs.append("The same registered customer is listed twice.")
        voters = [m["voter_id"] for m in members if m["voter_id"]]
        if len(voters) != len(set(voters)):
            errs.append("Two members have the same Voter ID.")
    return h, members, errs


MEMBER_COLS = ["customer_id", "name", "husband_name", "age", "voter_id", "aadhaar4", "family_in_group", "house_type", "land_ha",
               "livestock", "annual_income", "family_size", "category", "loan_amount", "purpose", "frequency", "instalments",
               "c_meeting", "c_joint", "c_fee", "c_rate", "c_insurance", "c_company", "c_group"]
HEAD_COLS = ["branch", "center_no", "group_no", "village", "district", "form_date", "pso_name", "pso_empid", "bm_name",
             "bm_empid", "leader_knows_duties", "notes", "agent_id"]


def pregrt_customer_pick():
    """Registered customers (with a KYC form) the officer can drop into a Pre-GRT row."""
    w, a = "", ()
    if scope_agent():
        w, a = "WHERE c.agent_id=?", (scope_agent(),)
    out = {}
    for r in q(f"SELECT c.id,c.name,c.dob,c.voter,c.aadhaar,k.guardian_name,k.house_type,k.land_ha,k.livestock,k.annual_income,"
               f"k.category,k.family FROM customers c JOIN kyc_forms k ON k.customer_id=c.id {w} ORDER BY c.name", a):
        out[r["id"]] = dict(name=r["name"], husband=r["guardian_name"], age=age_of(r["dob"]), voter=r["voter"] or "",
                            aadhaar4=(r["aadhaar"] or "")[-4:] if r["aadhaar"] else "", house=r["house_type"], land=r["land_ha"],
                            livestock=r["livestock"] or "", income=r["annual_income"], category=r["category"],
                            famsize=len(json.loads(r["family"] or "[]")) or "")
    return out


def render_pregrt(p, h, members, editable, errors=False):
    return render_template("pregrt_form.html", p=p, h=h, members=members, editable=editable, errors=errors,
                           agents=agents_list(), pick=pregrt_customer_pick(),
                           can_review=can("approve") and p is not None and p["status"] == "submitted",
                           member_count=len(members))


def _pregrt_form(p):
    editable = pregrt_editable(p)
    if request.method == "POST":
        if not editable:
            flash("This group form is locked. Ask the reviewer to return it for correction.", "danger")
            return redirect(url_for("pregrt_detail", pid=p["id"])) if p else redirect(url_for("pregrt_list"))
        submit = request.form.get("action") == "submit"
        h, members, errs = parse_pregrt(request.form, submit)
        if errs:
            for e in errs:
                flash(e, "danger")
            flash("Nothing was saved. Please fix the points above.", "warning")
            return render_pregrt(p, h, members, True, True)
        now = datetime.now().isoformat(timespec="seconds")
        status = "submitted" if submit else "draft"
        db = get_db()
        with db:
            if p is None:
                pid = db.execute(f"INSERT INTO pregrt({','.join(HEAD_COLS)},status,created_at) VALUES({','.join('?' * len(HEAD_COLS))},?,?)",
                                 [h[c] for c in HEAD_COLS] + [status, now]).lastrowid
            else:
                pid = p["id"]
                db.execute(f"UPDATE pregrt SET {','.join(c + '=?' for c in HEAD_COLS)}, status=?, review_remarks=? WHERE id=?",
                           [h[c] for c in HEAD_COLS] + [status, "" if submit else (p["review_remarks"] or ""), pid])
                db.execute("DELETE FROM pregrt_members WHERE pregrt_id=?", (pid,))
            for m in members:
                db.execute(f"INSERT INTO pregrt_members(pregrt_id,sno,{','.join(MEMBER_COLS)}) VALUES(?,?,{','.join('?' * len(MEMBER_COLS))})",
                           [pid, m["sno"]] + [m[c] for c in MEMBER_COLS])
        flash("Group form submitted for the branch manager's review." if submit else "Draft saved.", "success")
        return redirect(url_for("pregrt_detail", pid=pid))
    if p is None:
        h = dict(branch=g.user["branch"], form_date=date.today().isoformat(), agent_id=scope_agent() or "",
                 pso_name=g.user["name"] if g.user["role"] == "field_agent" else "", leader_knows_duties="")
        return render_pregrt(None, h, [], True)
    members = [dict(r) for r in q("SELECT * FROM pregrt_members WHERE pregrt_id=? ORDER BY sno", (p["id"],))]
    return render_pregrt(p, dict(p), members, editable)


@app.route("/pregrt")
@need("pregrt")
def pregrt_list():
    f = get_filters()
    status = request.args.get("status", "")
    w, a = ["p.form_date BETWEEN ? AND ?"], [f["dfrom"] or "0000-01-01", f["dto"] or "9999-12-31"]
    if f["branch"]:
        w.append("p.branch=?"); a.append(f["branch"])
    if f["agent"]:
        w.append("p.agent_id=?"); a.append(f["agent"])
    if scope_agent():
        w.append("p.agent_id=?"); a.append(scope_agent())
    if status:
        w.append("p.status=?"); a.append(status)
    rows = q("SELECT p.*, u.name agent_name, (SELECT COUNT(*) FROM pregrt_members m WHERE m.pregrt_id=p.id) members, "
             "(SELECT COALESCE(SUM(loan_amount),0) FROM pregrt_members m WHERE m.pregrt_id=p.id) total "
             f"FROM pregrt p LEFT JOIN users u ON u.id=p.agent_id WHERE {' AND '.join(w)} ORDER BY p.id DESC", a)
    return render_template("pregrt_list.html", rows=rows, f=f, status=status, agents=agents_list())


@app.route("/pregrt/new", methods=["GET", "POST"])
@need("kycform")
def pregrt_new():
    return _pregrt_form(None)


@app.route("/pregrt/<int:pid>", methods=["GET", "POST"])
@need("pregrt")
def pregrt_detail(pid):
    return _pregrt_form(load_pregrt(pid))


@app.route("/pregrt/<int:pid>/print")
@need("pregrt")
def pregrt_print(pid):
    p = load_pregrt(pid)
    members = q("SELECT * FROM pregrt_members WHERE pregrt_id=? ORDER BY sno", (pid,))
    return render_template("pregrt_print.html", p=p, members=members)


@app.route("/pregrt/<int:pid>/review", methods=["POST"])
@need("approve")
def pregrt_review(pid):
    p = load_pregrt(pid)
    act, remarks = request.form.get("action"), request.form.get("remarks", "").strip()[:300]
    if p["status"] != "submitted":
        flash("Only a submitted group form can be reviewed.", "danger")
    elif act == "verify":
        ex("UPDATE pregrt SET status='verified', verified_by=?, verified_on=?, review_remarks=? WHERE id=?",
           (g.user["name"], date.today().isoformat(), remarks, pid))
        flash("Pre-GRT verified. Members can now be taken forward for loan applications.", "success")
    elif act == "return":
        if not remarks:
            flash("Please write the reason for returning the form.", "danger")
        else:
            ex("UPDATE pregrt SET status='draft', review_remarks=? WHERE id=?", (remarks, pid))
            flash("Returned to the field officer for correction.", "info")
    else:
        abort(400)
    return redirect(url_for("pregrt_detail", pid=pid))



# --------------------------------------------------------------------------- #
# Full settlement, loan card, employee printout
# --------------------------------------------------------------------------- #
def channel_error(f):
    ch = f.get("channel")
    if ch == "upi" and not re.fullmatch(r"[\w.\-]{2,}@[a-zA-Z]{2,}", f.get("upi_id", "")):
        return "Enter a valid UPI ID like name@bank."
    if ch == "card" and not re.fullmatch(r"\d{16}", f.get("card_no", "").replace(" ", "")):
        return "Enter a 16 digit card number (demo: 4111 1111 1111 1111)."
    if ch == "netbanking" and not f.get("bank"):
        return "Choose a bank."
    if ch == "wallet" and not f.get("wallet"):
        return "Choose a wallet."
    if ch not in ("upi", "card", "netbanking", "wallet"):
        return "Choose a payment method."
    return None


@app.route("/loans/<int:lid>/settle", methods=["GET", "POST"])
@need("payments")
def settle(lid):
    loan = q("SELECT * FROM loans WHERE id=?", (lid,), one=True) or abort(404)
    own_loan_check(loan)
    quote = settlement_quote(lid)
    if loan["status"] != "active" or not quote:
        flash("This loan is not open for settlement.", "info")
        return redirect(url_for("loan_detail", lid=lid))
    if request.method == "POST":
        err = channel_error(request.form)
        if err:
            flash(err, "danger")
        else:   # MOCK gateway: always succeeds. Settlement = principal outstanding + next instalment's interest.
            now = datetime.now().isoformat(timespec="seconds")
            ref = "SET" + uuid.uuid4().hex[:10].upper()
            db = get_db()
            with db:
                db.execute("UPDATE schedule SET paid=1, paid_on=? WHERE loan_id=? AND paid=0", (now[:10], lid))
                db.execute("INSERT INTO payments(loan_id,schedule_id,amount,channel,ref,at) VALUES(?,?,?,?,?,?)",
                           (lid, quote["next_id"], quote["total"], request.form["channel"], ref, now))
                db.execute("UPDATE loans SET status='closed', closure_date=?, settled=1, settle_amount=? WHERE id=?", (now[:10], quote["total"], lid))
            flash(f"Loan settled and closed. Amount paid {quote['total']:,.2f}. Reference {ref}. The NOC is available 15 days after closure.", "success")
            return redirect(url_for("loan_detail", lid=lid))
    return render_template("settle.html", loan=loan, quote=quote)


@app.route("/loans/<int:lid>/card")
@need("loans", "payments")
def loan_card(lid):
    loan = q("SELECT l.*, c.name cname, c.phone cphone, c.address caddress, c.branch cbranch, p.name pname, p.fee_pct, u.name agent_name "
             "FROM loans l JOIN customers c ON c.id=l.customer_id JOIN products p ON p.id=l.product_id "
             "LEFT JOIN users u ON u.id=l.agent_id WHERE l.id=?", (lid,), one=True) or abort(404)
    own_loan_check(loan)
    refs = {r["schedule_id"]: r["ref"] for r in q("SELECT schedule_id, ref FROM payments WHERE loan_id=?", (lid,))}
    kf = q("SELECT photo, center_no, group_no FROM kyc_forms WHERE customer_id=?", (loan["customer_id"],), one=True)
    return render_template("loan_card.html", loan=loan, sched=q("SELECT * FROM schedule WHERE loan_id=? ORDER BY no", (lid,)), refs=refs, kf=kf,
                           fs=fee_split(loan["principal"], loan["fee_pct"]), show_photo=g.user["role"] != "customer")


@app.route("/employees/<int:eid>/print")
@need("employees")
def employee_print(eid):
    e = q("SELECT e.*, m.name manager_name, u.username, u.role FROM employees e LEFT JOIN employees m ON m.id=e.manager_id "
          "LEFT JOIN users u ON u.id=e.user_id WHERE e.id=?", (eid,), one=True) or abort(404)
    return render_template("employee_print.html", e=e, docs=json.loads(e["docs"] or "[]"), all_docs=ONBOARD_DOCS)


# ------------------------------ Group loan application ------------------------------ #
@app.route("/pregrt/<int:pid>/apply", methods=["GET", "POST"])
@need("apply")
def group_apply(pid):
    pg = load_pregrt(pid)
    if pg["status"] != "verified":
        flash("Only a verified Pre-GRT group can apply for loans. Ask the branch manager to verify the group form first.", "warning")
        return redirect(url_for("pregrt_detail", pid=pid))
    prods = q("SELECT * FROM products WHERE active=1 AND group_only=1" + ("" if g.user["role"] == "admin" else " AND admin_only=0"))
    members = []
    for m in q("SELECT * FROM pregrt_members WHERE pregrt_id=? ORDER BY sno", (pid,)):
        d = dict(m, problem="", income_default="", co_income=0.0, cust=None)
        if not m["customer_id"]:
            d["problem"] = "Not linked to a registered customer. Fill her KYC form, then pick her from the list in the group form."
        else:
            c = q("SELECT c.*, k.annual_income, k.co_income FROM customers c LEFT JOIN kyc_forms k ON k.customer_id=c.id WHERE c.id=?",
                  (m["customer_id"],), one=True)
            if not c or (scope_agent() and c["agent_id"] != scope_agent()):
                d["problem"] = "This customer is not available to you."
            elif c["annual_income"] is None:
                d["problem"] = "She has no KYC form yet."
            else:
                d.update(cust=c, income_default=round((c["annual_income"] or 0) / 12), co_income=c["co_income"] or 0.0)
                ex_app = q("SELECT id FROM applications WHERE customer_id=? AND group_id=? AND status!='rejected'", (c["id"], pid), one=True)
                if ex_app:
                    d["problem"] = f"Already applied (application #{ex_app['id']})."
        members.append(d)
    if request.method == "POST":
        f, errs = request.form, []
        prod = next((x for x in prods if str(x["id"]) == f.get("product_id", "")), None)
        if not prod:
            errs.append("Select a group loan product.")
        tenure = to_num(f.get("tenure", ""), "Tenure", errs, req=True, lo=1, hi=120, integer=True) or 0
        if prod and tenure and not (prod["min_tenure"] <= tenure <= prod["max_tenure"]):
            errs.append(f"Tenure must be {prod['min_tenure']}-{prod['max_tenure']} months.")
        docs_dep = [x for x in f.getlist("docs_dep") if x in dict(DOC_CHOICES)]
        if len(set(docs_dep)) < 2:
            errs.append("Tick at least two documents deposited (Aadhaar, Voter ID, Ration card or other).")
        ins, ins_for = f.get("insurance_wanted", ""), f.get("insurance_for", "")
        if ins not in ("yes", "no"):
            errs.append("Life insurance: choose Yes or No.")
        elif ins == "yes":
            if ins_for not in ("husband", "self", "both"):
                errs.append("Life insurance: choose whose insurance is wanted.")
            if not f.get("insurance_ack"):
                errs.append("Tick the life-insurance acknowledgement.")
        else:
            ins_for = ""
        if not f.get("app_declaration"):
            errs.append("Tick the group's declaration.")
        chosen = []
        for m in members:
            if m["problem"] or not f.get(f"use_{m['id']}"):
                continue
            lab = m["name"]
            amt = to_num(f.get(f"amt_{m['id']}", ""), f"{lab}: loan amount", errs, req=True, lo=1, hi=10 ** 7)
            inc = to_num(f.get(f"income_{m['id']}", ""), f"{lab}: monthly income", errs, req=True, lo=1, hi=10 ** 7)
            exp_ = to_num(f.get(f"exp_{m['id']}", "0") or "0", f"{lab}: monthly expenses", errs, hi=10 ** 7) or 0.0
            if prod and amt and not (prod["min_amt"] <= amt <= prod["max_amt"]):
                errs.append(f"{lab}: amount must be between {prod['min_amt']:.0f} and {prod['max_amt']:.0f}.")
            if inc:
                house = inc + m["co_income"]
                if house > CFG["income_limit"]:
                    errs.append(f"{lab}: household monthly income {house:,.0f} is above the eligibility limit of {CFG['income_limit']:,.0f}.")
                if inc - exp_ + m["co_income"] <= 0:
                    errs.append(f"{lab}: expenses are higher than income.")
                if prod and amt and tenure:
                    e_ = emi_calc(amt, prod["rate"], tenure, prod["method"])
                    if e_ > CFG["emi_pct"] / 100 * house:
                        errs.append(f"{lab}: EMI {e_:.0f} exceeds {CFG['emi_pct']:.0f}% of household income.")
            chosen.append((m, amt, inc, exp_, " ".join(f.get(f"purpose_{m['id']}", "").split())[:60]))
        if not (CFG["group_min"] <= len(chosen) <= CFG["group_max"]):
            errs.append(f"A group loan needs {CFG['group_min']} to {CFG['group_max']} members applying together (selected {len(chosen)}).")
        if errs:
            for e_ in errs:
                flash(e_, "danger")
            flash("Nothing was saved. Please fix the points above.", "warning")
            return render_template("group_apply.html", pg=pg, prods=prods, members=members, form=f)
        now = datetime.now().isoformat(timespec="seconds")
        db = get_db()
        ids = []
        with db:
            for m, amt, inc, exp_, purpose in chosen:
                c = m["cust"]
                cycle = db.execute("SELECT COUNT(*) FROM loans WHERE customer_id=?", (c["id"],)).fetchone()[0] + 1
                kf = db.execute("SELECT co_name,co_phone,co_relation,co_income FROM kyc_forms WHERE customer_id=?", (c["id"],)).fetchone()
                aid = db.execute(
                    "INSERT INTO applications(customer_id,product_id,amount,tenure,rate,purpose,income,occupation,employer,co_name,co_phone,"
                    "co_relation,co_income,status,agent_id,branch,created,docs,group_id) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                    (c["id"], prod["id"], amt, tenure, prod["rate"], purpose or (m["purpose"] or ""), inc, "", "", kf["co_name"] or "",
                     kf["co_phone"] or "", kf["co_relation"] or "", kf["co_income"] or 0.0, "submitted", c["agent_id"] or g.user["id"],
                     c["branch"], now, "{}", pid)).lastrowid
                db.execute("INSERT INTO app_extra(application_id,prev_loans,insurance_wanted,insurance_for,docs_deposited,docs_other,"
                           "inc_agri,inc_business,inc_job,inc_other,exp_basic,exp_education,exp_festival,exp_health,exp_emi,exp_other,"
                           "group_rec,center_rec,loan_cycle,requested_amt,income_total,expense_total,net_saving,declaration) "
                           "VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                           (aid, "[]", ins, ins_for, json.dumps(sorted(set(docs_dep))), "", 0, 0, 0, inc, 0, 0, 0, 0, 0, exp_,
                            m["loan_amount"], None, cycle, amt, inc, exp_, round(inc - exp_, 2), 1))
                db.execute("INSERT INTO approvals(application_id,stage,by_user,by_role,amount,remarks,at) VALUES(?,?,?,?,?,?,?)",
                           (aid, "Submitted", g.user["name"], g.user["role"], amt, f"Group application, Pre-GRT #{pid}", now))
                ids.append(aid)
        flash(f"{len(ids)} loan applications were submitted together for group {pg['center_no'] or '-'} / {pg['group_no'] or '-'}: "
              + ", ".join(f"#{i}" for i in ids) + ".", "success")
        return redirect(url_for("applications"))
    return render_template("group_apply.html", pg=pg, prods=prods, members=members,
                           form={"insurance_wanted": "no", "tenure": "", "use_all": "1"})


# ------------------------------ Dashboard click-through ------------------------------ #
@app.route("/dashboard/details")
@need("dashboard")
def dashboard_details():
    f = get_filters()
    kind, val = request.args.get("kind", ""), request.args.get("value", "")
    w, a = loan_where(f, "l")
    wl = (" AND " + " AND ".join(w)) if w else ""
    dfrom, dto = f["dfrom"] or "0000-01-01", f["dto"] or "9999-12-31"
    today = date.today().isoformat()
    loan_sql = ("SELECT l.id, l.principal, l.status, l.branch, l.start_date, c.name cname, u.name agent_name, "
                "(SELECT COALESCE(SUM(s.principal),0) FROM schedule s WHERE s.loan_id=l.id AND s.paid=0) outstanding, "
                "(SELECT MIN(s.due_date) FROM schedule s WHERE s.loan_id=l.id AND s.paid=0) next_due, "
                "(SELECT COUNT(*) FROM schedule s WHERE s.loan_id=l.id AND s.paid=0 AND s.due_date<?) overdue "
                "FROM loans l JOIN customers c ON c.id=l.customer_id LEFT JOIN users u ON u.id=l.agent_id WHERE 1=1")
    title, mode, rows = "Details", "loans", []
    if kind == "branch":
        title = f"Outstanding principal: {val}"
        rows = q(loan_sql + " AND l.branch=?" + wl + " AND l.status='active' ORDER BY outstanding DESC", [today, val] + a)
    elif kind == "status":
        mode, title = "apps", f"Applications: {val.replace('_', ' ')}"
        aw, aa = [], []
        if f["branch"]:
            aw.append("ap.branch=?"); aa.append(f["branch"])
        if f["agent"]:
            aw.append("ap.agent_id=?"); aa.append(f["agent"])
        if scope_agent():
            aw.append("ap.agent_id=?"); aa.append(scope_agent())
        rows = q("SELECT ap.id, ap.amount, ap.tenure, ap.status, ap.created, ap.branch, c.name cname, p.name pname, u.name agent_name "
                 "FROM applications ap JOIN customers c ON c.id=ap.customer_id JOIN products p ON p.id=ap.product_id "
                 "LEFT JOIN users u ON u.id=ap.agent_id WHERE ap.status=? AND substr(ap.created,1,10) BETWEEN ? AND ?"
                 + "".join(" AND " + x for x in aw) + " ORDER BY ap.id DESC", [val, dfrom, dto] + aa)
    elif kind == "agent":
        mode, title = "pays", f"Collections by {val}"
        rows = q("SELECT p.at, p.amount, p.channel, p.ref, l.id loan_id, c.name cname FROM payments p JOIN loans l ON l.id=p.loan_id "
                 "JOIN customers c ON c.id=l.customer_id JOIN users u ON u.id=l.agent_id WHERE u.name=? AND substr(p.at,1,10) BETWEEN ? AND ?"
                 + wl + " ORDER BY p.id DESC", [val, dfrom, dto] + a)
    elif kind == "collected":
        mode, title = "pays", "Collections"
        rows = q("SELECT p.at, p.amount, p.channel, p.ref, l.id loan_id, c.name cname FROM payments p JOIN loans l ON l.id=p.loan_id "
                 "JOIN customers c ON c.id=l.customer_id WHERE substr(p.at,1,10) BETWEEN ? AND ?" + wl + " ORDER BY p.id DESC", [dfrom, dto] + a)
    elif kind == "active":
        title = "Active loans"
        rows = q(loan_sql + " AND l.status='active' AND l.start_date BETWEEN ? AND ?" + wl + " ORDER BY l.id DESC", [today, dfrom, dto] + a)
    elif kind == "disbursed":
        title = "Disbursed loans"
        rows = q(loan_sql + " AND l.start_date BETWEEN ? AND ?" + wl + " ORDER BY l.id DESC", [today, dfrom, dto] + a)
    elif kind == "outstanding":
        title = "Loans with outstanding principal"
        rows = [r for r in q(loan_sql + wl + " ORDER BY l.id DESC", [today] + a) if r["outstanding"] > 0]
    elif kind == "overdue":
        title = "Loans with overdue EMIs"
        rows = [r for r in q(loan_sql + wl + " ORDER BY l.id DESC", [today] + a) if r["overdue"] > 0]
    else:
        abort(404)
    return render_template("dashboard_detail.html", title=title, mode=mode, rows=rows, f=f, today=today)


# --------------------------------------------------------------------------- #
# Admin: branches (with GPS location for attendance), settings and public holidays
# --------------------------------------------------------------------------- #
def parse_location(txt):
    """Accepts a Google Maps link (...?q=lat,lng or ...@lat,lng) or plain 'lat, lng'. Returns (lat, lng) or (None, None) if empty."""
    t = (txt or "").strip()
    if not t:
        return None, None
    num = r"(-?\d+(?:\.\d+)?)"
    m = (re.search(r"[?&]q=" + num + r",\s*" + num, t) or re.search(r"@" + num + r"," + num, t)
         or re.fullmatch(r"\s*" + num + r"\s*[, ]\s*" + num + r"\s*", t))
    if not m:
        raise ValueError("bad location")
    la, lo = float(m.group(1)), float(m.group(2))
    if not (-90 <= la <= 90 and -180 <= lo <= 180):
        raise ValueError("range")
    return la, lo


BRANCH_TABLES = ("users", "employees", "customers", "applications", "loans", "pregrt", "att_requests")


@app.route("/branches/<int:bid>/details")
@need("branches")
def branch_detail(bid):
    b = q("SELECT * FROM branches WHERE id=?", (bid,), one=True) or abort(404)
    n, today = b["name"], date.today().isoformat()
    one = lambda sql, *a: q(sql, a, one=True)
    st = dict(
        staff=one("SELECT COUNT(*) c FROM employees WHERE branch=? AND status!='exited'", n)["c"],
        customers=one("SELECT COUNT(*) c FROM customers WHERE branch=? AND stage='customer'", n)["c"],
        leads=one("SELECT COUNT(*) c FROM customers WHERE branch=? AND stage!='customer'", n)["c"],
        active=one("SELECT COUNT(*) c FROM loans WHERE branch=? AND status='active'", n)["c"],
        closed=one("SELECT COUNT(*) c FROM loans WHERE branch=? AND status='closed'", n)["c"],
        disbursed=one("SELECT COALESCE(SUM(principal),0) v FROM loans WHERE branch=?", n)["v"],
        outstanding=one("SELECT COALESCE(SUM(s.principal),0) v FROM schedule s JOIN loans l ON l.id=s.loan_id WHERE s.paid=0 AND l.branch=?", n)["v"],
        collected=one("SELECT COALESCE(SUM(p.amount),0) v FROM payments p JOIN loans l ON l.id=p.loan_id WHERE l.branch=?", n)["v"],
        overdue=one("SELECT COUNT(*) c FROM schedule s JOIN loans l ON l.id=s.loan_id WHERE s.paid=0 AND s.due_date<? AND l.branch=?", today, n)["c"],
        pending_apps=one("SELECT COUNT(*) c FROM applications WHERE branch=? AND status IN ('submitted','under_review','approved','sanctioned')", n)["c"])
    staff = q("SELECT e.name, e.designation, e.phone, e.status FROM employees e WHERE e.branch=? AND e.status!='exited' ORDER BY e.name", (n,))
    loans = q("SELECT l.id, l.principal, l.status, c.name cname, "
              "(SELECT COALESCE(SUM(s.principal),0) FROM schedule s WHERE s.loan_id=l.id AND s.paid=0) outstanding "
              "FROM loans l JOIN customers c ON c.id=l.customer_id WHERE l.branch=? ORDER BY l.id DESC LIMIT 15", (n,))
    return render_template("branch_detail.html", b=b, st=st, staff=staff, loans=loans)


@app.route("/branches", methods=["GET", "POST"])
@need("branches")
def branches():
    if request.method == "POST":
        f, errs = request.form, []
        name = " ".join(f.get("name", "").split())[:60]
        if len(name) < 3:
            errs.append("Branch name is required (at least 3 letters).")
        try:
            lat, lng = parse_location(f.get("location", ""))
        except ValueError:
            lat = lng = None
            errs.append("Location: paste a Google Maps link or type 'latitude, longitude' (for example 23.27993, 77.45220).")
        if lat is None and not errs and f.get("location", "").strip() == "":
            errs.append("Location is required: attendance is checked against it.")
        rad = to_num(f.get("radius_m", "2000"), "Allowed distance (metres)", errs, lo=50, hi=20000, integer=True) or 2000
        bid = f.get("id", "")
        if q("SELECT 1 FROM branches WHERE lower(name)=lower(?) AND id!=?", (name, bid or 0), one=True):
            errs.append("A branch with this name already exists.")
        active = 1 if (f.get("active") or not bid) else 0
        if bid and not active and q("SELECT COUNT(*) c FROM branches WHERE active=1 AND id!=?", (bid,), one=True)["c"] == 0:
            errs.append("At least one branch must stay active.")
        if errs:
            for e in errs:
                flash(e, "danger")
            return redirect(url_for("branches"))
        vals = (name, f.get("code", "").strip()[:12], f.get("address", "").strip()[:200], f.get("phone", "").strip()[:15],
                f.get("head_name", "").strip()[:60], lat, lng, rad)
        db = get_db()
        with db:
            if bid:
                old = q("SELECT name FROM branches WHERE id=?", (bid,), one=True)
                db.execute("UPDATE branches SET name=?,code=?,address=?,phone=?,head_name=?,lat=?,lng=?,radius_m=?,active=? WHERE id=?",
                           vals + (active, bid))
                if old and old["name"] != name:   # branch names are stored on records, so keep them in step
                    for tbl in BRANCH_TABLES:
                        db.execute(f"UPDATE {tbl} SET branch=? WHERE branch=?", (name, old["name"]))
                flash("Branch updated.", "success")
            else:
                db.execute("INSERT INTO branches(name,code,address,phone,head_name,lat,lng,radius_m) VALUES(?,?,?,?,?,?,?,?)", vals)
                flash("Branch added. It now appears in every branch list.", "success")
        return redirect(url_for("branches"))
    return render_template("branches.html", rows=q("SELECT b.*, (SELECT COUNT(*) FROM users u WHERE u.branch=b.name) staff, "
                           "(SELECT COUNT(*) FROM customers c WHERE c.branch=b.name) customers FROM branches b ORDER BY b.id"))


@app.route("/settings", methods=["GET", "POST"])
@need("settings")
def settings():
    if request.method == "POST":
        act, f, errs = request.form.get("action"), request.form, []
        if act == "save":
            new = {}
            for key, label, default, kind in SETTING_DEFS:
                new[key] = to_num(f.get(key, ""), label.split(" (")[0].split(" - ")[0], errs, req=True, lo=0, hi=10 ** 7, integer=(kind == "int"))
            if not errs:
                if new["min_age"] < 18 or new["min_age"] >= new["max_age"]:
                    errs.append("Age limits: the minimum must be 18 or more and below the maximum.")
                if new["group_min"] < 1 or new["group_min"] > new["group_max"]:
                    errs.append("Group size: the minimum must be at least 1 and not above the maximum.")
                if not (0 < new["emi_pct"] <= 100) or not (0 <= new["gst_rate"] <= 40):
                    errs.append("EMI % must be 1-100 and GST 0-40.")
            if errs:
                for e in errs:
                    flash(e, "danger")
            else:
                db = get_db()
                with db:
                    for key, val in new.items():
                        db.execute("INSERT OR REPLACE INTO settings(key,value) VALUES(?,?)", (key, str(val)))
                flash("Settings saved.", "success")
        elif act == "add_holiday":
            d, nm = parse_date(f.get("day", "")), " ".join(f.get("name", "").split())[:60]
            if not d or not nm:
                flash("Enter the holiday date and name.", "danger")
            else:
                ex("INSERT OR REPLACE INTO holidays(day,name) VALUES(?,?)", (d.isoformat(), nm))
                flash("Holiday added. New loan schedules will skip this date.", "success")
        elif act == "del_holiday":
            ex("DELETE FROM holidays WHERE day=?", (f.get("day", ""),))
            flash("Holiday removed.", "info")
        return redirect(url_for("settings"))
    return render_template("settings.html", defs=SETTING_DEFS, cfg=CFG, holidays=q("SELECT * FROM holidays ORDER BY day"))


# --------------------------------------------------------------------------- #
# Upgrades for databases created by older versions (idempotent)
# --------------------------------------------------------------------------- #
def add_cols(db, table, cols):
    have = {r[1] for r in db.execute(f"PRAGMA table_info({table})")}
    for col, typ in cols.items():
        if col not in have:
            db.execute(f"ALTER TABLE {table} ADD COLUMN {col} {typ}")


def migrate(db):
    add_cols(db, "users", {"must_change": "INTEGER DEFAULT 0"})
    add_cols(db, "kyc_forms", {"co_name": "TEXT", "co_phone": "TEXT", "co_relation": "TEXT", "co_income": "REAL", "neighbours": "TEXT"})
    add_cols(db, "comm_logs", {"call_dir": "TEXT", "duration_min": "INTEGER", "outcome": "TEXT", "follow_up": "TEXT"})
    add_cols(db, "products", {"admin_only": "INTEGER DEFAULT 0", "group_only": "INTEGER DEFAULT 0"})
    add_cols(db, "applications", {"group_id": "INTEGER"})
    add_cols(db, "loans", {"settled": "INTEGER DEFAULT 0", "settle_amount": "REAL"})
    add_cols(db, "attendance", {"regularised": "INTEGER DEFAULT 0", "out_lat": "REAL", "out_lng": "REAL", "in_dist": "REAL",
                                "out_dist": "REAL", "note": "TEXT"})
    if not db.execute("SELECT COUNT(*) FROM branches").fetchone()[0]:
        for nm, code, addr, la, lo in DEFAULT_BRANCHES:
            db.execute("INSERT INTO branches(name,code,address,lat,lng) VALUES(?,?,?,?,?)", (nm, code, addr, la, lo))
    # meeting of 25 Oct 2026: 1.5% fee, emergency loan at 12% (Admin only), group loan product
    if not db.execute("SELECT 1 FROM settings WHERE key='mig_b1'").fetchone() and db.execute("SELECT COUNT(*) FROM products").fetchone()[0]:
        db.execute("UPDATE products SET fee_pct=1.5")
        db.execute("UPDATE products SET rate=12, admin_only=1 WHERE name='Emergency Loan'")
        if not db.execute("SELECT 1 FROM products WHERE name='Group Loan (JLG)'").fetchone():
            db.execute("INSERT INTO products(name,rate,min_amt,max_amt,min_tenure,max_tenure,method,fee_pct,group_only) "
                       "VALUES('Group Loan (JLG)',20,5000,30000,6,24,'reducing',1.5,1)")
        db.execute("INSERT INTO settings(key,value) VALUES('mig_b1','1')")
    db.commit()


# --------------------------------------------------------------------------- #
# Seed data
# --------------------------------------------------------------------------- #
def seed():
    db = sqlite3.connect(DB_PATH)
    db.row_factory = sqlite3.Row
    db.executescript(SCHEMA)
    migrate(db)
    if db.execute("SELECT COUNT(*) FROM users").fetchone()[0]:
        db.close()
        return
    db.close()
    with app.app_context():
        now = datetime.now().isoformat(timespec="seconds")
        today = date.today()
        staff = [("admin", "admin123", "Aarav Admin", "admin", BRANCHES[0], "9800000001", "Director", 90000),
                 ("manager1", "manager123", "Meera Manager", "manager", BRANCHES[0], "9800000002", "Regional Manager", 60000),
                 ("uw1", "uw123", "Uday Underwriter", "underwriter", BRANCHES[0], "9800000003", "Credit Underwriter", 45000),
                 ("agent1", "agent123", "Ravi Field Officer", "field_agent", BRANCHES[0], "9800000004", "Field Officer", 25000),
                 ("agent2", "agent123", "Sneha Field Officer", "field_agent", BRANCHES[1], "9800000005", "Field Officer", 25000),
                 ("agent3", "agent123", "Imran Field Officer", "field_agent", BRANCHES[2], "9800000006", "Field Officer", 25000)]
        uid = {}
        eid = {}
        for un, pw, nm, role, br, ph, desig, sal in staff:
            uid[un] = ex("INSERT INTO users(username,pw,name,role,branch,phone) VALUES(?,?,?,?,?,?)", (un, generate_password_hash(pw), nm, role, br, ph))
            mgr = None if un == "admin" else (eid["admin"] if un == "manager1" else eid["manager1"])
            eid[un] = ex("INSERT INTO employees(user_id,name,designation,branch,manager_id,phone,email,joined,status,bg_check,docs,salary) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)",
                         (uid[un], nm, desig, br, mgr, ph, f"{un}@sarvocch.demo", "2025-04-01", "active", "cleared", json.dumps(ONBOARD_DOCS), sal))
        ex("INSERT INTO employees(name,designation,branch,manager_id,phone,email,joined,status,bg_check,docs,salary) VALUES(?,?,?,?,?,?,?,?,?,?,?)",
           ("Pooja New-Joiner", "Field Officer", BRANCHES[1], eid["manager1"], "9800000099", "pooja@sarvocch.demo", today.isoformat(),
            "onboarding", "in_progress", json.dumps(["Aadhaar", "PAN"]), 25000))
        for nm, price in [("Micro Business Loan", (18, 10000, 100000, 6, 24, "reducing", 2)),
                          ("Income Generation Loan", (22, 5000, 50000, 6, 18, "flat", 1.5)),
                          ("Emergency Loan", (24, 2000, 25000, 3, 12, "reducing", 1))]:
            ex("INSERT INTO products(name,rate,min_amt,max_amt,min_tenure,max_tenure,method,fee_pct) VALUES(?,?,?,?,?,?,?,?)", (nm,) + price)
        people = [("Sunita Verma", "9811111111", "1988-04-12", "12 Vijay Nagar, Indore", 0, "agent1", "customer"),
                  ("Rajesh Patel", "9822222222", "1985-09-03", "45 Palasia, Indore", 1, "agent2", "customer"),
                  ("Kavita Sharma", "9833333333", "1990-01-25", "7 Bhawarkuan, Indore", 0, "agent1", "customer"),
                  ("Mohan Lal", "9844444444", "1979-11-30", "88 Rajwada, Indore", 0, "agent1", "customer"),
                  ("Farida Khan", "9855555555", "1992-06-18", "21 MP Nagar, Bhopal", 2, "agent3", "prospect"),
                  ("Deepak Joshi", "9866666666", "1987-02-09", "3 Rau, Indore", 1, "agent2", "lead"),
                  ("Anita Yadav", "9877777777", "1995-12-01", "19 Sarafa, Indore", 0, "agent1", "lead"),
                  ("Vikram Singh", "9888888888", "1983-07-21", "54 Vijay Nagar, Indore", 0, "agent1", "prospect")]
        cid = []
        for i, (nm, ph, dob, addr, bi, ag, stage) in enumerate(people):
            kyc = stage == "customer"
            cid.append(ex("INSERT INTO customers(name,phone,dob,address,branch,agent_id,stage,aadhaar,pan,voter,kyc_status,wa_verified,created) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)",
                          (nm, ph, dob, addr, BRANCHES[bi], uid[ag], stage,
                           ("XXXXXXXX" + make_aadhaar(f"{2345 + i}6789012")[-4:]) if kyc else None,
                           f"ABCPE{1230 + i}F" if kyc else None, None, "verified" if kyc else "pending", 1 if i < 2 else 0,
                           (today - timedelta(days=200 - i * 10)).isoformat() + "T10:00:00")))
        ex("INSERT INTO users(username,pw,name,role,branch,phone,customer_id) VALUES(?,?,?,?,?,?,?)",
           ("cust1", generate_password_hash("cust123"), "Sunita Verma", "customer", BRANCHES[0], "9811111111", cid[0]))

        # KYC forms for the demo customers (all fictional). Deepak Joshi and Anita Yadav are left without a form
        # on purpose, so the "KYC form pending" step can be shown in the demo.
        def seed_kyc(i, **kw):
            nm, dob = people[i][0], people[i][2]
            fam_default = [dict(name=nm, age=age_of(dob), edu="Secondary (10th)", rel="Self", occ="Small business")]
            base = dict(form_date=(today - timedelta(days=150)).isoformat(), center_no="", group_no="", guardian_type="father",
                        guardian_name="", education="Secondary (10th)", religion="Hindu", category="OBC", house_no="",
                        post_office="", village="", district="Indore", state="Madhya Pradesh", pincode="452010",
                        family=json.dumps(fam_default), house_type="pucca", land_ha=0.0, livestock="", bank_name="State Bank of India",
                        bank_acct="3012345678%d" % i, passbook_name=nm, poverty_line="APL", dist_center_m=300.0, dist_branch_km=6.0,
                        relative_in_center="no", relative_name="", annual_income=180000.0, other_loans=0, current_debt=0.0,
                        repay_freq="monthly", photo="", h_name="", h_father="", h_dob="", h_address="", h_photo="",
                        consent_given=0, consent_date="", declaration=1, bureau_consent=1, address_verified=1,
                        verified_by="Ravi Field Officer", verified_on=today.isoformat(), verify_remarks="", signed_copy="",
                        co_name="", co_phone="", co_relation="", co_income=0.0, neighbours="[]")
            base.update(kw)
            if base["guardian_type"] == "husband":
                base.update(h_name=base["guardian_name"], consent_given=1, consent_date=base["form_date"],
                            h_address=people[i][3], h_dob=kw.get("h_dob", "1984-01-01"))
            ex(f"INSERT INTO kyc_forms(customer_id,created_by,created_at,updated_at,{','.join(KYC_COLS)}) "
               f"VALUES(?,?,?,?,{','.join('?' * len(KYC_COLS))})",
               [cid[i], uid["agent1"], now, now] + [base[c] for c in KYC_COLS])
        seed_kyc(0, guardian_type="husband", guardian_name="Ramesh Verma", h_father="Suresh Verma", h_dob="1984-03-02",
                 village="Vijay Nagar", house_no="12", center_no="C-101", group_no="G-A", annual_income=216000.0,
                 family=json.dumps([dict(name="Sunita Verma", age=38, edu="Secondary (10th)", rel="Self", occ="Tailoring"),
                                    dict(name="Ramesh Verma", age=42, edu="Secondary (10th)", rel="Husband", occ="Shopkeeper"),
                                    dict(name="Aarav Verma", age=14, edu="Class 8", rel="Son", occ="Student")]))
        seed_kyc(1, guardian_name="Mohanlal Patel", village="Palasia", house_no="45", annual_income=240000.0,
                 category="General", center_no="C-202", group_no="G-B")
        seed_kyc(2, guardian_type="husband", guardian_name="Anil Sharma", h_father="Gopal Sharma", h_dob="1986-08-19",
                 village="Bhawarkuan", house_no="7", center_no="C-101", group_no="G-A", category="General", livestock="1 cow")
        seed_kyc(3, guardian_name="Ramlal", village="Rajwada", house_no="88", poverty_line="BPL", annual_income=96000.0)
        seed_kyc(4, guardian_type="husband", guardian_name="Salim Khan", h_father="Rashid Khan", h_dob="1988-12-05",
                 religion="Muslim", category="Minority", village="MP Nagar", house_no="21", district="Bhopal", pincode="462011")
        seed_kyc(7, guardian_name="Bharat Singh", village="Vijay Nagar", house_no="54", category="General", center_no="C-101",
                 group_no="G-A", annual_income=264000.0)
        ex("INSERT INTO comm_logs(customer_id,channel,note,by_name,at) VALUES(?,?,?,?,?)", (cid[0], "call", "Reminded about EMI due date", "Ravi Field Officer", now))
        ex("INSERT INTO comm_logs(customer_id,channel,note,by_name,at) VALUES(?,?,?,?,?)", (cid[5], "visit", "Interested in a business loan, will submit documents next week", "Sneha Field Officer", now))

        def mk_app(ci, pid, amt, ten, status, ag, br, created):
            rate = {1: 18, 2: 22, 3: 24}[pid]
            aid_ = ex("INSERT INTO applications(customer_id,product_id,amount,tenure,rate,purpose,income,occupation,employer,co_name,co_phone,co_relation,co_income,status,agent_id,branch,created,docs) "
                      "VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                      (cid[ci], pid, amt, ten, rate, "Business expansion", 30000, "Shop owner", "Self", "Family member", "9899999999", "Spouse", 12000,
                       status, uid[ag], BRANCHES[br], created, "{}"))
            ex("INSERT INTO app_extra(application_id,prev_loans,insurance_wanted,insurance_for,docs_deposited,docs_other,inc_agri,inc_business,"
               "inc_job,inc_other,exp_basic,exp_education,exp_festival,exp_health,exp_emi,exp_other,group_rec,center_rec,loan_cycle,requested_amt,"
               "income_total,expense_total,net_saving,declaration) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
               (aid_, "[]", "yes", "husband", json.dumps(["aadhaar", "voter"]), "", 0, 24000, 0, 6000, 9000, 2000, 1500, 1000, 0, 1500,
                amt, amt, 1, amt, 30000, 15000, 15000, 1))
            steps = {"submitted": [], "under_review": ["review"], "approved": ["review", "approve"],
                     "sanctioned": ["review", "approve", "sanction"], "disbursed": ["review", "approve", "sanction", "disburse"]}[status]
            ex("INSERT INTO approvals(application_id,stage,by_user,by_role,amount,remarks,at) VALUES(?,?,?,?,?,?,?)",
               (aid_, "Submitted", q("SELECT name FROM users WHERE id=?", (uid[ag],), one=True)["name"], "field_agent", amt, "", created))
            for st in steps:
                who = ("Uday Underwriter", "underwriter") if st in ("review", "approve") else ("Meera Manager", "manager")
                ex("INSERT INTO approvals(application_id,stage,by_user,by_role,amount,remarks,at) VALUES(?,?,?,?,?,?,?)",
                   (aid_, STAGE_LABEL[st], who[0], who[1], amt, "", created))
            return aid_
        # Loan A: active, 2 paid, 1 overdue
        a1 = mk_app(0, 1, 60000, 12, "disbursed", "agent1", 0, (today - timedelta(days=120)).isoformat() + "T10:00:00")
        l1 = create_loan(a1, today - timedelta(days=110))
        for s in q("SELECT id,due_date FROM schedule WHERE loan_id=? ORDER BY no LIMIT 2", (l1,)):
            record_payment(l1, s["id"], "upi", at=s["due_date"] + "T11:00:00")
        # Loan B: closed 20 days ago -> NOC eligible
        a2 = mk_app(1, 3, 12000, 6, "disbursed", "agent2", 1, (today - timedelta(days=230)).isoformat() + "T10:00:00")
        l2 = create_loan(a2, today - timedelta(days=200))
        for s in q("SELECT id,due_date FROM schedule WHERE loan_id=? ORDER BY no", (l2,)):
            record_payment(l2, s["id"], "card", at=s["due_date"] + "T11:00:00")
        ex("UPDATE loans SET closure_date=? WHERE id=?", ((today - timedelta(days=20)).isoformat(), l2))
        # Loan C: active with AutoPay
        a3 = mk_app(2, 2, 20000, 10, "disbursed", "agent1", 0, (today - timedelta(days=70)).isoformat() + "T10:00:00")
        l3 = create_loan(a3, today - timedelta(days=62))
        s = q("SELECT id,due_date FROM schedule WHERE loan_id=? AND no=1", (l3,), one=True)
        record_payment(l3, s["id"], "autopay", at=s["due_date"] + "T06:00:00")
        ex("INSERT INTO mandates(loan_id,mtype,bank,acct_last4,status,created) VALUES(?,?,?,?,?,?)", (l3, "eNACH", "SBIN", "4321", "active", now))
        # Loan D: closed 5 days ago -> NOC NOT yet eligible
        a4 = mk_app(3, 3, 6000, 3, "disbursed", "agent1", 0, (today - timedelta(days=130)).isoformat() + "T10:00:00")
        l4 = create_loan(a4, today - timedelta(days=100))
        for s in q("SELECT id,due_date FROM schedule WHERE loan_id=? ORDER BY no", (l4,)):
            record_payment(l4, s["id"], "wallet", at=s["due_date"] + "T11:00:00")
        ex("UPDATE loans SET closure_date=? WHERE id=?", ((today - timedelta(days=5)).isoformat(), l4))
        # Pipeline applications
        mk_app(7, 1, 40000, 12, "submitted", "agent1", 0, now)
        mk_app(4, 3, 10000, 6, "under_review", "agent3", 2, now)
        ap = mk_app(0, 2, 15000, 8, "approved", "agent1", 0, now)
        # Pre-GRT group forms: one submitted (waiting for the manager) and one draft
        pg = ex("INSERT INTO pregrt(branch,center_no,group_no,village,district,form_date,pso_name,pso_empid,bm_name,bm_empid,"
                "leader_knows_duties,notes,agent_id,status,created_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                (BRANCHES[0], "C-101", "G-A", "Vijay Nagar", "Indore", (today - timedelta(days=3)).isoformat(), "Ravi Field Officer",
                 "E-1004", "Meera Manager", "E-1002", "yes", "", uid["agent1"], "submitted", now))
        grp = [("Sunita Verma", "Ramesh Verma", 38, "DMO1234501", cid[0], 20000, "Tailoring shop"),
               ("Kavita Sharma", "Anil Sharma", 36, "DMO1234502", cid[2], 20000, "Grocery stock"),
               ("Meena Chouhan", "Dinesh Chouhan", 41, "DMO1234503", None, 20000, "Vegetable vending"),
               ("Lata Parmar", "Rakesh Parmar", 33, "DMO1234504", None, 20000, "Dairy animal"),
               ("Geeta Solanki", "Mahesh Solanki", 39, "DMO1234505", None, 20000, "Bangle shop")]
        for n, (mn, mh, ma, mv, mc, mamt, mp) in enumerate(grp, 1):
            ex(f"INSERT INTO pregrt_members(pregrt_id,sno,{','.join(MEMBER_COLS)}) VALUES(?,?,{','.join('?' * len(MEMBER_COLS))})",
               (pg, n, mc, mn, mh, ma, mv, "", "no", "pucca", 0.0, "", 180000.0, 4, "OBC", float(mamt), mp, "monthly", 12,
                1, 1, 1, 1, 1, 1, 1))
        pg2 = ex("INSERT INTO pregrt(branch,center_no,group_no,village,district,form_date,pso_name,pso_empid,bm_name,bm_empid,"
                 "leader_knows_duties,notes,agent_id,status,created_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                 (BRANCHES[1], "C-202", "G-B", "Palasia", "Indore", today.isoformat(), "Sneha Field Officer", "E-1005", "", "",
                  "", "Still collecting members", uid["agent2"], "draft", now))
        for n, (mn, mh, ma, mv, mc, mamt, mp) in enumerate([("Rekha Jain", "Sanjay Jain", 35, "DMO2234501", None, 15000, "Tiffin service"),
                                                            ("Pushpa Rao", "Vijay Rao", 40, "DMO2234502", None, 15000, "Tailoring")], 1):
            ex(f"INSERT INTO pregrt_members(pregrt_id,sno,{','.join(MEMBER_COLS)}) VALUES(?,?,{','.join('?' * len(MEMBER_COLS))})",
               (pg2, n, mc, mn, mh, ma, mv, "", "no", "pucca", 0.0, "", 150000.0, 4, "General", float(mamt), mp, "monthly", 12,
                1, 1, 1, 0, 0, 0, 0))
        # Field tasks (Indore coordinates) for today and tomorrow
        spots = [("Collection - Vijay Nagar", 0, "collection", 22.7533, 75.8937, "agent1"),
                 ("Collection - Scheme 54", 7, "collection", 22.7470, 75.8920, "agent1"),
                 ("KYC visit - Palasia", 1, "verification", 22.7244, 75.8839, "agent2"),
                 ("Verification - Rajwada", 3, "verification", 22.7185, 75.8575, "agent1"),
                 ("Collection - Sarafa", 6, "collection", 22.7176, 75.8560, "agent1"),
                 ("Collection - Bhawarkuan", 2, "collection", 22.6890, 75.8680, "agent1"),
                 ("Home visit - Rau", 5, "verification", 22.6419, 75.8040, "agent2"),
                 ("Collection - Palasia", 1, "collection", 22.7260, 75.8800, "agent2")]
        for i, (t, ci, tt, la, lo, ag) in enumerate(spots):
            ex("INSERT INTO tasks(title,customer_id,ttype,lat,lng,due_date,officer_id) VALUES(?,?,?,?,?,?,?)",
               (t, cid[ci], tt, la, lo, (today + timedelta(days=0 if i < 6 else 1)).isoformat(), uid[ag]))
        ex("UPDATE users SET lat=22.7510, lng=75.8900, loc_at=? WHERE id=?", (now, uid["agent1"]))
        ex("UPDATE users SET lat=22.7240, lng=75.8830, loc_at=? WHERE id=?", (now, uid["agent2"]))
        ex("INSERT INTO tasks(title,customer_id,ttype,lat,lng,due_date,officer_id,status,collected,done_at) VALUES(?,?,?,?,?,?,?,?,?,?)",
           ("Collection - Done earlier", cid[0], "collection", 22.75, 75.89, today.isoformat(), uid["agent1"], "done", 5200, now))
        # Attendance: last month for payroll demo, today for agent1
        prev = add_months(today.replace(day=1), -1)
        for un in uid:
            days = random.Random(un).randint(22, 26)
            d = prev
            cnt = 0
            while d.month == prev.month and cnt < days:
                if d.weekday() != 6:
                    ex("INSERT INTO attendance(user_id,day,in_time,out_time) VALUES(?,?,?,?)", (uid[un], d.isoformat(), d.isoformat() + "T09:30:00", d.isoformat() + "T18:00:00"))
                    cnt += 1
                d += timedelta(days=1)
        ex("INSERT INTO attendance(user_id,day,in_time,lat,lng) VALUES(?,?,?,?,?)", (uid["agent1"], today.isoformat(), now, 22.7510, 75.8900))
        ex("INSERT INTO leaves(user_id,from_d,to_d,reason,status) VALUES(?,?,?,?,?)", (uid["agent2"], (today + timedelta(days=5)).isoformat(), (today + timedelta(days=6)).isoformat(), "Family function", "pending"))
        ex("INSERT INTO att_requests(user_id,branch,day,in_time,out_time,reason,approver_role,approver_id,requested_at) VALUES(?,?,?,?,?,?,?,?,?)",
           (uid["agent1"], BRANCHES[0], (today - timedelta(days=2)).isoformat(), "09:45", "18:15", "Forgot to punch, was at a centre meeting", "manager", uid["manager1"], now))
        ex("INSERT INTO att_requests(user_id,branch,day,in_time,out_time,reason,approver_role,approver_id,requested_at) VALUES(?,?,?,?,?,?,?,?,?)",
           (uid["manager1"], BRANCHES[0], (today - timedelta(days=3)).isoformat(), "10:00", "18:30", "Phone battery died, worked from the head office", "admin", uid["admin"], now))
        ex("INSERT INTO perf(user_id,period,rating,notes,by_name) VALUES(?,?,?,?,?)", (uid["agent1"], "Q3 2026", 4, "Consistent collection efficiency", "Meera Manager"))


def _post_seed():
    db = sqlite3.connect(DB_PATH)
    migrate(db)
    db.close()


seed()
_post_seed()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5000)), debug=os.environ.get("FLASK_DEBUG") == "1")
