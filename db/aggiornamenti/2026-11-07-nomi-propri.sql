-- 7 novembre 2026: l'indice dei nomi propri e derivati. Oltre ai nomi (nome_proprio, colonna generata), vanno nell'indice
-- dei nomi le altre voci con la maiuscola nelle lingue che scrivono i nomi comuni con la minuscola: Romanus, Danish, Graece.
-- La colonna nome_indice si aggiunge senza riscrivere la tabella (null vale falso) e la tiene un trigger; parole_lingua(),
-- nodo_json() ed elenco_radici() la usano. Stesso testo di db/01_schema.sql e db/02_logica.sql. Ripetibile senza danni.
alter table lessema add column if not exists nome_indice boolean;

-- L'indice dei nomi propri e derivati: oltre ai nomi (nome_proprio), ogni voce con la maiuscola nelle lingue che scrivono i
-- nomi comuni con la minuscola: aggettivi etnici e di luogo (Romanus, Danish, Παμφυλιακός), avverbi (Graece), cognomi
-- marcati come verbi. Non il tedesco e le lingue che scrivono con la maiuscola tutti i nomi, né le sigle (né il pronome I).
create or replace function nome_con_maiuscola(p_lingua text, p_lemma text, p_pos text) returns boolean
language sql immutable as $$
  select p_pos is not null and p_pos <> 'np' and p_lemma ~ '^-?[[:upper:]]' and p_lemma ~ '[[:lower:]]'   -- non le sigle (CD, USB)
     and p_lingua not in ('de', 'lb', 'gsw', 'bar', 'pdc', 'nds', 'nds-de', 'sxu', 'swg', 'ksh', 'cim', 'mhn', 'vmf', 'hrx',
                          'gmw-cfr', 'gmw-ecg', 'gmw-rfr', 'gmw-msc', 'yi')
     and p_lingua not like 'de-%'
$$;

create or replace function segna_nome_indice() returns trigger language plpgsql as $$
begin
  new.nome_indice := case when nome_con_maiuscola(new.lingua, new.lemma, new.pos) then true end;
  return new;
end $$;

drop trigger if exists lessema_nome_indice on lessema;
create trigger lessema_nome_indice before insert or update of lingua, lemma, pos on lessema
  for each row execute function segna_nome_indice();

-- le voci che ci sono già: solo quelle che cambiano, senza scrivere lo storico (come l'import)
do $$
begin
  perform set_config('app.import', 'on', true);       -- un blocco solo: l'impostazione vale per tutta la transazione
  update lessema set nome_indice = true where nome_con_maiuscola(lingua, lemma, pos) and nome_indice is not true;
  update lessema set nome_indice = null where nome_indice and not nome_con_maiuscola(lingua, lemma, pos);
end $$;
create index if not exists lessema_nome_indice on lessema (lingua, chiave_indice) include (stato_editoriale) where nome_indice;

create or replace function nodo_json(p_id bigint, p_lingua text default 'it', p_anteprima boolean default false) returns jsonb
language sql stable as $$
  select jsonb_build_object('id', x.id, 'slug', x.slug, 'lingua', x.lingua,
           'lingua_nome', coalesce(etichetta_in('lingua', x.lingua, p_lingua), g.nome),
           'lingua_sigla', coalesce(etichetta_in('lingua', x.lingua, p_lingua, 'breve'), g.sigla),
           'ramo', g.ramo, 'lemma', x.lemma, 'ricostruito', x.ricostruito, 'translit', x.translit,
           'nome_proprio', x.nome_proprio or coalesce(x.nome_indice, false),   -- lo stemma nasconde i nomi propri e derivati
           'glossa', coalesce(t.testo, x.glossa),
           'glossa_lingua', case when t.testo is not null then t.lingua else x.glossa_lingua end,
           'glossa_automatica', coalesce(t.provenienza in ('traduzione-automatica', 'claude') and t.stato_editoriale = 'importato', false))
  from lessema x
  join lingua g on g.codice = x.lingua
  left join glossa t on t.lessema_id = x.id and t.accezione_id is null and t.lingua = p_lingua
                    and visibile(t.stato_editoriale, p_anteprima)
  where x.id = p_id
$$;

create or replace function parole_lingua(p_codice text, p_lingua text default 'it', p_anteprima boolean default false, p_iniziale text default null,
                              p_nomi boolean default false, p_pagina int default 1)
returns jsonb language sql stable as $$
-- l'indice per lettere: chiave_indice (le prime due lettere secondo l'alfabeto: 23 latine con J sotto I e U sotto V,
-- 24 greche) e nome_proprio sono colonne generate di lessema, indicizzate; i nomi propri e derivati hanno un indice a parte:
-- i nomi (nome_proprio) e le altre voci con la maiuscola (nome_indice, un indice parziale piccolo)
with
ix as (select ini2, left(ini2, 1) as ini, sum(n) as n from (
         select chiave_indice as ini2, count(*) as n
           from lessema where lingua = p_codice and nome_proprio = p_nomi and chiave_indice is not null
                          and visibile(stato_editoriale, p_anteprima)
          group by chiave_indice
         union all
         select chiave_indice, (case when p_nomi then 1 else -1 end) * count(*)
           from lessema where lingua = p_codice and nome_indice and chiave_indice is not null
                          and visibile(stato_editoriale, p_anteprima)
          group by chiave_indice) x
        group by ini2 having sum(n) > 0),
