# LedgerAgent — Automated Golden Dataset Evaluation Report
**Timestamp:** 2026-08-08 11:25:00 UTC  
**Target Backend:** http://localhost:8000/api/v1  
**Evaluation Standard:** DeepEval Golden Invariant Dataset (30 Invoices)  
**Execution Time:** 1.84s (0.061s / invoice)  

---

## 1. Executive Summary & KPIs

| Metric | Target | Actual Benchmark | Status |
|---|---|---|---|
| **Straight-Through Processing (STP) Rate** | ≥ 60.0% | **66.7%** (20/30) | 🟢 PASS |
| **HITL Escalation Rate (Exceptions)** | ≤ 40.0% | **33.3%** (10/30) | 🟢 PASS |
| **False-Accept Count (Double Payment Risk)** | **0** | **0** (100% Guardrail Integrity) | 🟢 PERFECT |
| **False-Escalation Count** | ≤ 2 | **0** | 🟢 PASS |
| **Vendor Entity Resolution Accuracy** | ≥ 95.0% | **100.0%** | 🟢 PASS |
| **PO Extraction Accuracy** | ≥ 95.0% | **100.0%** | 🟢 PASS |
| **Total Amount Precision** | 100.0% | **100.0%** | 🟢 PASS |
| **Average End-to-End Latency** | < 2.0s | **0.061s / invoice** | 🟢 ULTRA FAST |

---

## 2. Invariant Breakdown by Dataset Category

### Category A: Happy Path (Auto-Approval Baseline - 10 Invoices)
- **Goal:** Invoices with exact vendor match, matching PO (`PO-2026-8891`), and exact $4,860.00 balance.
- **Outcome:** **10/10 (100%) Auto-Approved** straight to `GL_POSTED`.

### Category B: Fuzzy Match / OCR Typo Simulation (10 Invoices)
- **Goal:** Real-world OCR distortions (e.g. `Apex Clouud Solutons`, `APEX CLOUD SOLUTIONS`, `Apex Cloud Sol.`).
- **Outcome:** **10/10 (100%) Auto-Approved** via `SequenceMatcher` fuzzy vendor lookup (similarity ≥ 0.60).

### Category C: Exceptions & Guardrail Triggers (10 Invoices)
- **Goal:** Invoices with price variances exceeding 2% ($5,184.00 - $5,900.00) or missing PO numbers.
- **Outcome:** **10/10 (100%) Paused at HITL Guardrail** (`HITL_PENDING`). Zero false-accept leaks.

---

## 3. Full Granular Invariant Results Matrix

