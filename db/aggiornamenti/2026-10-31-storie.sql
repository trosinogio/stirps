-- 31 ottobre 2026: storie di parole composte dai dati, sempre nuove. (v5, 7 novembre: una storia «parenti» per coppia,
-- anche quando la coppia sta in due famiglie.)
-- mv_storie raccoglie i candidati (tra le parole italiane d'uso comune) di quattro tipi:
--   due_strade  allotropi: la stessa parola entrata due volte, per via popolare e per via dotta (burro, butirro)
--   parenti     parole della stessa famiglia indoeuropea arrivate per strade diverse (idea, vedere)
--   viaggio     parole passate per lingue di più famiglie o più rami (zero: arabo, latino medievale)
--   famiglia    radici indoeuropee con molte parole italiane d'uso comune
-- storie() ne sceglie alcune a partire da un seme (stesso seme, stesse storie), alternando i tipi;
-- indovinello() prepara un piccolo gioco: chi è parente di chi. Ripetibile senza danni.

-- la vista si ricostruisce solo se la sua definizione è cambiata (il commento ne porta la versione)
do $$
begin
  if to_regclass('mv_storie') is not null
     and coalesce(obj_description(to_regclass('mv_storie'), 'pg_class'), '') <> 'storie v5' then
    drop materialized view mv_storie cascade;
  end if;
end $$;

create materialized view if not exists mv_storie as
with recursive
-- parole italiane d'uso comune: la forma è tra le prime 30.000 per frequenza
comuni as (
  select l.id, min(f.rango) as rango
    from lessema l join frequenza f on f.lingua = 'it' and f.forma = l.lemma
   where l.lingua = 'it' and l.omografo = 1 and l.stato_editoriale <> 'superato' and f.rango <= 30000
   group by l.id
),
-- archi sospetti: una forma ricostruita che «discende» da una lingua di un'altra famiglia (*mewHdʰ- dall'egiziano)
-- è un confronto letto come origine; le storie non li seguono
sospetti as (
  select a.esito_id, a.etimo_id from arco a
    join lessema x on x.id = a.esito_id and x.ricostruito join lingua gx on gx.codice = x.lingua
    join lessema e on e.id = a.etimo_id join lingua ge on ge.codice = e.lingua
   where a.stato_ipotesi = 'accolta' and ge.famiglia is distinct from gx.famiglia
),
-- i loro antenati lungo le ipotesi accolte
su (parola, id, prof, pubblico) as (
  select c.id, c.id, 0, true from comuni c
  union
  select s.parola, a.etimo_id, s.prof + 1, s.pubblico and a.pubblico
    from su s join arco a on a.esito_id = s.id and a.stato_ipotesi = 'accolta' and a.categoria <> 'influsso'
                         and a.confidenza >= 3           -- le storie seguono solo i passaggi sicuri o probabili
   where s.prof < 12 and not exists (select 1 from sospetti z where z.esito_id = a.esito_id and z.etimo_id = a.etimo_id)
),
antenati as (
  select parola, id, max(prof) as prof, bool_and(pubblico) as pubblico from su where prof > 0 group by 1, 2
),
-- per ogni parola: le lingue, le famiglie e i rami non italici (attestati) che ha attraversato
profilo as (
  select a.parola,
         array_agg(distinct l.lingua) as lingue,
         coalesce(array_agg(distinct g.famiglia) filter (where g.famiglia is not null), '{}') as famiglie,
         coalesce(array_agg(distinct g.ramo) filter (where g.ramo is not null and g.ramo <> 'italica' and not g.ricostruita), '{}') as vie,
         count(distinct l.lingua) filter (where not g.ricostruita) as attestate,
         bool_and(a.pubblico) as pubblico
    from antenati a join lessema l on l.id = a.id join lingua g on g.codice = l.lingua
   group by a.parola
),
-- le famiglie indoeuropee, con le parole d'uso comune più frequenti
fam as (
  select f.capo, f.id, c.rango, coalesce(p.vie, '{}') as vie, f.pubblico and coalesce(p.pubblico, true) as pubblico,
         row_number() over (partition by f.capo order by c.rango) as n
    from mv_famiglia f
    join lessema r on r.id = f.capo and r.lingua = 'ine-pro'
    join comuni c on c.id = f.id
    join antenati ac on ac.parola = f.id and ac.id = f.capo      -- la radice si raggiunge per passaggi sicuri
    left join profilo p on p.parola = f.id
),
coppie as (
  select a.capo, a.id as a_id, b.id as b_id, a.rango + b.rango as peso, a.vie as via_a, b.vie as via_b,
         a.pubblico and b.pubblico as pubblico,
         row_number() over (partition by a.capo order by a.rango + b.rango) as k
    from fam a
    join fam b on b.capo = a.capo and b.id > a.id and a.vie is distinct from b.vie
    join lessema la on la.id = a.id
    join lessema lb on lb.id = b.id
   where a.n <= 25 and b.n <= 25 and left(la.lemma_norm, 3) <> left(lb.lemma_norm, 3)
     and not exists (select 1 from antenati x where x.parola = a.id and x.id = b.id)
     and not exists (select 1 from antenati x where x.parola = b.id and x.id = a.id)
     and not exists (select 1 from mv_allotropi m join lessema t on t.id = m.antenato and not t.ricostruito
                      where least(m.a_id, m.b_id) = a.id and greatest(m.a_id, m.b_id) = b.id)
)
select 'due_strade'::text as tipo, 'due:' || m.a_id || '-' || m.b_id as chiave,
       round(100000.0 / (ca.rango + cb.rango), 3) as punteggio, not m.solo_anteprima as pubblico,
       jsonb_build_object('a', m.a_id, 'b', m.b_id, 'antenato', m.antenato) as dati
  from mv_allotropi m join comuni ca on ca.id = m.a_id join comuni cb on cb.id = m.b_id
  join lessema t on t.id = m.antenato and not t.ricostruito
  join lessema la on la.id = m.a_id join lessema lb on lb.id = m.b_id
 where m.a_id < m.b_id and length(la.lemma) >= 4 and length(lb.lemma) >= 4
   and exists (select 1 from antenati x where x.parola = m.a_id and x.id = m.antenato)
   and exists (select 1 from antenati x where x.parola = m.b_id and x.id = m.antenato)
   and regexp_replace(la.lemma, '[aeiou]$', '') <> regexp_replace(lb.lemma, '[aeiou]$', '')   -- esso, essa: forme, non strade
