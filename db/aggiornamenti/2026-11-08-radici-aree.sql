-- 8 novembre 2026: l'indice delle radici per area di significato. Le aree e le aree delle radici (stesso testo di
-- db/01_schema.sql), l'appoggio e importa_aree() (stesso testo di db/05_import_wiktionary.sql: se cambia lì, si rigenera
-- da lì) e indice_radici() (stesso testo di db/02_logica.sql). Ripetibile senza danni.

-- Le aree di significato dell'indice delle radici (corpo, parentela, movimento…): le assegna Claude dalle glosse
-- (import/definisci.py, lotto «aree»), la redazione può correggerle (provenienza «redazione», che l'import non tocca)
create table if not exists area_semantica (
  codice  text primary key,
  ordine  int not null,
  it      text not null,
  en      text not null
);
insert into area_semantica (codice, ordine, it, en) values
  ('corpo', 1, 'Corpo e salute', 'Body and health'), ('parentela', 2, 'Parentela e persone', 'Kinship and people'),
  ('vita', 3, 'Vita e morte', 'Life and death'), ('sentimenti', 4, 'Sentimenti e volontà', 'Feelings and will'),
  ('mente', 5, 'Percezione e mente', 'Perception and mind'), ('parola', 6, 'Parola', 'Speech'),
  ('movimento', 7, 'Movimento', 'Motion'), ('azione', 8, 'Fare, prendere, dare', 'Doing, taking, giving'),
  ('stato', 9, 'Essere e stare', 'Being and staying'), ('natura', 10, 'Animali e piante', 'Animals and plants'),
  ('elementi', 11, 'Terra, acqua, fuoco e cielo', 'Earth, water, fire and sky'), ('luce', 12, 'Luce e colori', 'Light and colour'),
  ('misura', 13, 'Numeri e misure', 'Numbers and measures'), ('spazio', 14, 'Spazio e tempo', 'Space and time'),
  ('casa', 15, 'Casa, mestieri e cibo', 'Home, crafts and food'), ('societa', 16, 'Società, guerra e sacro', 'Society, war and the sacred'),
  ('qualita', 17, 'Qualità e forme', 'Qualities and shapes'), ('grammatica', 18, 'Pronomi e particelle', 'Pronouns and particles')
on conflict (codice) do update set ordine = excluded.ordine, it = excluded.it, en = excluded.en;

create table if not exists area_radice (
  lessema_id   bigint primary key references lessema on delete cascade,
  area         text not null references area_semantica,
  provenienza  text not null default 'redazione',
  modello      text
);
create index if not exists area_radice_area on area_radice (area);

-- Le aree delle radici dal registro di Claude (dati/aree_radici.tsv.gz: chiave, glossa d'origine, area, -, modello), per
-- differenza; le aree della redazione non si toccano
create unlogged table if not exists stg_area_radice (chiave text, originale text, area text, vuoto text, modello text);

create or replace function importa_aree() returns jsonb
language plpgsql as $$
declare
  nuove int;
  cambiate int;
  tolte int;
begin
  if not exists (select 1 from stg_area_radice) then
    return jsonb_build_object('saltato', 'tabella di appoggio vuota');
  end if;
  drop table if exists cand_ar;
  create temp table cand_ar on commit drop as
    select distinct on (l.id) l.id, s.area, s.modello
      from stg_area_radice s join lessema l on l.id_esterno = s.chiave
     where s.area in (select codice from area_semantica)
     order by l.id;
  create index on cand_ar (id);
  analyze cand_ar;
  delete from area_radice a
   where a.provenienza = 'claude' and not exists (select 1 from cand_ar c where c.id = a.lessema_id);
  get diagnostics tolte = row_count;
  update area_radice a set area = c.area, modello = c.modello
    from cand_ar c where c.id = a.lessema_id and a.provenienza = 'claude' and (a.area, a.modello) is distinct from (c.area, c.modello);
  get diagnostics cambiate = row_count;
  insert into area_radice (lessema_id, area, provenienza, modello)
  select id, area, 'claude', modello from cand_ar on conflict (lessema_id) do nothing;
  get diagnostics nuove = row_count;
  return jsonb_build_object('nuove', nuove, 'cambiate', cambiate, 'tolte', tolte);
end $$;
comment on function importa_aree() is 'Aree di significato delle radici da Claude, per differenza; quelle della redazione non si toccano.';

-- L'indice delle radici per area di significato (8 novembre 2026): le forme ricostruite in cima a una famiglia, di una
-- protolingua. Senza area: per ogni area le radici con più discendenti (p_in_vista), e quante sono. Con un'area: tutte le
-- sue radici in ordine alfabetico, a pagine, con le iniziali. Per ogni radice fino a quattro parole della lingua del
-- lettore che ne discendono, come in elenco_radici().
create or replace function indice_radici(p_lingua text default 'it', p_anteprima boolean default false,
                                         p_capo_lingua text default 'ine-pro', p_area text default null,
                                         p_pagina int default 1, p_per_pagina int default 200, p_in_vista int default 8)
returns jsonb language sql stable as $$
with
capi as (
  select f.capo as id, count(*) as discendenti, count(distinct x.lingua) as lingue
    from mv_famiglia f join lessema c on c.id = f.capo join lessema x on x.id = f.id
   where c.ricostruito and (p_anteprima or f.pubblico)
     and visibile(c.stato_editoriale, p_anteprima) and visibile(x.stato_editoriale, p_anteprima)
   group by f.capo),
tutti as (
  select k.*, l.lemma, l.lingua, coalesce(a.area, '') as area, lower(left(nullif(l.lemma_norm, ''), 1)) as iniziale,
         coalesce(l.lemma_norm, l.lemma) as ordine
    from capi k join lessema l on l.id = k.id left join area_radice a on a.lessema_id = k.id),
scelte as (select * from tutti where lingua = p_capo_lingua),
vista as (
  select * from (
    select s.*, row_number() over (partition by s.area order by s.discendenti desc, s.ordine) as pos
      from scelte s where p_area is null) v
   where pos <= p_in_vista
  union all
  select s.*, 0 from scelte s where s.area = p_area
   order by 1 offset 0),
pagina as (
  select * from vista where p_area is null
  union all
  select * from (select * from vista where p_area is not null order by ordine, lemma
                  offset (greatest(p_pagina, 1) - 1) * p_per_pagina limit p_per_pagina) x),
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
    from pagina pg),
voce as (
  select pg.area, pg.id, pg.discendenti, pg.ordine, pg.lemma,
         nodo_json(pg.id, p_lingua, p_anteprima) || jsonb_build_object('discendenti', pg.discendenti, 'lingue', pg.lingue,
           'esempi', coalesce(e.esempi, '[]'::jsonb), 'area', nullif(pg.area, ''), 'iniziale', pg.iniziale) as j
    from pagina pg join esempi e on e.id = pg.id)
select jsonb_build_object(
  'capo_lingua', p_capo_lingua, 'area', p_area, 'pagina', greatest(p_pagina, 1), 'per_pagina', p_per_pagina,
  'totale', (select count(*) from scelte),
  'gruppi', coalesce((select jsonb_agg(jsonb_build_object('lingua', g.lingua, 'n', g.n,
                        'nome', coalesce(etichetta_in('lingua', g.lingua, p_lingua), l.nome)) order by g.n desc, g.lingua)
                      from (select lingua, count(*) as n from tutti group by lingua) g join lingua l on l.codice = g.lingua), '[]'::jsonb),
  'aree', coalesce((select jsonb_agg(jsonb_build_object('area', x.area, 'n', x.n,
                       'nome', case when p_lingua = 'it' then a.it else a.en end) order by coalesce(a.ordine, 99))
                    from (select area, count(*) as n from scelte group by area) x
                    left join area_semantica a on a.codice = x.area), '[]'::jsonb),
  'iniziali', case when p_area is null then '[]'::jsonb else coalesce((
      select jsonb_agg(jsonb_build_object('iniziale', i.iniziale, 'n', i.n, 'pagina', i.pagina) order by i.iniziale)
        from (select iniziale, count(*) as n,
                     min((rn - 1) / p_per_pagina + 1) as pagina
                from (select iniziale, row_number() over (order by ordine, lemma) as rn from scelte where area = p_area) r
               group by iniziale) i), '[]'::jsonb) end,
  'sezioni', case when p_area is not null then '[]'::jsonb else coalesce((
      select jsonb_agg(jsonb_build_object('area', x.area, 'n', x.n,
                         'nome', case when p_lingua = 'it' then a.it else a.en end,
                         'radici', (select jsonb_agg(v.j order by v.discendenti desc, v.ordine) from voce v where v.area = x.area))
                       order by coalesce(a.ordine, 99))
        from (select area, count(*) as n from scelte group by area) x left join area_semantica a on a.codice = x.area), '[]'::jsonb) end,
  'radici', case when p_area is null then '[]'::jsonb
                 else coalesce((select jsonb_agg(v.j order by v.ordine, v.lemma) from voce v), '[]'::jsonb) end)
$$;
comment on function indice_radici(text, boolean, text, text, int, int, int) is
  'L''indice delle radici ricostruite di una protolingua, per area di significato e, dentro un''area, in ordine alfabetico.';
