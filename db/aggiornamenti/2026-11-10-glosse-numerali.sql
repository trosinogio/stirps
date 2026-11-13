-- 10 novembre 2026: le glosse dei numerali italiani. Il Wikizionario scrive i numerali come aggettivi, e l'abbinamento per
-- parte del discorso non li trovava: cinque, quattro, uno prendevano da Wikidata «cardinale», nove «numero ordinale per 9».
-- Ora un numerale prende la glossa dell'aggettivo, e Wikidata non dà più un'etichetta di categoria come glossa. Stesso
-- testo di db/05_import_wiktionary.sql: se cambia lì, si rigenera da lì. Ripetibile senza danni.
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
    -- stessa parte del discorso; il Wikizionario scrive i numerali come aggettivi («cinque»: numero naturale che segue
    -- quattro e precede sei), e senza questo il numerale prendeva da Wikidata «cardinale»
    and ((x.wpos is not null and (w.pos = x.wpos or (x.wpos = 'num' and w.pos = 'adj')))
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
       and w.glossa !~* '^(cardinale|ordinale|numerale)$'   -- un'etichetta di categoria non è una glossa (cinque: «cardinale»)
       and not exists (select 1 from glossa g where g.lessema_id = l.id and g.lingua = 'it' and g.accezione_id is null
                        and not (g.provenienza in ('wikidata', 'traduzione-automatica', 'claude') and g.stato_editoriale = 'importato'))
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
  -- le traduzioni automatiche, dove non c'è altro: quella di Claude prima di quella di OPUS-MT; per le parole italiane
  -- (solo Claude) Wikidata viene prima. Valgono solo per la glossa inglese da cui sono nate: se cambia, aspettano
  create temp table cand_tr on commit drop as
    select distinct on (c.id) c.id, c.testo, c.provenienza
      from (select l.id, btrim(d.traduzione) as testo, 'claude' as provenienza, 1 as rango
              from stg_definizione d join lessema l on l.id_esterno = d.chiave
             where coalesce(l.glossa_lingua, '') <> 'it' and btrim(coalesce(d.traduzione, '')) <> ''
               and (coalesce(d.originale, '') in ('', coalesce(l.glossa, ''))) and l.stato_editoriale <> 'superato'
               -- per una parola italiana una «traduzione» uguale al lemma non dice nulla (limnofilo → «limnofilo»)
               and not (l.lingua = 'it' and norm(btrim(d.traduzione)) = norm(l.lemma))
            union all
            select l.id, btrim(t.testo), 'traduzione-automatica', 2
              from stg_glossa_tradotta t join lessema l on l.id_esterno = t.chiave
             where l.lingua <> 'it' and coalesce(l.glossa_lingua, '') <> 'it' and btrim(coalesce(t.testo, '')) <> ''
               and (coalesce(t.originale, '') = '' or t.originale = l.glossa)) c
     where not exists (select 1 from cand_wd w where w.id = c.id)
     order by c.id, c.rango, c.testo;
  create index on cand_tr (id);
  -- prima si tolgono le glosse aggiuntive superate, poi si mettono le nuove: così una glossa di rango più alto
  -- (Wikidata) prende il posto di una traduzione automatica dello stesso lessema
  delete from glossa g
   where g.provenienza = 'wikidata' and g.stato_editoriale = 'importato'
     and not exists (select 1 from cand_wd c where c.id = g.lessema_id and c.glossa = g.testo);
  delete from glossa g
   where g.provenienza in ('traduzione-automatica', 'claude') and g.stato_editoriale = 'importato'
     and not exists (select 1 from cand_tr c where c.id = g.lessema_id and c.testo = g.testo and c.provenienza = g.provenienza);
  insert into glossa (lessema_id, lingua, testo, provenienza, stato_editoriale)
  select id, 'it', glossa, 'wikidata', 'importato' from cand_wd
  on conflict (lessema_id, lingua) where accezione_id is null do nothing;
  select count(*) into n from glossa where provenienza = 'wikidata';
  r := r || jsonb_build_object('wikidata', n);
  insert into glossa (lessema_id, lingua, testo, provenienza, stato_editoriale)
  select id, 'it', testo, provenienza, 'importato' from cand_tr
  on conflict (lessema_id, lingua) where accezione_id is null do nothing;
  select count(*) into n from glossa where provenienza = 'traduzione-automatica';
  r := r || jsonb_build_object('traduzione_automatica', n);
  select count(*) into n from glossa where provenienza = 'claude';
  r := r || jsonb_build_object('claude', n);
  return r;
end $$;
comment on function importa_glosse_aggiuntive() is 'Glosse italiane di rango più basso: definizioni di Wikidata e traduzioni automatiche (Claude, poi OPUS-MT), solo dove mancano.';
