import React, { useEffect, useState } from 'react';
import { Outlet, Link, useLocation, useNavigate } from 'react-router-dom';
import { Sun, Moon } from 'lucide-react';
import { NumberedNav, MicroLabel, StatusTag } from '../components/swiss/primitives';
import { fetchHealthReport, fetchPendingApprovals, getCachedUserProfile, clearAuthSession } from '../services/api';
import { useTheme } from '../context/ThemeContext';
import { SystemHealthReport } from '../types';

export const AppLayout: React.FC = () => {
  const [health, setHealth] = useState<SystemHealthReport | null>(null);
  const [pendingCount, setPendingCount] = useState<number>(0);
  const location = useLocation();
  const navigate = useNavigate();
  const { theme, toggleTheme } = useTheme();

  const user = getCachedUserProfile();
  const roleName = (user?.role || 'reviewer').toUpperCase();

  useEffect(() => {
    const poll = async () => {
      const h = await fetchHealthReport();
      setHealth(h);
      const queue = await fetchPendingApprovals();
      setPendingCount(queue.length);
    };
    poll();
    const interval = setInterval(poll, 4000);
    return () => clearInterval(interval);
  }, [location.pathname]);

  const isErpUp = health?.dependencies?.mock_erp === 'up';

  const handleLogout = () => {
    clearAuthSession();
    navigate('/app/login');
  };

  const navItems = [
    { index: '01', label: 'Inbox', path: '/app/inbox' },
    { index: '02', label: 'Upload', path: '/app/upload' },
    { index: '03', label: 'HITL Queue', path: '/app/queue', badgeCount: pendingCount },
    { index: '04', label: 'Ledger', path: '/app/ledger' },
    { index: '05', label: 'Audit Trail', path: '/app/audit' },
  ];

  return (
    <div className="min-h-screen bg-paper dark:bg-darkPaper text-ink dark:text-darkInk flex flex-col font-body antialiased selection:bg-klein selection:text-white transition-colors duration-200">
      {/* Top Hairline Header Bar */}
      <header className="border-b border-hairline dark:border-darkHairline bg-paper dark:bg-darkPaper sticky top-0 z-40 transition-colors duration-200">
        <div className="max-w-[1600px] mx-auto px-4 sm:px-6 lg:px-8 h-12 flex items-center justify-between">
          
          {/* Brand & Mode Tag */}
          <div className="flex items-center space-x-3">
            <Link to="/" className="flex items-center space-x-2 text-ink dark:text-darkInk hover:text-klein dark:hover:text-darkKlein transition-colors">
              <span className="w-2.5 h-2.5 bg-klein dark:bg-darkKlein rounded-none inline-block"></span>
              <span className="font-display font-bold text-sm tracking-tight">LedgerAgent</span>
            </Link>
            <span className="text-hairlineDark dark:text-darkHairline">/</span>
            <span className="text-xs font-mono text-inkMuted dark:text-darkInkMuted uppercase tracking-wider">
              Swiss App Shell
            </span>
          </div>

          {/* User Session, Theme Toggle & Role Badge */}
          <div className="flex items-center space-x-3 sm:space-x-4 text-xs font-mono">
            {/* Theme Toggle Button */}
            <button
              onClick={toggleTheme}
              title={`Switch to ${theme === 'dark' ? 'Light' : 'Dark'} Mode`}
              className="p-1.5 border border-hairline dark:border-darkHairline text-ink dark:text-darkInk hover:bg-paperAlt dark:hover:bg-darkSurface transition-colors flex items-center justify-center rounded-none"
            >
              {theme === 'dark' ? (
                <Sun className="w-3.5 h-3.5 text-amberGlow" />
              ) : (
                <Moon className="w-3.5 h-3.5 text-inkMuted" />
              )}
            </button>

            {user && (
              <div className="flex items-center space-x-2 border-r border-hairline dark:border-darkHairline pr-3 sm:pr-4">
                <span className="text-[11px] text-inkMuted dark:text-darkInkMuted hidden md:inline">{user.email}</span>
                <StatusTag status={roleName} label={roleName} />
              </div>
            )}

            {/* Live Dependency Telemetry */}
            <div className="hidden sm:flex items-center space-x-1.5">
              <span
                className={`w-2 h-2 rounded-none inline-block ${
                  isErpUp ? 'bg-posted' : 'bg-signal animate-pulse'
                }`}
              ></span>
              <span className="text-inkMuted dark:text-darkInkMuted text-[11px]">
                ERP :8001 <span className={isErpUp ? 'text-posted font-medium' : 'text-signal font-medium'}>[{isErpUp ? 'UP' : 'DOWN'}]</span>
              </span>
            </div>

            <button
              onClick={handleLogout}
              className="text-xs font-mono text-inkMuted dark:text-darkInkMuted hover:text-signal hover:underline transition-colors pl-2 border-l border-hairline dark:border-darkHairline"
            >
              Sign Out
            </button>
          </div>

        </div>
      </header>

      {/* Main Workspace Frame (Sidebar + Content View) */}
      <div className="max-w-[1600px] w-full mx-auto flex-1 flex flex-col sm:flex-row">
        {/* Left Column: Numbered Navigation */}
        <NumberedNav items={navItems} />

        {/* Right Column: Route Viewport */}
        <main className="flex-1 p-4 sm:p-6 lg:p-8 overflow-y-auto bg-paper dark:bg-darkPaper transition-colors duration-200">
          <Outlet />
        </main>
      </div>

      {/* Hairline Footer Bar */}
      <footer className="border-t border-hairline dark:border-darkHairline bg-paper dark:bg-darkPaper py-2 px-6 text-center text-[10px] font-mono text-inkMuted dark:text-darkInkMuted flex justify-between items-center transition-colors duration-200">
        <span>LedgerAgent v2.0 &bull; JWT Role-Based Access Control Enforced</span>
        <span>Pushkar Kanjani &bull; B.Tech ICT</span>
      </footer>
    </div>
  );
};