ini as (select ini, sum(n) as n, (ini !~ '^[[:alpha:]]') as simbolo from ix group by ini),
scelta as (select coalesce(upper(left(p_iniziale, 1)), case when (select sum(n) from ini) <= 400 then null
                                         -- si apre sulla prima iniziale vera: non su una I con una sola parola greca
                                         else (select ini from ini order by simbolo, n * 100 < (select sum(n) from ini), ini
                                                limit 1) end) as v),
-- un'iniziale con più di 2000 parole si sfoglia per le prime due lettere (Αβ, Αγ…): pagine leggere anche per il greco
sotto as (select x.ini2, x.n from ix x, scelta sc where x.ini = sc.v),
scelta2 as (select case when (select sum(n) from sotto) > 2000
                        then coalesce((select ini2 from sotto where ini2 = upper(p_iniziale)),
                                      (select ini2 from sotto order by ini2 like '_-', ini2 limit 1)) end as v),
-- un gruppo con più di 500 voci si divide in pagine, con le parole guida come nei dizionari a stampa (κάβαισος – καθαίρω)
gruppo as (select l.id, l.slug, l.lingua, l.lemma, l.ricostruito, l.translit, l.glossa, l.glossa_lingua,
                  row_number() over (order by l.lemma_norm, l.lemma, l.id) as rn
             from lessema l, scelta sc, scelta2 s2
            where l.lingua = p_codice and l.chiave_indice is not null
              and ((l.nome_proprio = p_nomi and l.nome_indice is not true) or (p_nomi and l.nome_indice))
              and visibile(l.stato_editoriale, p_anteprima)
              and (sc.v is null or left(l.chiave_indice, 1) = sc.v) and (s2.v is null or l.chiave_indice = s2.v)),
pagine as (select (rn - 1) / 500 + 1 as n, (array_agg(lemma order by rn))[1] as da, (array_agg(lemma order by rn desc))[1] as a
             from gruppo group by 1),
pg as (select least(greatest(coalesce(p_pagina, 1), 1), greatest((select max(n) from pagine), 1)) as n),
tot as (select count(*) filter (where not nome_proprio and nome_indice is not true) as parole,
               count(*) filter (where nome_proprio or nome_indice) as nomi
          from lessema where lingua = p_codice and visibile(stato_editoriale, p_anteprima))
select jsonb_build_object(
  'totale', (select case when p_nomi then nomi else parole end from tot),
  'totale_parole', (select parole from tot),
  'totale_nomi', (select nomi from tot),
  'iniziale', (select v from scelta),
  'iniziali', coalesce((select jsonb_agg(jsonb_build_object('iniziale', ini, 'n', n) order by simbolo, ini) from ini), '[]'::jsonb),
  'sottoiniziale', (select v from scelta2),
  'pagina', (select n from pg),
  'pagine', case when (select count(*) from pagine) > 1
                 then (select jsonb_agg(jsonb_build_object('da', da, 'a', a) order by n) from pagine) else '[]'::jsonb end,
  'sottoiniziali', case when (select v from scelta2) is null then '[]'::jsonb
                        else (select jsonb_agg(jsonb_build_object('iniziale', ini2, 'n', n) order by ini2) from sotto) end,
  -- gli stessi campi di nodo_json(), ma la lingua si legge una volta sola
  'parole', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'slug', x.slug, 'lingua', x.lingua,
                          'lingua_nome', g.nome, 'lingua_sigla', g.sigla, 'ramo', g.ramo, 'lemma', x.lemma,
                          'ricostruito', x.ricostruito, 'translit', x.translit, 'glossa', coalesce(t.testo, x.glossa),
                          'glossa_lingua', case when t.testo is not null then t.lingua else x.glossa_lingua end,
                          'glossa_automatica', coalesce(t.provenienza in ('traduzione-automatica', 'claude') and t.stato_editoriale = 'importato', false))
                        order by x.rn)
                        from gruppo x
                        cross join (select coalesce(etichetta_in('lingua', codice, p_lingua), nome) as nome,
                                           coalesce(etichetta_in('lingua', codice, p_lingua, 'breve'), sigla) as sigla, ramo
                                      from lingua where codice = p_codice) g
                        left join glossa t on t.lessema_id = x.id and t.accezione_id is null and t.lingua = p_lingua
                                          and visibile(t.stato_editoriale, p_anteprima)
                       where (x.rn - 1) / 500 + 1 = (select n from pg)), '[]'::jsonb))
