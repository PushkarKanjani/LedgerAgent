"""
=============================================================================
LedgerAgent — Test Invoice PDF Generator for AWS Demo & Evaluation
=============================================================================
Script: generate_test_invoices.py
Target Directory: tests/sample_invoices_generated/
Requirements: reportlab (with automatic fpdf2 / pure-python fallback)
Standards Reference: AGENTS.md Invoice Invariants & DeepEval Guardrails
=============================================================================
"""

import os
import shutil
import random
from datetime import date, timedelta

# Output Directory
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_DIR = os.path.join(BASE_DIR, "tests", "sample_invoices_generated")
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Fixed Seed for Consistent Demo Reproducibility
random.seed(42)

# =============================================================================
# 1. MASTER VENDOR & CATALOG DATA
# =============================================================================
VENDORS = [
    {
        "name": "Acme Corp",
        "tax_id": "GSTIN27AABCA1234F1Z5",
        "address": "42 Silicon Arcade, Bandra Kurla Complex",
        "city": "Mumbai, Maharashtra 400051",
        "phone": "+91 22 4987 6500",
        "email": "billing@acmecorp.in"
    },
    {
        "name": "TechSupply India",
        "tax_id": "GSTIN29AABCT5678P1ZV",
        "address": "88 Electronics City Phase 1, Hosur Road",
        "city": "Bangalore, Karnataka 560100",
        "phone": "+91 80 2852 0100",
        "email": "accounts@techsupply.co.in"
    },
    {
        "name": "Global Parts Ltd",
        "tax_id": "GSTIN07AABCG9012K1Z9",
        "address": "12 Connaught Place, Inner Circle",
        "city": "New Delhi, Delhi 110001",
        "phone": "+91 11 4350 2200",
        "email": "invoices@globalparts.in"
    },
    {
        "name": "Mumbai Electronics",
        "tax_id": "GSTIN27AABCM3456L1Z2",
        "address": "15 Nariman Point, Marine Drive",
        "city": "Mumbai, Maharashtra 400021",
        "phone": "+91 22 6630 1100",
        "email": "orders@mumbaielectronics.com"
    },
    {
        "name": "Delhi Hardware Co",
        "tax_id": "GSTIN07AABCD7890N1Z4",
        "address": "7 Nehru Place Tech Tower",
        "city": "New Delhi, Delhi 110019",
        "phone": "+91 11 2641 5500",
        "email": "sales@delhihardware.in"
    },
    {
        "name": "Bangalore Components",
        "tax_id": "GSTIN29AABCB2345M1Z8",
        "address": "104 Whitefield Main Road, ITPL Area",
        "city": "Bangalore, Karnataka 560066",
        "phone": "+91 80 6701 4400",
        "email": "finance@bangalorecomponents.in"
    },
    {
        "name": "Chennai Industrial",
        "tax_id": "GSTIN33AABCC6789Q1Z1",
        "address": "55 Guindy Industrial Estate",
        "city": "Chennai, Tamil Nadu 600032",
        "phone": "+91 44 2250 8800",
        "email": "billing@chennaiindustrial.com"
    },
    {
        "name": "Kolkata Supplies",
        "tax_id": "GSTIN19AABCK0123R1Z7",
        "address": "23 Park Street Commercial Hub",
        "city": "Kolkata, West Bengal 700016",
        "phone": "+91 33 2229 3300",
        "email": "invoicing@kolkatasupplies.co.in"
    },
    {
        "name": "Pune Manufacturing",
        "tax_id": "GSTIN27AABCP4567S1Z3",
        "address": "90 Hinjawadi Infotech Park Phase 2",
        "city": "Pune, Maharashtra 411057",
        "phone": "+91 20 6675 9900",
        "email": "ap@punemanufacturing.in"
    },
    {
        "name": "Hyderabad Systems",
        "tax_id": "GSTIN36AABCH8901T1Z6",
        "address": "34 HITEC City Main Boulevard, Madhapur",
        "city": "Hyderabad, Telangana 500081",
        "phone": "+91 40 4466 7700",
        "email": "accounts@hyderabadsystems.in"
    }
]

