import os
import sys
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, Image, PageBreak
)
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.pdfgen import canvas

LOGO_PATH = "/Users/vaidik/sarvocch_repo/static_website/LOGO_1.jpg"
DESKTOP_DIR = "/Users/vaidik/Desktop"

class BaseLetterheadCanvas(canvas.Canvas):
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
            self.draw_decorations(num_pages)
            super().showPage()
        super().save()

    def draw_decorations(self, page_count):
        self.saveState()
        # Bottom footer line
        self.setStrokeColor(colors.HexColor("#cbd5e1"))
        self.setLineWidth(0.5)
        self.line(40, 42, 555, 42)

        # Footer text
        self.setFont("Helvetica", 7.5)
        self.setFillColor(colors.HexColor("#64748b"))
        footer_text = "SARVOOCCH Microcare Foundation | CIN: U88900MP2026NPL084139 | Regd. Office: Sagar High Street, Ayodhya Bypass, Bhopal - 462041 | Helpline: +91 91111 99101"
        self.drawCentredString(297.5, 30, footer_text)

        if page_count > 1:
            page_str = f"Page {self._pageNumber} of {page_count}"
            self.drawRightString(555, 30, page_str)
        else:
            self.drawRightString(555, 30, "Official Letterhead")

        self.restoreState()

def create_header_flowables():
    styles = getSampleStyleSheet()
    header_meta = ParagraphStyle(
        'HeaderMeta',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=7.5,
        leading=10.5,
        textColor=colors.HexColor("#475569"),
        alignment=2 # Right aligned
    )

    logo_img = Image(LOGO_PATH, width=140, height=44)
    header_text = """
    <b><font size="10.5" color="#0f766e">SARVOOCCH MICROCARE FOUNDATION</font></b><br/>
    <font size="7.5"><b>Section 8 Microfinance Institution</b> | CIN: <b>U88900MP2026NPL084139</b><br/>
    RoC Gwalior | Regd. Off: Shop No. 10A/GF, Sagar High Street, Ayodhya Bypass, Bhopal - 462041<br/>
    Correspondence: <b>sarvocchmicrocare@gmail.com</b> | Helpline: <b>+91 91111 99101</b><br/>
    Official Web Portal: <b>https://sarvocchfinance.com/portal</b></font>
    """
    header_p = Paragraph(header_text, header_meta)

    hdr_table = Table([[logo_img, header_p]], colWidths=[145, 370])
    hdr_table.setStyle(TableStyle([
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('BOTTOMPADDING', (0,0), (-1,-1), 2),
        ('TOPPADDING', (0,0), (-1,-1), 0),
        ('LEFTPADDING', (0,0), (-1,-1), 0),
        ('RIGHTPADDING', (0,0), (-1,-1), 0),
    ]))

    # Dual accent lines table
    line_data = [[""], [""]]
    line_table = Table(line_data, colWidths=[515], rowHeights=[3, 2])
    line_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (0,0), colors.HexColor("#0f766e")),
        ('BACKGROUND', (0,1), (0,1), colors.HexColor("#d97706")),
        ('TOPPADDING', (0,0), (-1,-1), 0),
        ('BOTTOMPADDING', (0,0), (-1,-1), 0),
        ('LEFTPADDING', (0,0), (-1,-1), 0),
        ('RIGHTPADDING', (0,0), (-1,-1), 0),
    ]))

    return [hdr_table, Spacer(1, 4), line_table, Spacer(1, 10)]

