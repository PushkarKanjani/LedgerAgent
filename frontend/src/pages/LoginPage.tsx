import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { MicroLabel, SwissButton } from '../components/swiss/primitives';
import { loginUser } from '../services/api';

export const LoginPage: React.FC = () => {
  const [email, setEmail] = useState('reviewer@ledgeragent.dev');
  const [password, setPassword] = useState('LedgerAgent@2026');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const navigate = useNavigate();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);
    setError(null);

    try {
      await loginUser(email, password);
      navigate('/app/inbox');
    } catch (err: any) {
      setError(err.message || 'Authentication failed. Please verify credentials.');
    } finally {
      setIsSubmitting(false);
    }
  };

  const fillCredentials = (roleEmail: string) => {
    setEmail(roleEmail);
    setPassword('LedgerAgent@2026');
    setError(null);
  };

  return (
    <div className="min-h-screen bg-paper dark:bg-darkPaper text-ink dark:text-darkInk flex flex-col justify-center items-center p-4 selection:bg-klein selection:text-white font-body transition-colors duration-200">
      <div className="w-full max-w-md border border-hairline dark:border-darkHairline bg-paper dark:bg-darkSurface p-8 space-y-6 animate-fadeIn shadow-none">
        
        {/* Header */}
        <div className="space-y-1 border-b border-hairline dark:border-darkHairline pb-4">
          <div className="flex items-center space-x-2">
            <span className="w-2.5 h-2.5 bg-klein dark:bg-darkKlein rounded-none inline-block"></span>
            <span className="font-display font-bold text-sm tracking-tight text-ink dark:text-darkInk">LedgerAgent</span>
          </div>
          <h1 className="font-display font-semibold text-2xl tracking-tight text-ink dark:text-darkInk">
            Authenticate Session
          </h1>
          <p className="font-mono text-[11px] text-inkMuted dark:text-darkInkMuted">
            JWT Role-Based Access Control &bull; Checkpoint 2 Guardrail
          </p>
        </div>

        {/* Demo Role Fast-Fill Buttons */}
        <div className="space-y-2">
          <MicroLabel mono>Demo Credentials (Password: LedgerAgent@2026)</MicroLabel>
          <div className="grid grid-cols-3 gap-2">
            <button
              type="button"
              onClick={() => fillCredentials('reviewer@ledgeragent.dev')}
              className={`p-2 text-[10px] font-mono border text-left transition-colors ${
                email === 'reviewer@ledgeragent.dev'
                  ? 'border-klein dark:border-darkKlein bg-klein/5 dark:bg-darkKlein/10 text-klein dark:text-darkKlein font-bold'
                  : 'border-hairline dark:border-darkHairline hover:bg-paperAlt dark:hover:bg-darkPaper text-inkMuted dark:text-darkInkMuted'
              }`}
            >
              <div>REVIEWER</div>
              <div className="text-[8px] truncate">Can approve</div>
            </button>

            <button
              type="button"
              onClick={() => fillCredentials('uploader@ledgeragent.dev')}
              className={`p-2 text-[10px] font-mono border text-left transition-colors ${
                email === 'uploader@ledgeragent.dev'
                  ? 'border-klein dark:border-darkKlein bg-klein/5 dark:bg-darkKlein/10 text-klein dark:text-darkKlein font-bold'
                  : 'border-hairline dark:border-darkHairline hover:bg-paperAlt dark:hover:bg-darkPaper text-inkMuted dark:text-darkInkMuted'
              }`}
            >
              <div>UPLOADER</div>
              <div className="text-[8px] truncate">Upload only</div>
            </button>

            <button
              type="button"
              onClick={() => fillCredentials('admin@ledgeragent.dev')}
              className={`p-2 text-[10px] font-mono border text-left transition-colors ${
                email === 'admin@ledgeragent.dev'
                  ? 'border-klein dark:border-darkKlein bg-klein/5 dark:bg-darkKlein/10 text-klein dark:text-darkKlein font-bold'
                  : 'border-hairline dark:border-darkHairline hover:bg-paperAlt dark:hover:bg-darkPaper text-inkMuted dark:text-darkInkMuted'
              }`}
            >
              <div>ADMIN</div>
              <div className="text-[8px] truncate">Full control</div>
            </button>
          </div>
        </div>

        {/* Form */}
        <form onSubmit={handleSubmit} className="space-y-4 font-mono text-xs">
          <div>
            <label className="block text-[10px] uppercase text-inkMuted dark:text-darkInkMuted tracking-wider mb-1">
              Work Email Address
            </label>
            <input
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full bg-paperAlt dark:bg-darkPaper border-b border-hairlineDark dark:border-darkHairline p-2 text-ink dark:text-darkInk focus:outline-none focus:border-klein dark:focus:border-darkKlein"
            />
          </div>

          <div>
            <label className="block text-[10px] uppercase text-inkMuted dark:text-darkInkMuted tracking-wider mb-1">
              Password Hash Secret
            </label>
            <input
              type="password"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full bg-paperAlt dark:bg-darkPaper border-b border-hairlineDark dark:border-darkHairline p-2 text-ink dark:text-darkInk focus:outline-none focus:border-klein dark:focus:border-darkKlein"
            />
          </div>

          {error && (
            <div className="p-3 border border-signal bg-signal/5 dark:bg-signal/10 text-signal font-mono text-xs">
              {error}
            </div>
          )}

          <SwissButton
            type="submit"
            variant="primary"
            size="lg"
            className="w-full"
            disabled={isSubmitting}
          >
            {isSubmitting ? 'Verifying bcrypt hash...' : 'Sign In →'}
          </SwissButton>
        </form>

        <div className="pt-2 border-t border-hairline dark:border-darkHairline text-center">
          <Link to="/" className="text-xs font-mono text-inkMuted dark:text-darkInkMuted hover:text-klein dark:hover:text-darkKlein underline">
            ← Return to Public Landing
          </Link>
        </div>

      </div>
    </div>
  );
};
