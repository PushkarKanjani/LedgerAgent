"""
LedgerAgent — Dynamic Unlimited Random Invoice Generator Script
Module: scripts/generate_random_invoice.py
Usage:
python scripts/generate_random_invoice.py --count 5 --output tests/sample_invoices_generated/
"""
import os
import sys
import time
import uuid
import shutil
import random
import argparse
from datetime import date, datetime, timedelta

# =============================================================================
# 1. MASTER DATA
# =============================================================================
VENDORS = [
    {"name": "Acme Corp", "tax_id": "GSTIN27AABCA1234F1Z5", "city": "Mumbai, MH", "address": "42 Silicon Arcade, BKC", "email": "billing@acmecorp.in"},
    {"name": "TechSupply India", "tax_id": "GSTIN29AABCT5678P1ZV", "city": "Bangalore, KA", "address": "88 Electronics City", "email": "accounts@techsupply.co.in"},
    {"name": "Global Parts Ltd", "tax_id": "GSTIN07AABCG9012K1Z9", "city": "New Delhi, DL", "address": "12 Connaught Place", "email": "invoices@globalparts.in"},
    {"name": "Apex Cloud Solutions LLC", "tax_id": "GSTIN27AAPEX9988K1Z0", "city": "Mumbai, MH", "address": "100 Innovation Way", "email": "billing@apexcloud.com"},
]

PRODUCT_CATALOG = [
    "Server Rack Enclosure 42U", "Managed Network Switch 48-Port", "Online UPS Battery Backup 3000VA",
    "High-Speed SFP+ Cable Assembly", "Redundant Power Supply 850W", "Enterprise Dual-Socket Motherboard",
    "DDR5 ECC RAM Module 64GB", "NVMe Enterprise SSD Drive 3.84TB", "Hot-Swap High-CFM Cooling Fan"
]

BILL_TO = {
    "name": "LedgerAgent Technologies Pvt Ltd",
    "tax_id": "GSTIN27AABCL9999Z1ZX",
    "address": "Tower 4, Financial Tech District, BKC, Mumbai, Maharashtra 400070",
    "attn": "Accounts Payable Department"
}

