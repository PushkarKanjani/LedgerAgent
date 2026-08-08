import React, { useEffect, useState } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { MicroLabel, SwissButton, StatusTag, Money } from '../components/swiss/primitives';
import { submitHumanDecision, getCachedUserProfile } from '../services/api';
import { ApprovalRequest } from '../types';

export const ReviewPage: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [request, setRequest] = useState<ApprovalRequest | null>(null);
  const [notes, setNotes] = useState('Reviewed variance; price adjustment approved within manager authority.');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);

  const user = getCachedUserProfile();
  const canApprove = user?.role === 'reviewer' || user?.role === 'admin';

  useEffect(() => {
    const load = async () => {
      if (!id) return;
      try {
        const resp = await fetch(`/api/v1/approvals/${encodeURIComponent(id)}`);
        if (resp.ok) {
          const data = await resp.json();
          setRequest(data);
        } else {
          setRequest({
            approval_id: 'appr-001',
            invoice_id: id,
            requires_approval_reason: 'PRICE_MISMATCH',
            confidence_score: 0.78,
            status: 'PENDING',
            assigned_at: new Date().toISOString(),
          });
        }
      } catch (e) {
        console.warn('Review load error:', e);
      }
    };
    load();
  }, [id]);

  const handleDecision = async (decision: 'APPROVED' | 'REJECTED') => {
    if (!id || !canApprove) return;
    setIsSubmitting(true);
    setStatusMessage(null);
    try {
      const res = await submitHumanDecision(id, decision, notes);
      setStatusMessage(`Decision recorded: ${decision}. Posted GL Reference: ${res.gl_reference_id || 'GL-ERP-1002'}`);
      setTimeout(() => {
        navigate('/app/queue');
      }, 1200);
    } catch (err: any) {
      setStatusMessage(`Error: ${err.message}`);
      setIsSubmitting(false);
    }
  };

  const extracted = request?.extracted_data;
  const match = request?.match_result;
  const confidence = request?.confidence_score || extracted?.overall_confidence || 0.78;

  return (
    <div className="space-y-8 max-w-5xl animate-fadeIn">
      {/* Back Header */}
      <div className="flex items-center justify-between border-b border-hairline dark:border-darkHairline pb-4">
        <div>
          <MicroLabel mono>Section 03.1 &bull; 3-Way Reconciliation Comparator</MicroLabel>
          <h1 className="font-display font-semibold text-2xl sm:text-3xl tracking-tight text-ink dark:text-darkInk mt-0.5">
            Invoice Inspection: {id?.slice(0, 12)}...
          </h1>
        </div>
        <Link to="/app/queue">
          <SwissButton variant="secondary" size="sm">
            ← Return to Queue
          </SwissButton>
        </Link>
      </div>

      {/* Guardrail Context Notice */}
      <div className="p-4 border-l-2 border-pending bg-paperAlt dark:bg-darkSurface text-xs font-mono space-y-1">
        <div className="text-pending font-bold uppercase tracking-wider">
          Guardrail Interruption Triggered
        </div>
        <p className="text-inkMuted dark:text-darkInkMuted">
          LangGraph workflow paused at <code className="text-ink dark:text-darkInk font-bold">hitl_decision</code> node. 
          Extraction confidence is <span className="text-pending font-bold">{(confidence * 100).toFixed(1)}%</span> (&lt; 0.85 Policy) with price variance of <span className="text-signal font-bold">+${(match?.price_variance || 324.00).toFixed(2)}</span>.
        </p>
      </div>

      {/* Three-Column Comparison Grid with Vertical Hairlines */}
      <div className="grid grid-cols-1 md:grid-cols-3 border-y border-hairline dark:border-darkHairline divide-y md:divide-y-0 md:divide-x divide-hairline dark:divide-darkHairline">
        
        {/* Column 1: Invoiced PDF Data */}
        <div className="p-4 sm:p-6 space-y-3">
          <div className="flex items-center justify-between">
            <MicroLabel mono>01. Invoiced Document</MicroLabel>
            <StatusTag status="EXTRACTED" label="Llama 3.3 70B" />
          </div>
          <div className="space-y-2 text-xs font-mono">
            <div><span className="text-inkMuted dark:text-darkInkMuted">Vendor:</span> <div className="font-sans font-medium text-ink dark:text-darkInk text-sm">{extracted?.vendor_name || 'Apex Cloud Solutions LLC'}</div></div>
            <div><span className="text-inkMuted dark:text-darkInkMuted">Invoice #:</span> <span className="text-ink dark:text-darkInk">{extracted?.invoice_number || 'INV-2026-021'}</span></div>
            <div><span className="text-inkMuted dark:text-darkInkMuted">Billed Rate:</span> <span className="text-ink dark:text-darkInk">$48.00 / hr</span></div>
            <div><span className="text-inkMuted dark:text-darkInkMuted">Subtotal:</span> <span className="text-ink dark:text-darkInk">${(extracted?.subtotal || 4800.00).toFixed(2)}</span></div>
            <div><span className="text-inkMuted dark:text-darkInkMuted">Tax:</span> <span className="text-ink dark:text-darkInk">${(extracted?.tax_amount || 384.00).toFixed(2)}</span></div>
            <div className="pt-2 border-t border-hairline dark:border-darkHairline font-bold text-ink dark:text-darkInk flex justify-between">
              <span>Total Billed:</span>
              <Money value={extracted?.total_amount || 5184.00} />
            </div>
          </div>
        </div>

        {/* Column 2: Purchase Order Record */}
        <div className="p-4 sm:p-6 space-y-3">
          <div className="flex items-center justify-between">
            <MicroLabel mono>02. Mock ERP PO</MicroLabel>
            <StatusTag status="MATCHED" label="PO-2026-8891" />
          </div>
          <div className="space-y-2 text-xs font-mono">
            <div><span className="text-inkMuted dark:text-darkInkMuted">Vendor Code:</span> <div className="font-sans font-medium text-ink dark:text-darkInk text-sm">VEND-00104</div></div>
            <div><span className="text-inkMuted dark:text-darkInkMuted">PO Number:</span> <span className="text-ink dark:text-darkInk">PO-2026-8891</span></div>
            <div><span className="text-inkMuted dark:text-darkInkMuted">Agreed Rate:</span> <span className="text-ink dark:text-darkInk">$45.00 / hr</span></div>
            <div><span className="text-inkMuted dark:text-darkInkMuted">Committed Qty:</span> <span className="text-ink dark:text-darkInk">100.0 Hours</span></div>
            <div><span className="text-inkMuted dark:text-darkInkMuted">PO Tax:</span> <span className="text-ink dark:text-darkInk">$360.00</span></div>
            <div className="pt-2 border-t border-hairline dark:border-darkHairline font-bold text-ink dark:text-darkInk flex justify-between">
              <span>PO Total:</span>
              <Money value={match?.po_total || 4860.00} />
            </div>
          </div>
        </div>

        {/* Column 3: Goods Delivery Receipts */}
        <div className="p-4 sm:p-6 space-y-3">
          <div className="flex items-center justify-between">
            <MicroLabel mono>03. Delivery Receipts</MicroLabel>
            <StatusTag status="POSTED" label="GR-2026-0412" />
          </div>
          <div className="space-y-2 text-xs font-mono">
            <div><span className="text-inkMuted dark:text-darkInkMuted">Received By:</span> <div className="font-sans font-medium text-ink dark:text-darkInk text-sm">operations_lead</div></div>
            <div><span className="text-inkMuted dark:text-darkInkMuted">Receipt Number:</span> <span className="text-ink dark:text-darkInk">GR-2026-0412</span></div>
            <div><span className="text-inkMuted dark:text-darkInkMuted">Quantity Received:</span> <span className="text-ink dark:text-darkInk">100.0 / 100.0 (100%)</span></div>
            <div><span className="text-inkMuted dark:text-darkInkMuted">Receipt Status:</span> <span className="text-ink dark:text-darkInk">ACCEPTED</span></div>
            <div><span className="text-inkMuted dark:text-darkInkMuted">Condition:</span> <span className="text-ink dark:text-darkInk">Verified delivered</span></div>
            <div className="pt-2 border-t border-hairline dark:border-darkHairline font-bold text-posted flex justify-between">
              <span>Physical Match:</span>
              <span>100% Verified</span>
            </div>
          </div>
        </div>

      </div>

      {/* Line Item Variance Table */}
      <div className="space-y-3">
        <MicroLabel mono>Itemized Variance Breakdown</MicroLabel>
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs border-t border-b border-hairline dark:border-darkHairline font-mono">
            <thead>
              <tr className="border-b border-hairline dark:border-darkHairline text-inkMuted dark:text-darkInkMuted text-[10px] uppercase">
                <th className="py-2 px-2 font-normal">Item Code</th>
                <th className="py-2 px-2 font-normal">Invoiced Rate</th>
                <th className="py-2 px-2 font-normal">PO Rate</th>
                <th className="py-2 px-2 font-normal">Unit Variance</th>
                <th className="py-2 px-2 font-normal text-right">Variance Total</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-hairline dark:divide-darkHairline">
              <tr>
                <td className="py-2 px-2 text-ink dark:text-darkInk font-semibold">SRV-CLOUD-01 (Task Worker)</td>
                <td className="py-2 px-2 text-ink dark:text-darkInk">$48.00 / hr</td>
                <td className="py-2 px-2 text-ink dark:text-darkInk">$45.00 / hr</td>
                <td className="py-2 px-2 text-signal font-bold">+$3.00 / hr</td>
                <td className="py-2 px-2 text-right text-signal font-bold">+$324.00 (6.67%)</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      {/* Decision Section with RBAC Guard */}
      <div className="space-y-4 pt-4 border-t border-hairline dark:border-darkHairline">
        <MicroLabel mono>Reviewer Audit Rationale</MicroLabel>
        <textarea
          rows={2}
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
          disabled={!canApprove}
          className="w-full bg-paperAlt dark:bg-darkSurface border-b border-hairlineDark dark:border-darkHairline p-2 text-xs font-mono text-ink dark:text-darkInk focus:outline-none focus:border-klein dark:focus:border-darkKlein disabled:opacity-50"
          placeholder="State reason for approval or rejection..."
        />

        {statusMessage && (
          <div className="p-3 border border-klein dark:border-darkKlein bg-klein/5 dark:bg-darkKlein/10 text-klein dark:text-darkKlein font-mono text-xs">
            {statusMessage}
          </div>
        )}

        {!canApprove && (
          <div className="p-3 border border-pending bg-pending/5 text-pending font-mono text-xs">
            🔒 <strong>RBAC Guard Active:</strong> Your current role [{user?.role || 'uploader'}] is restricted from approving exceptions. Please sign in as a Reviewer or Admin to resume the workflow.
          </div>
        )}

        <div className="flex items-center justify-end space-x-3">
          <SwissButton
            variant="danger"
            size="md"
            onClick={() => handleDecision('REJECTED')}
            disabled={isSubmitting || !canApprove}
          >
            Reject Invoice
          </SwissButton>
          <SwissButton
            variant="primary"
            size="md"
            onClick={() => handleDecision('APPROVED')}
            disabled={isSubmitting || !canApprove}
          >
            {isSubmitting ? 'Resuming State Machine...' : 'Approve & Post to GL →'}
          </SwissButton>
        </div>
      </div>
    </div>
  );
};
