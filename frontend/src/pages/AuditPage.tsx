import React, { useEffect, useState } from 'react';
import { MicroLabel, StatusTag, SwissButton } from '../components/swiss/primitives';
import { fetchAuditLogs } from '../services/api';

export const AuditPage: React.FC = () => {
  const [logs, setLogs] = useState<any[]>([]);
  const [isLoading, setIsLoading] = useState<boolean>(true);

  const load = async () => {
    setIsLoading(true);
    try {
      const data = await fetchAuditLogs();
      setLogs(data);
    } catch (e) {
      console.warn('Audit fetch error:', e);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    load();
  }, []);

  return (
    <div className="space-y-8 animate-fadeIn">
      {/* Title */}
      <div className="flex flex-col sm:flex-row sm:items-baseline justify-between border-b border-hairline pb-4 gap-2">
        <div>
          <MicroLabel mono>Section 05 &bull; Immutable Audit Trail</MicroLabel>
          <h1 className="font-display font-semibold text-3xl sm:text-4xl tracking-tight text-ink mt-0.5">
            System Event &amp; Decision Stream
          </h1>
        </div>
        <SwissButton variant="secondary" size="sm" onClick={load}>
          {isLoading ? 'Polling...' : 'Refresh Trail →'}
        </SwissButton>
      </div>

      {/* Audit Stream Table */}
      {logs.length === 0 ? (
        <div className="py-16 border-y border-hairline text-center space-y-2">
          <p className="font-mono text-xs text-inkMuted">
            No audit trail records logged yet.
          </p>
        </div>
      ) : (
        <div className="overflow-x-auto border-t border-hairline font-mono text-xs">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="border-b border-hairline text-inkMuted text-[10px] uppercase tracking-wider">
                <th className="py-2.5 px-2 font-normal">Timestamp</th>
                <th className="py-2.5 px-2 font-normal">Actor</th>
                <th className="py-2.5 px-2 font-normal">Action Event</th>
                <th className="py-2.5 px-2 font-normal">Status</th>
                <th className="py-2.5 px-2 font-normal">Trace ID</th>
                <th className="py-2.5 px-2 font-normal">Details &amp; Metadata</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-hairline">
              {logs.map((log, idx) => (
                <tr key={idx} className="hover:bg-paperAlt transition-colors h-10">
                  <td className="py-2 px-2 text-inkMuted text-[11px]">
                    {log.timestamp}
                  </td>
                  <td className="py-2 px-2 text-ink font-semibold">
                    {log.actor}
                  </td>
                  <td className="py-2 px-2 text-klein font-medium">
                    {log.action}
                  </td>
                  <td className="py-2 px-2">
                    <StatusTag status={log.status} />
                  </td>
                  <td className="py-2 px-2 text-inkMuted text-[10px]">
                    {log.trace_id || 'trace_local'}
                  </td>
                  <td className="py-2 px-2 text-ink text-[11px] max-w-md truncate">
                    {log.details}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
};
