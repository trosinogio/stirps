-- 9 novembre 2026: l'analisi di un testo riconosce più forme. forma_lemma ha la colonna «sostituisce»: la forma è solo
-- una riduzione (dalla = da + la, l' = lo) o una grafia senza accento (piu = più), e l'analisi conta i lemmi a cui
-- rimanda, non la voce omonima; una voce omonima senza etimologia non conta quando la forma ha un lemma (ha: avere).
-- importa_forme() (stesso testo di db/05_import_wiktionary.sql) e analizza_testo() (stesso
-- testo di db/02_logica.sql): se cambiano lì, si rigenerano da lì. Ripetibile senza danni.

alter table forma_lemma add column if not exists sostituisce boolean not null default false;
create unlogged table if not exists stg_forma (lingua text, forma text, lemma text, sostituisce text);
alter table stg_forma add column if not exists sostituisce text;

create or replace function importa_forme() returns jsonb
language plpgsql as $$
declare
  nuove int;
  tolte int;
  cambiate int;
begin
  if not exists (select 1 from stg_forma) then
    return jsonb_build_object('saltato', 'tabella di appoggio vuota');
  end if;
  drop table if exists cand_fo;
  create temp table cand_fo on commit drop as
    select s.lingua, lower(s.forma) as forma, s.lemma, bool_or(coalesce(s.sostituisce, 'f') = 't') as sostituisce
      from stg_forma s
     where s.forma <> '' and s.lemma <> ''
       and exists (select 1 from lessema l where l.lingua = s.lingua and l.lemma = s.lemma and not l.ricostruito)
     group by 1, 2, 3;
  create index on cand_fo (lingua, forma, lemma);
  analyze cand_fo;
  delete from forma_lemma x
   where x.lingua in (select distinct lingua from stg_forma)
     and not exists (select 1 from cand_fo c where c.lingua = x.lingua and c.forma = x.forma and c.lemma = x.lemma);
  get diagnostics tolte = row_count;
  update forma_lemma x set sostituisce = c.sostituisce
    from cand_fo c where c.lingua = x.lingua and c.forma = x.forma and c.lemma = x.lemma and x.sostituisce <> c.sostituisce;
  get diagnostics cambiate = row_count;
  insert into forma_lemma (lingua, forma, lemma, sostituisce) select lingua, forma, lemma, sostituisce from cand_fo
    on conflict do nothing;
  get diagnostics nuove = row_count;
  return jsonb_build_object('nuove', nuove, 'tolte', tolte, 'cambiate', cambiate, 'in_tutto', (select count(*) from forma_lemma));
end $$;
comment on function importa_forme() is 'Forme flesse frequenti e lemmi (forme_it.tsv), per differenza: servono all''analisi di un testo.';

create or replace function analizza_testo(p_lingua text, p_forme text[], p_conteggi int[], p_lang text default 'it',
                               p_anteprima boolean default false)
returns jsonb language sql stable as $$
with recursive
forme as (
  select lower(f) as forma, sum(coalesce(c, 1))::numeric as n
    from unnest(p_forme, p_conteggi) as u(f, c)
   where f is not null and btrim(f) <> ''
   group by 1),
lemmi as (
  select f.forma, fl.lemma from forme f join forma_lemma fl on fl.lingua = p_lingua and fl.forma = f.forma
  union
  select f.forma, f.forma from forme f
   where not exists (select 1 from forma_lemma fl where fl.lingua = p_lingua and fl.forma = f.forma and fl.sostituisce)
     -- una voce omonima senza etimologia non ruba peso al lemma della forma (ha: avere, non la voce ha; sono: essere)
     and (not exists (select 1 from forma_lemma fl where fl.lingua = p_lingua and fl.forma = f.forma)
          or exists (select 1 from lessema l join ipotesi h on h.esito_id = l.id and h.stato = 'accolta'
                      where l.lingua = p_lingua and l.lemma = f.forma and not l.ricostruito))),
voci as (
  select x.forma, l.id, l.lemma, l.slug
    from lemmi x
    join lessema l on l.lingua = p_lingua and l.lemma = x.lemma and not l.ricostruito
                  and visibile(l.stato_editoriale, p_anteprima)),
pesi as (
  select v.id, v.lemma, v.slug, sum(f.n / (select count(*) from voci w where w.forma = v.forma)) as peso
    from voci v join forme f on f.forma = v.forma
   group by v.id, v.lemma, v.slug),
salita (voce, id, prof, lingua, tipo) as (
  select p.id, p.id, 0, p_lingua, null::text from pesi p
  union all
  select s.voce, x.etimo_id, s.prof + 1, coalesce(g.varieta_di, g.codice), x.tipo
    from salita s
    join ipotesi h on h.esito_id = s.id and h.stato = 'accolta' and visibile(h.stato_editoriale, p_anteprima)
    join relazione x on x.ipotesi_id = h.id and x.ordine = 1
    join lessema e on e.id = x.etimo_id
    join lingua g on g.codice = e.lingua
   where s.lingua = p_lingua and s.prof < 12),
uscita as (
  select distinct on (voce) voce, lingua, tipo from salita where lingua <> p_lingua order by voce, prof),
classi as (
  select p.id, p.lemma, p.slug, p.peso, u.lingua,
         case when u.tipo = 'eredita' then 'popolare'
              when u.tipo in ('prestito_dotto', 'semidotto') then 'dotta'
              when u.tipo in ('prestito', 'calco') then 'prestito'
              when u.tipo is not null then 'altro' end as via
    from pesi p left join uscita u on u.voce = p.id),
per_lingua as (
  select c.lingua, sum(c.peso) as peso, count(*) as lemmi,
         jsonb_build_object('popolare', round(coalesce(sum(c.peso) filter (where c.via = 'popolare'), 0), 2),
                            'dotta', round(coalesce(sum(c.peso) filter (where c.via = 'dotta'), 0), 2),
                            'prestito', round(coalesce(sum(c.peso) filter (where c.via = 'prestito'), 0), 2),
                            'altro', round(coalesce(sum(c.peso) filter (where c.via = 'altro'), 0), 2)) as vie,
         (select jsonb_agg(jsonb_build_object('lemma', e.lemma, 'slug', e.slug, 'peso', round(e.peso, 2)) order by e.peso desc, e.lemma)
            from (select * from classi d where d.lingua is not distinct from c.lingua order by d.peso desc, d.lemma limit 8) e) as esempi
    from classi c
   group by c.lingua)
select jsonb_build_object(
  'occorrenze', (select coalesce(sum(n), 0) from forme),
  'forme', (select count(*) from forme),
  'riconosciute', (select coalesce(sum(f.n), 0) from forme f where exists (select 1 from voci v where v.forma = f.forma)),
  'lemmi', (select count(*) from pesi),
  'origini', coalesce((
     select jsonb_agg(jsonb_build_object('codice', p.lingua, 'nome', coalesce(etichetta_in('lingua', p.lingua, p_lang), g.nome),
                                         'ramo', g.ramo, 'peso', round(p.peso, 2), 'lemmi', p.lemmi, 'vie', p.vie,
                                         'esempi', p.esempi) order by p.peso desc)
       from per_lingua p join lingua g on g.codice = p.lingua), '[]'::jsonb),
  'senza_origine', coalesce((
     select jsonb_build_object('peso', round(p.peso, 2), 'lemmi', p.lemmi, 'esempi', p.esempi)
       from per_lingua p where p.lingua is null), jsonb_build_object('peso', 0, 'lemmi', 0, 'esempi', '[]'::jsonb)),
  'sconosciute', coalesce((
     select jsonb_agg(x.forma order by x.n desc, x.forma)
       from (select f.forma, f.n from forme f where not exists (select 1 from voci v where v.forma = f.forma)
              order by f.n desc, f.forma limit 40) x), '[]'::jsonb));
$$;
comment on function analizza_testo(text, text[], int[], text, boolean) is
  'Le parole di un testo per lingua d''origine e via d''ingresso, risalendo le catene accolte (pagina «Analizza un testo»).';
