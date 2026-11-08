'use client';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { TESTI, type Lang } from '@/lib/i18n';

// La barra di navigazione: indica la sezione corrente, scorre in orizzontale sui telefoni
export default function Navigazione({ lang }: { lang: Lang }) {
  const t = TESTI[lang];
  const via = usePathname() ?? '';
  const voci: [string, string][] = [
    ['radici', t.nav.radici], ['lingue', t.nav.lingue], ['storie', t.nav.storie], ['analisi', t.nav.analisiBreve], ['metodo', t.nav.metodo], ['chi-siamo', t.nav.chiSiamo],
  ];
  const attiva = (seg: string) =>
    via.startsWith(`/${lang}/${seg}`) || (seg === 'radici' && via.startsWith(`/${lang}/r/`)) || (seg === 'lingue' && via.startsWith(`/${lang}/l/`));
  return (
    <nav className="navigazione" aria-label={t.navAria}>
      {voci.map(([seg, nome]) => (
        <Link key={seg} href={`/${lang}/${seg}`} aria-current={attiva(seg) ? 'page' : undefined}>{nome}</Link>
      ))}
    </nav>
  );
}
