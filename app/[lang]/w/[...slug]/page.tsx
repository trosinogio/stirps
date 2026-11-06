import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { isLang, TESTI, type Lang, type Testi } from '@/lib/i18n';
import { lingueGeo, pronuncia, scheda, sensi, periodiLingue } from '@/lib/dati';
import { classeRamo, datazione, fmt, G, nodiUnici, perLingua, tx } from '@/lib/forme';
import { Fiducia, intercala, VoceLink } from '@/components/comuni';
import Mappa from '@/components/Mappa';
import Automatica from '@/components/Automatica';
import Definizione from '@/components/Definizione';
import Pronuncia from '@/components/Pronuncia';
import InBreve from '@/components/InBreve';
import LineaTempo, { type NodoTempo } from '@/components/LineaTempo';
import type { Attestazione, NodoCatena, Relazione, Rimando, Scheda } from '@/lib/tipi';

export const revalidate = 300;
// nessuna pagina in fase di build: si generano alla prima visita e restano in cache (ISR)
export async function generateStaticParams() { return []; }

export async function generateMetadata({ params }: { params: Promise<{ lang: string; slug: string[] }> }): Promise<Metadata> {
  const { lang, slug } = await params;
  if (!isLang(lang)) return {};
  const sc = await scheda(slug.map(decodeURIComponent).join('/'), lang);
  if (!sc) return {};
  const L = sc.lessema;
  const catena = nodiUnici(sc.catena).slice(0, 3).map((c) => `${c.lingua_sigla} ${fmt(c)}`).join(' < ');
  return {
    title: TESTI[lang].etimologiaDi(fmt(L), L.lingua_nome),
    description: [L.glossa, catena ? `${fmt(L)} < ${catena}` : ''].filter(Boolean).join('. '),
    alternates: { languages: { it: `/it/w/${L.slug}`, en: `/en/w/${L.slug}` } },
  };
}

function Sezione({ titolo, children }: { titolo: string; children: React.ReactNode }) {
  return <section className="sez"><h2>{titolo}</h2>{children}</section>;
}

// Le note di redazione sono scritte in una lingua: se non è quella dell'interfaccia, lo diciamo
function Nota({ testo, sc, t, className, lingua }: { testo?: string | null; sc: Scheda; t: Testi; className?: string; lingua?: string | null }) {
  if (!testo) return null;
  const l = lingua ?? sc.lingua_redazione;
  const altra = !!l && l !== sc.lingua_richiesta;
  return (
    <span className={className} lang={altra ? l! : undefined}>
      {tx(testo)}
      {altra && <span className="marca-lingua">({t.inLingua(t.nomiLingue[l!] ?? l!)})</span>}
    </span>
  );
}

function Rimandi({ rs, t, strato }: { rs: Rimando[]; t: Testi; strato?: { nome: string; licenza: string } | null }) {
  if (!rs?.length) {
    // un'ipotesi importata ha una fonte: lo strato da cui viene
    if (strato) return <p className="rimandi">{t.fonteStrato(strato.nome.split(',')[0], strato.licenza)}</p>;
    return <p className="rimandi senza">{t.nessunaFonte}</p>;
  }
  return (
    <p className="rimandi">
      {t.fonti}
      {intercala(rs.map((r, i) => <span key={i}>{r.opera}{r.sv ? `, s.v. ${r.sv}` : ''}{r.locus ? `, ${r.locus}` : ''} ({t.posizioni[r.posizione] ?? r.posizione})</span>), (i) => <span key={'s' + i}>; </span>)}
    </p>
  );
}

function DettagliRelazione({ r, sc, t, lang }: { r: Relazione; sc: Scheda; t: Testi; lang: Lang }) {
  return (
    <>
      {r.forma_citata && <>{t.dallaForma}<i>{r.forma_citata}</i></>}
      {r.affisso && <>{t.con}<i>{r.affisso}</i></>}
      {r.etimo_accezione && t.nelSenso(G(r.etimo_accezione, lang))}
      {r.processo && t.per(r.processo_etichetta ?? r.processo)}
      {r.luogo && `, ${r.luogo}`}
      {r.nota && <>. <Nota testo={r.nota} sc={sc} t={t} className="rel-nota" /></>}
    </>
  );
}