def build_blank_single(out_path):
    doc = SimpleDocTemplate(
        out_path,
        pagesize=A4,
        leftMargin=40,
        rightMargin=40,
        topMargin=36,
        bottomMargin=50
    )

    styles = getSampleStyleSheet()
    meta_style = ParagraphStyle(
        'MetaStyle',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=9,
        leading=13,
        textColor=colors.HexColor("#334155")
    )

    story = []
    # Header
    story.extend(create_header_flowables())

    # Reference & Date Bar
    ref_date_data = [
        [
            Paragraph("<b>Ref. No.:</b> SMF / ____________________ / 2026-27", meta_style),
            Paragraph("<div align='right'><b>Date:</b> _____ / _____ / 202___</div>", meta_style)
        ]
    ]
    ref_table = Table(ref_date_data, colWidths=[315, 200])
    ref_table.setStyle(TableStyle([
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('TOPPADDING', (0,0), (-1,-1), 2),
        ('BOTTOMPADDING', (0,0), (-1,-1), 2),
        ('LEFTPADDING', (0,0), (-1,-1), 0),
        ('RIGHTPADDING', (0,0), (-1,-1), 0),
    ]))
    story.append(ref_table)

    # Large Blank Workspace (Spacer)
    # Total available printable height ~ 680 pt
    # Header ~ 75 pt, Ref ~ 20 pt, Signatory ~ 130 pt, Footer ~ 45 pt -> Spacer ~ 410 pt
    story.append(Spacer(1, 440))

    # Signatory Block at bottom right
    sig_data = [
        [
            "",
            Paragraph(
                "<b>For SARVOOCCH MICROCARE FOUNDATION</b><br/><br/><br/><br/>"
                "__________________________________________<br/>"
                "<b>Authorized Signatory / Branch Manager</b><br/>"
                "<font size='7.5' color='#64748b'>[ Affix Official Seal / Stamp Here ]</font>",
                ParagraphStyle('SigBlock', parent=meta_style, fontSize=8.5, leading=12, alignment=2)
            )
        ]
    ]
    sig_table = Table(sig_data, colWidths=[245, 270])
    sig_table.setStyle(TableStyle([
        ('VALIGN', (0,0), (-1,-1), 'BOTTOM'),
        ('TOPPADDING', (0,0), (-1,-1), 0),
        ('BOTTOMPADDING', (0,0), (-1,-1), 0),
        ('LEFTPADDING', (0,0), (-1,-1), 0),
        ('RIGHTPADDING', (0,0), (-1,-1), 0),
    ]))
    story.append(sig_table)

    doc.build(story, canvasmaker=BaseLetterheadCanvas)
    print(f"Blank Letterhead generated: {out_path} ({os.path.getsize(out_path)} bytes)")

def build_formal_template(out_path):
    doc = SimpleDocTemplate(
        out_path,
        pagesize=A4,
        leftMargin=40,
        rightMargin=40,
        topMargin=36,
        bottomMargin=50
    )

    styles = getSampleStyleSheet()
    meta_style = ParagraphStyle(
        'MetaStyle',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=9,
        leading=13,
        textColor=colors.HexColor("#334155")
    )
    body_style = ParagraphStyle(
        'BodyPrompt',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=9,
        leading=14,
        textColor=colors.HexColor("#1e293b")
    )

    story = []
    story.extend(create_header_flowables())

    # Reference & Date
    ref_date_data = [
        [
            Paragraph("<b>Ref. No.:</b> SMF / ____________________ / 2026-27", meta_style),
            Paragraph("<div align='right'><b>Date:</b> _____ / _____ / 202___</div>", meta_style)
        ]
    ]
    ref_table = Table(ref_date_data, colWidths=[315, 200])
    ref_table.setStyle(TableStyle([
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('TOPPADDING', (0,0), (-1,-1), 2),
        ('BOTTOMPADDING', (0,0), (-1,-1), 2),
        ('LEFTPADDING', (0,0), (-1,-1), 0),
        ('RIGHTPADDING', (0,0), (-1,-1), 0),
    ]))
    story.append(ref_table)
    story.append(Spacer(1, 14))

    # Formal Correspondence Prompts
    story.append(Paragraph("<b>To,</b><br/>"
                           "__________________________________________________________________________________<br/>"
                           "__________________________________________________________________________________<br/>"
                           "__________________________________________________________________________________", body_style))
    story.append(Spacer(1, 12))
    story.append(Paragraph("<b>SUBJECT:</b> ____________________________________________________________________________", body_style))
    story.append(Spacer(1, 14))
    story.append(Paragraph("<b>Dear Sir / Madam,</b>", body_style))
    story.append(Spacer(1, 8))

    # Ruled lines simulating formal correspondence template
    ruled_lines = []
    for _ in range(12):
        ruled_lines.append([""])
    ruled_table = Table(ruled_lines, colWidths=[515], rowHeights=[20]*12)
    ruled_table.setStyle(TableStyle([
        ('LINEBELOW', (0,0), (-1,-1), 0.5, colors.HexColor("#e2e8f0")),
        ('TOPPADDING', (0,0), (-1,-1), 0),
        ('BOTTOMPADDING', (0,0), (-1,-1), 0),
        ('LEFTPADDING', (0,0), (-1,-1), 0),
        ('RIGHTPADDING', (0,0), (-1,-1), 0),
    ]))
    story.append(ruled_table)
    story.append(Spacer(1, 15))

    # Signatory block
    sig_data = [
        [
            Paragraph("<b>Thanking You,</b><br/>Yours Faithfully,", body_style),
            Paragraph(
                "<b>For SARVOOCCH MICROCARE FOUNDATION</b><br/><br/><br/><br/>"
                "__________________________________________<br/>"
                "<b>Authorized Signatory / Branch Manager</b><br/>"
                "<font size='7.5' color='#64748b'>[ Affix Official Seal / Stamp Here ]</font>",
                ParagraphStyle('SigBlock', parent=meta_style, fontSize=8.5, leading=12, alignment=2)
            )
        ]
    ]
    sig_table = Table(sig_data, colWidths=[245, 270])
    sig_table.setStyle(TableStyle([
        ('VALIGN', (0,0), (-1,-1), 'BOTTOM'),
        ('TOPPADDING', (0,0), (-1,-1), 0),
        ('BOTTOMPADDING', (0,0), (-1,-1), 0),
        ('LEFTPADDING', (0,0), (-1,-1), 0),
        ('RIGHTPADDING', (0,0), (-1,-1), 0),
    ]))
    story.append(sig_table)

    doc.build(story, canvasmaker=BaseLetterheadCanvas)
    print(f"Formal Letterhead Template generated: {out_path} ({os.path.getsize(out_path)} bytes)")