$$;

create or replace function elenco_radici(p_lingua text default 'it', p_anteprima boolean default false,
                              p_dichiarate boolean default true, p_pagina int default 1, p_per_pagina int default 100,
                              p_capo_lingua text default null)
returns jsonb language sql stable as $$
-- l'indice delle radici: i capostipiti (di una sola lingua con p_capo_lingua), dalla famiglia più grande; per ciascuno fino a
-- quattro parole della lingua del lettore che ne discendono, le più usate per prime (il rango d'uso vale per la prima voce
-- di una forma, non per gli omografi); e, per scegliere, quanti capostipiti ha ogni lingua
with
fam as (
  select f.capo, f.id from mv_famiglia f
  join lessema c on c.id = f.capo join lessema x on x.id = f.id
  where (p_anteprima or f.pubblico) and visibile(c.stato_editoriale, p_anteprima) and visibile(x.stato_editoriale, p_anteprima)
),
rad as (
  select f.capo as id, count(*) as discendenti, count(distinct x.lingua) as lingue
  from fam f join lessema x on x.id = f.id group by f.capo
),
radd as (
  select r.*, l.lemma, l.lingua
  from rad r join lessema l on l.id = r.id
  where (l.ricostruito or coalesce(l.pos = 'rad.', false)
         or exists (select 1 from ipotesi h where h.esito_id = l.id and h.stato = 'accolta' and h.origine <> 'etimo')) = p_dichiarate
),
scelte as (select * from radd where p_capo_lingua is null or lingua = p_capo_lingua),
pagina as (select * from scelte order by discendenti desc, lemma offset (greatest(p_pagina, 1) - 1) * p_per_pagina limit p_per_pagina),
esempi as (
  select pg.id, (
    select jsonb_agg(e.lemma order by e.rango nulls last, e.prof, e.lemma) from (
      select x.lemma, min(case when x.omografo = 1 then q.rango end) as rango, min(f.profondita) as prof
      from mv_famiglia f join lessema x on x.id = f.id
      left join frequenza q on q.lingua = x.lingua and q.forma = x.lemma
      where f.capo = pg.id and x.id <> pg.id and x.lingua = p_lingua and not x.nome_proprio and x.nome_indice is not true
        and (p_anteprima or f.pubblico) and visibile(x.stato_editoriale, p_anteprima)
      group by x.lemma
      order by rango nulls last, prof, x.lemma limit 4) e) as esempi
  from pagina pg
)
select jsonb_build_object(
  'totale', (select count(*) from scelte),
  'pagina', greatest(p_pagina, 1), 'per_pagina', p_per_pagina, 'capo_lingua', p_capo_lingua,
  'gruppi', coalesce((select jsonb_agg(jsonb_build_object('lingua', g.lingua, 'n', g.n,
                        'nome', coalesce(etichetta_in('lingua', g.lingua, p_lingua), l.nome)) order by g.n desc, g.lingua)
                      from (select lingua, count(*) as n from radd group by lingua) g join lingua l on l.codice = g.lingua), '[]'::jsonb),
  'radici', coalesce((select jsonb_agg(nodo_json(pg.id, p_lingua, p_anteprima) || jsonb_build_object(
      'discendenti', pg.discendenti, 'lingue', pg.lingue, 'esempi', coalesce(e.esempi, '[]'::jsonb)) order by pg.discendenti desc, pg.lemma)
    from pagina pg join esempi e on e.id = pg.id), '[]'::jsonb))
$$;
