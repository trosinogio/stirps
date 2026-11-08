import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { isLang, TESTI } from '@/lib/i18n';
import { etichetteEtimo, TESTI_REDAZIONE, type TestiRedazione } from '@/lib/testi-redazione';
import { richiediRedattore } from '@/lib/auth/redattore';
import { attestazioniRedazione, ipotesiRedazione, lingueScelta, opereScelta, postoInLista, tipiRelazione, voceRedazione } from '@/lib/redazione';
import { classeRamo, datazione, fmt } from '@/lib/forme';
import TestataRedazione from '@/components/redazione/Testata';
import SceltaEtimo from '@/components/redazione/SceltaEtimo';
import {
  aggiungiArco, aggiungiAttestazione, aggiungiFonte, modificaArco, nuovaIpotesi, salvaIpotesi, salvaVoce,
  togliArco, togliAttestazione, togliFonte, verificaIpotesi,
} from '../../azioni';

export const dynamic = 'force-dynamic';
export const metadata: Metadata = { robots: { index: false } };

type Tipo = { codice: string; categoria: string; nome: string };
type Opera = { id: number; sigla: string; titolo: string; ambito: string | null };

function SceltaTipo({ tipi, t, valore }: { tipi: Tipo[]; t: TestiRedazione; valore?: string }) {
  const cat = [...new Set(tipi.map((x) => x.categoria))];
  return (
    <label>{t.tipo}
      <select name="tipo" defaultValue={valore ?? 'eredita'} required>
        {cat.map((c) => (
          <optgroup key={c} label={t.categorie[c] ?? c}>
            {tipi.filter((x) => x.categoria === c).map((x) => <option key={x.codice} value={x.codice}>{x.nome}</option>)}
          </optgroup>
        ))}
      </select>
    </label>
  );
}

function SceltaOpera({ opere, ambiti, lang, facoltativa }: { opere: Opera[]; ambiti: string[]; lang: 'it' | 'en'; facoltativa?: boolean }) {
  return (
    <select name="opera" required={!facoltativa} defaultValue="">
      {facoltativa && <option value="">{TESTI_REDAZIONE[lang].nessuna}</option>}
      {ambiti.map((a) => (
        <optgroup key={a} label={TESTI[lang].ambiti[a] ?? a}>
          {opere.filter((o) => (o.ambito ?? '') === a).map((o) => <option key={o.id} value={o.id}>{o.sigla}</option>)}
        </optgroup>
      ))}
    </select>
  );
}

function Precisione({ t, valore }: { t: TestiRedazione; valore?: string | null }) {
  return (
    <label>{t.precisione}
      <select name="precisione" defaultValue={valore ?? 'esatta'}>
        {Object.entries(t.precisioni).map(([k, n]) => <option key={k} value={k}>{n}</option>)}
      </select>
    </label>
  );
}

function Certezza({ t, valore }: { t: TestiRedazione; valore?: number }) {
  return (
    <label>{t.confidenza}
      <select name="confidenza" defaultValue={String(valore ?? 3)}>
        {Object.entries(t.certezze).map(([k, n]) => <option key={k} value={k}>{n}</option>)}
      </select>
    </label>
  );
}