def build_print_pack_5pages(out_path):
    doc = SimpleDocTemplate(
        out_path,
        pagesize=A4,
        leftMargin=40,
        rightMargin=40,
        topMargin=36,
        bottomMargin=50
    )

    styles = getSampleStyleSheet()
    meta_style = ParagraphStyle(
        'MetaStyle',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=9,
        leading=13,
        textColor=colors.HexColor("#334155")
    )

    story = []
    for page_idx in range(5):
        story.extend(create_header_flowables())

        ref_date_data = [
            [
                Paragraph("<b>Ref. No.:</b> SMF / ____________________ / 2026-27", meta_style),
                Paragraph("<div align='right'><b>Date:</b> _____ / _____ / 202___</div>", meta_style)
            ]
        ]
        ref_table = Table(ref_date_data, colWidths=[315, 200])
        ref_table.setStyle(TableStyle([
            ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
            ('TOPPADDING', (0,0), (-1,-1), 2),
            ('BOTTOMPADDING', (0,0), (-1,-1), 2),
            ('LEFTPADDING', (0,0), (-1,-1), 0),
            ('RIGHTPADDING', (0,0), (-1,-1), 0),
        ]))
        story.append(ref_table)
        story.append(Spacer(1, 440))

        sig_data = [
            [
                "",
                Paragraph(
                    "<b>For SARVOOCCH MICROCARE FOUNDATION</b><br/><br/><br/><br/>"
                    "__________________________________________<br/>"
                    "<b>Authorized Signatory / Branch Manager</b><br/>"
                    "<font size='7.5' color='#64748b'>[ Affix Official Seal / Stamp Here ]</font>",
                    ParagraphStyle('SigBlock', parent=meta_style, fontSize=8.5, leading=12, alignment=2)
                )
            ]
        ]
        sig_table = Table(sig_data, colWidths=[245, 270])
        sig_table.setStyle(TableStyle([
            ('VALIGN', (0,0), (-1,-1), 'BOTTOM'),
            ('TOPPADDING', (0,0), (-1,-1), 0),
            ('BOTTOMPADDING', (0,0), (-1,-1), 0),
            ('LEFTPADDING', (0,0), (-1,-1), 0),
            ('RIGHTPADDING', (0,0), (-1,-1), 0),
        ]))
        story.append(sig_table)

        if page_idx < 4:
            story.append(PageBreak())

    doc.build(story, canvasmaker=BaseLetterheadCanvas)
    print(f"5-Page Print Pack generated: {out_path} ({os.path.getsize(out_path)} bytes)")

if __name__ == "__main__":
    p1 = os.path.join(DESKTOP_DIR, "SARVOOCCH_OFFICIAL_LETTERHEAD_BLANK.pdf")
    p2 = os.path.join(DESKTOP_DIR, "SARVOOCCH_LETTERHEAD_FORMAL_TEMPLATE.pdf")
    p3 = os.path.join(DESKTOP_DIR, "SARVOOCCH_LETTERHEAD_PRINT_PACK_5PAGES.pdf")
    
    build_blank_single(p1)
    build_formal_template(p2)
    build_print_pack_5pages(p3)

    # Also keep copies in docs/reports in repo
    repo_docs = "/Users/vaidik/sarvocch_repo/docs/reports"
    os.makedirs(repo_docs, exist_ok=True)
    import shutil
    shutil.copy2(p1, os.path.join(repo_docs, "SARVOOCCH_OFFICIAL_LETTERHEAD_BLANK.pdf"))
    shutil.copy2(p2, os.path.join(repo_docs, "SARVOOCCH_LETTERHEAD_FORMAL_TEMPLATE.pdf"))
    shutil.copy2(p3, os.path.join(repo_docs, "SARVOOCCH_LETTERHEAD_PRINT_PACK_5PAGES.pdf"))
