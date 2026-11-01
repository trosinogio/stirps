'use client';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { LINGUE_INTERFACCIA, TESTI, type Lang } from '@/lib/i18n';

export default function CambiaLingua({ lang }: { lang: Lang }) {
  const percorso = usePathname() || `/${lang}`;
  return (
    <nav className="cambia-lingua" aria-label={TESTI[lang].cambiaLingua}>
      {LINGUE_INTERFACCIA.map((l) => (
        <Link key={l} href={percorso.replace(/^\/[^/]+/, `/${l}`)} hrefLang={l} lang={l}
          aria-current={l === lang ? 'true' : undefined} className={l === lang ? 'attiva' : undefined}>
          {TESTI[l].nomeInterfaccia}
        </Link>
      ))}
    </nav>
  );
}
