// Una storia composta dai dati: titolo e racconto nascono dalle catene vere (lingue attraversate, tipo di passaggio,
// glosse), le parole rimandano alle loro voci. La variante del titolo dipende dalla chiave: la stessa storia si
// racconta sempre allo stesso modo, storie diverse in modi diversi.
import Link from 'next/link';
import type { ReactNode } from 'react';
import type { Lang } from '@/lib/i18n';
import { fmt } from '@/lib/forme';
import { hash, type NodoStoria, type Percorso, type Storia } from '@/lib/storie';
import { Parola } from './Storie';
import Automatica from './Automatica';

export const ETICHETTE_TIPO: Record<Lang, Record<Storia['tipo'], string>> = {
  it: { due_strade: 'Due strade', parenti: 'Parenti lontani', viaggio: 'Lungo viaggio', famiglia: 'Una radice, tante parole' },
  en: { due_strade: 'Two roads', parenti: 'Distant relatives', viaggio: 'Long journey', famiglia: 'One root, many words' },
};

// ---- piccoli attrezzi della lingua ----
function art(nome: string): string {          // l'articolo davanti al nome (maschile) di una lingua
  if (/^[aeiouàèéìòù]/i.test(nome)) return 'l’';
  if (/^(s[bcdfgklmnpqrstvz]|z|gn|ps|x|y)/i.test(nome)) return 'lo ';
  return 'il ';
}
function daArt(nome: string): string {
  const a = art(nome);
  return a === 'l’' ? 'dall’' : a === 'lo ' ? 'dallo ' : 'dal ';
}
// testi: le parole come testo, per la «d» eufonica (scegliere, orologio ed elegante; il greco antico e il latino)
function elenco(parti: ReactNode[], lang: Lang, testi?: string[]): ReactNode {
  if (parti.length <= 1) return parti[0] ?? null;
  return parti.map((p, i) => {
    const ultimo = i === parti.length - 1;
    const e = lang === 'it' ? (/^[eé]/i.test((testi?.[i] ?? '').replace(/^(il |lo |la |l’|\*)/, '')) ? ' ed ' : ' e ') : ' and ';
    return <span key={i}>{i > 0 && (ultimo ? e : ', ')}{p}</span>;
  });
}
const parole = (ns: NodoStoria[], lang: Lang) => elenco(ns.map((x) => <P key={x.id} n={x} lang={lang} />), lang, ns.map((x) => x.lemma));
const nomi = (l: string[], lang: Lang) => lang === 'it' ? elenco(l.map((x) => `${art(x)}${x}`), lang, l) : elenco(l, lang, l);
function P({ n, lang }: { n: NodoStoria; lang: Lang }) {
  return <Link className="parola-storia" href={`/${lang}/w/${n.slug}`}><i>{fmt(n)}</i></Link>;
}
function glossa(n: NodoStoria, lang: Lang): ReactNode {
  if (!n.glossa || n.glossa_lingua !== lang) return null;
  const g = n.glossa.split(/[;,(]/)[0].trim();
  return g && g.length <= 40 ? <> ({n.glossa_automatica && <Automatica lang={lang} />}«{g}»)</> : null;
}
// le lingue attestate attraversate, dalla più antica, senza la lingua di arrivo
function lingue(p: Percorso, arrivo = true): string[] {
  const nomi: string[] = [];
  const tratti = arrivo ? p.slice(0, -1) : p;
  for (const n of tratti) if (!n.ricostruito && n.lingua !== 'it' && nomi[nomi.length - 1] !== n.lingua_nome) nomi.push(n.lingua_nome);
  return nomi;
}
const ultimoPassaggio = (p: Percorso) => (p.length >= 2 ? p[p.length - 2].tipo ?? '' : '');
const DOTTI = ['prestito_dotto', 'semidotto'];
const FORMAZIONI = ['derivazione', 'composizione', 'accorciamento', 'retroformazione', 'deonimico'];

function modo(p: Percorso, lang: Lang): string {
  const t = ultimoPassaggio(p);
  const it = lang === 'it';
  if (t === 'eredita' || t === 'trasmissione' || t === 'variante') return it ? 'per tradizione ininterrotta' : 'by unbroken inheritance';
  if (DOTTI.includes(t)) return it ? 'per via dotta, dai libri' : 'through learned borrowing, from books';
  if (t === 'prestito') return it ? 'in prestito' : 'as a borrowing';
  if (t === 'calco' || t === 'calco_semantico') return it ? 'come calco' : 'as a calque';
  if (FORMAZIONI.includes(t)) return it ? 'per derivazione' : 'by derivation';
  return it ? 'per una via che le fonti non precisano' : 'by a route the sources leave open';
}
function attraverso(p: Percorso, lang: Lang): ReactNode {
  const l = lingue(p).slice(1);          // la prima è la lingua dell'antenato comune
  if (!l.length) return null;
  return lang === 'it'
    ? <>, passando per {nomi(l, lang)}</>
    : <>, by way of {nomi(l, lang)}</>;
}

// ---- titolo e racconto, per tipo ----
function racconto(s: Storia, lang: Lang): { titolo: ReactNode; testo: ReactNode } {
  const v = hash(s.chiave) % 3;
  const it = lang === 'it';
  if (s.tipo === 'due_strade') {
    const A = s.a[s.a.length - 1], B = s.b[s.b.length - 1], E = s.antenato;
    const a = <P n={A} lang={lang} />, b = <P n={B} lang={lang} />, e = <P n={E} lang={lang} />;
    const titolo = it
      ? [<>{a} e {b}: una parola, due strade</>, <>{a} e {b} sono la stessa parola</>, <>Da {e}, due parole italiane</>][v]
      : [<>{a} and {b}: one word, two roads</>, <>{a} and {b} are the same word</>, <>From {e}, two Italian words</>][v];
    const stesso = modo(s.a, lang) === modo(s.b, lang) && !attraverso(s.a, lang) && !attraverso(s.b, lang);
    const testo = stesso
      ? (it
        ? <>Vengono entrambe {daArt(E.lingua_nome)}{E.lingua_nome} {e}{glossa(E, lang)}, ed entrambe {modo(s.a, lang)}: due forme della stessa parola, sopravvissute una accanto all’altra fino a diventare due parole.</>
        : <>Both come from {E.lingua_nome} {e}{glossa(E, lang)}, and both {modo(s.a, lang)}: two forms of the same word that survived side by side until they became two words.</>)
      : (it
        ? <>Vengono entrambe {daArt(E.lingua_nome)}{E.lingua_nome} {e}{glossa(E, lang)}: {a} è arrivata {modo(s.a, lang)}{attraverso(s.a, lang)}; {b} {modo(s.b, lang)}{attraverso(s.b, lang)}. Sono allotropi: la stessa parola, entrata due volte nella lingua.</>
        : <>Both come from {E.lingua_nome} {e}{glossa(E, lang)}: {a} arrived {modo(s.a, lang)}{attraverso(s.a, lang)}; {b} {modo(s.b, lang)}{attraverso(s.b, lang)}. They are doublets: the same word, entering the language twice.</>);
    return { titolo, testo };
  }
  if (s.tipo === 'parenti') {
    const A = s.a[s.a.length - 1], B = s.b[s.b.length - 1], R = s.radice;
    const a = <P n={A} lang={lang} />, b = <P n={B} lang={lang} />, r = <P n={R} lang={lang} />;
    const via = (p: Percorso) => nomi(lingue(p), lang);
    const titolo = it
      ? [<>{a} e {b} sono parenti</>, <>Che cosa hanno in comune {a} e {b}?</>, <>{a} e {b}, cugini lontani</>][v]
      : [<>{a} and {b} are related</>, <>What do {a} and {b} have in common?</>, <>{a} and {b}, distant cousins</>][v];
    const testo = it
      ? <>A prima vista non si somigliano, eppure risalgono alla stessa radice indoeuropea, {r}{glossa(R, lang)}. {a} è arrivata attraverso {via(s.a)}; {b} attraverso {via(s.b)}.</>
      : <>At first sight they look nothing alike, yet both go back to the same Indo-European root, {r}{glossa(R, lang)}. {a} came through {via(s.a)}; {b} through {via(s.b)}.</>;
    return { titolo, testo };
  }
  if (s.tipo === 'viaggio') {
    const p = s.percorso, W = p[p.length - 1], O = p[0];
    const w = <P n={W} lang={lang} />, o = <P n={O} lang={lang} />;
    const l = lingue(p);
    const n = l.length;
    const titolo = it
      ? [<>Il lungo viaggio di {w}</>, <>{w} ha attraversato {n} lingue</>, <>{O.lingua_nome[0].toUpperCase() + O.lingua_nome.slice(1)}, poi l’italiano: {w}</>][v]
      : [<>The long journey of {w}</>, <>{w} has crossed {n} languages</>, <>{O.lingua_nome}, then Italian: {w}</>][v];
    const testo = it
      ? <>Prima di diventare italiana, {w} è passata per {nomi(l, lang)}. Tutto comincia con {o}{glossa(O, lang)}, in {O.lingua_nome}.</>
      : <>Before becoming Italian, {w} passed through {nomi(l, lang)}. It all begins with {o}{glossa(O, lang)}, in {O.lingua_nome}.</>;
    return { titolo, testo };
  }
  const R = s.radice, r = <P n={R} lang={lang} />;

  const titolo = it
    ? [<>{r}: una radice, {s.n} parole</>, <>Che cosa unisce {parole(s.parole.slice(0, 3), lang)}?</>, <>La famiglia di {r}</>][v]
    : [<>{r}: one root, {s.n} words</>, <>What links {parole(s.parole.slice(0, 3), lang)}?</>, <>The family of {r}</>][v];
  const testo = it
    ? <>Dalla radice indoeuropea {r}{glossa(R, lang)} discendono almeno {s.n} parole italiane d’uso comune, tra cui {parole(s.parole.slice(0, 6), lang)}.</>
    : <>At least {s.n} everyday Italian words descend from the Indo-European root {r}{glossa(R, lang)}, among them {parole(s.parole.slice(0, 6), lang)}.</>;
  return { titolo, testo };
}

export function Catena({ p, lang }: { p: Percorso; lang: Lang }) {
  return (
    <p className="catena-mini">
      {p.map((n, j) => (
        <span key={`${n.id}-${j}`} className="anello">
          {j > 0 && <span className="maggiore" aria-hidden="true">&gt;</span>}
          <Parola n={n} lang={lang} />
        </span>
      ))}
    </p>
  );
}

export default function StoriaCarta({ s, lang, grande, extra }: { s: Storia; lang: Lang; grande?: boolean; extra?: ReactNode }) {
  const { titolo, testo } = racconto(s, lang);
  const Titolo = grande ? 'h2' : 'h3';
  return (
    <article className={`storia storia-${s.tipo} ${grande ? 'storia-grande' : ''}`}>
      <p className="storia-tipo">{ETICHETTE_TIPO[lang][s.tipo]}</p>
      <Titolo className="storia-titolo">{titolo}</Titolo>
      <p className="storia-testo">{testo}</p>
      {s.tipo === 'famiglia'
        ? <p className="storia-parole">{s.parole.map((n) => <Parola key={n.id} n={n} lang={lang} />)}</p>
        : s.tipo === 'viaggio'
          ? <Catena p={s.percorso} lang={lang} />
          : <><Catena p={s.a} lang={lang} /><Catena p={s.b} lang={lang} /></>}
      {extra}
    </article>
  );
}
