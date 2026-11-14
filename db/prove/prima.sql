-- Fotografia del dizionario prima di un import di prova (scripts/prova-import.sh): ciò che un import non deve perdere
-- né cambiare senza che lo si veda. Solo su una copia del database, mai sulla produzione: scrive lo schema «prova».
\set ON_ERROR_STOP on
set client_min_messages = warning;
drop schema if exists prova cascade;
create schema prova;
create table prova.spazio as select round(pg_database_size(current_database()) / 1048576.0)::bigint as mb;   -- prima della fotografia

create table prova.lessema as
  select id, id_esterno, slug, lingua, lemma, glossa, provenienza, stato_editoriale::text as stato from lessema;
create unique index on prova.lessema (id);

-- l'etimologia accolta di ogni voce: gli etimi in ordine, riconoscibili anche se cambiano gli id
create table prova.accolta as
  select i.esito_id as id, min(i.confidenza) as confidenza,
         string_agg(e.etimi, ' | ' order by e.etimi) as etimi
    from ipotesi i
    cross join lateral (select coalesce(string_agg(coalesce(t.id_esterno, t.slug), ' + ' order by r.ordine, t.id), '') as etimi
                          from relazione r join lessema t on t.id = r.etimo_id where r.ipotesi_id = i.id) e
   where i.stato = 'accolta'
   group by i.esito_id;
create unique index on prova.accolta (id);

create table prova.glossa as
  select lessema_id as id, lingua, testo, provenienza, stato_editoriale::text as stato from glossa where accezione_id is null;
create index on prova.glossa (id, lingua);

create table prova.definizione as
  select lessema_id as id, lingua, md5(testo) as testo, provenienza from definizione;
create index on prova.definizione (id, lingua);

-- Il lavoro della redazione, riga per riga: tutto ciò che non è «importato», o che ha la provenienza della redazione.
-- L'import non lo deve toccare (CLAUDE.md, «Regole che non si violano»): l'impronta dopo dev'essere la stessa.
create table prova.redazione as
  select 'lessema' as tabella, id, md5(concat_ws('|', lingua, lemma, omografo, coalesce(glossa, ''), slug, provenienza, stato_editoriale)) as impronta
    from lessema where stato_editoriale <> 'importato' or provenienza = 'redazione'
  union all
  select 'ipotesi', id, md5(concat_ws('|', esito_id, coalesce(etichetta, ''), stato, confidenza, origine, coalesce(nota, ''), provenienza, stato_editoriale))
    from ipotesi where stato_editoriale <> 'importato' or provenienza = 'redazione'
  union all
  select 'relazione', id, md5(concat_ws('|', ipotesi_id, esito_id, etimo_id, tipo, ordine, coalesce(forma_citata, ''), coalesce(affisso, ''), confidenza, coalesce(nota, ''), provenienza, stato_editoriale))
    from relazione where stato_editoriale <> 'importato' or provenienza = 'redazione'
  union all
  select 'glossa', id, md5(concat_ws('|', lessema_id, coalesce(accezione_id, 0), lingua, testo, provenienza, stato_editoriale))
    from glossa where stato_editoriale <> 'importato' or provenienza = 'redazione'
  union all
  select 'definizione', id, md5(concat_ws('|', lessema_id, lingua, testo, provenienza, stato_editoriale))
    from definizione where stato_editoriale <> 'importato' or provenienza = 'redazione';
create index on prova.redazione (tabella, id);

create table prova.misura as
  select 'spazio_mb' as chiave, (select mb from prova.spazio) as valore
  union all select 'storico', (select count(*) from storico)
  union all select 'famiglie', (select count(*) from (select capo from mv_famiglia group by capo having count(*) > 1) f)
  union all select 'parole_in_famiglia', (select count(distinct id) from mv_famiglia)
  union all select 'storie', (select count(*) from mv_storie);

select 'fotografia: ' || (select count(*) from prova.lessema) || ' voci, ' || (select count(*) from prova.accolta) || ' etimologie accolte, '
    || (select count(*) from prova.glossa) || ' glosse, ' || (select count(*) from prova.definizione) || ' definizioni, '
    || (select count(*) from prova.redazione) || ' righe della redazione, ' || (select valore from prova.misura where chiave = 'spazio_mb') || ' MB';
