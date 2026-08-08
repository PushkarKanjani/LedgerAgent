import React from 'react';
import { NavLink } from 'react-router-dom';

// =============================================================================
// 1. MICRO LABEL (10-11px, Uppercase, 0.08em tracking, #666666 / #999999)
// =============================================================================
export const MicroLabel: React.FC<{
  children: React.ReactNode;
  className?: string;
  mono?: boolean;
}> = ({ children, className = '', mono = false }) => (
  <span
    className={`text-[10px] uppercase font-semibold tracking-micro text-inkMuted dark:text-darkInkMuted select-none ${
      mono ? 'font-mono' : 'font-body'
    } ${className}`}
  >
    {children}
  </span>
);


// =============================================================================
// 2. MONEY (IBM Plex Mono 500, Tabular-Nums, Right-Aligned)
// =============================================================================
export const Money: React.FC<{
  value: number;
  currency?: string;
  sign?: boolean;
  className?: string;
}> = ({ value, currency = '$', sign = false, className = '' }) => {
  const formatted = Math.abs(value).toLocaleString('en-US', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });

  const isNeg = value < 0;
  const isPos = value > 0 && sign;

  return (
    <span
      className={`font-mono font-medium text-right tabular-nums text-ink dark:text-darkInk ${className}`}
    >
      {isNeg ? '-' : isPos ? '+' : ''}
      {currency}
      {formatted}
    </span>
  );
};


// =============================================================================
// 3. STATUS TAG (1px Border Tag, Sharp Corners, Exact Swiss Color Semantics)
// =============================================================================
export type SwissStatus = 'POSTED' | 'MATCHED' | 'PENDING' | 'MISMATCH' | 'FAILED' | 'INGESTED' | string;

export const StatusTag: React.FC<{
  status: SwissStatus;
  label?: string;
  className?: string;
}> = ({ status, label, className = '' }) => {
  const norm = (status || '').toUpperCase();
  const text = label || norm;

  let colorClasses = 'border-ink dark:border-darkHairline text-ink dark:text-darkInk bg-transparent';

  if (norm.includes('POSTED') || norm.includes('AUTO') || norm.includes('SUCCESS')) {
    colorClasses = 'border-posted text-posted bg-posted/5 dark:bg-posted/10';
  } else if (norm.includes('PENDING') || norm.includes('HITL') || norm.includes('REVIEW')) {
    colorClasses = 'border-pending text-pending bg-pending/5 dark:bg-pending/10';
  } else if (norm.includes('MISMATCH') || norm.includes('EXCEPTION') || norm.includes('ERROR')) {
    colorClasses = 'border-signal text-signal bg-signal/5 dark:bg-signal/10';
  } else if (norm.includes('MATCHED') || norm.includes('EXTRACT')) {
    colorClasses = 'border-klein text-klein dark:border-darkKlein dark:text-darkKlein bg-klein/5 dark:bg-darkKlein/10';
  } else if (norm.includes('FAIL')) {
    colorClasses = 'border-ink text-white bg-ink dark:bg-darkSurface dark:border-darkHairline';
  }

  return (
    <span
      className={`inline-flex items-center px-1.5 py-0.5 text-[9px] font-mono font-semibold uppercase tracking-wider border rounded-none ${colorClasses} ${className}`}
    >
      {text}
    </span>
  );
};