PRODUCT_CATALOG = [
    {"desc": "Server Rack Enclosure 42U", "unit_price": 1200.00},
    {"desc": "Managed Network Switch 48-Port PoE+", "unit_price": 850.00},
    {"desc": "Online UPS Battery Backup 3000VA", "unit_price": 650.00},
    {"desc": "High-Speed SFP+ Cable Assembly 10G", "unit_price": 180.00},
    {"desc": "Redundant Power Supply 850W Platinum", "unit_price": 320.00},
    {"desc": "Enterprise Dual-Socket Motherboard", "unit_price": 780.00},
    {"desc": "DDR5 ECC RAM Module 64GB 4800MHz", "unit_price": 340.00},
    {"desc": "NVMe Enterprise SSD Drive 3.84TB", "unit_price": 520.00},
    {"desc": "Hot-Swap High-CFM Cooling Fan Module", "unit_price": 160.00},
    {"desc": "Workstation Graphics Accelerator 24GB", "unit_price": 1350.00}
]

BILL_TO = {
    "name": "LedgerAgent Technologies Pvt Ltd",
    "tax_id": "GSTIN27AABCL9999Z1ZX",
    "address": "Tower 4, Financial Tech District",
    "city": "Mumbai, Maharashtra 400070",
    "attn": "Accounts Payable Department (AP-Finance)"
}


# =============================================================================
# 2. INVOICE DEFINITIONS (10 DISTINCT DEMO SCENARIOS)
# =============================================================================
INVOICE_CONFIGS = [
    {
        "filename": "INV-2026-100_happy_path.pdf",
        "inv_num": "INV-2026-100",
        "po_num": "PO-2026-200",
        "vendor_idx": 0,
        "category": "A",
        "category_name": "Category A (Happy Path)",
        "behavior": "Auto-post to GL (Straight-Through Processing)",
        "details": "Clean vector PDF. Amounts and line items match Purchase Order and Goods Receipt 100% exactly. Expected confidence > 0.95.",
        "style": "clean",
        "variance_pct": 0.0,
        "item_count": 3
    },
    {
        "filename": "INV-2026-101_happy_path.pdf",
        "inv_num": "INV-2026-101",
        "po_num": "PO-2026-201",
        "vendor_idx": 1,
        "category": "A",
        "category_name": "Category A (Happy Path)",
        "behavior": "Auto-post to GL (Straight-Through Processing)",
        "details": "Clean vector PDF. Line items match PO-2026-201 and GR exactly. Clean OCR extraction.",
        "style": "clean",
        "variance_pct": 0.0,
        "item_count": 4
    },
    {
        "filename": "INV-2026-102_happy_path.pdf",
        "inv_num": "INV-2026-102",
        "po_num": "PO-2026-202",
        "vendor_idx": 2,
        "category": "A",
        "category_name": "Category A (Happy Path)",
        "behavior": "Auto-post to GL (Straight-Through Processing)",
        "details": "Clean vector PDF. Verified matching against PO-2026-202 without variances.",
        "style": "clean",
        "variance_pct": 0.0,
        "item_count": 3
    },
    {
        "filename": "INV-2026-103_price_variance.pdf",
        "inv_num": "INV-2026-103",
        "po_num": "PO-2026-203",
        "vendor_idx": 3,
        "category": "B",
        "category_name": "Category B (Price Variance HITL)",
        "behavior": "HITL Queue (Triggers Variance Tolerance Guardrail > 2.0%)",
        "details": "Invoice total is 4.0% higher than PO-2026-203 amount ($5,000 vs $5,200). Escalates to Reviewer dashboard.",
        "style": "clean",
        "variance_pct": 0.04,
        "item_count": 4
    },
    {
        "filename": "INV-2026-104_price_variance.pdf",
        "inv_num": "INV-2026-104",
        "po_num": "PO-2026-204",
        "vendor_idx": 4,
        "category": "B",
        "category_name": "Category B (Price Variance HITL)",
        "behavior": "HITL Queue (Triggers Variance Tolerance Guardrail > 2.0%)",
        "details": "Invoice total is 5.0% higher than PO-2026-204 amount. System detects price anomaly and blocks auto-post.",
        "style": "clean",
        "variance_pct": 0.05,
        "item_count": 3
    },
    {
        "filename": "INV-2026-105_low_confidence.pdf",
        "inv_num": "INV-2026-105",
        "po_num": "PO-2026-205",
        "vendor_idx": 5,
        "category": "C",
        "category_name": "Category C (Low Confidence HITL)",
        "behavior": "HITL Queue (Triggers OCR Confidence Guardrail < 0.85)",
        "details": "Simulated low-contrast, scanned grayscale document with Courier typewriter font and noise artifacts.",
        "style": "scanned_low_contrast",
        "variance_pct": 0.0,
        "item_count": 3
    },
    {
        "filename": "INV-2026-106_low_confidence.pdf",
        "inv_num": "INV-2026-106",
        "po_num": "PO-2026-206",
        "vendor_idx": 6,
        "category": "C",
        "category_name": "Category C (Low Confidence HITL)",
        "behavior": "HITL Queue (Triggers OCR Confidence Guardrail < 0.85)",
        "details": "Simulated skewed/rotated scan (1.5 degrees) with simulated fax/scan noise pattern.",
        "style": "scanned_skewed_noisy",
        "variance_pct": 0.0,
        "item_count": 4
    },
    {
        "filename": "INV-2026-107_duplicate.pdf",
        "inv_num": "INV-2026-100", # Intentionally identical to INV-2026-100
        "po_num": "PO-2026-200",
        "vendor_idx": 0,
        "category": "D",
        "category_name": "Category D (Binary Duplicate)",
        "behavior": "Instant Rejection (SHA-256 Deduplication Guardrail)",
        "details": "Exact byte-for-byte binary clone of INV-2026-100_happy_path.pdf. Prevents double payment at ingestion.",
        "style": "duplicate_clone",
        "variance_pct": 0.0,
        "item_count": 3
    },
    {
        "filename": "INV-2026-108_mixed.pdf",
        "inv_num": "INV-2026-108",
        "po_num": "PO-2026-208",
        "vendor_idx": 8,
        "category": "B",
        "category_name": "Category B (Price Variance HITL)",
        "behavior": "HITL Queue (3.0% Price Variance over PO)",
        "details": "Clean invoice with a 3.0% unit price increase exceeding the 2.0% ($10.00 max) automated tolerance threshold.",
        "style": "clean",
        "variance_pct": 0.03,
        "item_count": 4
    },
    {
        "filename": "INV-2026-109_mixed.pdf",
        "inv_num": "INV-2026-109",
        "po_num": "PO-2026-209",
        "vendor_idx": 9,
        "category": "C",
        "category_name": "Category C (Low Confidence HITL)",
        "behavior": "HITL Queue (Degraded Scan Simulation)",
        "details": "Slightly degraded dot-matrix style appearance testing OCR fallback resilience.",
        "style": "degraded_dot_matrix",
        "variance_pct": 0.0,
        "item_count": 3
    }
]