function Origine({ sc, t, lang }: { sc: Scheda; t: Testi; lang: Lang }) {
  const L = sc.lessema, cat = sc.catena;
  if (!cat.length) {
    const acc = sc.ipotesi.find((i) => i.stato === 'accolta');
    let testo: React.ReactNode;
    if (acc && acc.origine !== 'etimo') testo = <>{t.origini[acc.origine]}. <Nota testo={acc.nota} sc={sc} t={t} lingua={acc.nota_lingua} /></>;
    else if (sc.ipotesi.some((i) => i.stato !== 'respinta')) testo = t.etimologiaAperta;
    else if (L.ricostruito || L.pos === 'rad.') testo = t.eRadice;
    else testo = t.etimologiaAssente;
    return <Sezione titolo={t.sezioni.origine}><p>{testo}</p></Sezione>;
  }
  const sopra = new Map<number, NodoCatena[]>();
  for (const c of cat) {
    if (!sopra.has(c.esito)) sopra.set(c.esito, []);
    if (!sopra.get(c.esito)!.some((x) => x.id === c.id)) sopra.get(c.esito)!.push(c);
  }
  const visti = new Set<number>();
  const gradino = (id: number): React.ReactNode => {
    const lista = sopra.get(id) ?? [];
    if (!lista.length) return null;
    return (
      <ol className="ascendenza">
        {lista.map((c) => {
          const nuovo = !visti.has(c.id);
          visti.add(c.id);
          return (
            <li key={c.id + '-' + id}>
              <div className={`passo ${classeRamo(c.ramo)}`}>
                <span className="lt" aria-hidden="true">&lt;</span>
                <div>
                  {/* due date diverse: quella del passaggio accanto al tipo, la prima attestazione accanto alla parola */}
                  <div className="passo-1"><VoceLink n={c} lang={lang} /><span className="tp">{c.tipo_etichetta ?? c.tipo}{c.passaggio_data && <>, <span title={t.dataPassaggio}>{datazione(c.passaggio_data as Attestazione, t)}</span></>}</span>{c.attestata && <span className="data-catena" title={(c.attestata as Attestazione).stima ? t.stimaNota : t.primaAttestazione}>{(c.attestata as Attestazione).stima ? t.almenoDal(datazione(c.attestata as Attestazione, t)) : datazione(c.attestata as Attestazione, t)}</span>}</div>
                  {c.glossa && <div className="gl">{c.glossa_automatica && <Automatica lang={lang} />}{G(c.glossa, lang)}</div>}
                </div>
              </div>
              {nuovo && gradino(c.id)}
            </li>
          );
        })}
      </ol>
    );
  };
  const minimo = Math.min(...cat.map((c) => c.confidenza_catena ?? 3));
  const prima = [...sc.attestazioni].sort((a, b) => a.anno_da - b.anno_da)[0];
  const cima = nodiUnici(cat.filter((c) => !(sopra.get(c.id) ?? []).length));
  return (
    <Sezione titolo={t.sezioni.origine}>
      <div className="scala">
        <div className={`passo-0 ${classeRamo(L.ramo)}`}><span className="lemma">{fmt(L)}</span><span className="sigla">{L.lingua_sigla}</span>{prima && <span className="data-catena">{datazione(prima, t)}</span>}</div>
        {gradino(L.id)}
      </div>
      <p className="certezza">{t.certezzaCatena} <Fiducia n={minimo} /> {t.fiducia[minimo]}. {t.anelloDebole}</p>
      <p className="radici-di">
        {cima.length > 1 ? t.capostipiti : t.capostipite}{' '}
        {intercala(cima.map((c) => <VoceLink key={c.id} n={c} lang={lang} radice />), (i) => <span key={'s' + i}>, </span>)}
      </p>
      <p className="nota-sez suggerimento">{t.toccaCapo(cima.length)}</p>
    </Sezione>
  );
}

