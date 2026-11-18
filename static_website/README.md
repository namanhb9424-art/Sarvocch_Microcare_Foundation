# Sarvocch Microcare Foundation — Static Responsive Website

A modern, high-performance, and responsive static website built for **Sarvocch Microcare Foundation** (Bhopal, MP).

Engineered specifically for **Hostinger Premium Web Hosting** (or any standard Apache/Nginx web server with PHP support), eliminating Python/Flask dependencies while introducing a luxury, upmarket financial design system with smooth animations.

---

## 🌟 Key Features & Animations

- **Zero Python/Flask Runtime Dependency**: 100% compatible with Hostinger shared/premium hosting plans (HTML5, CSS3, Vanilla JS, and lightweight native PHP mailer).
- **Upmarket Modern Design System**:
  - Clean fintech typography powered by *Plus Jakarta Sans*.
  - Glassmorphic navigation header with subtle blur-on-scroll and automatic active section tracking (ScrollSpy).
  - Elegant gradient glow accents, floating badges, and micro-interactions.
- **Scroll-Triggered Reveal Animations**:
  - Hardware-accelerated Intersection Observer animations (fade up, slide-in, stagger delays).
  - Respects user accessibility preferences (`prefers-reduced-motion`).
- **Interactive Loan EMI Calculator**:
  - Real-time dual sliders for Principal Amount (₹5k - ₹5L), Annual Interest (1% - 30%), and Tenure (6 - 60 Months).
  - Quick preset selector chips.
  - Live animated monthly EMI, total interest, and total repayment calculations formatted in Indian currency format (`₹`).
  - Visual animated split bar showing Principal vs. Interest percentage.
  - "Enquire For This Amount" one-click action that scrolls to and pre-fills the enquiry form.
- **Live Animated Impact Counters**:
  - Numbers smoothly count up when scrolled into view (Incorporation year, customer-first metrics, branches).
- **Interactive Branch Locator**:
  - Verified branch office cards for **Registered Office (Bhopal)** and **Pipariya Branch**.
  - Direct embedded responsive Google Maps with one-click navigation links.
- **Multi-Channel Contact & Grievance Systems**:
  - **Loan Enquiry Form**: captures borrower details with 10-digit mobile number validation.
  - **Grievance Redressal Form**: dedicated portal for customer protection and complaints under Fair Practice Code.
  - **Direct Contact Form**: general messages.
  - Non-blocking AJAX submission with loading spinner button state and slide-in animated **Toast Notifications**.
  - Built-in honeypot anti-spam protection.
- **Accessible FAQ Accordion**:
  - Fluid animated expand/collapse transitions with rotating chevron indicators.
- **Back-to-Top Floating Button**:
  - Features an SVG circular progress ring that dynamically fills as the user scrolls down the page.
- **Full Legal & Statutory Disclosures**:
  - Dedicated pages for `privacy.html` and `terms.html`.
  - Section 8 CIN: `U88900MP2026NPL084139`.
  - Schema.org JSON-LD structured microdata for SEO and Google search snippets.

---

## 📂 Project Directory Structure

```
Sarvocch_Static_Website/
│
├── index.html                # Main responsive landing page
├── privacy.html              # Privacy Policy page
├── terms.html                # Terms & Conditions page
├── .htaccess                 # Hostinger Apache caching, security, GZIP & compression
│
├── assets/
│   ├── css/
│   │   ├── styles.css        # Core stylesheet (Design tokens, layout, typography)
│   │   └── animations.css    # Hardware-accelerated keyframe animations & reveals
│   ├── js/
│   │   └── main.js           # Interactive engine (Calculator, ScrollSpy, Forms, Toast)
│   └── images/
│       ├── LOGO_1.jpg        # Official company logo
│       ├── pushpraj-singh.jpg.jpeg # Director portrait
│       ├── bandna-singh.jpg.jpeg   # Managing Director portrait
│       └── favicon.svg       # Vector browser favicon
│
├── api/
│   └── submit.php            # Hostinger PHP mailer & submission endpoint
│
└── data/
    └── .htaccess             # Denies direct public HTTP access to submission records
```

---

## 🚀 How to Deploy on Hostinger (Step-by-Step)

### Option 1: Using Hostinger hPanel File Manager (Recommended)
1. Log in to your **Hostinger hPanel**.
2. Go to **Websites** &rarr; click **Manage** next to your domain (`sarvocchfinance.com`).
3. Click on **File Manager** (under Files).
4. Navigate into the **`public_html`** directory.
5. Upload all files and folders from this repository into `public_html`:
   - `index.html`
   - `privacy.html`
   - `terms.html`
   - `.htaccess`
   - `assets/`
   - `api/`
   - `data/`
6. Make sure permissions for folders are `755` and files are `644`.
7. Your website is instantly live!

### Option 2: Using FTP / FileZilla
1. In hPanel, find your **FTP Accounts** details (Host, Username, Port 21, Password).
2. Connect using FileZilla or your preferred FTP client.
3. Upload all files into the **`public_html`** directory.

---

## 🧪 Testing Locally Before Deployment

You can test the entire site locally using any standard local development server:

### Using PHP Built-in Server (Full Form Submission Testing):
```bash
cd /Users/vaidik/Sarvocch_Static_Website
php -S localhost:8080
```
Open [http://localhost:8080](http://localhost:8080) in your browser.

### Using Python HTTP Server (Static Frontend Testing):
```bash
cd /Users/vaidik/Sarvocch_Static_Website
python3 -m http.server 8000
```
Open [http://localhost:8000](http://localhost:8000) in your browser.

---

## 💬 WhatsApp Integration & Automated Alerts

This site includes a complete **100% Free** WhatsApp integration for both visitors and administrators:

### 1. Floating WhatsApp Quick-Chat Widget
- A floating chat pill is pinned to the bottom-left corner across all pages.
- Allows visitors to immediately chat with Sarvocch Microcare's official WhatsApp number (`+91 91111 99101`).

### 2. Form Direct-to-WhatsApp Forwarding
- When users submit the **Loan Enquiry Form** or **Contact Form**, they can choose between standard submission or **"Apply via WhatsApp"**.
- Upon submission, their input is sent to the server (saving a backup and emailing the office) **AND** generates a pre-formatted WhatsApp message directly to your team with all borrower fields (Name, Phone, State, Product, Amount, and Purpose).

### 3. Free Instant WhatsApp Notifications to Admin's Phone (CallMeBot)
You can receive an instant WhatsApp alert on your phone whenever any visitor submits a form:
1. From your personal/admin WhatsApp, send this message:
   ```text
   I allow callmebot to send me messages
   ```
   to **`+34 924 57 28 40`** (or open [CallMeBot Instructions](https://www.callmebot.com/blog/free-api-whatsapp-messages/)).
2. CallMeBot will reply with your free API Key within 5 seconds.
3. Open `api/submit.php` and set your key:
   ```php
   define('CALLMEBOT_ADMIN_PHONE', '919111199101'); // Your WhatsApp number
   define('CALLMEBOT_API_KEY', 'YOUR_API_KEY_HERE'); // Free API key
   ```
4. Save the file. Every new loan enquiry or grievance will now instantly buzz on your WhatsApp phone!

---

## 📧 Form Email Configuration

In `api/submit.php`:
- Submissions are automatically delivered to: `sarvocchmicrocare@gmail.com`.
- To change the recipient email address, update line 11:
  ```php
  define('ADMIN_EMAIL', 'sarvocchmicrocare@gmail.com');
  ```
- Submissions are also safely stored in `data/submissions.json` (protected from web access by `data/.htaccess`).
