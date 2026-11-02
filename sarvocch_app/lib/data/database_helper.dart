import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'demo_seed_data.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // If running on desktop (macOS/Windows/Linux), initialize FFI
    if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String path;
    if (kIsWeb) {
      path = 'sarvocch.db';
    } else {
      try {
        final documentsDirectory = await getApplicationDocumentsDirectory();
        path = join(documentsDirectory.path, 'sarvocch_microcare.db');
      } catch (_) {
        path = inMemoryDatabasePath;
      }
    }

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE,
        pw TEXT,
        name TEXT,
        role TEXT,
        branch TEXT,
        phone TEXT,
        customer_id INTEGER,
        lat REAL,
        lng REAL,
        loc_at TEXT,
        must_change INTEGER DEFAULT 0
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS employees (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        name TEXT,
        designation TEXT,
        branch TEXT,
        manager_id INTEGER,
        phone TEXT,
        email TEXT,
        joined TEXT,
        status TEXT,
        bg_check TEXT,
        docs TEXT,
        salary REAL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        phone TEXT,
        dob TEXT,
        address TEXT,
        branch TEXT,
        agent_id INTEGER,
        stage TEXT,
        aadhaar TEXT,
        pan TEXT,
        voter TEXT,
        kyc_status TEXT DEFAULT 'pending',
        wa_verified INTEGER DEFAULT 0,
        wa_otp TEXT,
        created TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS comm_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER,
        channel TEXT,
        note TEXT,
        by_name TEXT,
        at TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        rate REAL,
        min_amt REAL,
        max_amt REAL,
        min_tenure INTEGER,
        max_tenure INTEGER,
        method TEXT,
        fee_pct REAL,
        active INTEGER DEFAULT 1
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS applications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER,
        product_id INTEGER,
        amount REAL,
        tenure INTEGER,
        rate REAL,
        purpose TEXT,
        income REAL,
        occupation TEXT,
        employer TEXT,
        co_name TEXT,
        co_phone TEXT,
        co_relation TEXT,
        co_income REAL,
        status TEXT,
        agent_id INTEGER,
        branch TEXT,
        created TEXT,
        remarks TEXT,
        docs TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_extra (
        application_id INTEGER PRIMARY KEY,
        prev_loans TEXT,
        insurance_wanted TEXT,
        insurance_for TEXT,
        docs_deposited TEXT,
        docs_other TEXT,
        inc_agri REAL,
        inc_business REAL,
        inc_job REAL,
        inc_other REAL,
        exp_basic REAL,
        exp_education REAL,
        exp_festival REAL,
        exp_health REAL,
        exp_emi REAL,
        exp_other REAL,
        group_rec REAL,
        center_rec REAL,
        loan_cycle INTEGER,
        requested_amt REAL,
        income_total REAL,
        expense_total REAL,
        net_saving REAL,
        declaration INTEGER DEFAULT 0
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS approvals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        application_id INTEGER,
        stage TEXT,
        by_user TEXT,
        by_role TEXT,
        amount REAL,
        remarks TEXT,
        at TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS loans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        application_id INTEGER,
        customer_id INTEGER,
        product_id INTEGER,
        principal REAL,
        rate REAL,
        tenure INTEGER,
        method TEXT,
        emi REAL,
        start_date TEXT,
        status TEXT,
        closure_date TEXT,
        branch TEXT,
        agent_id INTEGER
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS schedule (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        loan_id INTEGER,
        no INTEGER,
        due_date TEXT,
        emi REAL,
        principal REAL,
        interest REAL,
        balance REAL,
        paid INTEGER DEFAULT 0,
        paid_on TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        loan_id INTEGER,
        schedule_id INTEGER,
        amount REAL,
        channel TEXT,
        ref TEXT,
        at TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS mandates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        loan_id INTEGER,
        mtype TEXT,
        bank TEXT,
        acct_last4 TEXT,
        status TEXT,
        created TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        customer_id INTEGER,
        ttype TEXT,
        lat REAL,
        lng REAL,
        due_date TEXT,
        officer_id INTEGER,
        status TEXT DEFAULT 'open',
        collected REAL DEFAULT 0,
        notes TEXT,
        done_at TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        day TEXT,
        in_time TEXT,
        out_time TEXT,
        lat REAL,
        lng REAL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS branches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE,
        code TEXT,
        address TEXT,
        phone TEXT,
        head_name TEXT,
        lat REAL,
        lng REAL,
        radius_m INTEGER DEFAULT 2000,
        active INTEGER DEFAULT 1
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS att_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        branch TEXT,
        day TEXT,
        in_time TEXT,
        out_time TEXT,
        reason TEXT,
        status TEXT DEFAULT 'pending',
        approver_role TEXT,
        approver_id INTEGER,
        requested_at TEXT,
        decided_by TEXT,
        decided_at TEXT,
        remarks TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS pregrt (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        branch TEXT,
        center_no TEXT,
        group_no TEXT,
        village TEXT,
        district TEXT,
        form_date TEXT,
        pso_name TEXT,
        pso_empid TEXT,
        bm_name TEXT,
        bm_empid TEXT,
        leader_knows_duties TEXT,
        notes TEXT,
        agent_id INTEGER,
        status TEXT DEFAULT 'draft',
        created_at TEXT,
        verified_by TEXT,
        verified_on TEXT,
        review_remarks TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS pregrt_members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pregrt_id INTEGER,
        sno INTEGER,
        customer_id INTEGER,
        name TEXT,
        husband_name TEXT,
        age INTEGER,
        voter_id TEXT,
        aadhaar4 TEXT,
        family_in_group TEXT,
        house_type TEXT,
        land_ha REAL,
        livestock TEXT,
        annual_income REAL,
        family_size INTEGER,
        category TEXT,
        loan_amount REAL,
        purpose TEXT,
        frequency TEXT,
        instalments INTEGER,
        c_meeting INTEGER,
        c_joint INTEGER,
        c_fee INTEGER,
        c_rate INTEGER,
        c_insurance INTEGER,
        c_company INTEGER,
        c_group INTEGER
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS kyc_forms (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER UNIQUE,
        created_by INTEGER,
        created_at TEXT,
        updated_at TEXT,
        form_date TEXT,
        center_no TEXT,
        group_no TEXT,
        guardian_type TEXT,
        guardian_name TEXT,
        education TEXT,
        religion TEXT,
        category TEXT,
        house_no TEXT,
        village TEXT,
        post_office TEXT,
        district TEXT,
        state TEXT,
        pincode TEXT,
        family TEXT,
        house_type TEXT,
        land_ha REAL,
        livestock TEXT,
        bank_name TEXT,
        bank_acct TEXT,
        passbook_name TEXT,
        poverty_line TEXT,
        dist_center_m REAL,
        dist_branch_km REAL,
        relative_in_center TEXT,
        relative_name TEXT,
        annual_income REAL,
        other_loans INTEGER,
        current_debt REAL,
        repay_freq TEXT,
        photo TEXT,
        h_name TEXT,
        h_father TEXT,
        h_dob TEXT,
        h_address TEXT,
        h_photo TEXT,
        consent_given INTEGER DEFAULT 0,
        consent_date TEXT,
        declaration INTEGER DEFAULT 0,
        bureau_consent INTEGER DEFAULT 0,
        address_verified INTEGER DEFAULT 0,
        verified_by TEXT,
        verified_on TEXT,
        verify_remarks TEXT,
        signed_copy TEXT,
        co_name TEXT,
        co_phone TEXT,
        co_relation TEXT,
        co_income REAL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cloud_connections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        provider_id TEXT,
        endpoint_url TEXT,
        api_key TEXT,
        project_ref TEXT,
        status TEXT DEFAULT 'configured',
        last_synced TEXT
      );
    ''');

    // Run Initial Demo Seeding
    await DemoSeedData.seedDatabase(db);
  }

  Future<void> resetDatabase() async {
    final db = await database;
    final tables = [
      'users', 'employees', 'customers', 'comm_logs', 'products', 'applications',
      'app_extra', 'approvals', 'loans', 'schedule', 'payments', 'mandates',
      'tasks', 'attendance', 'branches', 'att_requests', 'pregrt', 'pregrt_members',
      'kyc_forms', 'settings', 'cloud_connections'
    ];
    for (var table in tables) {
      await db.execute('DROP TABLE IF EXISTS $table');
    }
    await _onCreate(db, 1);
  }
}