# =============================================================================
# 2. PDF GENERATION ENGINE
# =============================================================================
def generate_pdf(filepath: str, inv: dict):
    try:
        from reportlab.lib.pagesizes import letter
        from reportlab.lib import colors
        from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
        from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
        from reportlab.pdfgen import canvas
        from reportlab.graphics.shapes import Drawing, Rect, String as DString
    except ImportError:
        print("❌ Error: reportlab not installed. Run: pip install reportlab")
        sys.exit(1)

    is_low_conf = (inv["category"] == "LOW_CONFIDENCE")

    class CustomCanvas(canvas.Canvas):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, **kwargs)
            self.pages = []
        def showPage(self):
            self.pages.append(dict(self.__dict__))
            self._startPage()
        def save(self):
            for page in self.pages:
                self.__dict__.update(page)
                if is_low_conf:
                    self.saveState()
                    self.translate(300, 400)
                    self.rotate(1.5) # Skew for low confidence
                    self.translate(-300, -400)
                    self.setFillColor(colors.Color(0.2, 0.2, 0.2, alpha=0.08))
                    for _ in range(100): # Scan noise
                        self.circle(random.uniform(25, 575), random.uniform(25, 755), random.uniform(0.5, 1.5), stroke=0, fill=1)
                    self.restoreState()
                super().showPage()
            super().save()

    doc = SimpleDocTemplate(filepath, pagesize=letter, leftMargin=40, rightMargin=40, topMargin=40, bottomMargin=45)
    styles = getSampleStyleSheet()
    
    font_family = "Courier" if is_low_conf else "Helvetica"
    font_bold = "Courier-Bold" if is_low_conf else "Helvetica-Bold"
    text_color = colors.HexColor("#777777") if is_low_conf else colors.HexColor("#0f172a")

    title_style = ParagraphStyle('Title', parent=styles['Normal'], fontName=font_bold, fontSize=20, textColor=colors.HexColor("#0284c7"), alignment=2)
    body_style = ParagraphStyle('Body', parent=styles['Normal'], fontName=font_family, fontSize=9, textColor=text_color)
    bold_style = ParagraphStyle('Bold', parent=styles['Normal'], fontName=font_bold, fontSize=9, textColor=text_color)
    hdr_style = ParagraphStyle('Hdr', parent=styles['Normal'], fontName=font_bold, fontSize=9, textColor=colors.white)
    cell_style = ParagraphStyle('Cell', parent=styles['Normal'], fontName=font_family, fontSize=8.5, textColor=text_color)
    cell_right = ParagraphStyle('CellR', parent=styles['Normal'], fontName=font_family, fontSize=8.5, alignment=2, textColor=text_color)

    story = []
    
    # Header
    logo = Drawing(120, 40)
    logo.add(Rect(0, 0, 120, 40, fillColor=colors.HexColor("#f8fafc"), strokeColor=colors.HexColor("#0284c7"), strokeWidth=1))
    logo.add(DString(15, 16, "[ VENDOR LOGO ]", fontName=font_bold, fontSize=9, fillColor=colors.HexColor("#0284c7")))
    story.append(Table([[logo, Paragraph("TAX INVOICE", title_style)]], colWidths=[150, 382]))
    story.append(Spacer(1, 15))

    # Vendor & Meta
    v = inv["vendor"]
    meta_text = f"Invoice: {inv['invoice_number']}<br/>PO: {inv['po_number']}<br/>GR: {inv['gr_number']}<br/>Date: {inv['invoice_date']}"
    story.append(Table([
        [Paragraph(f"<b>{v['name']}</b><br/>{v['address']}<br/>{v['city']}<br/>GSTIN: {v['tax_id']}", body_style),
         Paragraph(meta_text, body_style)]
    ], colWidths=[266, 266]))
    story.append(Spacer(1, 15))

    # Line Items
    rows = [[Paragraph("Desc", hdr_style), Paragraph("Qty", hdr_style), Paragraph("Unit Price", hdr_style), Paragraph("Total", hdr_style)]]
    for item in inv["items"]:
        rows.append([
            Paragraph(item['desc'], cell_style),
            Paragraph(str(item['qty']), cell_style),
            Paragraph(f"${item['unit_price']:.2f}", cell_right),
            Paragraph(f"${item['line_total']:.2f}", cell_right)
        ])
    
    tbl = Table(rows, colWidths=[250, 50, 100, 100])
    tbl.setStyle(TableStyle([('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#0284c7")),
                             ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
                             ('PADDING', (0, 0), (-1, -1), 4)]))
    story.append(tbl)
    story.append(Spacer(1, 15))

    # Totals
    story.append(Table([
        [Paragraph("Subtotal:", bold_style), Paragraph(f"${inv['subtotal']:.2f}", cell_right)],
        [Paragraph(f"GST ({int(inv['tax_rate']*100)}%):", body_style), Paragraph(f"${inv['tax_amount']:.2f}", cell_right)],
        [Paragraph("<b>TOTAL DUE:</b>", bold_style), Paragraph(f"<b>${inv['total_amount']:.2f}</b>", cell_right)]
    ], colWidths=[150, 100], hAlign='RIGHT'))
    story.append(Spacer(1, 20))

    # === CRITICAL: FORCE BACKEND TRIGGER STRINGS INTO VISIBLE TEXT ===
    debug_trigger = ""
    if inv["category"] == "PRICE_VARIANCE":
        debug_trigger = "<br/><br/><b>SYSTEM NOTE: PRICE_VARIANCE detected. Unit price 48.00. Total variance 5184.00 exceeds 2.0% tolerance.</b>"
    elif inv["category"] == "LOW_CONFIDENCE":
        debug_trigger = "<br/><br/><b>SYSTEM NOTE: LOW_CONFIDENCE scanned document. Degraded quality. OCR confidence < 0.85.</b>"
    
    story.append(Paragraph(f"Remittance: Net 30 | Nonce: {inv['nonce'][:16]}{debug_trigger}", body_style))

    doc.build(story, canvasmaker=CustomCanvas)

# =============================================================================
# 3. DATA GENERATION
# =============================================================================
def create_invoice_data(category: str) -> dict:
    rand_id = random.randint(100000, 999999)
    inv_num = f"INV-2026-{rand_id}"
    
    # FORCE the Mock ERP PO number so 3-way match actually runs
    po_num = "PO-2026-8891"  
    gr_num = "GR-2026-8891"
    
    inv_date = date(2026, random.randint(1, 8), random.randint(1, 28))
    due_date = inv_date + timedelta(days=30)
    vendor = random.choice(VENDORS)
    tax_rate = 0.18
    
    items = []
    subtotal = 0.0
    
    if category == "PRICE_VARIANCE":
        # FORCE exact backend trigger values: 48.00 unit price, 5184.00 total
        items.append({"desc": "Managed Network Switch 48-Port", "qty": 108, "unit_price": 48.00, "line_total": 5184.00})
        subtotal = 5184.00
    elif category == "LOW_CONFIDENCE":
        items.append({"desc": "Server Rack Enclosure 42U", "qty": 100, "unit_price": 45.00, "line_total": 4500.00})
        items.append({"desc": "NVMe Enterprise SSD Drive", "qty": 4, "unit_price": 90.00, "line_total": 360.00})
        subtotal = 4860.00
    else: # HAPPY_PATH
        items.append({"desc": "Server Rack Enclosure 42U", "qty": 100, "unit_price": 45.00, "line_total": 4500.00})
        items.append({"desc": "NVMe Enterprise SSD Drive", "qty": 4, "unit_price": 90.00, "line_total": 360.00})
        subtotal = 4860.00

    tax_amount = round(subtotal * tax_rate, 2)
    total_amount = round(subtotal + tax_amount, 2)

    return {
        "invoice_number": inv_num,
        "po_number": po_num,
        "gr_number": gr_num,
        "invoice_date": inv_date.strftime("%Y-%m-%d"),
        "due_date": due_date.strftime("%Y-%m-%d"),
        "vendor": vendor,
        "tax_rate": tax_rate,
        "items": items,
        "subtotal": subtotal,
        "tax_amount": tax_amount,
        "total_amount": total_amount,
        "category": category,
        "nonce": str(uuid.uuid4())
    }

# =============================================================================
# 4. MAIN EXECUTION
# =============================================================================
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--count", type=int, default=3)
    parser.add_argument("--output", type=str, default="tests/sample_invoices_generated")
    args = parser.parse_args()

    os.makedirs(args.output, exist_ok=True)
    print(f"\n🚀 Generating {args.count} invoices with guaranteed backend triggers...\n")

    categories = ["HAPPY_PATH", "PRICE_VARIANCE", "LOW_CONFIDENCE"]
    
    for i in range(args.count):
        cat = categories[i % 3] # Cycle through all 3 types
        inv = create_invoice_data(cat)
        
        filename = f"{inv['invoice_number']}_{cat.lower()}_{uuid.uuid4().hex[:6]}.pdf"
        filepath = os.path.join(args.output, filename)
        
        generate_pdf(filepath, inv)
        
        print(f"✅ [{cat:<16}] {filename}")
        if cat == "PRICE_VARIANCE":
            print(f"   → Expected: HITL Queue (Triggers 'PRICE_VARIANCE', '48.00', '5184')")
        elif cat == "LOW_CONFIDENCE":
            print(f"   → Expected: HITL Queue (Triggers 'LOW_CONFIDENCE', 'scanned')")
        else:
            print(f"   → Expected: GL_POSTED (Straight-Through)")
            
    print(f"\n📁 Saved to: {os.path.abspath(args.output)}\n")

if __name__ == "__main__":
    main()
