"""
LedgerAgent — Synthetic Invoice Dataset Generator (Data Pipeline)
=============================================================================
Module: tests/generate_synthetic_invoices.py
Target: tests/sample_invoices/ (30 Ground-Truth Synthetic Invoices + ground_truth.json)
Standards Reference: AGENTS.md DeepEval Golden Dataset & 3-Way Match Validation
=============================================================================
"""

import os
import json
import random
from datetime import date, timedelta

# Output directories
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "sample_invoices")
os.makedirs(OUTPUT_DIR, exist_ok=True)
GROUND_TRUTH_PATH = os.path.join(OUTPUT_DIR, "ground_truth.json")


# =============================================================================
# 1. PURE-PYTHON PDF WRITER (Zero-Dependency Fallback + FPDF2 Support)
# =============================================================================
def generate_pdf_fpdf(filepath: str, inv: dict):
    """Generates a professional structured PDF invoice using fpdf2."""
    from fpdf import FPDF

    pdf = FPDF()
    pdf.add_page()
    pdf.set_auto_page_break(auto=True, margin=15)

    # Header / Brand
    pdf.set_font("Helvetica", "B", 20)
    pdf.set_text_color(15, 23, 42) # Slate 900
    pdf.cell(0, 10, "INVOICE", ln=True, align="R")
    
    pdf.set_font("Helvetica", "B", 14)
    pdf.set_text_color(2, 132, 199) # Sky 600
    pdf.cell(0, 8, inv["vendor_name"], ln=True)

    pdf.set_font("Helvetica", "", 10)
    pdf.set_text_color(100, 116, 139) # Slate 500
    pdf.cell(0, 5, f"Tax ID: {inv.get('vendor_tax_id', 'XX-XXX7733')} | Tech & Cloud Services", ln=True)
    pdf.cell(0, 5, "100 Innovation Way, Suite 400, Austin, TX 78701", ln=True)
    pdf.ln(6)

    # Meta Section (2 columns)
    pdf.set_draw_color(226, 232, 240)
    pdf.line(10, pdf.get_y(), 200, pdf.get_y())
    pdf.ln(6)

    pdf.set_font("Helvetica", "B", 10)
    pdf.set_text_color(51, 65, 85)
    pdf.cell(95, 6, f"Invoice Number: {inv['invoice_number']}", ln=False)
    pdf.cell(95, 6, f"Invoice Date: {inv['invoice_date']}", ln=True)

    po_display = inv['po_number'] if inv['po_number'] else "N/A (Direct Billing)"
    pdf.cell(95, 6, f"PO Number: {po_display}", ln=False)
    pdf.cell(95, 6, f"Payment Due: {inv['due_date']}", ln=True)
    pdf.cell(95, 6, f"Currency: {inv['currency']}", ln=True)
    pdf.ln(6)

    # Table Header
    pdf.set_fill_color(241, 245, 249)
    pdf.set_text_color(30, 41, 59)
    pdf.set_font("Helvetica", "B", 9)
    pdf.cell(25, 8, "Item Code", border=1, fill=True)
    pdf.cell(85, 8, "Description", border=1, fill=True)
    pdf.cell(25, 8, "Quantity", border=1, align="R", fill=True)
    pdf.cell(25, 8, "Unit Price", border=1, align="R", fill=True)
    pdf.cell(30, 8, "Line Total", border=1, align="R", fill=True)
    pdf.ln()

    # Table Body
    pdf.set_font("Helvetica", "", 9)
    pdf.set_text_color(71, 85, 105)
    for item in inv["line_items"]:
        pdf.cell(25, 8, str(item["item_code"]), border=1)
        pdf.cell(85, 8, str(item["description"]), border=1)
        pdf.cell(25, 8, f"{item['quantity']:.1f}", border=1, align="R")
        pdf.cell(25, 8, f"${item['unit_price']:.2f}", border=1, align="R")
        pdf.cell(30, 8, f"${item['line_total']:.2f}", border=1, align="R")
        pdf.ln()

    pdf.ln(4)

    # Totals Summary Box (Right Aligned)
    pdf.set_font("Helvetica", "", 10)
    pdf.cell(135, 6, "", ln=False)
    pdf.cell(25, 6, "Subtotal:", align="R")
    pdf.cell(30, 6, f"${inv['subtotal']:.2f}", align="R", ln=True)

    pdf.cell(135, 6, "", ln=False)
    pdf.cell(25, 6, "Tax (8%):", align="R")
    pdf.cell(30, 6, f"${inv['tax_amount']:.2f}", align="R", ln=True)

    pdf.set_font("Helvetica", "B", 11)
    pdf.set_text_color(15, 23, 42)
    pdf.cell(135, 8, "", ln=False)
    pdf.cell(25, 8, "Total Due:", align="R")
    pdf.cell(30, 8, f"${inv['total_amount']:.2f}", align="R", ln=True)

    # Footer Notice
    pdf.set_y(-30)
    pdf.set_font("Helvetica", "I", 8)
    pdf.set_text_color(148, 163, 184)
    pdf.cell(0, 5, "Reconciliation Target: Mock ERP PO-2026-8891 | Processed by LedgerAgent", align="C", ln=True)
    pdf.cell(0, 5, f"Category: {inv['category']} | Expected: {inv['expected_outcome']}", align="C", ln=True)

    pdf.output(filepath)


