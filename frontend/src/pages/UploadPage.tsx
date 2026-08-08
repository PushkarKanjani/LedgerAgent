import React, { useState, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { MicroLabel, SwissButton, StatusTag, Money } from '../components/swiss/primitives';
import { uploadInvoicePdf } from '../services/api';
import { InvoiceUploadResponse } from '../types';

export const UploadPage: React.FC = () => {
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [isUploading, setIsUploading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<InvoiceUploadResponse | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const navigate = useNavigate();

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files[0]) {
      setSelectedFile(e.target.files[0]);
      setError(null);
      setResult(null);
    }
  };

  const handleProcessUpload = async () => {
    if (!selectedFile) return;
    setIsUploading(true);
    setError(null);

    try {
      const res = await uploadInvoicePdf(selectedFile);
      setResult(res);
    } catch (err: any) {
      setError(err.message || 'Invoice upload failed.');
    } finally {
      setIsUploading(false);
    }
  };

  const handleLoadHappyPath = () => {
    const timestamp = new Date().toISOString().slice(0, 10);
    const content = `INVOICE
Apex Cloud Solutions LLC
Tax ID: XX-XXX7733
Invoice Number: INV-2026-001
PO Number: PO-2026-8891
Date: ${timestamp}
Due Date: 2026-08-22
Currency: USD

Item: SRV-CLOUD-01 | Cloud Compute Task Worker | Qty: 100.0 | Unit Price: $45.00 | Total: $4500.00
Subtotal: $4500.00
Tax (8%): $360.00
Total Amount: $4860.00`;

    const blob = new Blob([content], { type: 'application/pdf' });
    const file = new File([blob], 'INV-2026-001_happy_path.pdf', { type: 'application/pdf' });
    setSelectedFile(file);
    setError(null);
    setResult(null);
  };

  const handleLoadException = () => {
    const timestamp = new Date().toISOString().slice(0, 10);
    const content = `INVOICE
Apex Cloud Solutions LLC
Tax ID: XX-XXX7733
Invoice Number: INV-2026-021
PO Number: PO-2026-8891
Date: ${timestamp}
Due Date: 2026-08-22
Currency: USD

Item: SRV-CLOUD-01 | Cloud Compute Task Worker | Qty: 100.0 | Unit Price: $48.00 | Total: $4800.00
Subtotal: $4800.00
Tax (8%): $384.00
Total Amount: $5184.00`;

    const blob = new Blob([content], { type: 'application/pdf' });
    const file = new File([blob], 'INV-2026-021_price_variance_hitl.pdf', { type: 'application/pdf' });
    setSelectedFile(file);
    setError(null);
    setResult(null);
  };

  return (
    <div className="space-y-8 animate-fadeIn">
      {/* Title */}
      <div className="border-b border-hairline dark:border-darkHairline pb-4">
        <MicroLabel mono>Section 02 &bull; Ingestion Pipeline</MicroLabel>
        <h1 className="font-display font-semibold text-3xl sm:text-4xl tracking-tight text-ink dark:text-darkInk mt-0.5">
          Ingest &amp; Reconcile Invoice
        </h1>
      </div>

      {/* Two-Column Swiss Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8">
        
        {/* Left Column: Dropzone (7 Cols) */}
        <div className="lg:col-span-7 space-y-4">
          <MicroLabel mono>PDF Document Stream</MicroLabel>

          <div
            onClick={() => fileInputRef.current?.click()}
            className="border border-dashed border-hairlineDark dark:border-darkHairline p-10 text-center cursor-pointer hover:bg-paperAlt dark:hover:bg-darkSurface transition-colors"
          >
            <input
              ref={fileInputRef}
              type="file"
              accept=".pdf,.png,.jpg,.jpeg"
              onChange={handleFileChange}
              className="hidden"
            />
            <div className="space-y-1">
              <p className="font-display font-medium text-sm text-ink dark:text-darkInk">
                {selectedFile ? selectedFile.name : 'Select or drag invoice document (.pdf)'}
              </p>
              <p className="font-mono text-[11px] text-inkMuted dark:text-darkInkMuted">
                {selectedFile
                  ? `${(selectedFile.size / 1024).toFixed(1)} KB — Ready to process`
                  : 'Binary SHA-256 hash will be evaluated at entry point'}
              </p>
            </div>
          </div>

          {/* Action Row */}
          <div className="flex flex-wrap items-center justify-between gap-3 pt-2">
            <div className="flex items-center space-x-2">
              <SwissButton variant="secondary" size="sm" onClick={handleLoadHappyPath}>
                Load Happy Path ($4,860)
              </SwissButton>
              <SwissButton variant="secondary" size="sm" onClick={handleLoadException}>
                Load Exception ($5,184)
              </SwissButton>
            </div>

            {selectedFile && !result && (
              <SwissButton
                variant="primary"
                size="md"
                onClick={handleProcessUpload}
                disabled={isUploading}
              >
                {isUploading ? 'Executing LangGraph...' : 'Start 3-Way Match →'}
              </SwissButton>
            )}
          </div>

          {/* Error Message */}
          {error && (
            <div className="p-3 border border-signal bg-signal/5 dark:bg-signal/10 text-signal text-xs font-mono">
              <span className="font-bold">Error:</span> {error}
            </div>
          )}

          {/* Execution Result Box */}
          {result && (
            <div className="p-4 border border-hairline dark:border-darkHairline bg-paperAlt dark:bg-darkSurface space-y-3">
              <div className="flex items-center justify-between">
                <span className="font-display font-bold text-sm text-ink dark:text-darkInk">
                  Execution State: {result.status}
                </span>
                <StatusTag status={result.status} />
              </div>

              <div className="font-mono text-xs text-inkMuted dark:text-darkInkMuted space-y-1 border-t border-hairline dark:border-darkHairline pt-2">
                <div>Invoice ID: <span className="text-ink dark:text-darkInk font-medium">{result.invoice_id}</span></div>
                <div>SHA-256: <span className="text-ink dark:text-darkInk font-medium">{result.sha256_hash.slice(0, 24)}...</span></div>
                {result.gl_reference_id && (
                  <div>GL Reference: <span className="text-posted font-bold">{result.gl_reference_id}</span></div>
                )}
              </div>

              <div className="flex justify-end space-x-3 pt-2">
                {result.status === 'HITL_PENDING' ? (
                  <SwissButton
                    variant="primary"
                    size="sm"
                    onClick={() => navigate(`/app/queue/${result.invoice_id}`)}
                  >
                    Open HITL Decision Review →
                  </SwissButton>
                ) : (
                  <SwissButton
                    variant="secondary"
                    size="sm"
                    onClick={() => navigate('/app/ledger')}
                  >
                    View in General Ledger →
                  </SwissButton>
                )}
              </div>
            </div>
          )}
        </div>

        {/* Right Column: Routing Rules & Ingestion Criteria */}
        <div className="lg:col-span-5 border border-hairline dark:border-darkHairline bg-paperAlt dark:bg-darkSurface p-6 space-y-4 font-mono text-xs">
          <MicroLabel mono>Deterministic Routing Specification</MicroLabel>

          <div className="space-y-3 divide-y divide-hairline dark:divide-darkHairline">
            <div className="pt-2">
              <span className="text-ink dark:text-darkInk font-semibold">01. SHA-256 Idempotency:</span>
              <p className="text-inkMuted dark:text-darkInkMuted mt-0.5">
                Exact binary duplicate hashes reject redundant LLM inference passes instantly.
              </p>
            </div>

            <div className="pt-2">
              <span className="text-ink dark:text-darkInk font-semibold">02. OCR Routing Strategy:</span>
              <p className="text-inkMuted dark:text-darkInkMuted mt-0.5">
                Native PDF vector paths execute AWS Textract; raster scans trigger local PaddleOCR fallback.
              </p>
            </div>

            <div className="pt-2">
              <span className="text-ink dark:text-darkInk font-semibold">03. Confidence Guardrail:</span>
              <p className="text-inkMuted dark:text-darkInkMuted mt-0.5">
                Overall score &lt; 0.85 interrupts graph into human approval state (<code className="text-pending">HITL_PENDING</code>).
              </p>
            </div>

            <div className="pt-2">
              <span className="text-ink dark:text-darkInk font-semibold">04. Tolerance Boundaries:</span>
              <p className="text-inkMuted dark:text-darkInkMuted mt-0.5">
                Price variance &gt; 2.0% ($10.00 max) triggers automatic human reviewer escalation.
              </p>
            </div>
          </div>
        </div>

      </div>
    </div>
  );
};
