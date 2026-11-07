-- L'indice delle radici si sfoglia per lingua della radice (p_capo_lingua) e mostra, sotto ogni radice, alcune parole della
-- lingua del lettore che ne discendono. Copia di elenco_radici() da db/02_logica.sql; la firma cambia, quindi prima si toglie
-- la vecchia (cinque argomenti), che renderebbe ambigue le chiamate.
drop function if exists elenco_radici(text, boolean, boolean, int, int);

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
      where f.capo = pg.id and x.id <> pg.id and x.lingua = p_lingua and not x.nome_proprio
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