def generate_minimal_raw_pdf(filepath: str, inv: dict):
    """
    Standard lightweight fallback PDF generator that produces valid PDF 1.4 syntax
    without requiring third-party C-extensions or external wheels.
    """
    po_val = inv['po_number'] or "NONE"
    stream_content = f"""BT
/F1 18 Tf
50 750 Td
(INVOICE - {inv['vendor_name']}) Tj
/F1 10 Tf
0 -25 Td
(Invoice Number: {inv['invoice_number']}    Date: {inv['invoice_date']}) Tj
0 -15 Td
(Purchase Order: {po_val}    Due Date: {inv['due_date']}) Tj
0 -15 Td
(Tax ID: {inv.get('vendor_tax_id', 'XX-XXX7733')}    Currency: {inv['currency']}) Tj
0 -30 Td
(--------------------------------------------------------------------------------) Tj
0 -15 Td
(Item: {inv['line_items'][0]['item_code']} | Qty: {inv['line_items'][0]['quantity']} | Unit: ${inv['line_items'][0]['unit_price']:.2f} | Total: ${inv['line_items'][0]['line_total']:.2f}) Tj
0 -15 Td
(--------------------------------------------------------------------------------) Tj
0 -25 Td
(Subtotal: ${inv['subtotal']:.2f}) Tj
0 -15 Td
(Tax: ${inv['tax_amount']:.2f}) Tj
/F1 12 Tf
0 -20 Td
(Grand Total: ${inv['total_amount']:.2f}) Tj
/F1 8 Tf
0 -30 Td
(Category: {inv['category']} | Expected Match: {inv['expected_outcome']}) Tj
ET"""

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
# 2. DATASET DEFINITION & CONFIGURATION (30 INVOICES)
# =============================================================================

# Category B Typo Variations (simulating OCR and human vendor misspellings)
TYPO_VENDORS = [
    "Apex Clouud Solutons",
    "Apex Cloud Sol.",
    "APEX CLOUD SOLUTIONS",
    "Apex C1oud Solutions LLC",
    "Apex Cloud Solutns LLC",
    "Apex Clud Solutions LLC",
    "Apex Cloud Solutions, LLC.",
    "APEX CLOUD SOLUTIONS LLC",
    "Apex Cloud Solutions Inc",
    "Apex Cloud Solution"
]

