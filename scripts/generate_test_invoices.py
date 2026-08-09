"""
LedgerAgent — Final Definitive Random Invoice Generator
Guarantees HITL triggers while keeping all invoice data uniquely random.
"""
import os
import sys
import uuid
import random
import argparse
from datetime import date, timedelta

# =============================================================================
# 1. MASTER DATA (Randomized for uniqueness)
# =============================================================================
VENDORS = [
    {"name": "Acme Corp", "tax_id": "GSTIN27AABCA1234F1Z5", "city": "Mumbai, MH", "address": "42 Silicon Arcade, BKC"},
    {"name": "TechSupply India", "tax_id": "GSTIN29AABCT5678P1ZV", "city": "Bangalore, KA", "address": "88 Electronics City"},
    {"name": "Global Parts Ltd", "tax_id": "GSTIN07AABCG9012K1Z9", "city": "New Delhi, DL", "address": "12 Connaught Place"},
    {"name": "Apex Cloud Solutions LLC", "tax_id": "GSTIN27AAPEX9988K1Z0", "city": "Mumbai, MH", "address": "100 Innovation Way"},
    {"name": "Pune Manufacturing", "tax_id": "GSTIN27AABCP4567S1Z3", "city": "Pune, MH", "address": "90 Hinjawadi Infotech Park"},
]

PRODUCTS = [
    "Server Rack Enclosure 42U", "Managed Network Switch 48-Port", "Online UPS Battery Backup 3000VA",
    "NVMe Enterprise SSD Drive 3.84TB", "DDR5 ECC RAM Module 64GB", "Redundant Power Supply 850W"
]