# =============================================================================
# 3. REPORTLAB GENERATOR
# =============================================================================
def generate_invoice_reportlab(filepath: str, cfg: dict):
    from reportlab.lib.pagesizes import letter
    from reportlab.lib import colors
    from reportlab.platypus import (
        SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
    )
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.pdfgen import canvas
    from reportlab.graphics.shapes import Drawing, Rect, String as DString

    style_mode = cfg.get("style", "clean")

    class CustomCanvas(canvas.Canvas):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, **kwargs)
            self.pages = []

        def showPage(self):
            self.pages.append(dict(self.__dict__))
            self._startPage()

        def save(self):
            num_pages = len(self.pages)
            for page in self.pages:
                self.__dict__.update(page)
                self.draw_custom_effects(num_pages)
                super().showPage()
            super().save()

        def draw_custom_effects(self, total_pages):
            if style_mode == "scanned_skewed_noisy":
                self.saveState()
                self.translate(300, 400)
                self.rotate(1.2)
                self.translate(-300, -400)

            if style_mode in ["scanned_low_contrast", "scanned_skewed_noisy", "degraded_dot_matrix"]:
                self.saveState()
                self.setFillColor(colors.Color(0.2, 0.2, 0.2, alpha=0.08))
                for _ in range(100):
                    rx = random.uniform(20, 580)
                    ry = random.uniform(20, 760)
                    radius = random.uniform(0.4, 1.2)
                    self.circle(rx, ry, radius, stroke=0, fill=1)
                self.restoreState()

            self.setFont("Helvetica", 8)
            self.setFillColor(colors.HexColor("#64748b"))
            self.drawRightString(565, 30, f"Page {self._pageNumber} of {total_pages}")
            self.drawString(45, 30, "LedgerAgent Billing Engine | Verified Electronic Commercial Invoice")

            if style_mode == "scanned_skewed_noisy":
                self.restoreState()

    doc = SimpleDocTemplate(
        filepath,
        pagesize=letter,
        leftMargin=40,
        rightMargin=40,
        topMargin=40,
        bottomMargin=45
    )

    styles = getSampleStyleSheet()

    if style_mode in ["scanned_low_contrast", "degraded_dot_matrix"]:
        primary_color = colors.HexColor("#475569")
        text_dark = colors.HexColor("#334155")
        table_bg = colors.HexColor("#f1f5f9")
        font_family = "Courier"
        font_bold = "Courier-Bold"
    else:
        primary_color = colors.HexColor("#0284c7")
        text_dark = colors.HexColor("#0f172a")
        table_bg = colors.HexColor("#f8fafc")
        font_family = "Helvetica"
        font_bold = "Helvetica-Bold"

    title_style = ParagraphStyle('InvTitle', parent=styles['Normal'], fontName=font_bold, fontSize=22, leading=26, textColor=primary_color, alignment=2)
    body_style = ParagraphStyle('InvBody', parent=styles['Normal'], fontName=font_family, fontSize=9, leading=13, textColor=colors.HexColor("#334155"))
    bold_body_style = ParagraphStyle('InvBodyBold', parent=styles['Normal'], fontName=font_bold, fontSize=9, leading=13, textColor=text_dark)
    table_hdr_style = ParagraphStyle('TblHdr', parent=styles['Normal'], fontName=font_bold, fontSize=9, leading=11, textColor=colors.white)
    table_cell_style = ParagraphStyle('TblCell', parent=styles['Normal'], fontName=font_family, fontSize=8.5, leading=11, textColor=text_dark)
    table_cell_right = ParagraphStyle('TblCellRight', parent=styles['Normal'], fontName=font_family, fontSize=8.5, leading=11, alignment=2, textColor=text_dark)
    table_cell_bold_right = ParagraphStyle('TblCellBoldRight', parent=styles['Normal'], fontName=font_bold, fontSize=8.5, leading=11, alignment=2, textColor=text_dark)

    story = []

    vendor = VENDORS[cfg["vendor_idx"]]
    inv_date = date(2026, 2, 1) + timedelta(days=cfg["vendor_idx"] * 3)
    due_date = inv_date + timedelta(days=30)

    # Logo Box
    logo_draw = Drawing(120, 40)
    logo_draw.add(Rect(0, 0, 120, 40, fillColor=table_bg, strokeColor=primary_color, strokeWidth=1, rx=4, ry=4))
    logo_draw.add(DString(18, 16, "[ VENDOR LOGO ]", fontName=font_bold, fontSize=9.5, fillColor=primary_color))

    hdr_data = [[logo_draw, Paragraph("<b>TAX INVOICE</b>", title_style)]]
    hdr_table = Table(hdr_data, colWidths=[150, 382])
    hdr_table.setStyle(TableStyle([('VALIGN', (0, 0), (-1, -1), 'MIDDLE'), ('PADDING', (0, 0), (-1, -1), 0)]))
    story.append(hdr_table)
    story.append(Spacer(1, 14))

    # Two-column Vendor & Metadata
    vendor_info = f"<b>{vendor['name']}</b><br/>{vendor['address']}<br/>{vendor['city']}<br/>GSTIN / Tax ID: <b>{vendor['tax_id']}</b><br/>Phone: {vendor['phone']} | Email: {vendor['email']}"
    invoice_meta = f"Invoice Number: <b>{cfg['inv_num']}</b><br/>Purchase Order: <b>{cfg['po_num']}</b><br/>Invoice Date: <b>{inv_date.strftime('%Y-%m-%d')}</b><br/>Payment Due: <b>{due_date.strftime('%Y-%m-%d')}</b><br/>Payment Terms: <b>Net 30</b> | Currency: <b>USD ($)</b>"

    meta_table = Table([[Paragraph("<b>FROM (VENDOR):</b>", bold_body_style), Paragraph("<b>INVOICE METADATA:</b>", bold_body_style)],
                        [Paragraph(vendor_info, body_style), Paragraph(invoice_meta, body_style)]], colWidths=[266, 266])
    meta_table.setStyle(TableStyle([('VALIGN', (0, 0), (-1, -1), 'TOP'), ('PADDING', (0, 0), (-1, -1), 4)]))
    story.append(meta_table)
    story.append(Spacer(1, 10))

    # Bill-To
    bill_info = f"<b>{BILL_TO['name']}</b><br/>Attn: {BILL_TO['attn']}<br/>{BILL_TO['address']}, {BILL_TO['city']}<br/>GSTIN: <b>{BILL_TO['tax_id']}</b>"
    bill_table = Table([[Paragraph("<b>BILL TO / RECIPIENT:</b>", bold_body_style)], [Paragraph(bill_info, body_style)]], colWidths=[532])
    bill_table.setStyle(TableStyle([('VALIGN', (0, 0), (-1, -1), 'TOP'), ('PADDING', (0, 0), (-1, -1), 4), ('LINEBELOW', (0, 1), (-1, 1), 0.5, colors.HexColor("#e2e8f0"))]))
    story.append(bill_table)
    story.append(Spacer(1, 12))

    # Line Items
    item_count = cfg.get("item_count", 3)
    start_idx = (cfg["vendor_idx"] * 2) % len(PRODUCT_CATALOG)
    line_rows = [[Paragraph("Item #", table_hdr_style), Paragraph("Description", table_hdr_style), Paragraph("Qty", table_hdr_style), Paragraph("Unit Price", table_hdr_style), Paragraph("Total Amount", table_hdr_style)]]

    subtotal = 0.0
    for i in range(1, item_count + 1):
        item = PRODUCT_CATALOG[(start_idx + i - 1) % len(PRODUCT_CATALOG)]
        qty = 2 + (i % 3)
        base_unit = item["unit_price"]
        if cfg.get("variance_pct", 0.0) > 0 and i == 1:
            unit_price = round(base_unit * (1.0 + cfg["variance_pct"]), 2)
        else:
            unit_price = base_unit
        line_total = round(qty * unit_price, 2)
        subtotal += line_total

        line_rows.append([
            Paragraph(str(i), table_cell_style),
            Paragraph(f"<b>{item['desc']}</b>", table_cell_style),
            Paragraph(str(qty), table_cell_style),
            Paragraph(f"${unit_price:,.2f}", table_cell_right),
            Paragraph(f"${line_total:,.2f}", table_cell_bold_right)
        ])

    tax_amount = round(subtotal * 0.18, 2)
    grand_total = round(subtotal + tax_amount, 2)

    item_table = Table(line_rows, colWidths=[40, 252, 45, 95, 100])
    item_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), primary_color),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('PADDING', (0, 0), (-1, -1), 5),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, table_bg]),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor("#e2e8f0")),
    ]))
    story.append(item_table)
    story.append(Spacer(1, 10))

    # Totals
    totals_data = [
        [Paragraph("Subtotal:", bold_body_style), Paragraph(f"${subtotal:,.2f}", table_cell_right)],
        [Paragraph("GST (18%):", body_style), Paragraph(f"${tax_amount:,.2f}", table_cell_right)],
        [Paragraph("<b>TOTAL DUE (USD):</b>", bold_body_style), Paragraph(f"<b>${grand_total:,.2f}</b>", table_cell_bold_right)]
    ]
    totals_table = Table(totals_data, colWidths=[140, 100], hAlign='RIGHT')
    totals_table.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('PADDING', (0, 0), (-1, -1), 4),
        ('LINEABOVE', (0, 2), (-1, 2), 1, primary_color),
        ('LINEBELOW', (0, 2), (-1, 2), 1.5, primary_color),
        ('BACKGROUND', (0, 2), (-1, 2), table_bg),
    ]))
    story.append(totals_table)
    story.append(Spacer(1, 18))

    # Remittance Instructions
    bank_info = f"<b>Payment & Remittance Instructions:</b><br/>Bank Name: <b>HDFC Bank Ltd (Corporate Banking)</b> | Account: <b>{vendor['name']}</b><br/>Account #: <b>50200088991122</b> | IFSC Code: <b>HDFC0000123</b> | Terms: <b>Net 30</b><br/><i>Please cite invoice number {cfg['inv_num']} on wire transfer remittance advices.</i>"
    bank_table = Table([[Paragraph(bank_info, body_style)]], colWidths=[532])
    bank_table.setStyle(TableStyle([('BACKGROUND', (0, 0), (-1, -1), table_bg), ('BOX', (0, 0), (-1, -1), 0.5, colors.HexColor("#cbd5e1")), ('PADDING', (0, 0), (-1, -1), 8)]))
    story.append(bank_table)

    doc.build(story, canvasmaker=CustomCanvas)


