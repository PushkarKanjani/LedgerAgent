================================================================================
LedgerAgent Demo & Test Invoices Dataset
Generated for Automated 3-Way Match & Guardrail Verification
================================================================================

OVERVIEW:
This directory contains realistic PDF invoices engineered to demonstrate
and validate all automated routing, HITL escalations, and security guardrails
in the LedgerAgent autonomous invoice reconciliation system on AWS.

--------------------------------------------------------------------------------
1. PRIMARY DEMO INVOICE SUITE
--------------------------------------------------------------------------------
Invoice File                        Cat   Expected Behavior                     
--------------------------------------------------------------------------------
INV-2026-100_happy_path.pdf         A     Auto-post to GL (Straight-Through)    
INV-2026-101_happy_path.pdf         A     Auto-post to GL (Straight-Through)    
INV-2026-102_happy_path.pdf         A     Auto-post to GL (Straight-Through)    
INV-2026-103_price_variance.pdf     B     HITL Queue (Variance Tolerance > 2.0%)
INV-2026-104_price_variance.pdf     B     HITL Queue (Variance Tolerance > 2.0%)
INV-2026-105_low_confidence.pdf     C     HITL Queue (OCR Confidence < 0.85)    
INV-2026-106_low_confidence.pdf     C     HITL Queue (OCR Confidence < 0.85)    
INV-2026-107_duplicate.pdf          D     Instant Rejection (SHA-256 Duplicate) 
INV-2026-108_mixed.pdf              B     HITL Queue (3.0% Price Variance)      
INV-2026-109_mixed.pdf              C     HITL Queue (Degraded Scan Simulation) 

--------------------------------------------------------------------------------
2. PRICE VARIANCE & HITL GUARDRAIL SUITE (Targeting PO-2026-8891)
--------------------------------------------------------------------------------
Invoice File                             Variance Amount / Type      Expected Queue Reason
--------------------------------------------------------------------------------
INV-2026-VAR-01_low_variance.pdf         +$145.80 (+3.0% Unit Price) PRICE_MISMATCH (> 2.0%)
INV-2026-VAR-02_medium_variance.pdf      +$324.00 (+6.7% Unit Price) PRICE_MISMATCH (> 2.0%)
INV-2026-VAR-03_high_variance.pdf        +$583.20 (+12.0% Unit Price)PRICE_MISMATCH (> 2.0%)
INV-2026-VAR-04_quantity_overbill.pdf    +$486.00 (+10 Hours Qty)    QUANTITY_MISMATCH
INV-2026-VAR-05_tax_variance.pdf         +$450.00 (18% vs 8% Tax)    TAX_TOTAL_MISMATCH
INV-2026-VAR-06_heavy_surge_variance.pdf +$1,215.00 (+25.0% Surge)   CRITICAL_PRICE_MISMATCH

--------------------------------------------------------------------------------
INSTRUCTIONS FOR LIVE DEMO:
1. Login to LedgerAgent UI (http://localhost:5173 or AWS ALB DNS endpoint).
2. Upload any invoice from the Price Variance suite (e.g. INV-2026-VAR-02).
3. Navigate to '03 HITL Queue' -> Click 'Refresh Queue'.
4. Observe the exact Price Variance badge (+$324.00) and click 'Inspect ->' to review and approve/reject!
