import React, { useEffect, useState } from 'react';
import { Layers, ShieldCheck, Zap, Server, Activity } from 'lucide-react';
import { fetchHealthReport } from '../services/api';
import { SystemHealthReport } from '../types';

interface NavbarProps {
  activeTab: 'dashboard' | 'upload' | 'approvals';
  setActiveTab: (tab: 'dashboard' | 'upload' | 'approvals') => void;
  pendingCount: number;
}

export const Navbar: React.FC<NavbarProps> = ({ activeTab, setActiveTab, pendingCount }) => {
  const [health, setHealth] = useState<SystemHealthReport | null>(null);

  useEffect(() => {
    const check = async () => {
      const data = await fetchHealthReport();
      setHealth(data);
    };
    check();
    const interval = setInterval(check, 4000);
    return () => clearInterval(interval);
  }, []);

  const isErpUp = health?.dependencies?.mock_erp === 'up';

  return (
    <header className="border-b border-slate-800 bg-slate-900/80 backdrop-blur-md sticky top-0 z-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
        
        {/* Brand */}
        <div className="flex items-center space-x-3 cursor-pointer" onClick={() => setActiveTab('dashboard')}>
          <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-cyan-600 via-sky-500 to-indigo-600 flex items-center justify-center shadow-lg shadow-cyan-500/20">
            <Layers className="w-6 h-6 text-white" />
          </div>
          <div>
            <div className="flex items-center space-x-2">
              <span className="font-bold text-lg tracking-tight text-white">LedgerAgent</span>
              <span className="text-[10px] uppercase font-bold tracking-wider px-2 py-0.5 rounded-full bg-cyan-500/10 text-cyan-400 border border-cyan-500/20">
                Agentic 3-Way Match
              </span>
            </div>
            <p className="text-xs text-slate-400">AWS ECS Fargate &amp; LangGraph Workflow</p>
          </div>
        </div>

        {/* Navigation Tabs */}
        <nav className="flex items-center space-x-1 sm:space-x-2">
          <button
            onClick={() => setActiveTab('dashboard')}
            className={`px-3.5 py-2 rounded-lg text-sm font-medium transition-all ${
              activeTab === 'dashboard'
                ? 'bg-slate-800 text-cyan-400 border border-slate-700 shadow-sm'
                : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/50'
            }`}
          >
            Dashboard
          </button>
          
          <button
            onClick={() => setActiveTab('upload')}
            className={`px-3.5 py-2 rounded-lg text-sm font-medium transition-all flex items-center space-x-1.5 ${
              activeTab === 'upload'
                ? 'bg-slate-800 text-cyan-400 border border-slate-700 shadow-sm'
                : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/50'
            }`}
          >
            <Zap className="w-4 h-4 text-cyan-400" />
            <span>Upload Invoice</span>
          </button>

          <button
            onClick={() => setActiveTab('approvals')}
            className={`px-3.5 py-2 rounded-lg text-sm font-medium transition-all flex items-center space-x-2 ${
              activeTab === 'approvals'
                ? 'bg-slate-800 text-cyan-400 border border-slate-700 shadow-sm'
                : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/50'
            }`}
          >
            <ShieldCheck className="w-4 h-4 text-amber-400" />
            <span>HITL Review Queue</span>
            {pendingCount > 0 && (
              <span className="px-2 py-0.5 text-xs font-bold rounded-full bg-amber-500/20 text-amber-300 border border-amber-500/30 animate-pulse">
                {pendingCount}
              </span>
            )}
          </button>
        </nav>

        {/* Live Status Indicators */}
        <div className="hidden md:flex items-center space-x-3 pl-4 border-l border-slate-800">
          <div className="flex items-center space-x-2 text-xs">
            <span className={`w-2.5 h-2.5 rounded-full ${isErpUp ? 'bg-emerald-500 shadow-lg shadow-emerald-500/50 animate-pulse' : 'bg-red-500'}`}></span>
            <span className={isErpUp ? 'text-emerald-400 font-medium' : 'text-red-400 font-medium'}>
              Mock ERP :8001 {isErpUp ? '(Online)' : '(Offline)'}
            </span>
          </div>
          <div className="flex items-center space-x-1.5 text-xs text-slate-400 font-mono bg-slate-950 px-2 py-1 rounded border border-slate-800">
            <Server className="w-3.5 h-3.5 text-cyan-400" />
            <span>LangGraph: Active</span>
          </div>
        </div>

      </div>
    </header>
  );
};
