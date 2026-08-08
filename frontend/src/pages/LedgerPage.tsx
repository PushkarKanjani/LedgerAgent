import React, { useEffect, useState } from 'react';
import { MicroLabel, StatusTag, Money, SwissButton } from '../components/swiss/primitives';
import { fetchGLEntries } from '../services/api';

export const LedgerPage: React.FC = () => {
  const [entries, setEntries] = useState<any[]>([]);
  const [isLoading, setIsLoading] = useState<boolean>(true);

  const load = async () => {
    setIsLoading(true);
    try {
      const data = await fetchGLEntries();
      setEntries(data);
    } catch (e) {
      console.warn('Ledger fetch error:', e);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    load();
  }, []);

  const totalAmount = entries.reduce((acc, e) => acc + (Number(e.amount) || 0), 0);

  return (
    <div className="space-y-8 animate-fadeIn">
      {/* Title */}
      <div className="flex flex-col sm:flex-row sm:items-baseline justify-between border-b border-hairline pb-4 gap-2">
        <div>
          <MicroLabel mono>Section 04 &bull; Accounting Synchronization</MicroLabel>
          <h1 className="font-display font-semibold text-3xl sm:text-4xl tracking-tight text-ink mt-0.5">
            General Ledger Journal Entries
          </h1>
        </div>
        <SwissButton variant="secondary" size="sm" onClick={load}>
          {isLoading ? 'Polling...' : 'Refresh Ledger →'}
        </SwissButton>
      </div>

      {/* Ledger Table */}
      {entries.length === 0 ? (
        <div className="py-16 border-y border-hairline text-center space-y-2">
          <p className="font-mono text-xs text-inkMuted">
            No journal entries posted yet. Reconcile and approve invoices to sync GL.
          </p>
        </div>
      ) : (
        <div className="overflow-x-auto border-t border-hairline">
          <table className="w-full text-left text-xs border-collapse">
            <thead>
              <tr className="border-b border-hairline text-inkMuted font-mono text-[10px] uppercase tracking-wider">
                <th className="py-2.5 px-2 font-normal">Date</th>
                <th className="py-2.5 px-2 font-normal">GL Reference</th>
                <th className="py-2.5 px-2 font-normal">Vendor &amp; Description</th>
                <th className="py-2.5 px-2 font-normal">Debit Account</th>
                <th className="py-2.5 px-2 font-normal">Credit Account</th>
                <th className="py-2.5 px-2 font-normal text-right">Amount</th>
                <th className="py-2.5 px-2 font-normal text-right">Posted By</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-hairline font-body">
              {entries.map((entry, idx) => (
                <tr key={idx} className="hover:bg-paperAlt transition-colors h-11">
                  <td className="py-2 px-2 font-mono text-inkMuted">
                    {entry.transaction_date}
                  </td>
                  <td className="py-2 px-2 font-mono font-semibold text-posted">
                    {entry.gl_reference_id}
                  </td>
                  <td className="py-2 px-2">
                    <div className="font-medium text-ink">{entry.vendor_name || 'Apex Cloud Solutions LLC'}</div>
                    <div className="text-[10px] text-inkMuted font-mono">{entry.description}</div>
                  </td>
                  <td className="py-2 px-2 font-mono text-xs text-ink">
                    {entry.debit_account}
                  </td>
                  <td className="py-2 px-2 font-mono text-xs text-inkMuted">
                    {entry.credit_account}
                  </td>
                  <td className="py-2 px-2 text-right">
                    <Money value={entry.amount} />
                  </td>
                  <td className="py-2 px-2 font-mono text-[10px] text-inkMuted text-right">
                    <StatusTag status="POSTED" label={entry.posted_by || 'AGENT_AUTO'} />
                  </td>
                </tr>
              ))}
            </tbody>
            <tfoot>
              <tr className="border-t-2 border-ink font-bold font-mono text-xs">
                <td colSpan={5} className="py-3 px-2 uppercase tracking-wider text-ink">
                  Total Reconciled Ledger Volume
                </td>
                <td className="py-3 px-2 text-right">
                  <Money value={totalAmount} />
                </td>
                <td className="py-3 px-2 text-right text-inkMuted text-[10px]">
                  {entries.length} Entries
                </td>
              </tr>
            </tfoot>
          </table>
        </div>
      )}
    </div>
  );
};
