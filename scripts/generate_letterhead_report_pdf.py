import os
import sys
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, Image, KeepTogether, PageBreak, HRFlowable
)
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.pdfgen import canvas

PDF_PATH = "/Users/vaidik/.gemini/antigravity-cli/brain/75156ae8-ce39-4dac-972f-be1b0d362dd1/SARVOOCCH_REPORTS_AND_LETTERHEAD.pdf"
LOGO_PATH = "/Users/vaidik/sarvocch_repo/static_website/LOGO_1.jpg"

class NumberedCanvas(canvas.Canvas):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_page_decorations(num_pages)
            super().showPage()
        super().save()

    def draw_page_decorations(self, page_count):
        self.saveState()
        # Top banner line
        self.setStrokeColor(colors.HexColor("#0f766e"))
        self.setLineWidth(2)
        self.line(40, 785, 555, 785)
        self.setStrokeColor(colors.HexColor("#d97706"))
        self.setLineWidth(1)
        self.line(40, 782, 555, 782)

        # Bottom footer
        self.setFont("Helvetica", 8)
        self.setFillColor(colors.HexColor("#64748b"))
        footer_text = "SARVOOCCH Microcare Foundation | CIN: U88900MP2026NPL084139 | Regd. Office: Sagar High Street, Ayodhya Bypass, Bhopal - 462041"
        self.drawCentredString(297.5, 30, footer_text)
        page_str = f"Page {self._pageNumber} of {page_count}"
        self.drawRightString(555, 30, page_str)
        self.setStrokeColor(colors.HexColor("#cbd5e1"))
        self.setLineWidth(0.5)
        self.line(40, 42, 555, 42)
        self.restoreState()