def build_dataset_spec():
    """Builds the 30 invoice metadata dictionaries across all 3 categories."""
    dataset = []
    base_date = date(2026, 7, 1)

    # -------------------------------------------------------------------------
    # CATEGORY A: Happy Path (Auto-Approve) - 10 Files (001 to 010)
    # -------------------------------------------------------------------------
    for i in range(1, 11):
        inv_num = f"INV-2026-{i:03d}"
        inv_date = (base_date + timedelta(days=i)).isoformat()
        due_date = (base_date + timedelta(days=i + 30)).isoformat()
        
        dataset.append({
            "filename": f"{inv_num}_happy_path.pdf",
            "category": "CATEGORY_A_HAPPY_PATH",
            "invoice_number": inv_num,
            "vendor_name": "Apex Cloud Solutions LLC",
            "vendor_tax_id": "XX-XXX7733",
            "po_number": "PO-2026-8891",
            "invoice_date": inv_date,
            "due_date": due_date,
            "currency": "USD",
            "subtotal": 4500.00,
            "tax_amount": 360.00,
            "total_amount": 4860.00,
            "line_items": [
                {
                    "item_code": "SRV-CLOUD-01",
                    "description": "Cloud Compute Task Worker (Hours)",
                    "quantity": 100.0,
                    "unit_price": 45.00,
                    "line_total": 4500.00
                }
            ],
            "expected_outcome": "FULL_MATCH",
            "expected_hitl": False,
            "expected_gl_posted": True
        })

    # -------------------------------------------------------------------------
    # CATEGORY B: Fuzzy Match / OCR Typo Simulation - 10 Files (011 to 020)
    # -------------------------------------------------------------------------
    for i in range(11, 21):
        idx = i - 11
        inv_num = f"INV-2026-{i:03d}"
        inv_date = (base_date + timedelta(days=i)).isoformat()
        due_date = (base_date + timedelta(days=i + 30)).isoformat()
        typo_name = TYPO_VENDORS[idx % len(TYPO_VENDORS)]

        dataset.append({
            "filename": f"{inv_num}_fuzzy_match.pdf",
            "category": "CATEGORY_B_FUZZY_MATCH",
            "invoice_number": inv_num,
            "vendor_name": typo_name,
            "vendor_tax_id": "XX-XXX7733",
            "po_number": "PO-2026-8891",
            "invoice_date": inv_date,
            "due_date": due_date,
            "currency": "USD",
            "subtotal": 4500.00,
            "tax_amount": 360.00,
            "total_amount": 4860.00,
            "line_items": [
                {
                    "item_code": "SRV-CLOUD-01",
                    "description": "Cloud Compute Task Worker (Hours)",
                    "quantity": 100.0,
                    "unit_price": 45.00,
                    "line_total": 4500.00
                }
            ],
            "expected_outcome": "FULL_MATCH_VIA_FUZZY_LOOKUP",
            "expected_hitl": False,
            "expected_gl_posted": True
        })

    # -------------------------------------------------------------------------
    # CATEGORY C: Exception / HITL Trigger - 10 Files (021 to 030)
    # -------------------------------------------------------------------------
    # C1: 5 Price Variance Exceptions ($5,200.00 to $5,900.00)
    for i in range(21, 26):
        inv_num = f"INV-2026-{i:03d}"
        inv_date = (base_date + timedelta(days=i)).isoformat()
        due_date = (base_date + timedelta(days=i + 30)).isoformat()
        
        # Over-billed price
        unit_price = 52.00 + (i - 21) * 3.00 # $52.00, $55.00, $58.00, $61.00, $64.00
        subtotal = round(100.0 * unit_price, 2)
        tax = round(subtotal * 0.08, 2)
        total = round(subtotal + tax, 2)

        dataset.append({
            "filename": f"{inv_num}_price_variance_hitl.pdf",
            "category": "CATEGORY_C_PRICE_VARIANCE",
            "invoice_number": inv_num,
            "vendor_name": "Apex Cloud Solutions LLC",
            "vendor_tax_id": "XX-XXX7733",
            "po_number": "PO-2026-8891",
            "invoice_date": inv_date,
            "due_date": due_date,
            "currency": "USD",
            "subtotal": subtotal,
            "tax_amount": tax,
            "total_amount": total,
            "line_items": [
                {
                    "item_code": "SRV-CLOUD-01",
                    "description": "Cloud Compute Task Worker (Overbilled Rate)",
                    "quantity": 100.0,
                    "unit_price": unit_price,
                    "line_total": subtotal
                }
            ],
            "expected_outcome": "PRICE_MISMATCH",
            "expected_hitl": True,
            "expected_gl_posted": False
        })

    # C2: 5 Missing PO Number Exceptions
    for i in range(26, 31):
        inv_num = f"INV-2026-{i:03d}"
        inv_date = (base_date + timedelta(days=i)).isoformat()
        due_date = (base_date + timedelta(days=i + 30)).isoformat()

        dataset.append({
            "filename": f"{inv_num}_missing_po_hitl.pdf",
            "category": "CATEGORY_C_MISSING_PO",
            "invoice_number": inv_num,
            "vendor_name": "Apex Cloud Solutions LLC",
            "vendor_tax_id": "XX-XXX7733",
            "po_number": None, # Missing PO
            "invoice_date": inv_date,
            "due_date": due_date,
            "currency": "USD",
            "subtotal": 4500.00,
            "tax_amount": 360.00,
            "total_amount": 4860.00,
            "line_items": [
                {
                    "item_code": "SRV-CLOUD-01",
                    "description": "Cloud Compute Task Worker",
                    "quantity": 100.0,
                    "unit_price": 45.00,
                    "line_total": 4500.00
                }
            ],
            "expected_outcome": "MISSING_PO",
            "expected_hitl": True,
            "expected_gl_posted": False
        })

    return dataset


# =============================================================================
# 3. MAIN EXECUTION PIPELINE
# =============================================================================
def main():
    print("=" * 70)
    print("🚀 [LedgerAgent] Generating 30 Synthetic Golden Invoices...")
    print("=" * 70)

    # Detect fpdf2 vs minimal builder
    use_fpdf = False
    try:
        import fpdf
        use_fpdf = True
        print("📄 Using 'fpdf2' PDF Engine for high-fidelity document layout.")
    except ImportError:
        print("ℹ️ 'fpdf2' not installed; using zero-dependency PDF 1.4 generator.")

    dataset = build_dataset_spec()
    ground_truth_map = {}

    for item in dataset:
        target_path = os.path.join(OUTPUT_DIR, item["filename"])
        
        if use_fpdf:
            try:
                generate_pdf_fpdf(target_path, item)
            except Exception as e:
                print(f"Fallback to minimal generator for {item['filename']} due to: {e}")
                generate_minimal_raw_pdf(target_path, item)
        else:
            generate_minimal_raw_pdf(target_path, item)

        ground_truth_map[item["filename"]] = item
        print(f"  ✅ Generated: {item['filename']} | {item['category']} | Outcome: {item['expected_outcome']}")

    # Write ground_truth.json
    with open(GROUND_TRUTH_PATH, "w", encoding="utf-8") as f:
        json.dump(ground_truth_map, f, indent=2)

    print("\n" + "=" * 70)
    print(f"🎉 Golden Dataset Ready! 30 PDF invoices created at:")
    print(f"   📁 {OUTPUT_DIR}")
    print(f"   📑 Ground truth manifest: {GROUND_TRUTH_PATH}")
    print("=" * 70)


if __name__ == "__main__":
    main()
