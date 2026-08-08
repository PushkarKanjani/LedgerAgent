import React from 'react';
import { ShieldCheck, AlertCircle, ArrowUpRight, Cpu, Layers, DollarSign, Activity } from 'lucide-react';
import { ApprovalRequest } from '../types';

interface DashboardProps {
  pendingApprovals: ApprovalRequest[];
  onOpenUpload: () => void;
  onOpenApprovals: () => void;
}

export const Dashboard: React.FC<DashboardProps> = ({
  pendingApprovals,
  onOpenUpload,
  onOpenApprovals,
}) => {
  return (
    <div className="space-y-8 animate-fadeIn">
      {/* Hero Welcome & Stats */}
      <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4 p-6 rounded-2xl bg-gradient-to-br from-slate-900 via-slate-900/90 to-slate-800 border border-slate-800 shadow-xl">
        <div>
          <div className="flex items-center space-x-2 text-cyan-400 font-semibold text-xs tracking-wider uppercase mb-1">
            <Activity className="w-4 h-4 animate-pulse" />
            <span>Autonomous Reconciliation Engine</span>
          </div>
          <h1 className="text-2xl sm:text-3xl font-extrabold text-white tracking-tight">
            Finance Operations Overview
          </h1>
          <p className="text-sm text-slate-400 mt-1 max-w-xl">
            Real-time three-way matching against Purchase Orders and Goods Receipts with confidence-scored Human-in-the-Loop guardrails.
          </p>
        </div>

        <div className="flex items-center space-x-3">
          <button
            onClick={onOpenUpload}
            className="px-4 py-2.5 rounded-xl bg-gradient-to-r from-cyan-500 to-sky-600 hover:from-cyan-400 hover:to-sky-500 text-white font-semibold text-sm shadow-lg shadow-cyan-500/20 transition-all flex items-center space-x-2"
          >
            <span>Upload New Invoice</span>
            <ArrowUpRight className="w-4 h-4" />
          </button>
        </div>
      </div>

      {/* KPI Cards Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* STP Auto-Approval Rate */}
        <div className="p-5 rounded-2xl bg-slate-900/80 border border-slate-800 hover:border-slate-700 transition-all">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold uppercase tracking-wider text-slate-400">STP Pass Rate</span>
            <div className="w-8 h-8 rounded-lg bg-emerald-500/10 text-emerald-400 flex items-center justify-center">
              <ShieldCheck className="w-4 h-4" />
            </div>
          </div>
          <div className="mt-3">
            <div className="text-2xl font-bold text-white tracking-tight">88.4%</div>
            <p className="text-xs text-emerald-400 mt-1 font-medium">Confidence ≥ 0.85 auto-approved</p>
          </div>
        </div>

        {/* Pending HITL Approvals */}
        <div 
          onClick={onOpenApprovals}
          className="p-5 rounded-2xl bg-slate-900/80 border border-slate-800 hover:border-amber-500/50 cursor-pointer transition-all group"
        >
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold uppercase tracking-wider text-slate-400">HITL Guardrail Queue</span>
            <div className="w-8 h-8 rounded-lg bg-amber-500/10 text-amber-400 flex items-center justify-center group-hover:scale-110 transition-transform">
              <AlertCircle className="w-4 h-4" />
            </div>
          </div>
          <div className="mt-3">
            <div className="text-2xl font-bold text-white tracking-tight flex items-baseline space-x-2">
              <span>{pendingApprovals.length}</span>
              <span className="text-xs text-amber-400 font-medium">Requires Review</span>
            </div>
            <p className="text-xs text-slate-400 mt-1">Confidence &lt; 0.85 or Price Variance</p>
          </div>
        </div>

        {/* OCR Latency & Engine */}
        <div className="p-5 rounded-2xl bg-slate-900/80 border border-slate-800 hover:border-slate-700 transition-all">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold uppercase tracking-wider text-slate-400">Dual OCR Engine</span>
            <div className="w-8 h-8 rounded-lg bg-cyan-500/10 text-cyan-400 flex items-center justify-center">
              <Cpu className="w-4 h-4" />
            </div>
          </div>
          <div className="mt-3">
            <div className="text-2xl font-bold text-white tracking-tight">1.2s avg</div>
            <p className="text-xs text-cyan-400 mt-1 font-medium">Textract + PaddleOCR Fallback</p>
          </div>
        </div>

        {/* Free-Tier Cloud Cost */}
        <div className="p-5 rounded-2xl bg-slate-900/80 border border-slate-800 hover:border-slate-700 transition-all">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold uppercase tracking-wider text-slate-400">AWS Monthly Cost</span>
            <div className="w-8 h-8 rounded-lg bg-indigo-500/10 text-indigo-400 flex items-center justify-center">
              <DollarSign className="w-4 h-4" />
            </div>
          </div>
          <div className="mt-3">
            <div className="text-2xl font-bold text-white tracking-tight">$0.00</div>
            <p className="text-xs text-indigo-400 mt-1 font-medium">100% Free-Tier Optimized</p>
          </div>
        </div>
      </div>

      {/* Workflow Topology Architecture Visualizer */}
      <div className="p-6 rounded-2xl bg-slate-900/80 border border-slate-800">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-lg font-bold text-white flex items-center space-x-2">
            <Layers className="w-5 h-5 text-cyan-400" />
            <span>LangGraph Pipeline Topology & Guardrail States</span>
          </h2>
          <span className="text-xs font-mono text-cyan-400 bg-cyan-950/60 px-2.5 py-1 rounded-md border border-cyan-800/40">
            Durable Checkpointer: Memory / Redis
          </span>
        </div>

        <div className="grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-7 gap-3 text-center">
          <div className="p-3 rounded-xl bg-slate-800/60 border border-slate-700">
            <div className="text-xs font-bold text-slate-300">1. Ingest</div>
            <p className="text-[11px] text-slate-400 mt-1">SHA-256 Dedup</p>
          </div>
          <div className="p-3 rounded-xl bg-slate-800/60 border border-slate-700">
            <div className="text-xs font-bold text-slate-300">2. Dual OCR</div>
            <p className="text-[11px] text-slate-400 mt-1">Textract/Paddle</p>
          </div>
          <div className="p-3 rounded-xl bg-slate-800/60 border border-slate-700">
            <div className="text-xs font-bold text-slate-300">3. Extraction</div>
            <p className="text-[11px] text-slate-400 mt-1">Pydantic Validate</p>
          </div>
          <div className="p-3 rounded-xl bg-slate-800/60 border border-slate-700">
            <div className="text-xs font-bold text-slate-300">4. 3-Way Match</div>
            <p className="text-[11px] text-slate-400 mt-1">PO & Receipts</p>
          </div>
          <div className="p-3 rounded-xl bg-amber-500/10 border border-amber-500/40">
            <div className="text-xs font-bold text-amber-300">5. HITL Pause</div>
            <p className="text-[11px] text-amber-400/80 mt-1">&lt;0.85 / Variance</p>
          </div>
          <div className="p-3 rounded-xl bg-emerald-500/10 border border-emerald-500/40">
            <div className="text-xs font-bold text-emerald-300">6. GL Post</div>
            <p className="text-[11px] text-emerald-400/80 mt-1">Idempotent Sync</p>
          </div>
          <div className="p-3 rounded-xl bg-slate-800/60 border border-slate-700">
            <div className="text-xs font-bold text-slate-300">7. Audit Log</div>
            <p className="text-[11px] text-slate-400 mt-1">PostgreSQL Trail</p>
          </div>
        </div>
      </div>
    </div>
  );
};