export default async function EditorVoce({ params, searchParams }: { params: Promise<{ lang: string; slug: string[] }>; searchParams: Promise<{ esito?: string }> }) {
  const { lang, slug: parti } = await params;
  if (!isLang(lang)) notFound();
  const { esito } = await searchParams;
  const t = TESTI_REDAZIONE[lang];
  const ts = TESTI[lang];
  const redattore = await richiediRedattore(lang);
  const slug = parti.map(decodeURIComponent).join('/');
  const v = await voceRedazione(slug, lang);
  if (!v) notFound();
  const [ipotesi, opere, tipi, lingue, attestazioni, posto] = await Promise.all([
    ipotesiRedazione(v.id, lang), opereScelta(), tipiRelazione(lang), lingueScelta(lang), attestazioniRedazione(v.id), postoInLista(v.id),
  ]);
  const ambiti = [...new Set(opere.map((o) => o.ambito ?? ''))];
  const negativi = new Set(['errore', 'servono-fonti', 'servono-due-fonti', 'ciclo', 'gia-presente', 'etimo-mancante', 'etichetta-usata', 'dati-non-validi']);
  const nascosti = (extra: Record<string, string | number>) => (
    <>
      <input type="hidden" name="lang" value={lang} />
      <input type="hidden" name="slug" value={v.slug} />
      {Object.entries(extra).map(([k, x]) => <input key={k} type="hidden" name={k} value={x} />)}
    </>
  );
  return (
    <div className="redazione">
      <TestataRedazione lang={lang} redattore={redattore} />
      <p className="red-percorso">
        <Link href={`/${lang}/redazione`}>‹ {t.coda}</Link>
        <a href={`/${lang}/w/${v.slug}`} target="_blank" rel="noopener">{t.vediPubblica}</a>
      </p>
      {esito && t.esiti[esito] && <p className={`red-esito ${negativi.has(esito) ? 'red-esito-errore' : ''}`} role="status">{t.esiti[esito]}</p>}

      <header className="testa-voce">
        <h1 className="voce-titolo">{v.ricostruito ? '*' : ''}{v.lemma}</h1>
        <p className="meta">
          <span>{v.lingua_nome}</span>
          {v.pos && <span>{v.pos}</span>}
          <span className={`red-stato red-stato-${v.stato_editoriale}`}>{t.stati[v.stato_editoriale]}</span>
        </p>
      </header>

      {posto && (
        <aside className="red-lista">
          <p className="red-lista-testa"><b>{t.inLista(posto.lista === 'prime-100' ? t.prime : posto.lista === 'senza-etimologia' ? t.senzaEtimologia : t.catene, posto.posizione, posto.totale)}</b> · {posto.gruppo}</p>
          {posto.suggerimento && <p><b>{t.controllare}:</b> {posto.suggerimento}</p>}
          {posto.prossima && (
            <p><Link href={`/${lang}/redazione/w/${posto.prossima.slug}`}>{t.prossima}: <i>{posto.prossima.lemma}</i> →</Link></p>
          )}
        </aside>
      )}

      <section className="red-sezione">
        <h2>{t.voce}</h2>
        <form action={salvaVoce} className="red-modulo red-modulo-riga">
          {nascosti({ lessema: v.id })}
          <label>{t.statoVoce}
            <select name="stato_editoriale" defaultValue={v.stato_editoriale}>
              {['bozza', 'importato', 'rivisto', 'verificato', 'superato'].map((s) => <option key={s} value={s}>{t.stati[s]}</option>)}
            </select>
          </label>
          <label className="red-largo">{t.glossaIt}
            <input name="glossa_it" defaultValue={v.glossa_it ?? (v.glossa_lingua === 'it' ? v.glossa ?? '' : '')} placeholder={v.glossa_lingua !== 'it' ? v.glossa ?? '' : ''} />
          </label>
          <button className="btn btn-pieno">{t.salva}</button>
        </form>
      </section>

      <section className="red-sezione">
        <h2>{t.ipotesi}</h2>
        {ipotesi.map((h) => (
          <article key={h.id} className={`red-ipotesi ${h.stato === 'accolta' ? 'red-accolta' : ''}`}>
            <h3>
              {h.etichetta}
              <span className={`red-stato red-stato-${h.stato_editoriale}`}>{t.stati[h.stato_editoriale]}</span>
              <span className="red-prov">{h.provenienza}</span>
            </h3>

            <h4>{t.passaggi}</h4>
            {h.archi.length ? (
              <ul className="red-passaggi">
                {h.archi.map((a) => (
                  <li key={a.id}>
                    <p className="red-passo">
                      <span className="red-tipo">{a.tipo_nome}</span>{' '}
                      <Link className={`voce ${classeRamo(a.etimo.ramo)}`} href={`/${lang}/redazione/w/${a.etimo.slug}`}>
                        <span className="lemma">{fmt(a.etimo)}</span><span className="sigla">{a.etimo.lingua_sigla}</span>
                      </Link>
                      {a.affisso && <span className="gl"> + {a.affisso}</span>}
                      {a.forma && <span className="gl"> ({a.forma})</span>}
                      {a.anno_da !== null && <span className="data-catena">{datazione({ anno_da: a.anno_da, anno_a: a.anno_a, precisione: a.precisione ?? 'esatta' } as never, ts)}</span>}
                    </p>
                    <details className="red-alternativa">
                      <summary>{t.modifica}</summary>
                      <form action={modificaArco} className="red-modulo red-modulo-riga">
                        {nascosti({ relazione: a.id })}
                        <SceltaTipo tipi={tipi} t={t} valore={a.tipo} />
                        <label>{t.forma}<input name="forma" defaultValue={a.forma ?? ''} /></label>
                        <label>{t.affisso}<input name="affisso" defaultValue={a.affisso ?? ''} /></label>
                        <Certezza t={t} valore={a.confidenza} />
                        <label>{t.annoPassaggio}<input name="anno_da" inputMode="numeric" defaultValue={a.anno_da ?? ''} /></label>
                        <Precisione t={t} valore={a.precisione} />
                        <button className="btn">{t.salva}</button>
                      </form>
                      <form action={togliArco}>{nascosti({ relazione: a.id })}<button className="btn btn-piccolo">{t.togli}</button></form>
                    </details>
                  </li>
                ))}
              </ul>
            ) : <p className="vuoto">—</p>}
            <details className="red-alternativa">
              <summary>{t.aggiungiEtimo}</summary>
              <form action={aggiungiArco} className="red-modulo red-modulo-pieno">
                {nascosti({ ipotesi: h.id })}
                <SceltaEtimo lang={lang} lingue={lingue} t={etichetteEtimo(t)} />
                <div className="red-modulo-riga">
                  <SceltaTipo tipi={tipi} t={t} />
                  <label>{t.forma}<input name="forma" /></label>
                  <label>{t.affisso}<input name="affisso" /></label>
                  <Certezza t={t} />
                  <label>{t.annoPassaggio}<input name="anno_da" inputMode="numeric" /></label>
                  <Precisione t={t} />
                </div>
                <button className="btn btn-pieno">{t.aggiungiEtimo}</button>
              </form>
            </details>

            <form action={salvaIpotesi} className="red-modulo red-modulo-riga">
              {nascosti({ ipotesi: h.id })}
              <label>{t.statoIpotesi}
                <select name="stato" defaultValue={h.stato}>
                  {Object.entries(t.statiIpotesi).map(([k, n]) => <option key={k} value={k}>{n}</option>)}
                </select>
              </label>
              <Certezza t={t} valore={h.confidenza} />
              <label className="red-largo">{t.nota}
                <textarea name="nota" rows={2} defaultValue={h.nota ?? ''} lang={h.nota_lingua ?? undefined} />
              </label>
              <button className="btn">{t.salva}</button>
            </form>

            <h4>{t.fonti}</h4>
            {h.rimandi.length ? (
              <ul className="red-fonti">
                {h.rimandi.map((m) => (
                  <li key={m.id}>
                    <span><b>{m.sigla}</b>{m.sv && <>, s.v. <i>{m.sv}</i></>}{m.locus && <>, {m.locus}</>} <span className="red-tipo">{t.posizioni[m.posizione] ?? m.posizione}</span>{m.nota && <span className="gl"> {m.nota}</span>}</span>
                    <form action={togliFonte}>{nascosti({ rimando: m.id })}<button className="btn btn-piccolo">{t.togli}</button></form>
                  </li>
                ))}
              </ul>
            ) : <p className="vuoto">{t.nessunaFonte}</p>}
            <details className="red-alternativa">
              <summary>{t.aggiungiFonte}</summary>
              <form action={aggiungiFonte} className="red-modulo red-modulo-riga">
                {nascosti({ ipotesi: h.id })}
                <label>{t.opera}<SceltaOpera opere={opere} ambiti={ambiti} lang={lang} /></label>
                <label>{t.sv}<input name="sv" defaultValue={v.lemma} /></label>
                <label>{t.locus}<input name="locus" /></label>
                <label>{t.posizione}
                  <select name="posizione" defaultValue="accoglie">
                    {['propone', 'accoglie', 'discute', 'respinge'].map((p) => <option key={p} value={p}>{t.posizioni[p]}</option>)}
                  </select>
                </label>
                <label className="red-largo">{t.nota}<input name="nota" /></label>
                <button className="btn">{t.aggiungiFonte}</button>
              </form>
            </details>
            {h.stato_editoriale !== 'verificato' && (
              <form action={verificaIpotesi} className="red-verifica">
                {nascosti({ ipotesi: h.id })}
                <button className="btn btn-pieno">{t.verifica}</button>
                <span className="gl">{t.verificaNota}</span>
              </form>
            )}
          </article>
        ))}

        <details className="red-alternativa red-nuova">
          <summary>{t.nuovaIpotesi}</summary>
          <form action={nuovaIpotesi} className="red-modulo red-modulo-riga">
            {nascosti({})}
            <label>{t.etichetta}<input name="etichetta" defaultValue="redazione" required /></label>
            <label>{t.origine}
              <select name="origine" defaultValue="etimo">
                {Object.entries(t.origini).map(([k, n]) => <option key={k} value={k}>{n}</option>)}
              </select>
            </label>
            <label>{t.statoIpotesi}
              <select name="stato" defaultValue={ipotesi.some((h) => h.stato === 'accolta') ? 'alternativa' : 'accolta'}>
                {Object.entries(t.statiIpotesi).map(([k, n]) => <option key={k} value={k}>{n}</option>)}
              </select>
            </label>
            <Certezza t={t} />
            <label className="red-largo">{t.nota}<textarea name="nota" rows={2} /></label>
            <button className="btn btn-pieno">{t.nuovaIpotesi}</button>
          </form>
        </details>
      </section>

      <section className="red-sezione">
        <h2>{t.attestazioni}</h2>
        {attestazioni.length ? (
          <ul className="red-fonti">
            {attestazioni.map((a) => (
              <li key={a.id}>
                <span>
                  <b>{datazione(a as never, ts)}</b> {a.testo}{a.rif && <>, {a.rif}</>}
                  {a.forma_attestata && <> <i>{a.forma_attestata}</i></>}
                  <span className="red-tipo"> {t.tipiAtt[a.tipo] ?? a.tipo}</span>
                  {a.rimandi.map((m) => <span key={m.id} className="gl"> {m.sigla}{m.sv && <>, s.v. {m.sv}</>}</span>)}
                  <span className="red-prov">{a.provenienza}</span>
                </span>
                <form action={togliAttestazione}>{nascosti({ attestazione: a.id })}<button className="btn btn-piccolo">{t.togli}</button></form>
              </li>
            ))}
          </ul>
        ) : <p className="vuoto">{t.nessunaAttestazione}</p>}
        <details className="red-alternativa">
          <summary>{t.aggiungiAttestazione}</summary>
          <form action={aggiungiAttestazione} className="red-modulo red-modulo-riga">
            {nascosti({})}
            <label>{t.annoDa}<input name="anno_da" inputMode="numeric" required /></label>
            <Precisione t={t} />
            <label>{t.annoA}<input name="anno_a" inputMode="numeric" /></label>
            <label className="red-largo">{t.testoAtt}<input name="testo" required /></label>
            <label>{t.tipoAtt}
              <select name="tipo" defaultValue="letteraria">
                {Object.entries(t.tipiAtt).map(([k, n]) => <option key={k} value={k}>{n}</option>)}
              </select>
            </label>
            <label>{t.formaAttestata}<input name="forma_attestata" /></label>
            <label className="red-largo">{t.citazione}<input name="citazione" /></label>
            <label>{t.rif}<input name="rif" /></label>
            <label>{t.fonteFacoltativa}<SceltaOpera opere={opere} ambiti={ambiti} lang={lang} facoltativa /></label>
            <label>{t.sv}<input name="sv" defaultValue={v.lemma} /></label>
            <label>{t.locus}<input name="locus" /></label>
            <button className="btn btn-pieno">{t.aggiungiAttestazione}</button>
          </form>
        </details>
      </section>
    </div>
  );
}