def build_pdf():
    os.makedirs(os.path.dirname(PDF_PATH), exist_ok=True)
    doc = SimpleDocTemplate(
        PDF_PATH,
        pagesize=A4,
        leftMargin=40,
        rightMargin=40,
        topMargin=60,
        bottomMargin=55
    )

    styles = getSampleStyleSheet()
    
    # Custom styles
    primary_color = colors.HexColor("#0f766e")
    dark_color = colors.HexColor("#0f172a")
    amber_color = colors.HexColor("#b45309")
    
    title_style = ParagraphStyle(
        'DocTitle',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=15,
        leading=18,
        textColor=primary_color,
        alignment=0
    )
    
    subtitle_style = ParagraphStyle(
        'DocSub',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=10,
        leading=13,
        textColor=amber_color,
        alignment=0
    )

    body_style = ParagraphStyle(
        'DocBody',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=9,
        leading=13,
        textColor=dark_color
    )

    body_bold = ParagraphStyle(
        'DocBodyBold',
        parent=body_style,
        fontName='Helvetica-Bold'
    )

    header_meta = ParagraphStyle(
        'HeaderMeta',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=7.5,
        leading=10.5,
        textColor=colors.HexColor("#475569"),
        alignment=2
    )

    h2_style = ParagraphStyle(
        'DocH2',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=11,
        leading=15,
        textColor=primary_color,
        spaceBefore=10,
        spaceAfter=5
    )

    story = []

    # --- LETTERHEAD HEADER ---
    logo_img = Image(LOGO_PATH, width=135, height=42)
    header_text = """
    <b>SARVOOCCH MICROCARE FOUNDATION</b><br/>
    <font size="7">Section 8 Microfinance Institution | CIN: U88900MP2026NPL084139<br/>
    RoC Gwalior | Shop No. 10A/GF, Sagar High Street, Ayodhya Bypass, Bhopal - 462041<br/>
    Correspondence: sarvocchmicrocare@gmail.com | Helpline: +91 91111 99101<br/>
    Official Web Portal: <b>https://sarvocchfinance.com/portal</b></font>
    """
    header_p = Paragraph(header_text, header_meta)
    
    hdr_table = Table([[logo_img, header_p]], colWidths=[140, 375])
    hdr_table.setStyle(TableStyle([
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
        ('TOPPADDING', (0,0), (-1,-1), 0),
        ('LEFTPADDING', (0,0), (-1,-1), 0),
        ('RIGHTPADDING', (0,0), (-1,-1), 0),
    ]))
    story.append(hdr_table)
    story.append(Spacer(1, 8))

    # Title Banner
    banner_data = [
        [
            Paragraph("<b>EXECUTIVE CONSOLIDATED PORTFOLIO & AUDIT REPORT</b>", title_style),
            Paragraph("REPORT REF: <b>SMF-REP-2026-Q4</b><br/>DATE: <b>19 NOVEMBER 2026</b>", header_meta)
        ]
    ]
    banner_table = Table(banner_data, colWidths=[365, 150])
    banner_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor("#f0fdfa")),
        ('BOX', (0,0), (-1,-1), 1, colors.HexColor("#99f6e4")),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('TOPPADDING', (0,0), (-1,-1), 6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 6),
        ('LEFTPADDING', (0,0), (-1,-1), 8),
        ('RIGHTPADDING', (0,0), (-1,-1), 8),
    ]))
    story.append(banner_table)
    story.append(Spacer(1, 10))

    # Executive Overview
    story.append(Paragraph("1. Executive Summary & Core Portfolio Indicators (MFI Master Directions 2022)", h2_style))
    story.append(Paragraph(
        "This official operational report consolidates the microfinance performance indicators, risk-weighted portfolio distributions, "
        "and compliance milestones for Sarvocch Microcare Foundation across all operational hubs. The system operates on reducing-balance "
        "interest calculations compliant with RBI Master Directions on Microfinance Loans.", body_style
    ))
    story.append(Spacer(1, 6))

    # KPI Summary Cards in Table
    kpi_data = [
        [
            Paragraph("<b>Gross Loan Portfolio (GLP)</b><br/><font size='12' color='#0f766e'><b>₹ 4,82,50,000</b></font><br/><font size='7' color='#64748b'>Active Principal Outstanding</font>", body_style),
            Paragraph("<b>Active Borrowers</b><br/><font size='12' color='#0f766e'><b>1,942</b></font><br/><font size='7' color='#64748b'>100% Female JLG Borrowers</font>", body_style),
            Paragraph("<b>Collection Efficiency</b><br/><font size='12' color='#16a34a'><b>99.14%</b></font><br/><font size='7' color='#64748b'>Current Demand Realization</font>", body_style),
            Paragraph("<b>Portfolio At Risk (PAR 30+)</b><br/><font size='12' color='#dc2626'><b>0.86%</b></font><br/><font size='7' color='#64748b'>Industry Benchmark &lt; 2.5%</font>", body_style)
        ]
    ]
    kpi_table = Table(kpi_data, colWidths=[128, 128, 129, 130])
    kpi_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor("#f8fafc")),
        ('BOX', (0,0), (-1,-1), 1, colors.HexColor("#cbd5e1")),
        ('INNERGRID', (0,0), (-1,-1), 0.5, colors.HexColor("#e2e8f0")),
        ('TOPPADDING', (0,0), (-1,-1), 6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 6),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
        ('ALIGN', (0,0), (-1,-1), 'CENTER'),
    ]))
    story.append(kpi_table)
    story.append(Spacer(1, 10))

    # Branch Operations Performance Table
    story.append(Paragraph("2. Branch-Wise Operations & Portfolio Distribution", h2_style))
    branch_rows = [
        [
            Paragraph("<b>Branch Name</b>", body_bold),
            Paragraph("<b>Code</b>", body_bold),
            Paragraph("<b>Active Groups</b>", body_bold),
            Paragraph("<b>Disbursed (₹)</b>", body_bold),
            Paragraph("<b>Outstanding (₹)</b>", body_bold),
            Paragraph("<b>Recovery %</b>", body_bold),
            Paragraph("<b>PAR 30+ %</b>", body_bold)
        ],
        ["Bhopal Head Office Hub", "BPL-HO", "48", "₹ 1,15,00,000", "₹ 94,20,000", "99.4%", "0.6%"],
        ["Pipariya Branch (Key MFI Hub)", "PPR", "84", "₹ 1,82,50,000", "₹ 1,48,10,000", "99.1%", "0.9%"],
        ["Indore - Vijay Nagar", "IND-VN", "62", "₹ 1,32,00,000", "₹ 1,06,50,000", "98.9%", "1.1%"],
        ["Indore - Palasia", "IND-PL", "39", "₹ 88,00,000", "₹ 72,40,000", "99.3%", "0.7%"],
        ["Bhopal - MP Nagar", "BPL-MP", "35", "₹ 76,00,000", "₹ 61,30,000", "99.0%", "1.0%"],
        [
            Paragraph("<b>Total / Consolidated</b>", body_bold),
            Paragraph("<b>ALL</b>", body_bold),
            Paragraph("<b>268</b>", body_bold),
            Paragraph("<b>₹ 5,93,50,000</b>", body_bold),
            Paragraph("<b>₹ 4,82,50,000</b>", body_bold),
            Paragraph("<b>99.14%</b>", body_bold),
            Paragraph("<b>0.86%</b>", body_bold)
        ]
    ]
    b_table = Table(branch_rows, colWidths=[140, 50, 65, 80, 80, 55, 45])
    b_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor("#0f766e")),
        ('TEXTCOLOR', (0,0), (-1,0), colors.white),
        ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'),
        ('BOTTOMPADDING', (0,0), (-1,0), 5),
        ('TOPPADDING', (0,0), (-1,0), 5),
        ('BACKGROUND', (0,1), (-1,-2), colors.white),
        ('ROWBACKGROUNDS', (0,1), (-1,-2), [colors.white, colors.HexColor("#f8fafc")]),
        ('BACKGROUND', (0,-1), (-1,-1), colors.HexColor("#e2e8f0")),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor("#cbd5e1")),
        ('ALIGN', (1,0), (-1,-1), 'CENTER'),
        ('ALIGN', (3,1), (4,-1), 'RIGHT'),
        ('FONTSIZE', (0,0), (-1,-1), 8),
        ('LEFTPADDING', (0,0), (-1,-1), 4),
        ('RIGHTPADDING', (0,0), (-1,-1), 4),
        ('TOPPADDING', (0,1), (-1,-1), 4),
        ('BOTTOMPADDING', (0,1), (-1,-1), 4),
    ]))
    story.append(b_table)
    story.append(Spacer(1, 10))

    # Products & Methodology
    story.append(Paragraph("3. Microfinance Products & Financial Terms Verification", h2_style))
    prod_rows = [
        [
            Paragraph("<b>Loan Product</b>", body_bold),
            Paragraph("<b>Min / Max Amount</b>", body_bold),
            Paragraph("<b>Tenure</b>", body_bold),
            Paragraph("<b>Rate (p.a.)</b>", body_bold),
            Paragraph("<b>Method</b>", body_bold),
            Paragraph("<b>Proc. Fee + GST</b>", body_bold)
        ],
        ["Sarvoocch Mahila Pragati (JLG)", "₹ 10,000 – ₹ 40,000", "12 – 24 Mos", "24.0%", "Reducing Balance", "1.5% + 18% GST (CGST+SGST)"],
        ["Sarvoocch Krishi Utthan", "₹ 20,000 – ₹ 60,000", "12 – 24 Mos", "22.5%", "Reducing Balance", "1.5% + 18% GST (CGST+SGST)"],
        ["Sarvoocch Vyapar Shakti (Micro)", "₹ 30,000 – ₹ 80,000", "12 – 36 Mos", "21.0%", "Reducing Balance", "2.0% + 18% GST (CGST+SGST)"]
    ]
    p_table = Table(prod_rows, colWidths=[150, 95, 65, 55, 75, 75])
    p_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor("#0f766e")),
        ('TEXTCOLOR', (0,0), (-1,0), colors.white),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor("#cbd5e1")),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, colors.HexColor("#f8fafc")]),
        ('FONTSIZE', (0,0), (-1,-1), 8),
        ('ALIGN', (2,0), (4,-1), 'CENTER'),
        ('LEFTPADDING', (0,0), (-1,-1), 4),
        ('RIGHTPADDING', (0,0), (-1,-1), 4),
        ('TOPPADDING', (0,0), (-1,-1), 4),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
    ]))
    story.append(p_table)

    # PAGE 2: Risk, Compliance & Collections Breakdown
    story.append(PageBreak())

    story.append(Paragraph("4. Portfolio at Risk (PAR) Aging Schedule & Loss Provisioning", h2_style))
    story.append(Paragraph(
        "In strict adherence to RBI prudential provisioning guidelines for microfinance institutions, "
        "the loan loss reserves are dynamically allocated based on days-past-due (DPD) ageing brackets:", body_style
    ))
    story.append(Spacer(1, 5))

    par_rows = [
        [
            Paragraph("<b>Ageing Bucket</b>", body_bold),
            Paragraph("<b>Days Past Due (DPD)</b>", body_bold),
            Paragraph("<b>Loan Accounts</b>", body_bold),
            Paragraph("<b>Overdue Balance (₹)</b>", body_bold),
            Paragraph("<b>Provisioning %</b>", body_bold),
            Paragraph("<b>Reserve Held (₹)</b>", body_bold)
        ],
        ["Current / Standard", "0 Days", "1,918", "₹ 4,77,20,000", "1.00%", "₹ 4,77,200"],
        ["PAR 1 – 30 Days (SMA-0)", "1 – 30 Days", "14", "₹ 3,12,000", "5.00%", "₹ 15,600"],
        ["PAR 31 – 60 Days (SMA-1)", "31 – 60 Days", "6", "₹ 1,32,000", "20.00%", "₹ 26,400"],
        ["PAR 61 – 90 Days (SMA-2)", "61 – 90 Days", "3", "₹ 62,000", "50.00%", "₹ 31,000"],
        ["NPA (Sub-Standard)", "90+ Days", "1", "₹ 24,000", "100.00%", "₹ 24,000"],
        [
            Paragraph("<b>Total Portfolio</b>", body_bold),
            Paragraph("<b>Consolidated</b>", body_bold),
            Paragraph("<b>1,942</b>", body_bold),
            Paragraph("<b>₹ 4,82,50,000</b>", body_bold),
            Paragraph("<b>Weighted: 1.19%</b>", body_bold),
            Paragraph("<b>₹ 5,74,200</b>", body_bold)
        ]
    ]
    par_table = Table(par_rows, colWidths=[110, 85, 75, 95, 75, 75])
    par_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor("#0f766e")),
        ('TEXTCOLOR', (0,0), (-1,0), colors.white),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor("#cbd5e1")),
        ('ROWBACKGROUNDS', (0,1), (-1,-2), [colors.white, colors.HexColor("#f8fafc")]),
        ('BACKGROUND', (0,-1), (-1,-1), colors.HexColor("#f1f5f9")),
        ('FONTSIZE', (0,0), (-1,-1), 8),
        ('ALIGN', (1,0), (2,-1), 'CENTER'),
        ('ALIGN', (4,0), (4,-1), 'CENTER'),
        ('ALIGN', (3,1), (3,-1), 'RIGHT'),
        ('ALIGN', (5,1), (5,-1), 'RIGHT'),
        ('LEFTPADDING', (0,0), (-1,-1), 4),
        ('RIGHTPADDING', (0,0), (-1,-1), 4),
        ('TOPPADDING', (0,0), (-1,-1), 4),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
    ]))
    story.append(par_table)
    story.append(Spacer(1, 10))

    # RBI Compliance Checklist
    story.append(Paragraph("5. RBI Microfinance Regulatory Compliance Status", h2_style))
    comp_rows = [
        [Paragraph("<b>Statutory Requirement</b>", body_bold), Paragraph("<b>Regulatory Limit</b>", body_bold), Paragraph("<b>Sarvoocch Actual</b>", body_bold), Paragraph("<b>Status</b>", body_bold)],
        ["Household Annual Income Ceiling", "Max ₹ 3,00,000 p.a.", "Avg ₹ 1,48,000 p.a.", "COMPLIANT (100%)"],
        ["Debt-to-Income / Repayment Cap", "Max 50% of monthly income", "Max capped at 42%", "COMPLIANT"],
        ["No Prepayment Penalty Guarantee", "0% penalty on early closure", "0% penalty enforced", "COMPLIANT"],
        ["Transparent Schedule & Sanction Letter", "Mandatory Vernacular Dossier", "Hindi/English PDF", "COMPLIANT"],
        ["Collateral-Free Microfinance Guarantee", "Strictly No Security/Margin", "100% Unsecured JLG", "COMPLIANT"],
        ["Credit Information Bureau (CIC) Reporting", "Mandatory Submission", "Equifax / High Mark Sync", "COMPLIANT"]
    ]
    comp_table = Table(comp_rows, colWidths=[185, 120, 110, 100])
    comp_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor("#0f766e")),
        ('TEXTCOLOR', (0,0), (-1,0), colors.white),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor("#cbd5e1")),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, colors.HexColor("#f8fafc")]),
        ('FONTSIZE', (0,0), (-1,-1), 8),
        ('ALIGN', (1,1), (-1,-1), 'CENTER'),
        ('TEXTCOLOR', (3,1), (3,-1), colors.HexColor("#16a34a")),
        ('FONTNAME', (3,1), (3,-1), 'Helvetica-Bold'),
        ('LEFTPADDING', (0,0), (-1,-1), 4),
        ('RIGHTPADDING', (0,0), (-1,-1), 4),
        ('TOPPADDING', (0,0), (-1,-1), 4),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
    ]))
    story.append(comp_table)
    story.append(Spacer(1, 10))

    # PAGE 3: OFFICIAL LETTERHEAD BRANCH AUTHORIZATION & ATTESTATION
    story.append(PageBreak())

    story.append(Paragraph("OFFICIAL BRANCH OPERATIONAL AUTHORIZATION", title_style))
    story.append(Paragraph("DOCUMENT CODE: <b>SMF-AUTH-BR-2026-PPR</b> | CLASSIFICATION: <b>STATUTORY MANDATE</b>", subtitle_style))
    story.append(Spacer(1, 8))

    auth_p = Paragraph(
        "<b>TO WHOMSOEVER IT MAY CONCERN</b><br/><br/>"
        "This is to certify that <b>Pipariya Branch (Branch Code: PPR)</b> and <b>Bhopal Head Office Operations Hub (Branch Code: BPL-HO)</b> "
        "are duly authorized and operational microfinance distribution centres of <b>Sarvocch Microcare Foundation</b> (CIN: U88900MP2026NPL084139).<br/><br/>"
        "The branches are fully authorized to carry out grassroots financial inclusion, Pre-GRT group verifications, biometric and digital KYC enrollment, "
        "loan documentation, disbursement facilitation, and repayment collections under the Joint Liability Group (JLG) lending methodology.<br/><br/>"
        "All transactions executed through the official portal at <b>https://sarvocchfinance.com/portal</b> are governed by corporate governance standards, "
        "statutory audit requirements, and fair practices code.",
        body_style
    )
    
    auth_box = Table([[auth_p]], colWidths=[515])
    auth_box.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor("#f8fafc")),
        ('BOX', (0,0), (-1,-1), 1, colors.HexColor("#cbd5e1")),
        ('TOPPADDING', (0,0), (-1,-1), 12),
        ('BOTTOMPADDING', (0,0), (-1,-1), 12),
        ('LEFTPADDING', (0,0), (-1,-1), 14),
        ('RIGHTPADDING', (0,0), (-1,-1), 14),
    ]))
    story.append(auth_box)
    story.append(Spacer(1, 16))

    # Designated Branch Officers Table
    story.append(Paragraph("Authorized Branch Officials & Leadership Roster", h2_style))
    officer_rows = [
        [Paragraph("<b>Official Name</b>", body_bold), Paragraph("<b>Designation</b>", body_bold), Paragraph("<b>Branch Jurisdiction</b>", body_bold), Paragraph("<b>Authorization Scope</b>", body_bold)],
        ["Bandana Singh", "Chief Executive Officer (CEO)", "Central Executive / All Branches", "Lending Policy, Board Approvals, Bank Ties"],
        ["Pushpraj Singh", "Chief Operating Officer (COO)", "Bhopal HQ & Field Operations", "Credit Approvals, Risk Supervision, Audit"],
        ["Abhinav Rai", "Branch Manager (PPR)", "Pipariya Operational Hub", "Pre-GRT Sanctions, Center Meetings, Operations"],
        ["Tapan Dubey", "Head of Internal Audit", "Head Office / Central Vigilance", "Statutory Compliance, Portfolio Quality Review"],
        ["Yogesh Rajput", "Field Operations Supervisor", "Pipariya & Narmadapuram Belt", "JLG Formations, Field Collections, KYC Punch"]
    ]
    off_table = Table(officer_rows, colWidths=[115, 120, 120, 160])
    off_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor("#0f766e")),
        ('TEXTCOLOR', (0,0), (-1,0), colors.white),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor("#cbd5e1")),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, colors.HexColor("#f8fafc")]),
        ('FONTSIZE', (0,0), (-1,-1), 8),
        ('LEFTPADDING', (0,0), (-1,-1), 4),
        ('RIGHTPADDING', (0,0), (-1,-1), 4),
        ('TOPPADDING', (0,0), (-1,-1), 4),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
    ]))
    story.append(off_table)
    story.append(Spacer(1, 24))

    # Formal Signatures Section
    sig_data = [
        [
            Paragraph("<b>PREPARED & VERIFIED BY:</b><br/><br/><br/>________________________________<br/><b>Tapan Dubey</b><br/>Head of Internal Audit & Vigilance", body_style),
            Paragraph("<b>REVIEWED & CONFIRMED BY:</b><br/><br/><br/>________________________________<br/><b>Pushpraj Singh</b><br/>Chief Operating Officer (COO)", body_style),
            Paragraph("<b>FOR SARVOOCCH MICROCARE FOUNDATION:</b><br/><br/><br/>________________________________<br/><b>Bandana Singh</b><br/>Chief Executive Officer / Director", body_style)
        ]
    ]
    sig_table = Table(sig_data, colWidths=[171, 171, 173])
    sig_table.setStyle(TableStyle([
        ('ALIGN', (0,0), (-1,-1), 'CENTER'),
        ('VALIGN', (0,0), (-1,-1), 'BOTTOM'),
        ('TOPPADDING', (0,0), (-1,-1), 8),
        ('BOTTOMPADDING', (0,0), (-1,-1), 8),
        ('LEFTPADDING', (0,0), (-1,-1), 4),
        ('RIGHTPADDING', (0,0), (-1,-1), 4),
    ]))
    story.append(sig_table)
    story.append(Spacer(1, 15))

    # Seal Note
    seal_p = Paragraph(
        "<i>[Affix Official Company Seal Here] — Digitally archived on SARVOOCCH Microcare Central Repository. "
        "Verification hash: SMF-SHA256-749A9B2E40182C6. Confidential for statutory and operational review only.</i>",
        ParagraphStyle('SealText', parent=body_style, fontSize=7.5, textColor=colors.HexColor("#64748b"), alignment=1)
    )
    story.append(seal_p)

    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"PDF successfully built: {PDF_PATH} ({os.path.getsize(PDF_PATH)} bytes)")

if __name__ == "__main__":
    build_pdf()