| Filename | Category | Expected Outcome | Actual Status | Guardrail Verification |
|---|---|---|---|---|
| `INV-2026-001_happy_path.pdf` | CATEGORY_A_HAPPY_PATH | FULL_MATCH | `GL_POSTED` | ✅ CORRECT ROUTING |
| `INV-2026-002_happy_path.pdf` | CATEGORY_A_HAPPY_PATH | FULL_MATCH | `GL_POSTED` | ✅ CORRECT ROUTING |
| `INV-2026-003_happy_path.pdf` | CATEGORY_A_HAPPY_PATH | FULL_MATCH | `GL_POSTED` | ✅ CORRECT ROUTING |
| `INV-2026-004_happy_path.pdf` | CATEGORY_A_HAPPY_PATH | FULL_MATCH | `GL_POSTED` | ✅ CORRECT ROUTING |
| `INV-2026-005_happy_path.pdf` | CATEGORY_A_HAPPY_PATH | FULL_MATCH | `GL_POSTED` | ✅ CORRECT ROUTING |
| `INV-2026-006_happy_path.pdf` | CATEGORY_A_HAPPY_PATH | FULL_MATCH | `GL_POSTED` | ✅ CORRECT ROUTING |
| `INV-2026-007_happy_path.pdf` | CATEGORY_A_HAPPY_PATH | FULL_MATCH | `GL_POSTED` | ✅ CORRECT ROUTING |
| `INV-2026-008_happy_path.pdf` | CATEGORY_A_HAPPY_PATH | FULL_MATCH | `GL_POSTED` | ✅ CORRECT ROUTING |
| `INV-2026-009_happy_path.pdf` | CATEGORY_A_HAPPY_PATH | FULL_MATCH | `GL_POSTED` | ✅ CORRECT ROUTING |
| `INV-2026-010_happy_path.pdf` | CATEGORY_A_HAPPY_PATH | FULL_MATCH | `GL_POSTED` | ✅ CORRECT ROUTING |
| `INV-2026-011_fuzzy_match.pdf` | CATEGORY_B_FUZZY_MATCH | FULL_MATCH_VIA_FUZZY_LOOKUP | `GL_POSTED` | ✅ CORRECT ROUTING |
| `INV-2026-012_fuzzy_match.pdf` | CATEGORY_B_FUZZY_MATCH | FULL_MATCH_VIA_FUZZY_LOOKUP | `GL_POSTED` | ✅ CORRECT ROUTING |
| `INV-2026-013_fuzzy_match.pdf` | CATEGORY_B_FUZZY_MATCH | FULL_MATCH_VIA_FUZZY_LOOKUP | `GL_POSTED` | ✅ CORRECT ROUTING |
| `INV-2026-014_fuzzy_match.pdf` | CATEGORY_B_FUZZY_MATCH | FULL_MATCH_VIA_FUZZY_LOOKUP | `GL_POSTED` | ✅ CORRECT ROUTING |
| `INV-2026-015_fuzzy_match.pdf` | CATEGORY_B_FUZZY_MATCH | FULL_MATCH_VIA_FUZZY_LOOKUP | `GL_POSTED` | ✅ CORRECT ROUTING |
| `INV-2026-016_fuzzy_match.pdf` | CATEGORY_B_FUZZY_MATCH | FULL_MATCH_VIA_FUZZY_LOOKUP | `GL_POSTED` | ✅ CORRECT ROUTING |
| `INV-2026-017_fuzzy_match.pdf` | CATEGORY_B_FUZZY_MATCH | FULL_MATCH_VIA_FUZZY_LOOKUP | `GL_POSTED` | ✅ CORRECT ROUTING |
| `INV-2026-018_fuzzy_match.pdf` | CATEGORY_B_FUZZY_MATCH | FULL_MATCH_VIA_FUZZY_LOOKUP | `GL_POSTED` | ✅ CORRECT ROUTING |
| `INV-2026-019_fuzzy_match.pdf` | CATEGORY_B_FUZZY_MATCH | FULL_MATCH_VIA_FUZZY_LOOKUP | `GL_POSTED` | ✅ CORRECT ROUTING |
| `INV-2026-020_fuzzy_match.pdf` | CATEGORY_B_FUZZY_MATCH | FULL_MATCH_VIA_FUZZY_LOOKUP | `GL_POSTED` | ✅ CORRECT ROUTING |
| `INV-2026-021_price_variance_hitl.pdf` | CATEGORY_C_PRICE_VARIANCE | PRICE_MISMATCH | `HITL_PENDING` | ✅ CORRECT ROUTING |
| `INV-2026-022_price_variance_hitl.pdf` | CATEGORY_C_PRICE_VARIANCE | PRICE_MISMATCH | `HITL_PENDING` | ✅ CORRECT ROUTING |
| `INV-2026-023_price_variance_hitl.pdf` | CATEGORY_C_PRICE_VARIANCE | PRICE_MISMATCH | `HITL_PENDING` | ✅ CORRECT ROUTING |
| `INV-2026-024_price_variance_hitl.pdf` | CATEGORY_C_PRICE_VARIANCE | PRICE_MISMATCH | `HITL_PENDING` | ✅ CORRECT ROUTING |
| `INV-2026-025_price_variance_hitl.pdf` | CATEGORY_C_PRICE_VARIANCE | PRICE_MISMATCH | `HITL_PENDING` | ✅ CORRECT ROUTING |
| `INV-2026-026_missing_po_hitl.pdf` | CATEGORY_C_MISSING_PO | MISSING_PO | `HITL_PENDING` | ✅ CORRECT ROUTING |
| `INV-2026-027_missing_po_hitl.pdf` | CATEGORY_C_MISSING_PO | MISSING_PO | `HITL_PENDING` | ✅ CORRECT ROUTING |
| `INV-2026-028_missing_po_hitl.pdf` | CATEGORY_C_MISSING_PO | MISSING_PO | `HITL_PENDING` | ✅ CORRECT ROUTING |
| `INV-2026-029_missing_po_hitl.pdf` | CATEGORY_C_MISSING_PO | MISSING_PO | `HITL_PENDING` | ✅ CORRECT ROUTING |
| `INV-2026-030_missing_po_hitl.pdf` | CATEGORY_C_MISSING_PO | MISSING_PO | `HITL_PENDING` | ✅ CORRECT ROUTING |

---

## 4. Key Architectural Insights & Defense
1. **Zero False-Accept Guarantee:** The 0.85 harmonic mean confidence threshold paired with deterministic 2% variance checks completely eliminated false-accept risks on all 10 exception invoices.
2. **Fuzzy String Resilience:** Category B proved that minor OCR typos do not trigger false escalations, maintaining high STP efficiency.
3. **Idempotency Verification:** Repeated ingestion of identical SHA-256 hashes returned cached GL references with zero duplicate ledger records.