export default async function Voce({ params }: { params: Promise<{ lang: string; slug: string[] }> }) {
  const { lang, slug } = await params;
  if (!isLang(lang)) notFound();
  const t = TESTI[lang];
  const s = slug.map(decodeURIComponent).join('/');
  const [sc, pr, se] = await Promise.all([scheda(s, lang), pronuncia(s), sensi(s)]);
  if (!sc) notFound();
  const L = sc.lessema;
  const strato = sc.strati.find((x) => x.codice === L.provenienza);
  const glossaAltrove = L.glossa_lingua && L.glossa_lingua !== lang;

  // viaggio: solo se c'è uno spostamento geografico vero
  const nodiViaggio = [L, ...nodiUnici(sc.catena)];
  const geo = sc.catena.length ? await lingueGeo(lang) : [];
  // la linea del tempo: i nodi della catena con il periodo della loro lingua e la prima attestazione
  const periodi = sc.catena.length ? await periodiLingue([...new Set(nodiViaggio.map((n) => n.lingua))]) : new Map();
  const primaAtt = [...sc.attestazioni].sort((a, b) => a.anno_da - b.anno_da)[0];
  const generazione = new Map<number, number>([[L.id, 0]]);
  for (const c of sc.catena) generazione.set(c.id, Math.max(generazione.get(c.id) ?? 0, c.profondita));
  const nodiTempo: NodoTempo[] = nodiViaggio.map((n, i) => {
    const p = periodi.get(n.lingua);
    const att = i === 0 ? primaAtt : (n as NodoCatena).attestata;
    return {
      id: n.id, slug: n.slug, etichetta: fmt(n), sigla: n.lingua_sigla, lingua_nome: n.lingua_nome, ramo: n.ramo ?? null,
      ricostruita: p?.ricostruita ?? !!n.ricostruito,
      periodo: p?.anno_da != null ? { da: p.anno_da, a: p.anno_a } : null,
      attestata: att ? { anno_da: att.anno_da, anno_a: att.anno_a ?? null, precisione: att.precisione } : null,
      principale: i === 0,
      generazione: generazione.get(n.id) ?? 0,
    };
  });
  const perCod = new Map(geo.map((g) => [g.codice, g]));
  const xy = [...new Set(nodiViaggio.map((n) => n.lingua))].map((c) => {
    let g = perCod.get(c);
    if (g && g.lat == null && g.varieta_di) g = perCod.get(g.varieta_di);
    return g && g.lat != null && g.lon != null ? [g.lon, g.lat] : null;
  }).filter((v): v is number[] => !!v);
  const ampiezza = xy.length > 1 ? Math.max(Math.max(...xy.map((p) => p[0])) - Math.min(...xy.map((p) => p[0])), Math.max(...xy.map((p) => p[1])) - Math.min(...xy.map((p) => p[1]))) : 0;

  const accById = new Map(sc.accezioni.map((a) => [a.id, a]));
  const disc = nodiUnici(sc.discendenti).sort(perLingua);
  const perLinguaDisc = new Map<string, typeof disc>();
  for (const d of disc) { if (!perLinguaDisc.has(d.lingua_nome)) perLinguaDisc.set(d.lingua_nome, []); perLinguaDisc.get(d.lingua_nome)!.push(d); }
  const stretti = sc.cognati.filter((g) => g.tipo === 'stretto').sort(perLingua);
  const prestito = sc.cognati.filter((g) => g.tipo !== 'stretto').sort(perLingua);

  return (
    <>
      <Link className="indietro" href={`/${lang}`}>‹ {t.radici}</Link>
      <header className="testa-voce">
        <h1 className={`voce-titolo ${classeRamo(L.ramo)}`}><span className="lemma">{fmt(L)}</span></h1>
        {L.translit && <p className="translit">{L.translit}</p>}
        <Pronuncia pr={pr} lang={lang} />
        {se?.testa && <p className="forme-testa" lang={L.lingua}>{t.scheda.grammatica(se.testa)}</p>}
        <p className={`meta ${classeRamo(L.ramo)}`}>
          <Link className="lingua-b lingua-n" href={`/${lang}/l/${L.lingua}`}>{L.lingua_nome}</Link>
          {L.pos && <span>{t.pos[L.pos] ?? L.pos}</span>}
          {L.ricostruito && <span className="etichetta">{t.formaRicostruita}</span>}
          {L.obsoleto && <span className="etichetta">{t.formaAntiquata}</span>}
          {L.provenienza !== 'redazione' && strato && <span className="etichetta">{t.dati(strato.nome.split(',')[0], strato.licenza)}</span>}
        </p>
        {L.glossa && (
          <p className="glossa-g" lang={glossaAltrove ? L.glossa_lingua! : undefined}>
            {L.glossa_automatica && <Automatica lang={lang} />}
            {G(L.glossa, lang)}
            {glossaAltrove && <span className="marca-lingua">({t.inLingua(t.nomiLingue[L.glossa_lingua!] ?? L.glossa_lingua!)})</span>}
          </p>
        )}
        <Definizione L={L} lang={lang} />
        {L.nota && <p className="origine"><Nota testo={L.nota} sc={sc} t={t} /></p>}
      </header>

      <InBreve sc={sc} t={t} lang={lang} />

      <Origine sc={sc} t={t} lang={lang} />

      {sc.ipotesi.length > 0 && (
        <Sezione titolo={sc.ipotesi.length > 1 ? t.sezioni.ipotesi : t.sezioni.ipotesiFonti}>
          {sc.ipotesi.map((i) => (
            <div key={i.id} className={`ipotesi${i.stato === 'respinta' ? ' respinta' : ''}`}>
              <div className="ip-testa">
                <span className="ip-nome">{i.etichetta === 'principale' ? t.ipotesiPrincipale : i.etichetta}</span>
                <span className={`stato ${i.stato}`}>{t.stati[i.stato]}</span>
                <span className="conf"><Fiducia n={i.confidenza} /> {t.fiducia[i.confidenza]}</span>
              </div>
              {i.origine !== 'etimo' && <p className="ip-nota">{t.origini[i.origine]}: {t.nessunEtimo}</p>}
              {i.relazioni.length > 0 && (
                <ul className="rel">
                  {i.relazioni.map((r, k) => (
                    <li key={k}><span className="tp">{r.tipo_etichetta}</span> {t.da} <VoceLink n={r.etimo} lang={lang} /><DettagliRelazione r={r} sc={sc} t={t} lang={lang} /></li>
                  ))}
                </ul>
              )}
              {i.nota && <p className="ip-nota"><Nota testo={i.nota} sc={sc} t={t} lingua={i.nota_lingua} /></p>}
              <Rimandi rs={i.rimandi} t={t} strato={i.provenienza && i.provenienza !== 'redazione' ? sc.strati.find((x) => x.codice === i.provenienza) : null} />
            </div>
          ))}
        </Sezione>
      )}

      {sc.accezioni.length > 1 && (
        <Sezione titolo={t.sezioni.significati}>
          <ol className="accezioni">
            {sc.accezioni.map((a) => (
              <li key={a.id}>
                {G(a.glossa, lang)}
                {a.ambito && <span className="gl">, {a.ambito}</span>}
                {a.deriva_da && <span className="proc"> &lt; {G(accById.get(a.deriva_da)?.glossa, lang)}{a.processo ? t.per(a.processo_etichetta ?? a.processo) : ''}</span>}
              </li>
            ))}
          </ol>
        </Sezione>
      )}

      {sc.accezioni.length <= 1 && (se?.sensi.length ?? 0) > 1 && (
        <Sezione titolo={t.sezioni.significati}>
          <ol className="accezioni sensi-w" lang="en">
            {se!.sensi.map(([testo, et], k) => (
              <li key={k}>{et && <span className="et" lang={lang}>{t.scheda.etichette(et)} </span>}{testo}</li>
            ))}
          </ol>
          <p className="nota-fonte">{t.scheda.sensiWiktionary}</p>
        </Sezione>
      )}

      {sc.falsi_miti.length > 0 && (
        <Sezione titolo={t.sezioni.mito}>
          {sc.falsi_miti.map((m, i) => (
            <div key={i} className="mito">
              <span className="barrato">{m.etichetta}</span>
              <p><Nota testo={m.nota} sc={sc} t={t} /></p>
              {m.riguarda !== L.slug && (() => {
                const c = sc.catena.find((x) => x.slug === m.riguarda);
                return c ? <p>{t.riguarda} <VoceLink n={c} lang={lang} />{t.nellaCatena}</p> : null;
              })()}
            </div>
          ))}
        </Sezione>
      )}

      {sc.cognati.length > 0 && (
        <Sezione titolo={t.sezioni.sorelle}>
          <p className="nota-sez">{t.sorelleNota}</p>
          {[[t.perEredita, stretti], [t.attraversoPrestito, prestito]].map(([titolo, lista]) => (lista as typeof stretti).length > 0 && (
            <div key={titolo as string} className="gruppo-sorelle">
              <h3>{titolo as string}</h3>
              <ul className="elenco-voci">
                {(lista as typeof stretti).map((g) => (
                  <li key={g.id}>
                    <VoceLink n={g} lang={lang} />
                    {g.glossa && <span className="gl">{G(g.glossa, lang)}</span>}
                    <span className="da">{t.da} {g.antenato_comune.lingua_sigla} {fmt(g.antenato_comune)}</span>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </Sezione>
      )}

      {sc.allotropi.length > 0 && (
        <Sezione titolo={t.sezioni.allotropi}>
          <p className="nota-sez">{t.allotropiNota}</p>
          <ul className="elenco-voci">
            {sc.allotropi.map((a) => (
              <li key={a.id}>
                <VoceLink n={a} lang={lang} />
                {a.glossa && <span className="gl">{G(a.glossa, lang)}</span>}
                <span className="da">{t.stessoEtimo} {a.antenato_comune.lingua_sigla} {fmt(a.antenato_comune)}</span>
              </li>
            ))}
          </ul>
        </Sezione>
      )}

      {sc.catena.length > 0 && (
        <Sezione titolo={t.sezioni.tempo}>
          <LineaTempo lang={lang} nodi={nodiTempo} archi={sc.catena.map((c) => ({ da: c.id, a: c.esito, tipo: c.tipo, etichetta: c.tipo_etichetta }))} t={t} />
        </Sezione>
      )}

      {ampiezza >= 8 && (
        <Sezione titolo={t.sezioni.viaggio}>
          <Mappa lang={lang} nodi={nodiViaggio} archi={sc.catena.map((c) => ({ da: c.id, a: c.esito, tipo: c.tipo }))} lingue={geo} />
        </Sezione>
      )}

      <Sezione titolo={t.sezioni.attestazioni}>
        {sc.attestazioni.length ? (
          <ul className="attestazioni">
            {sc.attestazioni.map((a, i) => (
              <li key={i}>
                {/* una stima è un terminus ante quem: «almeno dal 1525», con la spiegazione al passaggio del mouse */}
                <span className="data" title={a.stima ? t.stimaNota : undefined}>{a.stima ? t.almenoDal(datazione(a, t)) : datazione(a, t)}</span>
                <span>
                  <span>{a.stima && a.banca_dati
                    ? <>{a.url ? <a href={a.url} target="_blank" rel="noopener noreferrer">{a.testo}</a> : a.testo}, {t.secondo(a.banca_dati)}</>
                    : a.provenienza && a.provenienza !== 'redazione' ? t.secondo(a.testo) : a.testo}{a.rif ? `, ${a.rif}` : ''}</span>
                  {a.forma_attestata && <> <span className="gl">{t.forma}</span> <i>{a.forma_attestata}</i></>}
                  {a.citazione && <>: <span className="cit">{G(a.citazione, lang)}</span></>}
                  {a.nota && <span className="nota"><Nota testo={a.nota} sc={sc} t={t} /></span>}
                </span>
              </li>
            ))}
          </ul>
        ) : <p className="vuoto">{t.nessunaAttestazione}</p>}
      </Sezione>

      {disc.length > 0 && (
        <Sezione titolo={t.sezioni.discendenti}>
          <ul className="elenco-voci">
            {[...perLinguaDisc.entries()].map(([nome, ns]) => (
              <li key={nome}>
                <span className="da">{nome}</span>
                <span>{intercala(ns.map((n) => <VoceLink key={n.id} n={n} lang={lang} sigla={false} />), (i) => <span key={'s' + i}>, </span>)}</span>
              </li>
            ))}
          </ul>
          <p className="apri-voce"><Link className="btn" href={`/${lang}/r/${L.slug}`}>{t.apriStemmaDa}</Link></p>
        </Sezione>
      )}

      {sc.connessioni.length > 0 && (
        <Sezione titolo={t.sezioni.connessioni}>
          <ul className="elenco-voci">
            {sc.connessioni.map((c) => (
              <li key={c.id}>
                <span className="da">{t.legame(t.tipiConnessione[c.tipo] ?? c.tipo)}</span>
                <VoceLink n={c} lang={lang} />
                <span className="gl"><Nota testo={c.descrizione} sc={sc} t={t} /></span>
              </li>
            ))}
          </ul>
        </Sezione>
      )}

      {(() => {
        // la stessa parola nelle opere di riferimento in rete, più Wiktionary (anche per le forme ricostruite), salvo per
        // le voci dei dizionari del Perseus: sono proprio quelle che Wiktionary non ha
        const L = sc.lessema;
        const enc = encodeURIComponent(L.lemma);
        const ling = L.provenienza === 'perseus' ? '' : (L.wiktionary_lingua ?? '').replace(/ /g, '_');
        const wikt = ling ? (L.ricostruito ? `https://en.wiktionary.org/wiki/Reconstruction:${ling}/${enc}` : `https://en.wiktionary.org/wiki/${enc}#${ling}`) : null;
        const voci = (sc.consultabili ?? []).map((o) => ({ chiave: o.sigla, titolo: o.titolo, meta: [o.autore, o.anno].filter(Boolean).join(', '), url: o.modello.replace('{lemma}', enc) }));
        if (wikt) voci.push({ chiave: 'Wiktionary', titolo: 'Wiktionary', meta: '', url: wikt });
        return voci.length ? (
          <Sezione titolo={t.daConsultare}>
            <p className="nota-sez">{t.daConsultareNota}</p>
            <ul className="consultare">
              {voci.map((x) => (
                <li key={x.chiave}><a href={x.url} target="_blank" rel="noopener noreferrer">{x.titolo}</a>{x.meta && <span className="meta-opera">{x.meta}</span>}</li>
              ))}
            </ul>
          </Sezione>
        ) : null;
      })()}

      {sc.strati.length > 0 && (
      <Sezione titolo={t.sezioni.fonti}>
          <ul className="strati">
            {sc.strati.map((x) => <li key={x.codice}>{x.nome}: {x.licenza}{x.attribuzione ? `. ${x.attribuzione}` : ''}</li>)}
          </ul>
        </Sezione>
      )}
    </>
  );
}