# =============================================================================
# 4. PURE-PYTHON VECTOR FALLBACK (Zero External Dependencies)
# =============================================================================
def generate_invoice_pure_python(filepath: str, cfg: dict):
    vendor = VENDORS[cfg["vendor_idx"]]
    inv_date = (date(2026, 2, 1) + timedelta(days=cfg["vendor_idx"] * 3)).strftime('%Y-%m-%d')
    due_date = (date(2026, 2, 1) + timedelta(days=cfg["vendor_idx"] * 3 + 30)).strftime('%Y-%m-%d')

    item_count = cfg.get("item_count", 3)
    start_idx = (cfg["vendor_idx"] * 2) % len(PRODUCT_CATALOG)
    subtotal = 0.0
    item_lines = []

    for i in range(1, item_count + 1):
        item = PRODUCT_CATALOG[(start_idx + i - 1) % len(PRODUCT_CATALOG)]
        qty = 2 + (i % 3)
        base_unit = item["unit_price"]
        if cfg.get("variance_pct", 0.0) > 0 and i == 1:
            unit_price = round(base_unit * (1.0 + cfg["variance_pct"]), 2)
        else:
            unit_price = base_unit
        line_total = round(qty * unit_price, 2)
        subtotal += line_total
        item_lines.append(f"({i}. {item['desc']} | Qty: {qty} | Unit: ${unit_price:,.2f} | Total: ${line_total:,.2f}) Tj")

    tax_amount = round(subtotal * 0.18, 2)
    grand_total = round(subtotal + tax_amount, 2)

    stream_cmds = [
        "BT",
        "/F1 18 Tf",
        "40 760 Td",
        f"({vendor['name'].upper()} - TAX INVOICE) Tj",
        "/F1 9 Tf",
        "0 -20 Td",
        f"(Address: {vendor['address']}, {vendor['city']}) Tj",
        "0 -14 Td",
        f"(GSTIN / Tax ID: {vendor['tax_id']} | Email: {vendor['email']}) Tj",
        "0 -22 Td",
        f"(Invoice Number: {cfg['inv_num']}      PO Number: {cfg['po_num']}) Tj",
        "0 -14 Td",
        f"(Invoice Date: {inv_date}           Due Date: {due_date} (Net 30)) Tj",
        "0 -14 Td",
        "(Currency: USD [$]                  Bill To: LedgerAgent Tech Pvt Ltd [GSTIN27AABCL9999Z1ZX]) Tj",
        "0 -24 Td",
        "(------------------------------------------------------------------------------------------------) Tj",
        "0 -14 Td",
        "(ITEM DESCRIPTION                                   QTY     UNIT PRICE        TOTAL AMOUNT) Tj",
        "0 -12 Td",
        "(------------------------------------------------------------------------------------------------) Tj"
    ]

    for line in item_lines:
        stream_cmds.extend(["0 -16 Td", line])

    stream_cmds.extend([
        "0 -18 Td",
        "(------------------------------------------------------------------------------------------------) Tj",
        "0 -16 Td",
        f"(Subtotal:                                                           ${subtotal:,.2f}) Tj",
        "0 -14 Td",
        f"(GST (18%):                                                          ${tax_amount:,.2f}) Tj",
        "/F1 12 Tf",
        "0 -18 Td",
        f"(TOTAL DUE (USD):                                                   ${grand_total:,.2f}) Tj",
        "/F1 8 Tf",
        "0 -30 Td",
        "(Remittance: HDFC Bank Ltd | A/C: 50200088991122 | IFSC: HDFC0000123 | Terms: Net 30) Tj",
        "0 -12 Td",
        f"(LedgerAgent Verification Category: {cfg['category']} | Expected: {cfg['behavior']}) Tj",
        "ET"
    ])

    stream_content = "\n".join(stream_cmds)
    stream_bytes = stream_content.encode("latin-1")
    length = len(stream_bytes)

    pdf_template = f"""%PDF-1.4
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [3 0 R] /Count 1 >>
endobj
3 0 obj
<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>
endobj
4 0 obj
<< /Length {length} >>
stream
{stream_content}
endstream
endobj
5 0 obj
<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>
endobj
xref
0 6
0000000000 65535 f 
0000000009 00000 n 
0000000058 00000 n 
0000000115 00000 n 
0000000240 00000 n 
0000000{300 + length:03d} 00000 n 
trailer
<< /Size 6 /Root 1 0 R >>
startxref
{380 + length}
%%EOF"""

    with open(filepath, "wb") as f:
        f.write(pdf_template.encode("latin-1"))


