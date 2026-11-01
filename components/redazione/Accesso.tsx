'use client';
import { useActionState } from 'react';
import { entraConCodice, entraConPassword, inviaCodice, type StatoAccesso } from '@/app/[lang]/redazione/azioni';
import type { Lang } from '@/lib/i18n';
import { TESTI_REDAZIONE } from '@/lib/testi-redazione';

// Accesso in due passi: l'indirizzo, poi il codice di sei cifre ricevuto per email. In alternativa, la password.
export default function Accesso({ lang }: { lang: Lang }) {
  const t = TESTI_REDAZIONE[lang];
  const [invio, inviaAzione, inviando] = useActionState<StatoAccesso, FormData>(inviaCodice, null);
  const [codice, codiceAzione, entrando] = useActionState<StatoAccesso, FormData>(entraConCodice, null);
  const [pw, pwAzione, entrandoPw] = useActionState<StatoAccesso, FormData>(entraConPassword, null);
  const email = codice?.inviato ?? invio?.inviato;
  const errore = codice?.esito ?? invio?.esito;
  return (
    <div className="red-accesso">
      {!email ? (
        <form action={inviaAzione} className="red-modulo">
          <input type="hidden" name="lang" value={lang} />
          <label>{t.email}<input name="email" type="email" autoComplete="email" required /></label>
          <button className="btn btn-pieno" disabled={inviando}>{t.inviaCodice}</button>
        </form>
      ) : (
        <form action={codiceAzione} className="red-modulo">
          <p className="red-nota">{t.codiceInviato(email)}</p>
          <input type="hidden" name="lang" value={lang} />
          <input type="hidden" name="email" value={email} />
          <label>{t.codice}<input name="codice" inputMode="numeric" autoComplete="one-time-code" pattern="[0-9 ]{6,8}" required /></label>
          <button className="btn btn-pieno" disabled={entrando}>{t.entra}</button>
        </form>
      )}
      {errore && <p className="red-esito red-esito-errore" role="alert">{t.esiti[errore]}</p>}
      <details className="red-alternativa">
        <summary>{t.conPassword}</summary>
        <form action={pwAzione} className="red-modulo">
          <input type="hidden" name="lang" value={lang} />
          <label>{t.email}<input name="email" type="email" autoComplete="username" required /></label>
          <label>{t.password}<input name="password" type="password" autoComplete="current-password" required /></label>
          <button className="btn" disabled={entrandoPw}>{t.entra}</button>
          {pw?.esito && <p className="red-esito red-esito-errore" role="alert">{t.esiti[pw.esito]}</p>}
        </form>
      </details>
    </div>
  );
}
