# SARVOOCCH — Security Architecture & Hardening Guide

**Document Classification:** Enterprise Security Specification  
**Date:** 3 November 2026  
**Application Name:** SARVOOCCH  

---

## 1. Authentication & Session Architecture

1. **Password Storage**: Passwords are cryptographically salted and hashed using PBKDF2:SHA256 (`scrypt` in modern Werkzeug releases).
2. **Session Cookies**:
   - `HttpOnly`: Enforced to prevent XSS session exfiltration.
   - `SameSite=Lax`: Prevents cross-site request forgery on state-changing navigations.
   - `Secure`: Mandatory in production HTTPS environments.

---

## 2. Authorization & Data Isolation Controls

1. **Role Verification**: Route-level `@need("permission")` decorator validates permissions against the authoritative `PERMS` RBAC table before handler invocation.
2. **Branch & Agent Scoping**:
   - `scope_agent()` filters queries dynamically: field officers and branch managers only access borrower data and loans belonging to their assigned operational scope.
   - Customer users are strictly restricted to `customer_id` matching their authenticated session.

---

## 3. Input Validation & Defensive Engineering

1. **SQL Injection Mitigation**: All database queries utilize parameterized SQL queries (`?` placeholders) preventing injection attacks.
2. **XSS Protection**: Jinja2 autoescaping is active across all 38 HTML templates.
3. **Aadhaar Masking**: Conforms to UIDAI standards; full 12-digit Aadhaar numbers are never stored in plain text.