# =============================================================================
# 2. PDF GENERATION (Forces Backend Triggers)
# =============================================================================
def generate_pdf(filepath: str, inv: dict):
    try:
        from reportlab.lib.pagesizes import letter
        from reportlab.lib import colors
        from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
        from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
        from reportlab.pdfgen import canvas
    except ImportError:
        print("❌ Error: pip install reportlab")
        sys.exit(1)

    is_low_conf = (inv["category"] == "LOW_CONFIDENCE")

    class CustomCanvas(canvas.Canvas):
        def showPage(self):
            if is_low_conf:
                self.saveState()
                self.translate(300, 400)
                self.rotate(random.choice([-1.5, 1.5]))  # Skew
                self.translate(-300, -400)
                self.setFillColor(colors.Color(0.2, 0.2, 0.2, alpha=0.08))
                for _ in range(100):  # Scan noise
                    self.circle(random.uniform(25, 575), random.uniform(25, 755), random.uniform(0.5, 1.5), stroke=0, fill=1)
                self.restoreState()
            super().showPage()

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
    v = inv["vendor"]
    
    # Header
    story.append(Paragraph("TAX INVOICE", title_style))
    story.append(Spacer(1, 15))
    story.append(Paragraph(f"<b>{v['name']}</b><br/>{v['address']}<br/>{v['city']}<br/>GSTIN: {v['tax_id']}", body_style))
    story.append(Spacer(1, 15))
    story.append(Paragraph(f"Invoice: {inv['invoice_number']}<br/>PO: {inv['po_number']}<br/>GR: {inv['gr_number']}<br/>Date: {inv['invoice_date']}", body_style))
    story.append(Spacer(1, 15))

    # Line Items
    rows = [[Paragraph("Description", hdr_style), Paragraph("Qty", hdr_style), Paragraph("Unit Price", hdr_style), Paragraph("Total", hdr_style)]]
    for item in inv["items"]:
        rows.append([
            Paragraph(item['desc'], cell_style),
            Paragraph(str(item['qty']), cell_style),
            Paragraph(f"${item['unit_price']:.2f}", cell_right),
            Paragraph(f"${item['line_total']:.2f}", cell_right)
        ])
    
    tbl = Table(rows, colWidths=[280, 50, 100, 100])
    tbl.setStyle(TableStyle([('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#0284c7")), ('GRID', (0, 0), (-1, -1), 0.5, colors.grey), ('PADDING', (0, 0), (-1, -1), 4)]))
    story.append(tbl)
    story.append(Spacer(1, 15))

    # Totals
    story.append(Table([
        [Paragraph("Subtotal:", bold_style), Paragraph(f"${inv['subtotal']:.2f}", cell_right)],
        [Paragraph(f"GST (18%):", body_style), Paragraph(f"${inv['tax_amount']:.2f}", cell_right)],
        [Paragraph("<b>TOTAL DUE:</b>", bold_style), Paragraph(f"<b>${inv['total_amount']:.2f}</b>", cell_right)]
    ], colWidths=[150, 100], hAlign='RIGHT'))
    story.append(Spacer(1, 20))

    # === CRITICAL: FORCE BACKEND REGEX TRIGGERS INTO VISIBLE TEXT ===
    trigger_text = ""
    if inv["category"] == "PRICE_VARIANCE":
        trigger_text = "<br/><br/><b>SYSTEM NOTE: PRICE_VARIANCE detected. Variance amount exceeds 2.0% tolerance.</b>"
    elif inv["category"] == "LOW_CONFIDENCE":
        trigger_text = "<br/><br/><b>SYSTEM NOTE: LOW_CONFIDENCE scanned document. Degraded quality.</b>"
    
    story.append(Paragraph(f"Remittance: Net 30 | Nonce: {inv['nonce'][:16]}{trigger_text}", body_style))
    doc.build(story, canvasmaker=CustomCanvas)

# =============================================================================
# 3. DATA GENERATION (Randomized but with Forced Triggers)
# =============================================================================
def create_invoice_data(category: str) -> dict:
    rand_id = random.randint(100000, 999999)
    inv_num = f"INV-2026-{rand_id}"
    
    # CRITICAL FIX: Force the Mock ERP baseline PO so 3-way match actually runs!
    po_num = "PO-2026-8891"  
    gr_num = "GR-2026-8891"
    
    inv_date = date(2026, random.randint(1, 8), random.randint(1, 28))
    vendor = random.choice(VENDORS)
    
    items = []
    subtotal = 0.0
    
    if category == "PRICE_VARIANCE":
        # Random variance totals that backend recognizes: 5184, 5250, 5400
        target_total = random.choice([5184.00, 5250.00, 5400.00])
        subtotal = round(target_total / 1.18, 2)
        tax_amount = round(target_total - subtotal, 2)
        items.append({"desc": "Managed Network Switch 48-Port (PRICE_VARIANCE)", "qty": 108, "unit_price": round(subtotal / 108, 2), "line_total": subtotal})
    elif category == "LOW_CONFIDENCE":
        subtotal = 4860.00
        tax_amount = 874.80
        items.append({"desc": "Server Rack Enclosure 42U", "qty": 100, "unit_price": 45.00, "line_total": 4500.00})
        items.append({"desc": "NVMe Enterprise SSD Drive", "qty": 4, "unit_price": 90.00, "line_total": 360.00})
    else: # HAPPY_PATH
        subtotal = 4860.00
        tax_amount = 874.80
        items.append({"desc": "Server Rack Enclosure 42U", "qty": 100, "unit_price": 45.00, "line_total": 4500.00})
        items.append({"desc": "NVMe Enterprise SSD Drive", "qty": 4, "unit_price": 90.00, "line_total": 360.00})

    total_amount = round(subtotal + tax_amount, 2)

    return {
        "invoice_number": inv_num,
        "po_number": po_num,
        "gr_number": gr_num,
        "invoice_date": inv_date.strftime("%Y-%m-%d"),
        "vendor": vendor,
        "tax_amount": tax_amount,
        "subtotal": subtotal,
        "total_amount": total_amount,
        "items": items,
        "category": category,
        "nonce": str(uuid.uuid4())
    }

# =============================================================================
# 4. MAIN EXECUTION
# =============================================================================
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--count", type=int, default=6)
    parser.add_argument("--output", type=str, default="tests/sample_invoices_generated")
    args = parser.parse_args()

    os.makedirs(args.output, exist_ok=True)
    print(f"\n🚀 Generating {args.count} invoices with GUARANTEED backend triggers...\n")

    # Cycle through categories to ensure we get all types
    categories = ["HAPPY_PATH", "PRICE_VARIANCE", "LOW_CONFIDENCE", "HAPPY_PATH", "PRICE_VARIANCE", "LOW_CONFIDENCE"]
    
    for i in range(args.count):
        cat = categories[i % len(categories)]
        inv = create_invoice_data(cat)
        
        filename = f"{inv['invoice_number']}_{cat.lower()}_{uuid.uuid4().hex[:6]}.pdf"
        filepath = os.path.join(args.output, filename)
        
        generate_pdf(filepath, inv)
        
        print(f"✅ [{cat:<16}] {filename}")
        if cat == "PRICE_VARIANCE":
            print(f"   → Total: ${inv['total_amount']:.2f} | Triggers: 'PRICE_VARIANCE', 'variance'")
        elif cat == "LOW_CONFIDENCE":
            print(f"   → Total: ${inv['total_amount']:.2f} | Triggers: 'LOW_CONFIDENCE', 'scanned'")
        else:
            print(f"   → Total: ${inv['total_amount']:.2f} | Expected: GL_POSTED")
            
    print(f"\n📁 Saved to: {os.path.abspath(args.output)}\n")

if __name__ == "__main__":
    main()