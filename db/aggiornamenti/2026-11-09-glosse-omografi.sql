-- 9 novembre 2026: le glosse italiane del Wikizionario solo per le parole senza omografi (brew², «ciglio di un colle»,
-- prendeva «fermentazione, infusione» di brew¹), mai il segnaposto «definizione mancante; se vuoi, aggiungila tu», e le
-- glosse importate che non valgono più se ne vanno. Stesso testo di db/05_import_wiktionary.sql: se cambia lì, si
-- rigenera da lì. Ripetibile senza danni.
create or replace function importa_glosse_wikizionario() returns jsonb
language plpgsql as $$
declare n int; r jsonb;
begin
  if not exists (select 1 from stg_wikizionario) then
    return jsonb_build_object('saltato', 'tabella di appoggio vuota');
  end if;
  perform set_config('app.import', 'on', true);
  create temp table cand on commit drop as
  with tutti as (
    select l.id, l.lingua, l.lemma, l.glossa_lingua, l.stato_editoriale,
           case when l.pos like 's%' then 'noun' when l.pos = 'agg.' then 'adj' when l.pos = 'v.' then 'verb'
                when l.pos = 'avv.' then 'adv' when l.pos = 'np' then 'name' when l.pos = 'prep.' then 'prep'
                when l.pos = 'pron.' then 'pron' when l.pos = 'cong.' then 'conj' when l.pos = 'inter.' then 'intj'
                when l.pos = 'num.' then 'num' when l.pos = 'det.' then 'det' when l.pos = 'loc.' then 'phrase'
                when l.pos = 'suff.' then 'suffix' when l.pos = 'pref.' then 'prefix' end as wpos
    from lessema l
  ),
  omografi as (select lingua, lemma, count(*) as n from tutti group by 1, 2),
  lx as (
    select t.* from tutti t
    where t.glossa_lingua is distinct from 'it'          -- se la glossa di base è già italiana non serve tradurla
      and t.stato_editoriale <> 'superato'
      and not exists (select 1 from glossa g where g.lessema_id = t.id and g.lingua = 'it' and g.accezione_id is null
                       and not (g.provenienza in ('wikizionario', 'wikidata', 'traduzione-automatica')
                                and g.stato_editoriale = 'importato'))
  )
  select distinct on (x.id) x.id, w.glossa
  from lx x
  join stg_wikizionario w on w.lingua = x.lingua and w.parola = x.lemma
  join omografi o on o.lingua = x.lingua and o.lemma = x.lemma
  -- il segnaposto di una pagina senza definizione non è una glossa
  where w.glossa !~* '(definizione mancante|aggiungila tu)'
    -- una parola con omografi no: il Wikizionario ha una pagina per parola, Wiktionary una voce per etimologia, e la
    -- parte del discorso non dice quale omografo è quale (brew², «ciglio di un colle», prendeva «fermentazione,
    -- infusione» di brew¹, che è registrato come verbo); vale la traduzione della glossa della voce
    and o.n = 1
    and ((x.wpos is not null and w.pos = x.wpos)                       -- stessa parte del discorso
         or (x.wpos is null                                            -- voce senza parte del discorso:
             and (select count(distinct w2.pos) from stg_wikizionario w2   -- il Wikizionario deve darne una sola
                   where w2.lingua = x.lingua and w2.parola = x.lemma) = 1))
  order by x.id, w.ordine;

  -- le glosse del Wikizionario importate che non valgono più (omografi, segnaposto, pagine cambiate) se ne vanno:
  -- al loro posto, con importa_glosse_aggiuntive(), la traduzione della glossa della voce
  delete from glossa g
   where g.provenienza = 'wikizionario' and g.stato_editoriale = 'importato' and g.lingua = 'it' and g.accezione_id is null
     and not exists (select 1 from cand c where c.id = g.lessema_id);
  get diagnostics n = row_count;

  delete from glossa g using cand c
   where g.lessema_id = c.id and g.lingua = 'it' and g.accezione_id is null
     and g.provenienza in ('wikidata', 'traduzione-automatica') and g.stato_editoriale = 'importato';
  insert into glossa (lessema_id, lingua, testo, provenienza, stato_editoriale)
  select id, 'it', glossa, 'wikizionario', 'importato' from cand
  on conflict (lessema_id, lingua) where accezione_id is null
  do update set testo = excluded.testo
  where glossa.provenienza = 'wikizionario' and glossa.stato_editoriale = 'importato' and glossa.testo <> excluded.testo;

  select jsonb_build_object(
    'tolte', n,
    'glosse_italiane', (select count(*) from glossa where provenienza = 'wikizionario'),
    'per_lingua', (select jsonb_object_agg(lingua, quante) from (
        select l.lingua, count(*) as quante from glossa g join lessema l on l.id = g.lessema_id
         where g.provenienza = 'wikizionario' group by 1 order by 2 desc limit 8) t))
    into r;
  return r;
end $$;
