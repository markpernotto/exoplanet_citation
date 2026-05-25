import { useRef, useState, type CSSProperties, type FormEvent } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { api } from '../api';

const fieldStyle: CSSProperties = {
  background: 'var(--bg-elev)',
  color: 'var(--fg)',
  border: '1px solid var(--border)',
  borderRadius: 6,
  padding: '0.55rem 0.7rem',
  font: 'inherit',
  width: '100%',
  boxSizing: 'border-box',
};

const buttonStyle = (disabled: boolean): CSSProperties => ({
  background: 'var(--bg-elev)',
  color: disabled ? 'var(--fg-muted)' : 'var(--fg)',
  border: '1px solid var(--border)',
  borderRadius: 6,
  padding: '0.5rem 1.1rem',
  font: 'inherit',
  cursor: disabled ? 'default' : 'pointer',
  opacity: disabled ? 0.6 : 1,
});

// Honeypot: off-screen, not announced to assistive tech, tempting to bots.
const honeypotStyle: CSSProperties = {
  position: 'absolute',
  left: '-9999px',
  width: 1,
  height: 1,
  opacity: 0,
};

export default function Feedback() {
  const [params] = useSearchParams();
  const from = params.get('from') ?? '';
  const theme = params.get('theme');
  const themeQuery = theme ? `?theme=${theme}` : '';
  const mountedAt = useRef(Date.now());

  const [message, setMessage] = useState('');
  const [email, setEmail] = useState('');
  const [company, setCompany] = useState(''); // honeypot, must stay empty
  const [status, setStatus] = useState<'idle' | 'sending' | 'sent' | 'error'>('idle');

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    if (!message.trim()) return;
    setStatus('sending');
    try {
      await api.submitFeedback({
        message: message.trim(),
        email: email.trim() || undefined,
        page_url: from || undefined,
        company: company || undefined,
        elapsed_ms: Date.now() - mountedAt.current,
      });
      setStatus('sent');
    } catch {
      setStatus('error');
    }
  };

  if (status === 'sent') {
    return (
      <div style={{ maxWidth: '42rem' }}>
        <h1 style={{ margin: '0 0 0.5rem' }}>Thanks</h1>
        <p style={{ color: 'var(--fg-muted)', lineHeight: 1.6 }}>
          Your report was sent.{email.trim() ? ' I may follow up at the address you left.' : ''}
        </p>
        <p><Link to={from || `/${themeQuery}`}>← back</Link></p>
      </div>
    );
  }

  return (
    <div style={{ maxWidth: '42rem' }}>
      <p style={{ margin: '0 0 1rem' }}><Link to={from || `/${themeQuery}`}>← back</Link></p>
      <h1 style={{ margin: '0 0 0.5rem' }}>Report an issue</h1>
      <p style={{ margin: '0 0 1.5rem', color: 'var(--fg-muted)', lineHeight: 1.6 }}>
        Spotted an error, a mis-attributed citation, or a planet that looks wrong or missing?
        Tell me what you saw. Every value on this site links to its source, so a pointer to the
        page and the paper is plenty.
      </p>
      {from && (
        <p style={{ margin: '0 0 1rem', fontSize: '0.85rem', color: 'var(--fg-muted)' }}>
          Regarding: <code>{from}</code>
        </p>
      )}
      <form onSubmit={submit} style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
        <label style={{ display: 'flex', flexDirection: 'column', gap: '0.35rem' }}>
          <span>What did you find? <span aria-hidden style={{ color: 'var(--tier-a)' }}>*</span></span>
          <textarea
            required
            value={message}
            onChange={(e) => setMessage(e.target.value)}
            rows={6}
            maxLength={4000}
            style={{ ...fieldStyle, resize: 'vertical' }}
          />
        </label>
        <label style={{ display: 'flex', flexDirection: 'column', gap: '0.35rem' }}>
          <span>Email <span style={{ color: 'var(--fg-muted)' }}>(optional, only if you want a reply)</span></span>
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            maxLength={320}
            autoComplete="email"
            style={fieldStyle}
          />
        </label>
        <input
          type="text"
          name="company"
          tabIndex={-1}
          autoComplete="off"
          aria-hidden
          value={company}
          onChange={(e) => setCompany(e.target.value)}
          style={honeypotStyle}
        />
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
          <button type="submit" disabled={status === 'sending' || !message.trim()} style={buttonStyle(status === 'sending' || !message.trim())}>
            {status === 'sending' ? 'Sending…' : 'Send report'}
          </button>
          {status === 'error' && (
            <span style={{ color: 'var(--tier-a)', fontSize: '0.9rem' }}>Something went wrong. Please try again.</span>
          )}
        </div>
      </form>
    </div>
  );
}
