'use client';
import { useEffect, useRef, type ReactNode } from 'react';

// Sui telefoni la linea del tempo scorre: all'apertura si porta dove sta la parola principale
export default function ScorriTempo({ frazione, children }: { frazione: number; children: ReactNode }) {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const max = el.scrollWidth - el.clientWidth;
    if (max > 0) el.scrollLeft = Math.max(0, Math.min(max, frazione * el.scrollWidth - el.clientWidth * 0.55));
  }, [frazione]);
  return <div ref={ref} className="lt-scorre">{children}</div>;
}
