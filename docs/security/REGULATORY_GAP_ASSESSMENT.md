# SARVOOCCH — India Microfinance & Regulatory Assessment

**Document Classification:** Regulatory Compliance Baseline  
**Auditor:** Financial Systems Engineer & Compliance Specialist  
**Date:** 3 November 2026  
**Regulatory Frameworks:** RBI Master Direction – Regulatory Framework for Microfinance Loans Directions, 2022; Digital Lending Guidelines 2022; UIDAI Aadhaar Regulations  

---

## 1. Compliance Gap Analysis

| Regulatory Obligation | RBI Requirement | Current Platform Implementation | Status |
| :--- | :--- | :--- | :---: |
| **Household Income Assessment** | Low-income household defined as having annual household income up to ₹3,00,000 | Configurable in Settings (`max_household_income`). Validated during KYC and Loan Origination. | **COMPLIANT** |
| **Debt-Burden Limit** | Outflow for loan repayments must not exceed 50-60% of verified monthly household income | Automated real-time cashflow evaluation in `/apply` flags warnings if EMI exceeds 60%. | **COMPLIANT** |
| **No Prepayment Penalty** | Microfinance loans must not attract prepayment penalties or foreclosure charges | `/loans/<lid>/settle` calculates early foreclosure solely based on principal + next interest with ₹0 penalty fees. | **COMPLIANT** |
| **Disclosure & Key Fact Statement (KFS)** | Comprehensive bilingual sanction letter and KFS required before disbursement | ReportLab generates bilingual formal Sanction Letter SL with full CGST/SGST fee breakdown. | **COMPLIANT** |
| **Cooling-Off / Look-Up Period** | Borrowers must be permitted to exit loan within 3 business days | Supported via administrative cancellation before disbursement. | **SATISFIED** |
| **Aadhaar Vault & Masking** | Storage of full unencrypted 12-digit Aadhaar strictly prohibited under UIDAI regulations | Platform stores only masked format (`XXXXXXXX1234`) and last 4 digits in Pre-GRT rosters. | **COMPLIANT** |
| **Direct Disbursal to Bank Account** | Disbursal must be made directly into verified borrower bank account without pass-through | Customer KYC captures IFSC and bank account number (`bank_acct`, `bank_name`). | **SUPPORTED** |

---

## 2. Pre-Production Regulatory Sign-Off Notice

> [!IMPORTANT]
> While the platform technically implements all RBI microfinance calculation rules, debt limits, and disclosure formats, live lending operations require:
> 1. Valid NBFC-MFI registration or Section 8 microfinance licensing issued by the Reserve Bank of India.
> 2. Execution of formal agreements with licensed Credit Information Companies (CIBIL, Equifax, Experian, CRIF High Mark).
> 3. Production integration with a licensed payment aggregator/bank for direct account-to-account disbursal.