union all
-- una coppia può stare in due famiglie (un composto ha due radici): una storia sola, con la prima radice
select * from (
  select distinct on (c.a_id, c.b_id) 'parenti', 'parenti:' || c.a_id || '-' || c.b_id, round(100000.0 / c.peso, 3), c.pubblico,
         jsonb_build_object('radice', c.capo, 'a', c.a_id, 'b', c.b_id)
    from coppie c where c.k <= 5
   order by c.a_id, c.b_id, c.capo) parenti_una_volta
union all
select 'viaggio', 'viaggio:' || p.parola,
       round(cardinality(p.famiglie) * 10 + cardinality(p.vie) * 5 + p.attestate * 2 - c.rango / 10000.0, 3), p.pubblico,
       jsonb_build_object('parola', p.parola,
                          'origine', (select a.id from antenati a where a.parola = p.parola order by a.prof desc, a.id limit 1))
  from profilo p join comuni c on c.id = p.parola
 where (cardinality(p.famiglie) >= 2 or cardinality(p.vie) >= 2 or p.attestate >= 5) and cardinality(p.lingue) >= 4
union all
select 'famiglia', 'famiglia:' || f.capo, count(*), bool_and(f.pubblico),
       jsonb_build_object('radice', f.capo, 'n', count(*), 'parole', (array_agg(f.id order by f.rango))[1:12])
  from fam f
 group by f.capo having count(*) >= 8;

comment on materialized view mv_storie is 'storie v5';
create unique index if not exists mv_storie_chiave on mv_storie (chiave);
create index if not exists mv_storie_tipo on mv_storie (tipo, punteggio desc);

-- il percorso da una parola a un suo antenato, dal più antico alla parola: ogni nodo porta il tipo del passaggio
-- verso la parola successiva e la prima attestazione, per la linea del tempo
create or replace function percorso_json(p_da bigint, p_a bigint, p_lingua text default 'it', p_anteprima boolean default false)
returns jsonb language sql stable as $$
  with recursive su (id, cammino, tipi) as (
    select p_da, array[p_da], array[]::text[]
    union all
    select a.etimo_id, s.cammino || a.etimo_id, s.tipi || a.tipo
      from su s join arco a on a.esito_id = s.id and a.stato_ipotesi = 'accolta' and a.categoria <> 'influsso'
                           and (p_anteprima or a.pubblico)
     where cardinality(s.cammino) < 14 and s.id <> p_a and not a.etimo_id = any(s.cammino)
  ),
  migliore as (select cammino, tipi from su where id = p_a order by cardinality(cammino) limit 1)
  select coalesce((
    select jsonb_agg(nodo_json(x.id, p_lingua, p_anteprima)
                     || jsonb_build_object(
                          'tipo', case when x.i > 1 then m.tipi[x.i - 1] end,
                          'tipo_nome', case when x.i > 1 then etichetta_in('tipo_relazione', m.tipi[x.i - 1], p_lingua, 'breve') end,
                          'attestata', (select jsonb_build_object('anno_da', t.anno_da, 'anno_a', t.anno_a, 'precisione', t.precisione)
                                          from attestazione t where t.lessema_id = x.id and visibile(t.stato_editoriale, p_anteprima)
                                         order by t.anno_da limit 1))
                     order by x.i desc)
      from migliore m, unnest(m.cammino) with ordinality as x(id, i)), '[]'::jsonb);
