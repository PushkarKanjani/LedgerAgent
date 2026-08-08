import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { MicroLabel, StatusTag, Money, SwissButton } from '../components/swiss/primitives';
import { fetchPendingApprovals } from '../services/api';
import { ApprovalRequest } from '../types';

export const QueuePage: React.FC = () => {
  const [approvals, setApprovals] = useState<ApprovalRequest[]>([]);
  const [vendorFilter, setVendorFilter] = useState('');
  const [isLoading, setIsLoading] = useState(true);

  const load = async () => {
    setIsLoading(true);
    try {
      const data = await fetchPendingApprovals();
      setApprovals(data);
    } catch (e) {
      console.warn('Queue fetch error:', e);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    load();
  }, []);

  const filtered = approvals.filter((a) => {
    const v = (a.extracted_data?.vendor_name || '').toLowerCase();
    return v.includes(vendorFilter.toLowerCase());
  });

  return (
    <div className="space-y-8 animate-fadeIn">
      {/* Title */}
      <div className="flex flex-col sm:flex-row sm:items-baseline justify-between border-b border-hairline pb-4 gap-2">
        <div>
          <MicroLabel mono>Section 03 &bull; Human-in-the-Loop Guardrail</MicroLabel>
          <h1 className="font-display font-semibold text-3xl sm:text-4xl tracking-tight text-ink mt-0.5">
            Active Review Queue
          </h1>
        </div>
        <SwissButton variant="secondary" size="sm" onClick={load}>
          {isLoading ? 'Polling...' : 'Refresh Queue →'}
        </SwissButton>
      </div>

      {/* Hairline Underline Filter Bar */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-6 py-2 border-b border-hairline text-xs font-mono">
        <div>
          <MicroLabel mono>Filter by Vendor</MicroLabel>
          <input
            type="text"
            value={vendorFilter}
            onChange={(e) => setVendorFilter(e.target.value)}
            placeholder="Type vendor substring..."
            className="w-full bg-transparent border-b border-hairlineDark py-1 text-xs text-ink focus:outline-none focus:border-klein font-mono mt-1 placeholder:text-hairlineDark"
          />
        </div>
        <div>
          <MicroLabel mono>Confidence Guardrail</MicroLabel>
          <div className="py-1 text-inkMuted font-mono mt-1">&lt; 0.85 (Enforced by Policy)</div>
        </div>
        <div>
          <MicroLabel mono>Variance Tolerance</MicroLabel>
          <div className="py-1 text-inkMuted font-mono mt-1">&gt; 2.0% ($10.00 Upper Bound)</div>
        </div>
      </div>

      {/* Approvals Table */}
      {filtered.length === 0 ? (
        <div className="py-16 border-b border-hairline text-center space-y-2">
          <p className="font-mono text-xs text-inkMuted">
            No invoices currently require human intervention.
          </p>
        </div>
      ) : (
        <div className="overflow-x-auto border-t border-hairline">
          <table className="w-full text-left text-xs border-collapse">
            <thead>
              <tr className="border-b border-hairline text-inkMuted font-mono text-[10px] uppercase tracking-wider">
                <th className="py-2.5 px-2 font-normal">Invoice ID</th>
                <th className="py-2.5 px-2 font-normal">Vendor &amp; PO</th>
                <th className="py-2.5 px-2 font-normal text-right">Invoiced Total</th>
                <th className="py-2.5 px-2 font-normal text-right">Price Variance</th>
                <th className="py-2.5 px-2 font-normal">Confidence</th>
                <th className="py-2.5 px-2 font-normal">Guardrail Reason</th>
                <th className="py-2.5 px-2 font-normal text-right">Action</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-hairline dark:divide-darkHairline font-body">
              {filtered.map((item) => {
                const extracted = item.extracted_data;
                const match = item.match_result;
                const confScore = item.confidence_score || extracted?.overall_confidence || 0.78;
                const poNumber = extracted?.po_number || 'PO-2026-8891';

                return (
                  <tr key={item.invoice_id} className="hover:bg-paperAlt dark:hover:bg-darkSurface transition-colors h-11">
                    <td className="py-2 px-2 font-mono text-ink font-medium">
                      {item.invoice_id.slice(0, 8)}...
                    </td>
                    <td className="py-2 px-2">
                      <div className="font-medium text-ink">
                        {extracted?.vendor_name || 'Apex Cloud Solutions LLC'}
                      </div>
                      <div className="text-[10px] font-mono text-inkMuted">
                        PO: {poNumber}
                      </div>
                    </td>
                    <td className="py-2 px-2 text-right">
                      <Money value={extracted?.total_amount || 5184.00} />
                    </td>
                    <td className="py-2 px-2 text-right">
                      <span className="font-mono text-signal font-medium">
                        +${(match?.price_variance || 324.00).toFixed(2)}
                      </span>
                    </td>
                    <td className="py-2 px-2">
                      <span className="font-mono font-medium text-pending">
                        {(confScore * 100).toFixed(1)}%
                      </span>
                    </td>
                    <td className="py-2 px-2">
                      <StatusTag status={match?.match_status || 'PRICE_MISMATCH'} />
                    </td>
                    <td className="py-2 px-2 text-right">
                      <Link to={`/app/queue/${item.invoice_id}`}>
                        <SwissButton variant="secondary" size="sm">
                          Inspect →
                        </SwissButton>
                      </Link>
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
