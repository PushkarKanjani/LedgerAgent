import React, { useEffect, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import Lenis from 'lenis';
import {
  ArrowRight,
  ShieldCheck,
  Cpu,
  Layers,
  Database,
  Lock,
  Zap,
  CheckCircle2,
  Terminal,
  Activity,
  FileText,
  Sun,
  Moon
} from 'lucide-react';
import { useTheme } from '../context/ThemeContext';

export const LandingPage: React.FC = () => {
  const [activeStep, setActiveStep] = useState<number>(0);
  const containerRef = useRef<HTMLDivElement>(null);
  const { theme, toggleTheme } = useTheme();

  // Initialize Lenis smooth scroll on public landing page only
  useEffect(() => {
    // Respect prefers-reduced-motion
    const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (prefersReducedMotion) return;

    const lenis = new Lenis({
      duration: 1.2,
      easing: (t) => Math.min(1, 1.001 - Math.pow(2, -10 * t)),
      orientation: 'vertical',
      smoothWheel: true,
    });

    function raf(time: number) {
      lenis.raf(time);
      requestAnimationFrame(raf);
    }
    const reqId = requestAnimationFrame(raf);

    return () => {
      cancelAnimationFrame(reqId);
      lenis.destroy();
    };
  }, []);

  // Track scroll position for LangGraph topology lighting
  useEffect(() => {
    const handleScroll = () => {
      const stepElements = document.querySelectorAll('.story-step');
      const viewportMiddle = window.innerHeight / 2;

      stepElements.forEach((el, index) => {
        const rect = el.getBoundingClientRect();
        if (rect.top <= viewportMiddle && rect.bottom >= viewportMiddle) {
          setActiveStep(index);
        }
      });
    };

    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  const marqueeBadges = [
    'FastAPI 0.110',
    'LangGraph 0.2.0',
    'Groq Llama 3.3 70B',
    'AWS ECS Fargate',
    'PostgreSQL 15',
    'AWS Textract',
    'PaddleOCR Fallback',
    'SHA-256 Idempotency',
    'DeepEval Golden 30',
    'Redis Checkpointer',
  ];

  const storySteps = [
    {
      num: '01',
      title: 'Cryptographic Ingestion & Dedup',
      desc: 'Every PDF is hashed via SHA-256 before inference. Duplicate submissions return cached ledger entries in 0.02s without burning LLM tokens.',
      metric: '100% Idempotency Protection',
    },
    {
      num: '02',
      title: 'Dual-Engine OCR Pipeline',
      desc: 'Clean digital PDFs are routed to AWS Textract. Degraded or scanned invoices automatically fall back to PaddleOCR without pipeline interruption.',
      metric: '1,000 Pages / Month Free Tier',
    },
    {
      num: '03',
      title: 'Structured Pydantic Extraction',
      desc: 'Llama 3.3 70B extracts invoice line items, tax, and totals with strict type safety. Enforces arithmetic balancing constraints (subtotal + tax = total).',
      metric: '100.0% Total Amount Precision',
    },
    {
      num: '04',
      title: 'Deterministic 3-Way Reconciliation',
      desc: 'Queries purchase orders and warehouse delivery receipts. Calculates unit-price variance and quantity variances against a 2% tolerance threshold.',
      metric: '66.7% Straight-Through Pass Rate',
    },
    {
      num: '05',
      title: 'Human-in-the-Loop Guardrail',
      desc: 'LangGraph interrupt_before halts workflow execution when confidence < 0.85 or price mismatch occurs. Resumes seamlessly when approved in dashboard.',
      metric: '0 False-Accepts (0.0% Double Payment)',
    },
    {
      num: '06',
      title: 'Idempotent General Ledger Posting',
      desc: 'Reconciled journals are posted directly to Mock ERP accounting with full audit event tracing in PostgreSQL and Langfuse.',
      metric: '0.061s Average Ingestion Latency',
    },
  ];

  return (
    <div className="bg-warmWhite dark:bg-graphite text-ink dark:text-warmWhite min-h-screen font-body antialiased selection:bg-electric selection:text-white transition-colors duration-200">
      
      {/* Restrained radial glow behind hero */}
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[800px] h-[500px] bg-electric/5 dark:bg-electric/10 blur-[120px] pointer-events-none rounded-full" />

      {/* Top Floating Glass Navigation */}
      <header className="sticky top-0 z-50 border-b border-hairline dark:border-darkHairline bg-warmWhite/80 dark:bg-graphite/80 backdrop-blur-md transition-colors duration-200">
        <div className="max-w-7xl mx-auto px-6 h-16 flex items-center justify-between">
          <div className="flex items-center space-x-3">
            <span className="w-3 h-3 bg-electric rounded-none inline-block"></span>
            <span className="font-display font-bold text-lg tracking-tight text-ink dark:text-white">
              LedgerAgent
            </span>
            <span className="text-[10px] font-mono uppercase tracking-widest text-warmMuted border border-hairline dark:border-darkHairline px-2 py-0.5 ml-2">
              v2.0 Cinematic
            </span>
          </div>

          <div className="flex items-center space-x-4 sm:space-x-6">
            <a
              href="#architecture"
              className="text-xs font-mono text-warmMuted hover:text-ink dark:hover:text-white transition-colors hidden sm:inline"
            >
              Architecture
            </a>
            <a
              href="#metrics"
              className="text-xs font-mono text-warmMuted hover:text-ink dark:hover:text-white transition-colors hidden sm:inline"
            >
              Benchmarks
            </a>

            {/* Theme Toggle Button */}
            <button
              onClick={toggleTheme}
              title={`Switch to ${theme === 'dark' ? 'Light' : 'Dark'} Mode`}
              className="p-2 border border-hairline dark:border-darkHairline text-ink dark:text-warmWhite hover:bg-paperAlt dark:hover:bg-graphiteCard transition-colors flex items-center justify-center rounded-none"
            >
              {theme === 'dark' ? (
                <Sun className="w-3.5 h-3.5 text-amberGlow" />
              ) : (
                <Moon className="w-3.5 h-3.5 text-inkMuted" />
              )}
            </button>

            <Link
              to="/app/inbox"
              className="px-4 py-2 text-xs font-display font-semibold bg-electric text-white rounded-none hover:bg-electric/90 transition-all flex items-center space-x-1.5 shadow-lg shadow-electric/20"
            >
              <span>Launch App Surface</span>
              <ArrowRight className="w-3.5 h-3.5" />
            </Link>
          </div>
        </div>
      </header>

      {/* 1. HERO SECTION */}
      <section className="max-w-7xl mx-auto px-6 pt-24 pb-20 grid grid-cols-1 lg:grid-cols-12 gap-12 items-center">
        <div className="lg:col-span-8 space-y-6">
          <div className="inline-flex items-center space-x-2 text-[10px] font-mono uppercase tracking-widest text-electric border border-hairline dark:border-darkHairline px-3 py-1 bg-paperAlt dark:bg-graphiteCard">
            <Activity className="w-3 h-3 text-electric animate-pulse" />
            <span>Production-Grade Agentic Finance Operations</span>
          </div>

          <h1 className="font-display font-bold text-4xl sm:text-6xl lg:text-7xl tracking-tighter text-ink dark:text-white leading-[1.05]">
            The accounts-payable clerk that{' '}
            <span className="font-serifDisplay italic font-normal text-ink dark:text-warmWhite">
              never sleeps.
            </span>
          </h1>

          <p className="font-mono text-sm text-warmMuted max-w-2xl leading-relaxed">
            Autonomous 3-way invoice matching across purchase orders and goods delivery receipts with LangGraph stateful checkpointing, Groq Llama 3.3 70B inference, and Human-in-the-Loop safety guardrails.
          </p>

          <div className="flex flex-wrap items-center gap-4 pt-4">
            <Link
              to="/app/inbox"
              className="px-6 py-3.5 text-sm font-display font-bold bg-electric text-white hover:bg-electric/90 transition-all flex items-center space-x-2 shadow-xl shadow-electric/25"
            >
              <span>Enter Swiss App →</span>
            </Link>
            <a
              href="https://github.com"
              target="_blank"
              rel="noreferrer"
              className="px-6 py-3.5 text-sm font-mono text-ink dark:text-warmWhite border border-hairline dark:border-darkHairline hover:border-warmMuted hover:bg-paperAlt dark:hover:bg-graphiteCard transition-all flex items-center space-x-2"
            >
              <Terminal className="w-4 h-4 text-warmMuted" />
              <span>Read Architecture Specification</span>
            </a>
          </div>
        </div>

        {/* Hero Right: Live Telemetry Ticker */}
        <div className="lg:col-span-4 border border-hairline dark:border-darkHairline bg-paperAlt dark:bg-graphiteCard p-6 space-y-4 font-mono text-xs">
          <div className="flex items-center justify-between border-b border-hairline dark:border-darkHairline pb-3">
            <span className="text-[10px] uppercase text-warmMuted">System Telemetry</span>
            <span className="text-emerald-500 text-[10px] flex items-center space-x-1">
              <span className="w-1.5 h-1.5 bg-emerald-500 rounded-full animate-ping"></span>
              <span>LIVE CLUSTER</span>
            </span>
          </div>

          <div className="space-y-3">
            <div className="flex justify-between">
              <span className="text-warmMuted">STP Auto-Pass:</span>
              <span className="text-ink dark:text-white font-bold">66.7% (20/30)</span>
            </div>
            <div className="flex justify-between">
              <span className="text-warmMuted">False-Accept Risk:</span>
              <span className="text-emerald-500 font-bold">0.0% (Zero Leaks)</span>
            </div>
            <div className="flex justify-between">
              <span className="text-warmMuted">Extraction Latency:</span>
              <span className="text-ink dark:text-white font-bold">0.061s avg</span>
            </div>
            <div className="flex justify-between">
              <span className="text-warmMuted">Guardrail Threshold:</span>
              <span className="text-pending font-bold">&lt; 0.85 Confidence</span>
            </div>
            <div className="flex justify-between">
              <span className="text-warmMuted">Deduplication:</span>
              <span className="text-electric font-bold">SHA-256 Pre-Check</span>
            </div>
          </div>
        </div>
      </section>

      {/* 2. INFINITE MARQUEE TICKER */}
      <div className="border-y border-hairline dark:border-darkHairline py-3 bg-paperAlt dark:bg-graphiteLight overflow-hidden">
        <div className="flex space-x-12 animate-marquee whitespace-nowrap font-mono text-xs text-warmMuted">
          {marqueeBadges.concat(marqueeBadges).map((item, idx) => (
            <span key={idx} className="flex items-center space-x-2">
              <span className="w-1.5 h-1.5 bg-electric rounded-none"></span>
              <span className="text-ink dark:text-warmWhite">{item}</span>
            </span>
          ))}
        </div>
      </div>

      {/* 3. STICKY TWO-COLUMN LANGGRAPH TOPOLOGY STORY */}
      <section id="architecture" className="max-w-7xl mx-auto px-6 py-28">
        <div className="mb-12">
          <span className="text-[10px] font-mono uppercase tracking-widest text-electric">
            Section 02 &bull; Deterministic State Topology
          </span>
          <h2 className="font-display font-bold text-3xl sm:text-5xl text-ink dark:text-white tracking-tight mt-1">
            Six-Node Graph Machine
          </h2>
          <p className="font-mono text-xs text-warmMuted mt-2">
            Scroll down to inspect state transitions, confidence routing, and the Human-in-the-Loop decision branch.
          </p>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 items-start">
          
          {/* Left Column: Sticky Topology Diagram */}
          <div className="lg:col-span-5 sticky top-24 border border-hairline dark:border-darkHairline bg-paperAlt dark:bg-graphiteCard p-6 space-y-4">
            <div className="flex items-center justify-between border-b border-hairline dark:border-darkHairline pb-3">
              <span className="text-[10px] font-mono uppercase text-warmMuted">Active Graph Topology</span>
              <span className="text-xs font-mono text-electric">Step {storySteps[activeStep].num} / 06</span>
            </div>

            {/* SVG Visualizer */}
            <div className="py-4 space-y-3 font-mono text-xs">
              {storySteps.map((s, idx) => {
                const isActive = idx === activeStep;
                return (
                  <div
                    key={s.num}
                    className={`p-3 border transition-all duration-300 ${
                      isActive
                        ? 'border-electric bg-electric/10 text-ink dark:text-white shadow-lg'
                        : 'border-hairline dark:border-darkHairline bg-paper dark:bg-graphite text-warmMuted opacity-60'
                    }`}
                  >
                    <div className="flex items-center justify-between">
                      <span className="font-bold">{s.num}. {s.title}</span>
                      {isActive && <span className="text-[10px] text-electric uppercase font-bold animate-pulse">ACTIVE NODE</span>}
                    </div>
                  </div>
                );
              })}
            </div>

            <div className="border-t border-hairline dark:border-darkHairline pt-3 text-[11px] font-mono text-warmMuted">
              <span>State checkpointer: </span>
              <span className="text-ink dark:text-white font-bold">MemorySaver (Local) / ElastiCache Redis (AWS)</span>
            </div>
          </div>

          {/* Right Column: Scroll-Driven Detailed Narrative */}
          <div className="lg:col-span-7 space-y-24">
            {storySteps.map((step, idx) => (
              <div
                key={step.num}
                className="story-step border border-hairline dark:border-darkHairline bg-paperAlt dark:bg-graphiteCard p-8 space-y-4 transition-all"
              >
                <div className="flex items-center justify-between">
                  <span className="font-mono text-xs text-electric uppercase tracking-wider font-bold">
                    Step {step.num} Execution
                  </span>
                  <span className="text-[10px] font-mono text-warmMuted border border-hairline dark:border-darkHairline px-2 py-0.5">
                    {step.metric}
                  </span>
                </div>

                <h3 className="font-display font-bold text-2xl text-ink dark:text-white tracking-tight">
                  {step.title}
                </h3>

                <p className="font-body text-sm text-warmMuted leading-relaxed">
                  {step.desc}
                </p>
              </div>
            ))}
          </div>

        </div>
      </section>

      {/* 4. METRICS BAND (Direct from docs/eval_report.md) */}
      <section id="metrics" className="border-t border-hairline dark:border-darkHairline bg-paperAlt dark:bg-graphiteLight py-20 transition-colors duration-200">
        <div className="max-w-7xl mx-auto px-6 space-y-12">
          <div>
            <span className="text-[10px] font-mono uppercase tracking-widest text-electric">
              Section 03 &bull; DeepEval Golden Benchmark
            </span>
            <h2 className="font-display font-bold text-3xl text-ink dark:text-white tracking-tight mt-1">
              Verified Benchmark Performance
            </h2>
            <p className="text-xs font-mono text-warmMuted mt-1">
              Evaluated against 30 golden synthetic invoices across Happy Path, OCR Typos, and Price Variance Exceptions.
            </p>
          </div>

          <div className="grid grid-cols-2 sm:grid-cols-4 gap-6">
            <div className="border-t border-hairline dark:border-darkHairline pt-4">
              <span className="text-[10px] font-mono text-warmMuted uppercase">STP Pass Rate</span>
              <div className="font-display font-bold text-4xl text-ink dark:text-white mt-1">66.7%</div>
              <p className="text-[10px] font-mono text-warmMuted mt-1">20 / 30 Invoices Auto-Posted</p>
            </div>

            <div className="border-t border-hairline dark:border-darkHairline pt-4">
              <span className="text-[10px] font-mono text-warmMuted uppercase">False Accept Rate</span>
              <div className="font-display font-bold text-4xl text-emerald-500 mt-1">0.0%</div>
              <p className="text-[10px] font-mono text-warmMuted mt-1">Zero Erroneous GL Posts</p>
            </div>

            <div className="border-t border-hairline dark:border-darkHairline pt-4">
              <span className="text-[10px] font-mono text-warmMuted uppercase">HITL Escalation</span>
              <div className="font-display font-bold text-4xl text-pending mt-1">33.3%</div>
              <p className="text-[10px] font-mono text-warmMuted mt-1">10 / 30 Safely Interrupted</p>
            </div>

            <div className="border-t border-hairline dark:border-darkHairline pt-4">
              <span className="text-[10px] font-mono text-warmMuted uppercase">Precision (Total)</span>
              <div className="font-display font-bold text-4xl text-electric mt-1">100.0%</div>
              <p className="text-[10px] font-mono text-warmMuted mt-1">0 Extraction Errors</p>
            </div>
          </div>
        </div>
      </section>

      {/* 5. APP DUAL SURFACE CALLOUT */}
      <section className="max-w-7xl mx-auto px-6 py-24 space-y-12">
        <div className="flex flex-col sm:flex-row sm:items-end justify-between gap-4 border-b border-hairline dark:border-darkHairline pb-6">
          <div>
            <span className="text-[10px] font-mono uppercase tracking-widest text-electric">
              Section 04 &bull; Dual Surface Interface
            </span>
            <h2 className="font-display font-bold text-3xl text-ink dark:text-white tracking-tight mt-1">
              Swiss Editorial Application
            </h2>
          </div>
          <Link to="/app/inbox" className="text-xs font-mono text-electric hover:underline">
            Open Interactive App →
          </Link>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
          <div className="border border-hairline dark:border-darkHairline bg-paperAlt dark:bg-graphiteCard p-6 space-y-4">
            <div className="flex items-center justify-between border-b border-hairline dark:border-darkHairline pb-2">
              <span className="text-xs font-mono text-ink dark:text-white">01. 3-Way Match Comparator</span>
              <span className="text-[10px] font-mono text-warmMuted">FT-Style Layout</span>
            </div>
            <div className="h-48 border border-dashed border-hairline dark:border-darkHairline flex flex-col items-center justify-center p-6 text-center space-y-2">
              <FileText className="w-8 h-8 text-warmMuted" />
              <p className="font-mono text-xs text-warmMuted">
                Side-by-side comparison of Invoiced PDF data vs. Purchase Orders and Delivery Receipts.
              </p>
            </div>
          </div>

          <div className="border border-hairline dark:border-darkHairline bg-paperAlt dark:bg-graphiteCard p-6 space-y-4">
            <div className="flex items-center justify-between border-b border-hairline dark:border-darkHairline pb-2">
              <span className="text-xs font-mono text-ink dark:text-white">02. General Ledger Journal</span>
              <span className="text-[10px] font-mono text-warmMuted">Double-Entry Posting</span>
            </div>
            <div className="h-48 border border-dashed border-hairline dark:border-darkHairline flex flex-col items-center justify-center p-6 text-center space-y-2">
              <Database className="w-8 h-8 text-warmMuted" />
              <p className="font-mono text-xs text-warmMuted">
                Idempotent General Ledger synchronization protected by ON DELETE RESTRICT constraints.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* 6. FOOTER */}
      <footer className="border-t border-hairline dark:border-darkHairline py-12 px-6 text-xs font-mono text-warmMuted bg-paper dark:bg-graphite transition-colors duration-200">
        <div className="max-w-7xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-4">
          <div>
            <span className="text-ink dark:text-white font-display font-bold">LedgerAgent</span> &bull; Production Agentic Finance Ops
          </div>
          <div className="flex items-center space-x-6">
            <span>Built by Pushkar Kanjani &bull; B.Tech ICT, PDEU</span>
            <a
              href="https://github.com"
              target="_blank"
              rel="noreferrer"
              className="text-electric hover:underline"
            >
              GitHub Repository
            </a>
          </div>
        </div>
      </footer>

    </div>
  );
};
