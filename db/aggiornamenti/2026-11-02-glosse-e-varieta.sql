-- 2 novembre 2026: il greco arcadocipriota (grc-arp, le parole nel sillabario cipriota) si indicizza per segni, non con
-- le 24 lettere; le traduzioni automatiche valgono solo per la glossa inglese che è stata tradotta. Funzioni copiate da
-- db/01_schema.sql e db/05_import_wiktionary.sql. Ripetibile senza danni.

-- La chiave dell'indice di una lingua: le prime due lettere della forma normalizzata, secondo l'alfabeto della lingua
-- (23 lettere latine, con J sotto I e U sotto V; 24 greche). «A-» raccoglie le parole di una lettera e quelle come
-- «a priori»; null per le parole che cominciano fuori dall'alfabeto (W latina, ϝοῖκος con la lettera epicorica), che
-- restano voci ma fuori dall'indice.
-- È nella colonna generata lessema.chiave_indice: se cambia, la colonna va ricalcolata (update lessema set lemma = lemma).
create or replace function indice_iniziali(p_lingua text, p_forma text) returns text
language sql immutable parallel safe
return (with a as (select case when p_lingua ~ '^la(-|$)' then 'ABCDEFGHIKLMNOPQRSTVXYZ'
                               -- il greco arcadocipriota ha il sillabario: si indicizza per segni
                               when p_lingua ~ '^grc(-|$)' and p_lingua <> 'grc-arp' then 'ΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩ' end as lettere,
                          case when p_lingua ~ '^la(-|$)' then translate(upper(p_forma), 'JU', 'IV') else upper(p_forma) end as f)
        select case when f is null or f = '' then null
                    when lettere is not null and strpos(lettere, left(f, 1)) = 0 then null
                    when substr(f, 2, 1) ~ '^[[:alpha:]]$' and (lettere is null or strpos(lettere, substr(f, 2, 1)) > 0) then left(f, 2)
                    else left(f, 1) || '-' end
          from a);

-- Dopo il Wikizionario: definizioni di Wikidata per le parole italiane che non ne hanno (stessa parte del discorso,
-- niente omografi), poi traduzioni automatiche per gli etimi che non hanno una glossa italiana. Per differenza: le
-- glosse uguali restano, quelle che non valgono più si tolgono, le nuove si aggiungono.
create or replace function importa_glosse_aggiuntive() returns jsonb
language plpgsql as $$
declare
  r jsonb := '{}';
  n int;
begin
  perform set_config('app.import', 'on', true);
  create temp table cand_wd on commit drop as
    select distinct on (l.id) l.id, w.glossa
      from lessema l
      join stg_glossa_wikidata w on w.lemma = l.lemma
     where l.lingua = 'it' and l.stato_editoriale <> 'superato' and coalesce(l.glossa_lingua, '') <> 'it'
       and w.glossa ~ '^[[:lower:]]' and length(w.glossa) >= 6
       and not exists (select 1 from glossa g where g.lessema_id = l.id and g.lingua = 'it' and g.accezione_id is null
                        and not (g.provenienza = 'wikidata' and g.stato_editoriale = 'importato'))
       and (case w.categoria
              when 'Q1084' then l.pos like 's.%' or l.pos = 's.'
              when 'Q34698' then l.pos = 'agg.'
              when 'Q24905' then l.pos = 'v.'
              when 'Q380057' then l.pos = 'avv.'
              when 'Q147276' then l.pos = 'np'
              when 'Q63116' then l.pos like 'num%'
              when 'Q83034' then l.pos like 'inter%'
              else false end
            or (l.pos is null and (select count(*) from stg_glossa_wikidata w2 where w2.lemma = l.lemma) = 1))
       and (select count(*) from lessema o where o.lingua = 'it' and o.lemma = l.lemma) = 1
     order by l.id, w.sensi desc, w.lid;
  create index on cand_wd (id);
  delete from glossa g
   where g.provenienza = 'wikidata' and g.stato_editoriale = 'importato'
     and not exists (select 1 from cand_wd c where c.id = g.lessema_id and c.glossa = g.testo);
  insert into glossa (lessema_id, lingua, testo, provenienza, stato_editoriale)
  select id, 'it', glossa, 'wikidata', 'importato' from cand_wd
  on conflict (lessema_id, lingua) where accezione_id is null do nothing;
  select count(*) into n from glossa where provenienza = 'wikidata';
  r := r || jsonb_build_object('wikidata', n);

  create temp table cand_tr on commit drop as
    select distinct on (l.id) l.id, btrim(t.testo) as testo
      from stg_glossa_tradotta t join lessema l on l.id_esterno = t.chiave
     where l.lingua <> 'it' and coalesce(l.glossa_lingua, '') <> 'it' and btrim(coalesce(t.testo, '')) <> ''
       -- la traduzione vale solo per la glossa inglese che è stata tradotta: se la glossa cambia, aspetta la nuova
       and (coalesce(t.originale, '') = '' or t.originale = l.glossa)
     order by l.id, btrim(t.testo);
  create index on cand_tr (id);
  delete from glossa g
   where g.provenienza = 'traduzione-automatica' and g.stato_editoriale = 'importato'
     and not exists (select 1 from cand_tr c where c.id = g.lessema_id and c.testo = g.testo);
  insert into glossa (lessema_id, lingua, testo, provenienza, stato_editoriale)
  select id, 'it', testo, 'traduzione-automatica', 'importato' from cand_tr
  on conflict (lessema_id, lingua) where accezione_id is null do nothing;
  select count(*) into n from glossa where provenienza = 'traduzione-automatica';
  r := r || jsonb_build_object('traduzione_automatica', n);
  return r;
end $$;
comment on function importa_glosse_aggiuntive() is 'Glosse italiane di rango più basso: definizioni di Wikidata e traduzioni automatiche, solo dove mancano.';