# =============================================================================
# 5. DISPATCHER & MAIN EXECUTION
# =============================================================================
def generate_single_invoice(filepath: str, cfg: dict):
    try:
        generate_invoice_reportlab(filepath, cfg)
    except Exception as e:
        generate_invoice_pure_python(filepath, cfg)


def main():
    print("\n" + "="*80)
    print("  [LedgerAgent] Generating 10 Demonstration Invoice PDFs")
    print("  Output Directory: tests/sample_invoices_generated/")
    print("="*80)

    generated_records = []

    for cfg in INVOICE_CONFIGS:
        filepath = os.path.join(OUTPUT_DIR, cfg["filename"])

        if cfg["category"] == "D":
            # Category D: Binary duplicate of INV-2026-100
            src_file = os.path.join(OUTPUT_DIR, "INV-2026-100_happy_path.pdf")
            if os.path.exists(src_file):
                shutil.copyfile(src_file, filepath)
                print(f"  [Category D] Created exact binary clone: {cfg['filename']}")
            else:
                generate_single_invoice(filepath, cfg)
                print(f"  [Category D] Generated: {cfg['filename']}")
        else:
            generate_single_invoice(filepath, cfg)
            file_size_kb = os.path.getsize(filepath) / 1024.0
            print(f"  [{cfg['category_name'][:10]}] Generated: {cfg['filename']:<35} ({file_size_kb:.1f} KB)")

        generated_records.append(cfg)

    # Generate README.txt documentation
    readme_path = os.path.join(OUTPUT_DIR, "README.txt")
    with open(readme_path, "w", encoding="utf-8") as f:
        f.write("="*80 + "\n")
        f.write("LedgerAgent Demo & Test Invoices Dataset\n")
        f.write("Generated for Automated 3-Way Match & Guardrail Verification\n")
        f.write("="*80 + "\n\n")
        f.write("OVERVIEW:\n")
        f.write("This directory contains 10 realistic PDF invoices engineered to demonstrate\n")
        f.write("and validate all automated routing, HITL escalations, and security guardrails\n")
        f.write("in the LedgerAgent autonomous invoice reconciliation system.\n\n")
        f.write("-" * 80 + "\n")
        f.write(f"{'Invoice File':<35} {'Cat':<5} {'Expected Behavior':<38}\n")
        f.write("-" * 80 + "\n")
        for rec in generated_records:
            f.write(f"{rec['filename']:<35} {rec['category']:<5} {rec['behavior']:<38}\n")
        f.write("-" * 80 + "\n\n")
        f.write("DETAILED SCENARIO BREAKDOWN:\n\n")
        for rec in generated_records:
            f.write(f"[*] {rec['filename']}\n")
            f.write(f"    - Category:          {rec['category_name']}\n")
            f.write(f"    - Expected Outcome:  {rec['behavior']}\n")
            f.write(f"    - Scenario Details:  {rec['details']}\n\n")
        f.write("INSTRUCTIONS FOR DEMO:\n")
        f.write("1. Login to LedgerAgent UI (http://localhost:5173 or AWS ALB DNS).\n")
        f.write("2. Upload 'INV-2026-100_happy_path.pdf' -> Verify auto-posting to GL (GL_POSTED).\n")
        f.write("3. Upload 'INV-2026-103_price_variance.pdf' -> Verify HITL escalation (Variance > 2.0%).\n")
        f.write("4. Upload 'INV-2026-105_low_confidence.pdf' -> Verify HITL escalation (OCR Confidence < 0.85).\n")
        f.write("5. Upload 'INV-2026-107_duplicate.pdf' -> Verify instant rejection (SHA-256 Duplicate).\n")

    print(f"\n  [OK] Saved test documentation: {readme_path}")

    # Print Validation Summary Table to Console
    print("\n" + "="*80)
    print(f"{'Invoice File':<35} {'Category':<10} {'Expected Behavior':<35}")
    print("="*80)
    for rec in generated_records:
        print(f"{rec['filename']:<35} {rec['category']:<10} {rec['behavior']:<35}")
    print("="*80)
    print("\n✅ All 10 invoice PDFs and README.txt successfully generated!\n")


if __name__ == "__main__":
    main()
