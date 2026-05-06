import { useEffect, useRef, useState } from 'react';

interface Props {
  loading: boolean;
}

export default function LoadingBar({ loading }: Props) {
  const [pct, setPct] = useState(0);
  const [phase, setPhase] = useState<'idle' | 'running' | 'done'>('idle');
  const everLoadedRef = useRef(false);
  const rafRef = useRef<number>(0);

  useEffect(() => {
    if (loading) {
      everLoadedRef.current = true;
      const start = performance.now();
      setPhase('running');
      setPct(0);

      const tick = (now: number) => {
        const elapsed = now - start;
        // Asymptotic approach to 88%: fast at first, crawls near the end
        setPct(88 * (1 - Math.exp(-elapsed / 1200)));
        rafRef.current = requestAnimationFrame(tick);
      };
      rafRef.current = requestAnimationFrame(tick);
      return () => cancelAnimationFrame(rafRef.current);
    } else if (everLoadedRef.current) {
      cancelAnimationFrame(rafRef.current);
      setPct(100);
      setPhase('done');
      const t = setTimeout(() => {
        setPhase('idle');
        setPct(0);
      }, 900);
      return () => clearTimeout(t);
    }
  }, [loading]);

  if (phase === 'idle') return null;

  return (
    <div className={`loading-bar${phase === 'done' ? ' loading-bar--done' : ''}`}>
      <div className="loading-bar__track">
        <div className="loading-bar__fill" style={{ width: `${pct}%` }} />
      </div>
      <span className="loading-bar__pct">{Math.floor(pct)}%</span>
    </div>
  );
}
