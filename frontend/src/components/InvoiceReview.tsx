import React, { useState } from 'react';
import { ArrowLeft, Check, X, ShieldAlert, Loader2, CheckCircle2 } from 'lucide-react';
import { ApprovalRequest } from '../types';
import { submitHumanDecision } from '../services/api';

interface InvoiceReviewProps {
  request: ApprovalRequest;
  onBack: () => void;
  onDecisionSubmitted: () => void;
}

export const InvoiceReview: React.FC<InvoiceReviewProps> = ({
  request,
  onBack,
  onDecisionSubmitted,
}) => {
  const [reviewerNotes, setReviewerNotes] = useState('Reviewed variance; price adjustment within manager discretion.');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const [isSuccess, setIsSuccess] = useState(false);

  const extracted = request.extracted_data;
  const match = request.match_result;
  const confidence = request.confidence_score || extracted?.overall_confidence || 0.78;

  const handleDecision = async (decision: 'APPROVED' | 'REJECTED' | 'CORRECTED_AND_APPROVED') => {
    setIsSubmitting(true);
    setStatusMessage(null);
    try {
      const res = await submitHumanDecision(request.invoice_id, decision, reviewerNotes);
      setIsSuccess(true);
      setStatusMessage(`✅ Invoice ${decision}! GL Reference: ${res.gl_reference_id || 'GL-ERP-1001'} (Workflow Resumed & Completed)`);
      setTimeout(() => {
        onDecisionSubmitted();
      }, 1400);
    } catch (err: any) {
      setIsSuccess(false);
      setStatusMessage(`❌ ${err.message}`);
      setIsSubmitting(false);
    }
  };

  return (
    <div className="space-y-6 max-w-5xl mx-auto animate-fadeIn">
      {/* Top Bar Navigation */}
      <div className="flex items-center justify-between">
        <button
          onClick={onBack}
          className="px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-medium flex items-center space-x-1.5 transition-all"
        >
          <ArrowLeft className="w-4 h-4" />
          <span>Back to Queue</span>
        </button>

        <div className="flex items-center space-x-2">
          <span className="text-xs text-slate-400 font-mono">Invoice ID:</span>
          <span className="text-xs font-mono font-bold text-cyan-400 bg-slate-900 px-2 py-0.5 rounded border border-slate-800">
            {request.invoice_id}
          </span>
        </div>
      </div>

      {/* Guardrail Alert Banner */}
      <div className="p-4 rounded-2xl bg-amber-500/10 border border-amber-500/30 flex items-start space-x-3 text-amber-200 text-xs">
        <ShieldAlert className="w-5 h-5 text-amber-400 flex-shrink-0 mt-0.5" />
        <div>
          <span className="font-bold text-sm text-amber-300 block mb-0.5">
            Human-in-the-Loop Review Triggered
          </span>
          LangGraph state machine paused before <code className="bg-amber-950/60 px-1 py-0.5 rounded font-mono">post_to_gl</code> node.
          Reason: <span className="font-semibold text-white">Extraction confidence {(confidence * 100).toFixed(1)}% (&lt; 0.85 guardrail) + Price Variance (+${(match?.price_variance || 324.00).toFixed(2)})</span>.
        </div>
      </div>

      {/* 3-Way Match Comparator Columns */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        {/* Column 1: Invoiced Extraction */}
        <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800 space-y-3">
          <div className="flex items-center justify-between border-b border-slate-800 pb-2">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-400">1. Invoiced PDF Data</span>
            <span className="text-[10px] font-bold px-2 py-0.5 rounded bg-cyan-500/10 text-cyan-400 border border-cyan-500/20">
              Llama 3.3 70B
            </span>
          </div>

          <div className="space-y-1.5 text-xs">
            <div className="flex justify-between"><span className="text-slate-500">Vendor:</span> <span className="font-semibold text-white">{extracted?.vendor_name || 'Apex Cloud Solutions LLC'}</span></div>
            <div className="flex justify-between"><span className="text-slate-500">Invoice Number:</span> <span className="font-mono text-slate-300">{extracted?.invoice_number || 'INV-2026-0911'}</span></div>
            <div className="flex justify-between"><span className="text-slate-500">Subtotal:</span> <span className="font-mono text-slate-300">${(extracted?.subtotal || 4800.00).toFixed(2)}</span></div>
            <div className="flex justify-between"><span className="text-slate-500">Tax (8%):</span> <span className="font-mono text-slate-300">${(extracted?.tax_amount || 384.00).toFixed(2)}</span></div>
            <div className="flex justify-between pt-1 border-t border-slate-800 font-bold"><span className="text-slate-300">Total Billed:</span> <span className="text-cyan-400">${(extracted?.total_amount || 5184.00).toFixed(2)}</span></div>
          </div>
        </div>

        {/* Column 2: Purchase Order Record */}
        <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800 space-y-3">
          <div className="flex items-center justify-between border-b border-slate-800 pb-2">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-400">2. Mock ERP PO</span>
            <span className="text-[10px] font-bold px-2 py-0.5 rounded bg-indigo-500/10 text-indigo-400 border border-indigo-500/20">
              PO-2026-8891
            </span>
          </div>

          <div className="space-y-1.5 text-xs">
            <div className="flex justify-between"><span className="text-slate-500">Vendor Code:</span> <span className="font-mono text-slate-300">VEND-00104</span></div>
            <div className="flex justify-between"><span className="text-slate-500">Ordered Qty:</span> <span className="font-mono text-slate-300">100.0 Hours</span></div>
            <div className="flex justify-between"><span className="text-slate-500">Unit Price Agreed:</span> <span className="font-mono text-slate-300">$45.00 / hr</span></div>
            <div className="flex justify-between"><span className="text-slate-500">PO Tax:</span> <span className="font-mono text-slate-300">$360.00</span></div>
            <div className="flex justify-between pt-1 border-t border-slate-800 font-bold"><span className="text-slate-300">Committed Total:</span> <span className="text-indigo-400">${(match?.po_total || 4860.00).toFixed(2)}</span></div>
          </div>
        </div>

        {/* Column 3: Goods Receipts */}
        <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800 space-y-3">
          <div className="flex items-center justify-between border-b border-slate-800 pb-2">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-400">3. Delivery Receipts</span>
            <span className="text-[10px] font-bold px-2 py-0.5 rounded bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
              GR-2026-0412
            </span>
          </div>

          <div className="space-y-1.5 text-xs">
            <div className="flex justify-between"><span className="text-slate-500">Received By:</span> <span className="text-slate-300">operations_lead</span></div>
            <div className="flex justify-between"><span className="text-slate-500">Quantity Verified:</span> <span className="font-mono text-emerald-400 font-bold">100.0 / 100.0</span></div>
            <div className="flex justify-between"><span className="text-slate-500">Delivery Status:</span> <span className="text-emerald-400 font-semibold">ACCEPTED</span></div>
            <div className="flex justify-between"><span className="text-slate-500">Condition:</span> <span className="text-slate-300">Compute delivered</span></div>
            <div className="flex justify-between pt-1 border-t border-slate-800 font-bold"><span className="text-slate-300">Receipt Match:</span> <span className="text-emerald-400">100% Qty Match</span></div>
          </div>
        </div>
      </div>

      {/* Line-Level Variance Analysis */}
      <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800 space-y-3">
        <h3 className="text-xs font-bold uppercase tracking-wider text-slate-400">
          Line Item Reconciliation &amp; Unit Variance
        </h3>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs border-collapse">
            <thead>
              <tr className="border-b border-slate-800 text-slate-500 font-semibold uppercase">
                <th className="pb-2">SKU / Item</th>
                <th className="pb-2">Invoiced Qty</th>
                <th className="pb-2">PO Qty</th>
                <th className="pb-2">Invoice Unit</th>
                <th className="pb-2">PO Unit</th>
                <th className="pb-2">Unit Variance</th>
                <th className="pb-2 text-right">Match Result</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800/60 font-mono text-slate-200">
              <tr>
                <td className="py-3 font-sans font-semibold text-white">SRV-CLOUD-01 (Task Worker)</td>
                <td className="py-3">100.0</td>
                <td className="py-3">100.0</td>
                <td className="py-3 text-red-400 font-bold">$48.00</td>
                <td className="py-3 text-slate-400">$45.00</td>
                <td className="py-3 text-red-400 font-bold">+$3.00 / hr</td>
                <td className="py-3 text-right">
                  <span className="px-2 py-0.5 rounded text-[10px] font-bold bg-red-500/10 text-red-400 border border-red-500/30">
                    PRICE_MISMATCH
                  </span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      {/* Reviewer Action Box */}
      <div className="p-6 rounded-2xl bg-slate-900 border border-slate-800 space-y-4">
        <h3 className="text-sm font-bold text-white flex items-center space-x-2">
          <span>Submit Human Guardrail Decision</span>
        </h3>

        <div>
          <label className="block text-xs font-semibold text-slate-400 mb-1.5">
            Audit Trail Notes &amp; Justification
          </label>
          <input
            type="text"
            value={reviewerNotes}
            onChange={(e) => setReviewerNotes(e.target.value)}
            className="w-full px-4 py-2.5 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-100 focus:outline-none focus:border-cyan-500"
            placeholder="State rationale for approval or override..."
          />
        </div>

        {statusMessage && (
          <div className={`p-3 rounded-xl border text-xs font-semibold flex items-center space-x-2 animate-fadeIn ${
            isSuccess 
              ? 'bg-emerald-500/10 border-emerald-500/30 text-emerald-300' 
              : 'bg-red-500/10 border-red-500/30 text-red-300'
          }`}>
            {isSuccess ? <CheckCircle2 className="w-4 h-4 text-emerald-400" /> : <X className="w-4 h-4 text-red-400" />}
            <span>{statusMessage}</span>
          </div>
        )}

        <div className="flex items-center justify-end space-x-3 pt-2">
          <button
            onClick={() => handleDecision('REJECTED')}
            disabled={isSubmitting}
            className="px-4 py-2.5 rounded-xl bg-red-500/10 hover:bg-red-500/20 text-red-400 border border-red-500/30 text-xs font-semibold flex items-center space-x-1.5 transition-all disabled:opacity-50"
          >
            <X className="w-4 h-4" />
            <span>Reject Invoice</span>
          </button>

          <button
            onClick={() => handleDecision('APPROVED')}
            disabled={isSubmitting}
            className="px-6 py-2.5 rounded-xl bg-gradient-to-r from-emerald-500 to-teal-600 hover:from-emerald-400 hover:to-teal-500 text-white text-xs font-bold shadow-lg shadow-emerald-500/20 flex items-center space-x-1.5 transition-all disabled:opacity-50"
          >
            {isSubmitting ? (
              <>
                <Loader2 className="w-4 h-4 animate-spin" />
                <span>Posting to General Ledger...</span>
              </>
            ) : (
              <>
                <Check className="w-4 h-4" />
                <span>Approve &amp; Resume LangGraph (Post to GL)</span>
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  );
};
