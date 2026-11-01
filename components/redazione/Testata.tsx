import Link from 'next/link';
import { esci } from '@/app/[lang]/redazione/azioni';
import type { Lang } from '@/lib/i18n';
import { TESTI_REDAZIONE } from '@/lib/testi-redazione';
import type { Redattore } from '@/lib/auth/redattore';

// La barra della redazione: chi è dentro, il ritorno al cruscotto, l'uscita
export default function TestataRedazione({ lang, redattore }: { lang: Lang; redattore: Redattore }) {
  const t = TESTI_REDAZIONE[lang];
  return (
    <div className="red-barra">
      <Link href={`/${lang}/redazione`} className="red-titolo">{t.redazione}</Link>
      <span className="red-chi">{t.ciao(redattore.nome)}</span>
      <form action={esci}>
        <input type="hidden" name="lang" value={lang} />
        <button className="btn">{t.esci}</button>
      </form>
    </div>
  );
}