// =============================================================================
// 4. SWISS BUTTON (Primary: Klein Fill; Secondary: 1px Ink Border Invert)
// =============================================================================
export const SwissButton: React.FC<{
  children: React.ReactNode;
  variant?: 'primary' | 'secondary' | 'danger' | 'ghost';
  size?: 'sm' | 'md' | 'lg';
  onClick?: (e?: any) => void;
  disabled?: boolean;
  type?: 'button' | 'submit' | 'reset';
  className?: string;
}> = ({
  children,
  variant = 'primary',
  size = 'md',
  onClick,
  disabled = false,
  type = 'button',
  className = '',
}) => {
  const sizeClasses = {
    sm: 'px-3 py-1.5 text-xs',
    md: 'px-4 py-2.5 text-xs font-semibold',
    lg: 'px-6 py-3 text-sm font-semibold',
  }[size];

  let variantClasses = 'bg-klein dark:bg-darkKlein text-white hover:bg-klein/90 dark:hover:bg-darkKlein/90 border border-klein dark:border-darkKlein';
  if (variant === 'secondary') {
    variantClasses =
      'bg-transparent text-ink dark:text-darkInk border border-ink dark:border-darkHairline hover:bg-ink hover:text-white dark:hover:bg-darkSurface dark:hover:text-white transition-colors duration-150';
  } else if (variant === 'danger') {
    variantClasses =
      'bg-transparent text-signal border border-signal hover:bg-signal hover:text-white transition-colors duration-150';
  } else if (variant === 'ghost') {
    variantClasses =
      'bg-transparent text-ink dark:text-darkInk hover:bg-hairline dark:hover:bg-darkSurface border-transparent transition-colors duration-150';
  }

  return (
    <button
      type={type}
      onClick={onClick}
      disabled={disabled}
      className={`inline-flex items-center justify-center font-display tracking-tight transition-all rounded-sm disabled:opacity-40 disabled:cursor-not-allowed ${sizeClasses} ${variantClasses} ${className}`}
    >
      {children}
    </button>
  );
};


// =============================================================================
// 5. STAT BLOCK (Micro-Label + Oversized Space Grotesk Numeral + Hairline Rule)
// =============================================================================
export const StatBlock: React.FC<{
  label: string;
  value: string | number;
  subline?: string;
  highlight?: boolean;
}> = ({ label, value, subline, highlight = false }) => (
  <div className="pt-3 border-t border-hairline dark:border-darkHairline flex flex-col justify-between">
    <MicroLabel>{label}</MicroLabel>
    <div
      className={`font-display font-bold text-3xl sm:text-4xl md:text-5xl tracking-tighter tabular-nums mt-1 ${
        highlight ? 'text-klein dark:text-darkKlein' : 'text-ink dark:text-darkInk'
      }`}
    >
      {value}
    </div>
    {subline && (
      <p className="text-[11px] text-inkMuted dark:text-darkInkMuted font-mono mt-1">{subline}</p>
    )}
  </div>
);


// =============================================================================
// 6. NUMBERED SIDEBAR NAVIGATION (220px, Hairline Border, Klein Left Rule)
// =============================================================================
interface NavItem {
  index: string;
  label: string;
  path: string;
  badgeCount?: number;
}

export const NumberedNav: React.FC<{ items: NavItem[] }> = ({ items }) => {
  return (
    <nav className="w-full sm:w-56 flex-shrink-0 border-b sm:border-b-0 sm:border-r border-hairline dark:border-darkHairline bg-paper dark:bg-darkPaper py-4 sm:py-6">
      <div className="px-4 mb-4">
        <MicroLabel mono>Navigation Index</MicroLabel>
      </div>
      <ul className="space-y-0.5">
        {items.map((item) => (
          <li key={item.path}>
            <NavLink
              to={item.path}
              end={item.path === '/app/inbox' || item.path === '/app'}
              className={({ isActive }) =>
                `flex items-center justify-between px-4 py-2.5 text-xs font-mono transition-colors relative ${
                  isActive
                    ? 'text-klein dark:text-darkKlein font-semibold bg-paperAlt dark:bg-darkSurface border-l-2 border-klein dark:border-darkKlein'
                    : 'text-inkMuted dark:text-darkInkMuted hover:text-ink dark:hover:text-darkInk hover:bg-paperAlt/80 dark:hover:bg-darkSurface/80 border-l-2 border-transparent'
                }`
              }
            >
              <div className="flex items-center space-x-2.5">
                <span className="text-[10px] text-inkLight dark:text-darkInkMuted">{item.index}</span>
                <span className="font-display tracking-tight text-ink dark:text-darkInk font-medium">{item.label}</span>
              </div>
              {item.badgeCount !== undefined && item.badgeCount > 0 && (
                <span className="px-1.5 py-0.2 text-[9px] font-mono font-bold bg-pending text-white rounded-none">
                  {item.badgeCount}
                </span>
              )}
            </NavLink>
          </li>
        ))}
      </ul>
    </nav>
  );
};
