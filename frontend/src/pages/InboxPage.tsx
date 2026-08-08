import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { MicroLabel, StatBlock, StatusTag, Money, SwissButton } from '../components/swiss/primitives';
import { fetchInvoices, fetchInboxStats, InboxStats } from '../services/api';

export const InboxPage: React.FC = () => {
  const [invoices, setInvoices] = useState<any[]>([]);
  const [stats, setStats] = useState<InboxStats>({
    total_processed: 0,
    pending_hitl: 0,
    posted_volume: 0,
    stp_rate: '0.0%'
  });
  const [isLoading, setIsLoading] = useState<boolean>(true);

  const load = async () => {
    setIsLoading(true);
    try {
      const [list, st] = await Promise.all([
        fetchInvoices(),
        fetchInboxStats()
      ]);
      setInvoices(list);
      setStats(st);
    } catch (e) {
      console.warn('Inbox load error:', e);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    load();
  }, []);

  return (
    <div className="space-y-8 animate-fadeIn">
      {/* Page Title */}
      <div className="flex flex-col sm:flex-row sm:items-baseline justify-between border-b border-hairline pb-4 gap-2">
        <div>
          <MicroLabel mono>System Inbox &bull; Operational Telemetry</MicroLabel>
          <h1 className="font-display font-semibold text-3xl sm:text-4xl tracking-tight text-ink mt-0.5">
            Operations &amp; Reconciled Invoices
          </h1>
        </div>
        <div className="flex items-center space-x-3">
          <SwissButton variant="secondary" size="sm" onClick={load}>
            {isLoading ? 'Polling...' : 'Refresh Inbox →'}
          </SwissButton>
          <Link to="/app/upload">
            <SwissButton variant="primary" size="sm">
              + Ingest New PDF
            </SwissButton>
          </Link>
        </div>
      </div>

      {/* 4-StatBlock KPI Strip Computed Directly from Database */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-6">
        <StatBlock
          label="Total Processed"
          value={stats.total_processed}
          subline="Invoices persisted in database"
        />
        <StatBlock
          label="STP Pass Rate"
          value={stats.stp_rate}
          subline="Auto-posted without intervention"
          highlight
        />
        <StatBlock
          label="Pending HITL Review"
          value={stats.pending_hitl}
          subline="Paused at confidence guardrail"
        />
        <StatBlock
          label="Total Posted Volume"
          value={`$${stats.posted_volume.toLocaleString('en-US', { minimumFractionDigits: 0, maximumFractionDigits: 0 })}`}
          subline="Cleared to General Ledger"
        />
      </div>

      {/* Ingested Invoices HairlineTable */}
      <div className="space-y-3 pt-4">
        <div className="flex items-baseline justify-between">
          <MicroLabel mono>Ingested Invoice Ledger Stream</MicroLabel>
          <span className="text-[11px] font-mono text-inkMuted">Showing {invoices.length} database entries</span>
        </div>

        {invoices.length === 0 ? (
          <div className="py-12 border-y border-hairline text-center space-y-2">
            <p className="font-mono text-xs text-inkMuted">No invoices ingested yet.</p>
            <Link to="/app/upload" className="inline-block">
              <span className="text-xs font-mono text-klein underline underline-offset-4">
                Ingest your first invoice &rarr;
              </span>
            </Link>
          </div>
        ) : (
          <div className="overflow-x-auto border-t border-hairline">
            <table className="w-full text-left text-xs border-collapse">
              <thead>
                <tr className="border-b border-hairline text-inkMuted font-mono text-[10px] uppercase tracking-wider">
                  <th className="py-2.5 px-2 font-normal">Invoice ID</th>
                  <th className="py-2.5 px-2 font-normal">Vendor</th>
                  <th className="py-2.5 px-2 font-normal">PO Number</th>
                  <th className="py-2.5 px-2 font-normal text-right">Amount</th>
                  <th className="py-2.5 px-2 font-normal">3-Way Match</th>
                  <th className="py-2.5 px-2 font-normal">Status</th>
                  <th className="py-2.5 px-2 font-normal text-right">Date</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-hairline dark:divide-darkHairline font-body">
                {invoices.map((inv) => (
                  <tr key={inv.invoice_id} className="hover:bg-paperAlt dark:hover:bg-darkSurface transition-colors h-10">
                    <td className="py-2 px-2 font-mono text-ink font-medium">
                      {inv.invoice_id.slice(0, 8)}
                    </td>
                    <td className="py-2 px-2 font-medium text-ink">
                      {inv.vendor_name}
                    </td>
                    <td className="py-2 px-2 font-mono text-inkMuted">
                      {inv.po_number || 'NONE'}
                    </td>
                    <td className="py-2 px-2 text-right">
                      <Money value={inv.total_amount} />
                    </td>
                    <td className="py-2 px-2">
                      <StatusTag status={inv.match_status} />
                    </td>
                    <td className="py-2 px-2">
                      <StatusTag status={inv.status} />
                    </td>
                    <td className="py-2 px-2 font-mono text-[11px] text-inkMuted text-right">
                      {inv.created_at}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
};
