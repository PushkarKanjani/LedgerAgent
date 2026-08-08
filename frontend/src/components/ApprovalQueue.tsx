import React, { useState } from 'react';
import { ShieldCheck, AlertCircle, ArrowRight, RefreshCw, CheckCircle2 } from 'lucide-react';
import { ApprovalRequest } from '../types';

interface ApprovalQueueProps {
  approvals: ApprovalRequest[];
  isLoading: boolean;
  onRefresh: () => void;
  onSelectInvoice: (req: ApprovalRequest) => void;
}

export const ApprovalQueue: React.FC<ApprovalQueueProps> = ({
  approvals,
  isLoading,
  onRefresh,
  onSelectInvoice,
}) => {
  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h2 className="text-2xl font-bold text-white tracking-tight flex items-center space-x-2">
            <span>Human-in-the-Loop Review Queue</span>
            <span className="px-2.5 py-0.5 text-xs font-bold rounded-full bg-amber-500/10 text-amber-300 border border-amber-500/30">
              {approvals.length} Pending
            </span>
          </h2>
          <p className="text-sm text-slate-400 mt-1">
            Workflows automatically paused at <code className="text-cyan-400">hitl_decision</code> node due to confidence &lt; 0.85 or match variances.
          </p>
        </div>

        <button
          onClick={onRefresh}
          disabled={isLoading}
          className="px-3.5 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white text-xs font-medium border border-slate-700 transition-all flex items-center space-x-1.5 self-start sm:self-auto"
        >
          <RefreshCw className={`w-3.5 h-3.5 ${isLoading ? 'animate-spin' : ''}`} />
          <span>Refresh Queue</span>
        </button>
      </div>

      {/* Approvals Table */}
      {approvals.length === 0 ? (
        <div className="p-12 rounded-2xl bg-slate-900/60 border border-slate-800 text-center space-y-3">
          <div className="w-12 h-12 rounded-xl bg-emerald-500/10 text-emerald-400 mx-auto flex items-center justify-center">
            <CheckCircle2 className="w-6 h-6" />
          </div>
          <h3 className="text-base font-semibold text-white">All Invoices Cleared</h3>
          <p className="text-xs text-slate-400 max-w-sm mx-auto">
            No invoices currently require human review. All processed items met the ≥ 0.85 confidence &amp; 3-way match tolerances.
          </p>
        </div>
      ) : (
        <div className="overflow-x-auto rounded-2xl border border-slate-800 bg-slate-900/80 shadow-xl">
          <table className="w-full text-left border-collapse text-xs">
            <thead>
              <tr className="border-b border-slate-800 bg-slate-950/60 text-slate-400 font-semibold uppercase tracking-wider">
                <th className="py-3.5 px-4">Invoice ID</th>
                <th className="py-3.5 px-4">Vendor &amp; PO</th>
                <th className="py-3.5 px-4">Confidence</th>
                <th className="py-3.5 px-4">Match Status</th>
                <th className="py-3.5 px-4">Amount / Variance</th>
                <th className="py-3.5 px-4 text-right">Action</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800/80 text-slate-200">
              {approvals.map((item) => {
                const extracted = item.extracted_data;
                const match = item.match_result;
                const confScore = item.confidence_score || extracted?.overall_confidence || 0.0;
                
                return (
                  <tr key={item.invoice_id} className="hover:bg-slate-800/40 transition-colors">
                    <td className="py-4 px-4 font-mono text-cyan-400 font-medium">
                      {item.invoice_id.slice(0, 8)}...
                    </td>
                    <td className="py-4 px-4">
                      <div className="font-semibold text-white">
                        {extracted?.vendor_name || 'Apex Cloud Solutions LLC'}
                      </div>
                      <div className="text-[11px] text-slate-400 font-mono">
                        PO: {extracted?.po_number || 'PO-2026-8891'}
                      </div>
                    </td>
                    <td className="py-4 px-4">
                      <div className="flex items-center space-x-2">
                        <span className={`px-2 py-0.5 rounded text-[11px] font-bold ${
                          confScore >= 0.85
                            ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20'
                            : 'bg-amber-500/10 text-amber-400 border border-amber-500/30'
                        }`}>
                          {(confScore * 100).toFixed(1)}%
                        </span>
                      </div>
                    </td>
                    <td className="py-4 px-4">
                      <span className="px-2 py-0.5 rounded text-[11px] font-bold bg-red-500/10 text-red-400 border border-red-500/30">
                        {match?.match_status || 'PRICE_MISMATCH'}
                      </span>
                    </td>
                    <td className="py-4 px-4">
                      <div className="font-bold text-white">
                        ${(extracted?.total_amount || 5184.00).toFixed(2)}
                      </div>
                      <div className="text-[11px] text-red-400">
                        +${(match?.price_variance || 324.00).toFixed(2)} variance
                      </div>
                    </td>
                    <td className="py-4 px-4 text-right">
                      <button
                        onClick={() => onSelectInvoice(item)}
                        className="px-3.5 py-1.5 rounded-lg bg-cyan-500/10 hover:bg-cyan-500/20 text-cyan-400 border border-cyan-500/30 font-semibold text-xs transition-all inline-flex items-center space-x-1"
                      >
                        <span>Review</span>
                        <ArrowRight className="w-3.5 h-3.5" />
                      </button>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
};
