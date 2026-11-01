-- 1° novembre 2026: latino e greco completi, le pagine delle lingue. Con ventimila parole sotto un'iniziale (Α del
-- greco), oltre le 2000 si sfoglia per le prime due lettere: parole_lingua() restituisce anche sottoiniziali e
-- sottoiniziale. Funzione copiata da db/02_logica.sql. Ripetibile senza danni.
create or replace function parole_lingua(p_codice text, p_lingua text default 'it', p_anteprima boolean default false, p_iniziale text default null)
returns jsonb language sql stable as $$
with
lf as (select l.*, coalesce(nullif(l.lemma_norm, ''), l.lemma) as f
       from lessema l where l.lingua = p_codice and visibile(l.stato_editoriale, p_anteprima)),
-- le prime due lettere: le parole di una lettera sola e quelle come «a priori» o «a-» stanno nel gruppo «A-»
lx as (select l.*, upper(left(l.f, 1)) as ini,
              case when substr(l.f, 2, 1) ~ '^[[:alpha:]]$' then upper(left(l.f, 2)) else upper(left(l.f, 1)) || '-' end as ini2
       from lf l),
ini as (select ini, count(*) as n, (ini !~ '^[[:alpha:]]') as simbolo from lx group by ini),
scelta as (select coalesce(upper(left(p_iniziale, 1)), case when (select count(*) from lx) <= 400 then null
                                         -- si apre sulla prima iniziale vera: non su una I con una sola parola greca
                                         else (select ini from ini order by simbolo, n * 100 < (select count(*) from lx), ini
                                                limit 1) end) as v),
-- un'iniziale con più di 2000 parole si sfoglia per le prime due lettere (Αβ, Αγ…): pagine leggere anche per il greco
sotto as (select x.ini2, count(*) as n from lx x, scelta sc where x.ini = sc.v group by x.ini2),
scelta2 as (select case when (select sum(n) from sotto) > 2000
                        then coalesce((select ini2 from sotto where ini2 = upper(p_iniziale)),
                                      (select ini2 from sotto order by ini2 like '_-', ini2 limit 1)) end as v)
select jsonb_build_object(
  'totale', (select count(*) from lx),
  'iniziale', (select v from scelta),
  'iniziali', coalesce((select jsonb_agg(jsonb_build_object('iniziale', ini, 'n', n) order by simbolo, ini) from ini), '[]'::jsonb),
  'sottoiniziale', (select v from scelta2),
  'sottoiniziali', case when (select v from scelta2) is null then '[]'::jsonb
                        else (select jsonb_agg(jsonb_build_object('iniziale', ini2, 'n', n) order by ini2) from sotto) end,
  'parole', coalesce((select jsonb_agg(nodo_json(x.id, p_lingua, p_anteprima) order by x.lemma_norm, x.lemma)
                        from lx x, scelta sc, scelta2 s2
                       where (sc.v is null or x.ini = sc.v) and (s2.v is null or x.ini2 = s2.v)), '[]'::jsonb))
$$;