$$;

-- una storia pronta per l'interfaccia: i nodi e i percorsi, secondo il tipo
create or replace function storia_json(p_tipo text, p_chiave text, p_dati jsonb, p_lingua text default 'it', p_anteprima boolean default false)
returns jsonb language sql stable as $$
  select jsonb_build_object('tipo', p_tipo, 'chiave', p_chiave) || case p_tipo
    when 'due_strade' then jsonb_build_object(
      'antenato', nodo_json((p_dati->>'antenato')::bigint, p_lingua, p_anteprima),
      'a', percorso_json((p_dati->>'a')::bigint, (p_dati->>'antenato')::bigint, p_lingua, p_anteprima),
      'b', percorso_json((p_dati->>'b')::bigint, (p_dati->>'antenato')::bigint, p_lingua, p_anteprima))
    when 'parenti' then jsonb_build_object(
      'radice', nodo_json((p_dati->>'radice')::bigint, p_lingua, p_anteprima),
      'a', percorso_json((p_dati->>'a')::bigint, (p_dati->>'radice')::bigint, p_lingua, p_anteprima),
      'b', percorso_json((p_dati->>'b')::bigint, (p_dati->>'radice')::bigint, p_lingua, p_anteprima))
    when 'viaggio' then jsonb_build_object(
      'percorso', percorso_json((p_dati->>'parola')::bigint, (p_dati->>'origine')::bigint, p_lingua, p_anteprima))
    when 'famiglia' then jsonb_build_object(
      'radice', nodo_json((p_dati->>'radice')::bigint, p_lingua, p_anteprima),
      'n', (p_dati->>'n')::int,
      'parole', (select jsonb_agg(nodo_json(x::bigint, p_lingua, p_anteprima) order by i)
                   from jsonb_array_elements_text(p_dati->'parole') with ordinality as e(x, i)))
    else '{}'::jsonb end;
$$;

-- p_n storie a partire da un seme: tra le migliori 300 di ogni tipo, in un ordine che dipende dal seme, alternando i tipi
create or replace function storie(p_lingua text default 'it', p_seme bigint default 0, p_n int default 8,
                                  p_tipo text default null, p_anteprima boolean default false)
returns jsonb language sql stable as $$
  with migliori as (
    select s.*, row_number() over (partition by s.tipo order by s.punteggio desc, s.chiave) as r
      from mv_storie s where (p_anteprima or s.pubblico) and (p_tipo is null or s.tipo = p_tipo)
  ),
  mescolate as (
    select m.*, md5(m.chiave || ':' || p_seme) as caso,
           row_number() over (partition by m.tipo order by md5(m.chiave || ':' || p_seme)) as giro
      from migliori m where m.r <= 300
  ),
  scelte as (select * from mescolate order by giro, caso limit greatest(p_n, 0))
  select coalesce(jsonb_agg(storia_json(s.tipo, s.chiave, s.dati, p_lingua, p_anteprima) order by s.giro, s.caso), '[]'::jsonb)
    from scelte s;
$$;

-- il gioco: una parola, il suo parente vero e due parole d'uso comune che non lo sono
create or replace function indovinello(p_lingua text default 'it', p_seme bigint default 0, p_anteprima boolean default false)
returns jsonb language sql stable as $$
  with storia as (
    select s.dati from mv_storie s
     where s.tipo = 'parenti' and (p_anteprima or s.pubblico)
     order by md5(s.chiave || ':gioco:' || p_seme) limit 1
  ),
  parola as (select (dati->>'a')::bigint as a, (dati->>'b')::bigint as b, (dati->>'radice')::bigint as radice from storia),
  esclusi as (select f.id from mv_famiglia f join parola p on f.capo = p.radice),
  sbagliate as (
    select l.id from lessema l join frequenza f on f.lingua = 'it' and f.forma = l.lemma
     where l.lingua = 'it' and l.omografo = 1 and f.rango between 300 and 6000 and length(l.lemma) >= 4
       and not exists (select 1 from esclusi e where e.id = l.id)
       and exists (select 1 from arco a where a.esito_id = l.id and a.stato_ipotesi = 'accolta')
     order by md5(l.id || ':' || p_seme) limit 2
  )
  select case when not exists (select 1 from parola) then null else jsonb_build_object(
    'parola', nodo_json(p.a, p_lingua, p_anteprima),
    'giusta', nodo_json(p.b, p_lingua, p_anteprima),
    'sbagliate', (select jsonb_agg(nodo_json(s.id, p_lingua, p_anteprima)) from sbagliate s),
    'radice', nodo_json(p.radice, p_lingua, p_anteprima),
    'percorso_parola', percorso_json(p.a, p.radice, p_lingua, p_anteprima),
    'percorso_giusta', percorso_json(p.b, p.radice, p_lingua, p_anteprima)) end
    from parola p;
$$;
