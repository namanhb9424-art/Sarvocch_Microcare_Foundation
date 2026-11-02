# SARVOOCCH — Visual Baseline Specification

**Document Classification:** Visual Design & Brand Standard  
**Auditor:** UI/UX & Frontend Engineer  
**Date:** 3 November 2026  
**Application Name:** SARVOOCCH  

---

## 1. Brand Color Palette (Strict Invariant)

The visual design is anchored on the official MFI brand palette:

| Token Name | Hex Code | RGB | Role / Usage |
| :--- | :--- | :--- | :--- |
| `teal-primary` | `#0F766E` | `rgb(15, 118, 110)` | Primary buttons, active navigation, header badges, primary branding |
| `teal-dark` | `#0B5E57` | `rgb(11, 94, 87)` | Hover states, table headers, dark accents |
| `teal-surface` | `#E6F4F2` | `rgb(230, 244, 242)` | Card accent backgrounds, active navigation pills, highlighted stat cards |
| `background` | `#F8FAFC` | `rgb(248, 250, 252)` | Application page background, off-white contrast canvas |
| `surface-white`| `#FFFFFF` | `rgb(255, 255, 255)` | Cards, dialogs, drawers, input backgrounds |
| `border-color` | `#E2E8F0` | `rgb(226, 232, 240)` | Card borders, dividers, input borders |
| `text-primary` | `#0F172A` | `rgb(15, 23, 42)` | High-contrast headlines, primary text |
| `text-secondary`| `#64748B`| `rgb(100, 116, 139)` | Subtitles, helper text, form labels, muted timestamps |
| `success` | `#16A34A` | `rgb(22, 163, 74)` | Paid status badges, approved milestones, verified checkmarks |
| `warning` | `#F59E0B` | `rgb(245, 158, 11)` | Under review states, pending actions, partial CGT warnings |
| `danger` | `#DC2626` | `rgb(220, 38, 38)` | Overdue badges, rejected applications, high risk cashflow warnings |

---

## 2. Typography Hierarchy

- **Font Family**: Google Fonts Inter (`GoogleFonts.inter()`).
- **Headlines (H1/H2)**: 20-22px, SemiBold (`w700`), letter-spacing: -0.5px.
- **Section Headers (H3/H4)**: 15-16px, SemiBold (`w600`), text-primary.
- **Body Text**: 13-14px, Regular (`w400`), line-height: 1.5, color: `#334155`.
- **Form Labels**: 12-12.5px, Medium (`w500`), color: `#64748B`.
- **Badges & Tags**: 10-11px, Bold (`w700`), uppercase, tracking: 0.5px.

---

## 3. Component Spacing & Geometry Standards

- **Border Radius**:
  - Cards: `12px`
  - Buttons: `8px`
  - Inputs: `8px`
  - Dialogs & Bottom Sheets: `16px` (top rounded)
  - Badges: `4px`
- **Card Shadows**: Subtle dual-layer box shadow: `0 1px 3px rgba(0,0,0,0.06), 0 1px 2px rgba(0,0,0,0.04)`.
- **Grid Density**: 16px page margins, 12px card padding, 10px list item spacing.
