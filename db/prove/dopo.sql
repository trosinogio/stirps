-- Confronto dopo un import di prova (scripts/prova-import.sh), con la fotografia di db/prove/prima.sql.
-- Scrive il rapporto e riempie prova.esito: una riga per cancello, con la misura, la soglia e se passa.
-- Soglie (variabili di psql, in percento delle voci o delle etimologie di prima): perse, etimi, indirizzi; limite_mb.
\set ON_ERROR_STOP on
\if :{?perse} \else \set perse 0.5 \endif
\if :{?etimi} \else \set etimi 0.5 \endif
\if :{?indirizzi} \else \set indirizzi 0.5 \endif
\if :{?limite_mb} \else \set limite_mb 0 \endif
\pset format unaligned
\pset tuples_only on
set client_min_messages = warning;
-- lo spazio dopo l'import, senza la fotografia della prova e prima delle tabelle temporanee del confronto
select round((pg_database_size(current_database()) - (select coalesce(sum(pg_total_relation_size(c.oid)), 0) from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'prova' and c.relkind = 'r')) / 1048576.0) as spazio_dopo \gset

create temp table e_persa as            -- voci che avevano un'etimologia accolta e non l'hanno più (la voce c'è ancora)
  select p.id, p.etimi from prova.accolta p join lessema l on l.id = p.id
   where not exists (select 1 from ipotesi i where i.esito_id = p.id and i.stato = 'accolta');
create temp table dopo_accolta as
  select i.esito_id as id, string_agg(e.etimi, ' | ' order by e.etimi) as etimi
    from ipotesi i
    cross join lateral (select coalesce(string_agg(coalesce(t.id_esterno, t.slug), ' + ' order by r.ordine, t.id), '') as etimi
                          from relazione r join lessema t on t.id = r.etimo_id where r.ipotesi_id = i.id) e
   where i.stato = 'accolta' group by i.esito_id;
create unique index on dopo_accolta (id);
create temp table v_persa as select p.* from prova.lessema p where not exists (select 1 from lessema l where l.id = p.id);
create temp table v_nuova as select l.id, l.lingua, l.slug from lessema l where not exists (select 1 from prova.lessema p where p.id = l.id);
create temp table slug_cambiato as select p.id, p.slug as prima, l.slug as dopo from prova.lessema p join lessema l on l.id = p.id where l.slug is distinct from p.slug;
create temp table r_toccata as
  select p.tabella, p.id from prova.redazione p
   where not exists (
     select 1 from (
       select 'lessema' as tabella, id, md5(concat_ws('|', lingua, lemma, omografo, coalesce(glossa, ''), slug, provenienza, stato_editoriale)) as impronta from lessema
       union all select 'ipotesi', id, md5(concat_ws('|', esito_id, coalesce(etichetta, ''), stato, confidenza, origine, coalesce(nota, ''), provenienza, stato_editoriale)) from ipotesi
       union all select 'relazione', id, md5(concat_ws('|', ipotesi_id, esito_id, etimo_id, tipo, ordine, coalesce(forma_citata, ''), coalesce(affisso, ''), confidenza, coalesce(nota, ''), provenienza, stato_editoriale)) from relazione
       union all select 'glossa', id, md5(concat_ws('|', lessema_id, coalesce(accezione_id, 0), lingua, testo, provenienza, stato_editoriale)) from glossa
       union all select 'definizione', id, md5(concat_ws('|', lessema_id, lingua, testo, provenienza, stato_editoriale)) from definizione) d
      where d.tabella = p.tabella and d.id = p.id and d.impronta = p.impronta);

\echo '== VOCI'
select 'voci: ' || (select count(*) from prova.lessema) || ' → ' || (select count(*) from lessema) || '; perse ' || (select count(*) from v_persa)
    || ', nuove ' || (select count(*) from v_nuova);
select '  perse per lingua: ' || coalesce(string_agg(lingua || ' ' || n, ', ' order by n desc), '—') from (select lingua, count(*) n from v_persa group by 1 order by 2 desc limit 12) t;
select '  nuove per lingua: ' || coalesce(string_agg(lingua || ' ' || n, ', ' order by n desc), '—') from (select lingua, count(*) n from v_nuova group by 1 order by 2 desc limit 12) t;
select '  esempi di voci perse: ' || coalesce(string_agg(slug, ', '), '—') from (select slug from v_persa order by md5(slug) limit 15) t;

\echo '== INDIRIZZI'
select 'indirizzi cambiati (la voce resta, lo slug no): ' || count(*) from slug_cambiato;
select '  esempi: ' || coalesce(string_agg(prima || ' → ' || dopo, ', '), '—') from (select * from slug_cambiato order by md5(prima) limit 10) t;

\echo '== ETIMOLOGIE'
select 'etimologie accolte: ' || (select count(*) from prova.accolta) || ' → ' || (select count(*) from dopo_accolta)
    || '; perse (la voce resta, l''etimologia no) ' || (select count(*) from e_persa)
    || ', nuove ' || (select count(*) from dopo_accolta d join prova.lessema l on l.id = d.id where not exists (select 1 from prova.accolta p where p.id = d.id))
    || ', cambiate ' || (select count(*) from dopo_accolta d join prova.accolta p on p.id = d.id where p.etimi <> d.etimi);
select '  perse per lingua: ' || coalesce(string_agg(lingua || ' ' || n, ', ' order by n desc), '—') from (select l.lingua, count(*) n from e_persa e join lessema l on l.id = e.id group by 1 order by 2 desc limit 12) t;
select '  esempi di etimologie perse: ' || coalesce(string_agg(l.slug || ' (era ' || left(e.etimi, 50) || ')', '; '), '—') from (select * from e_persa order by md5(id::text) limit 12) e join lessema l on l.id = e.id;
select '  nuove per lingua: ' || coalesce(string_agg(lingua || ' ' || n, ', ' order by n desc), '—') from (select l.lingua, count(*) n from dopo_accolta d join lessema l on l.id = d.id join prova.lessema pl on pl.id = d.id where not exists (select 1 from prova.accolta p where p.id = d.id) group by 1 order by 2 desc limit 12) t;
select '  esempi di etimologie cambiate: ' || coalesce(string_agg(l.slug || ': ' || left(x.prima, 45) || ' → ' || left(x.dopo, 45), '; '), '—')
  from (select d.id, p.etimi as prima, d.etimi as dopo from dopo_accolta d join prova.accolta p on p.id = d.id where p.etimi <> d.etimi order by md5(d.id::text) limit 12) x join lessema l on l.id = x.id;

\echo '== GLOSSE E DEFINIZIONI'
select 'glosse italiane: ' || (select count(*) from prova.glossa where lingua = 'it') || ' → ' || (select count(*) from glossa where lingua = 'it' and accezione_id is null)
    || '; sparite ' || (select count(*) from prova.glossa p join lessema l on l.id = p.id where p.lingua = 'it' and not exists (select 1 from glossa g where g.lessema_id = p.id and g.lingua = 'it' and g.accezione_id is null))
    || ', cambiate ' || (select count(*) from prova.glossa p join glossa g on g.lessema_id = p.id and g.lingua = p.lingua and g.accezione_id is null where p.lingua = 'it' and g.testo <> p.testo);
select '  cambiate per provenienza (prima → dopo): ' || coalesce(string_agg(k || ' ' || n, ', ' order by n desc), '—')
  from (select p.provenienza || ' → ' || g.provenienza as k, count(*) n from prova.glossa p join glossa g on g.lessema_id = p.id and g.lingua = p.lingua and g.accezione_id is null where p.lingua = 'it' and g.testo <> p.testo group by 1) t;
select '  glossa della voce (inglese) cambiata: ' || count(*) from prova.lessema p join lessema l on l.id = p.id where l.glossa is distinct from p.glossa;
select 'definizioni: ' || (select count(*) from prova.definizione) || ' → ' || (select count(*) from definizione)
    || '; cadute ' || (select count(*) from prova.definizione p join lessema l on l.id = p.id where not exists (select 1 from definizione d where d.lessema_id = p.id and d.lingua = p.lingua));

\echo '== FAMIGLIE, SPAZIO, REDAZIONE'
select 'famiglie: ' || (select valore from prova.misura where chiave = 'famiglie') || ' → ' || (select count(*) from (select capo from mv_famiglia group by capo having count(*) > 1) f)
    || '; parole in una famiglia: ' || (select valore from prova.misura where chiave = 'parole_in_famiglia') || ' → ' || (select count(distinct id) from mv_famiglia)
    || '; storie: ' || (select valore from prova.misura where chiave = 'storie') || ' → ' || (select count(*) from mv_storie);
select 'spazio: ' || (select valore from prova.misura where chiave = 'spazio_mb') || ' → '
    || :spazio_dopo || ' MB (senza la fotografia della prova)';
select 'redazione: righe toccate ' || (select count(*) from r_toccata) || ' su ' || (select count(*) from prova.redazione)
    || '; storico ' || (select valore from prova.misura where chiave = 'storico') || ' → ' || (select count(*) from storico);
select '  toccate: ' || string_agg(tabella || ' ' || id, ', ') from (select * from r_toccata order by 1, 2 limit 20) t having count(*) > 0;

-- i cancelli
drop table if exists prova.esito;
create table prova.esito as
  select 1 as ordine, 'lavoro della redazione toccato (righe)' as cancello, (select count(*) from r_toccata)::numeric as misura, 0::numeric as soglia
  union all select 2, 'voci perse (% delle voci di prima)', round(100.0 * (select count(*) from v_persa) / greatest(1, (select count(*) from prova.lessema)), 3), :perse
  union all select 3, 'etimologie perse (% delle accolte di prima)', round(100.0 * ((select count(*) from e_persa) + (select count(*) from v_persa v join prova.accolta a on a.id = v.id)) / greatest(1, (select count(*) from prova.accolta)), 3), :etimi
  union all select 4, 'indirizzi cambiati o spariti (% delle voci di prima)', round(100.0 * ((select count(*) from slug_cambiato) + (select count(*) from v_persa)) / greatest(1, (select count(*) from prova.lessema)), 3), :indirizzi
  union all select 5, 'definizioni cadute', (select count(*) from prova.definizione p join lessema l on l.id = p.id where not exists (select 1 from definizione d where d.lessema_id = p.id and d.lingua = p.lingua))::numeric, 0
  union all select 6, 'storico della redazione cambiato (righe)', abs((select count(*) from storico) - (select valore from prova.misura where chiave = 'storico'))::numeric, 0
  union all select 7, 'spazio dopo l''import (MB; soglia 0 = nessun limite)',
                   case when :limite_mb > 0 then :spazio_dopo else 0 end,
                   :limite_mb;
\echo '== CANCELLI'
select case when misura <= soglia then 'passa  ' else 'FERMA  ' end || cancello || ': ' || misura || ' (soglia ' || soglia || ')' from prova.esito order by ordine;
