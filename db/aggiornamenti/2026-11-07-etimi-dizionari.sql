-- 7 novembre 2026: le etimologie del Lewis & Short e dell'LSJ (tag <etym>) e l'analisi della forma (prefisso e base) per
-- le voci di latino e greco senza etimologia: la tabella d'appoggio e importa_etimi_dizionari(); importa_dizionari()
-- toglie prima queste etimologie dalle voci del dizionario che vanno via. Stesso testo di db/05_import_wiktionary.sql:
-- se cambia lì, si rigenera da lì. Ripetibile senza danni.

create or replace function importa_dizionari() returns jsonb
language plpgsql as $$
declare
  r jsonb := '{}';
  n int;
begin
  if not exists (select 1 from stg_dizionario) then
    return jsonb_build_object('saltato', 'tabella di appoggio vuota');
  end if;
  perform set_config('app.import', 'on', true);

  -- 1. voci già presenti, se nessuno le ha toccate: glossa e parte del discorso (l'indirizzo non cambia)
  update lessema l
     set glossa = s.glossa, pos = s.pos
    from stg_dizionario s
   where l.id_esterno = s.chiave and l.provenienza = 'perseus' and l.stato_editoriale = 'importato'
     and (l.glossa is distinct from s.glossa or l.pos is distinct from s.pos);
  get diagnostics n = row_count;
  r := r || jsonb_build_object('voci_aggiornate', n);

  -- 2. voci che il pacchetto non ha più (perché ora le ha Wiktionary, o perché il filtro le scarta), se intatte; prima
  --    vanno via le etimologie dei dizionari che le toccano, se nessuno le ha toccate (le rifà importa_etimi_dizionari)
  create temp table d_via on commit drop as
  select l.id from lessema l
   where l.provenienza = 'perseus' and l.stato_editoriale = 'importato'
     and (not exists (select 1 from stg_dizionario s where s.chiave = l.id_esterno)
          or exists (select 1 from lessema w where w.lingua = l.lingua and w.lemma = l.lemma and not w.ricostruito
                                              and w.provenienza <> 'perseus'));
  delete from ipotesi h
   where h.provenienza = 'perseus' and h.stato_editoriale = 'importato'
     and (h.esito_id in (select id from d_via)
          or exists (select 1 from relazione x where x.ipotesi_id = h.id and x.etimo_id in (select id from d_via)))
     and not exists (select 1 from relazione x where x.ipotesi_id = h.id
                      and (x.provenienza <> 'perseus' or x.stato_editoriale <> 'importato'));
  delete from lessema l using d_via v where l.id = v.id and voce_intatta(l.id);
  get diagnostics n = row_count;
  r := r || jsonb_build_object('voci_tolte', n);

  -- 3. lemmi nuovi: non ci sono già, né in Wiktionary con la stessa forma, né nella redazione con la stessa forma
  --    normalizzata (le voci della redazione sono poche: si confrontano in memoria, senza l'indice a trigrammi)
  create temp table d_nuove on commit drop as
  select s.*, slug_di(s.lingua, s.lemma, s.translit, 1, false) as base, norm(s.lemma) as forma
    from stg_dizionario s
   where exists (select 1 from lingua g where g.codice = s.lingua)
     and s.lemma is not null and s.lemma = btrim(s.lemma) and s.lemma <> '' and s.lemma !~ '^\*'
     and not exists (select 1 from lessema l where l.id_esterno = s.chiave)
     and not exists (select 1 from lessema l where l.lingua = s.lingua and l.lemma = s.lemma and not l.ricostruito
                                              and l.provenienza <> 'perseus');
  create temp table d_redazione on commit drop as
    select distinct lingua, lemma_norm from lessema where provenienza not in ('wiktionary', 'perseus');
  analyze d_nuove;
  analyze d_redazione;
  delete from d_nuove d using d_redazione x where x.lingua = d.lingua and x.lemma_norm = d.forma;
  with occupati as (
    select slug_di(l.lingua, l.lemma, l.translit, 1, l.ricostruito) as base, max(l.omografo) as massimo
      from lessema l
     where l.lingua in (select distinct lingua from d_nuove)
     group by 1),
  numerate as (
    select d.*, coalesce(o.massimo, 0)
                + row_number() over (partition by d.base order by d.omografo, d.lemma collate "C", d.chiave collate "C") as numero
      from d_nuove d left join occupati o on o.base = d.base)
  insert into lessema (lingua, lemma, omografo, ricostruito, translit, pos, glossa, glossa_lingua,
                       provenienza, stato_editoriale, id_esterno)
  select lingua, lemma, numero, false, translit, pos, glossa, 'en', 'perseus', 'importato', chiave
    from numerate
  on conflict do nothing;
  get diagnostics n = row_count;
  r := r || jsonb_build_object('voci_nuove', n,
    'voci_dei_dizionari', (select jsonb_object_agg(lingua, quante) from (
        select lingua, count(*) as quante from lessema where provenienza = 'perseus' group by 1) t));
  return r;
end $$;
comment on function importa_dizionari() is 'Lemmi del Lewis & Short e dell’LSJ (Perseus) per le parole che Wiktionary non ha: aggiorna, toglie e aggiunge solo le voci che nessuno ha toccato.';

-- ===== Etimologie dai dizionari del Perseus (7 novembre 2026) =====
-- Il Lewis & Short e l'LSJ scrivono nel tag <etym> la base di molte voci (anguinus: anguis; ἀγυρτάζω: ἀγύρτης), i
-- composti (anguicomus: anguis-coma) e i prefissi (abduco: ab-duco). filtra_perseus.py --etimi li legge; qui diventano
-- ipotesi con la loro fonte, solo per le voci che non hanno altre etimologie, e solo dove esito ed etimi sono voci certe:
-- un lemma con più voci nella sua lingua (caro, tre voci) è ambiguo e resta fuori. Le righe con opera «analisi» vengono da
-- analisi_composti.py (καταδάπτω = κατα- + δάπτω): «Analisi della forma», certezza 2, senza fonte, e solo dove i dizionari
-- non dicono niente.
create unlogged table if not exists stg_etimo_dizionario (
  chiave text, lingua text, lemma text, ordine int, etimo_lingua text, etimo text, tipo text, affisso text, opera text);

create or replace function importa_etimi_dizionari() returns jsonb
language plpgsql as $$
declare
  r jsonb := '{}';
  n int;
begin
  if not exists (select 1 from stg_etimo_dizionario) then
    return jsonb_build_object('saltato', 'tabella di appoggio vuota');
  end if;
  perform set_config('app.import', 'on', true);
  drop table if exists ed_lemmi, ed_righe, ed_voluti, ed_firme, ed_nuove;

  -- 1. le voci di latino e greco per lingua e lemma, con quante sono (una sola: la voce è certa)
  create temp table ed_lemmi on commit drop as
    select l.lingua, l.lemma, min(l.id) as id, count(*) as quante
      from lessema l
     where l.lingua in (select distinct lingua from stg_etimo_dizionario union select distinct etimo_lingua from stg_etimo_dizionario)
       and not l.ricostruito and l.stato_editoriale <> 'superato'
     group by 1, 2;
  alter table ed_lemmi add primary key (lingua, lemma);
  analyze ed_lemmi;

  -- 2. gli etimi voluti: l'esito è la voce del dizionario stessa o l'unica voce con quel lemma, di Wiktionary o del
  --    dizionario (non della redazione); ogni etimo è l'unica voce con il suo lemma. Una voce entra con tutti i suoi
  --    etimi o con nessuno
  create temp table ed_righe on commit drop as
  select s.chiave, s.ordine, s.tipo, s.affisso, s.opera, s.lemma as sv,
         coalesce(p.id, case when el.quante = 1 then el.id end) as esito_id,
         case when et.quante = 1 then et.id end as etimo_id
    from stg_etimo_dizionario s
    left join lessema p on p.id_esterno = regexp_replace(s.chiave, '^analisi:', '')
    left join ed_lemmi el on el.lingua = s.lingua and el.lemma = s.lemma
    left join ed_lemmi et on et.lingua = s.etimo_lingua and et.lemma = s.etimo
   where exists (select 1 from tipo_relazione t where t.codice = s.tipo);
  create index on ed_righe (chiave);
  analyze ed_righe;
  create temp table ed_voluti on commit drop as
  select r.* from ed_righe r
    join (select chiave from ed_righe group by chiave
           having bool_and(esito_id is not null and etimo_id is not null and etimo_id <> esito_id)) ok using (chiave);
  create index on ed_voluti (esito_id, etimo_id);
  analyze ed_voluti;
  -- solo le voci di Wiktionary e dei dizionari senza altre etimologie; per una voce, una sola voce del dizionario
  delete from ed_voluti v using lessema l
   where l.id = v.esito_id
     and (l.provenienza not in ('wiktionary', 'perseus')
          or exists (select 1 from ipotesi h where h.esito_id = v.esito_id and h.provenienza <> 'perseus'));
  delete from ed_voluti v using (
      select distinct on (esito_id) esito_id, chiave as prima from ed_voluti order by esito_id, opera = 'analisi', chiave) m
   where m.esito_id = v.esito_id and v.chiave <> m.prima;
  -- niente cerchi di due passi: l'etimo non deriva già dall'esito
  delete from ed_voluti v
   where exists (select 1 from relazione x where x.esito_id = v.etimo_id and x.etimo_id = v.esito_id)
      or exists (select 1 from ed_voluti y where y.esito_id = v.etimo_id and y.etimo_id = v.esito_id);
  delete from ed_voluti v using (
      select r.chiave from (select chiave, count(*) as n from ed_righe group by 1) r
        join (select chiave, count(*) as n from ed_voluti group by 1) w using (chiave)
       where w.n < r.n) monchi
   where monchi.chiave = v.chiave;
  create temp table ed_firme on commit drop as
  select chiave, min(esito_id) as esito_id, min(opera) as opera, min(sv) as sv,
         string_agg(etimo_id || ':' || tipo || ':' || ordine || ':' || coalesce(affisso, ''), ',' order by ordine, etimo_id) as firma
    from ed_voluti group by chiave;
  alter table ed_firme add primary key (chiave);
  analyze ed_firme;

  -- 3. le etimologie dei dizionari che non servono più o sono cambiate, se nessuno le ha toccate
  delete from ipotesi h
   where h.provenienza = 'perseus' and h.stato_editoriale = 'importato'
     and not exists (
       select 1 from ed_firme f
        where f.chiave = h.id_esterno and f.esito_id = h.esito_id
          and f.firma = (select string_agg(x.etimo_id || ':' || x.tipo || ':' || x.ordine || ':' || coalesce(x.affisso, ''), ','
                                           order by x.ordine, x.etimo_id) from relazione x where x.ipotesi_id = h.id))
     and not exists (select 1 from relazione x where x.ipotesi_id = h.id
                      and (x.provenienza <> 'perseus' or x.stato_editoriale <> 'importato'));
  get diagnostics n = row_count;
  r := r || jsonb_build_object('etimologie_tolte', n);

  -- se l'esito ha ora un'etimologia di Wiktionary, entrata come alternativa accanto a quella del dizionario, torna accolta
  with da_promuovere as (
    select distinct on (h.esito_id) h.id
      from ipotesi h join stg_ipotesi s on s.chiave = h.id_esterno
     where s.stato = 'accolta' and h.stato = 'alternativa'
       and h.provenienza = 'wiktionary' and h.stato_editoriale = 'importato'
       and not exists (select 1 from ipotesi x where x.esito_id = h.esito_id and x.stato = 'accolta')
     order by h.esito_id, h.id)
  update ipotesi h set stato = 'accolta' from da_promuovere p where h.id = p.id;

  -- 4. le nuove: ipotesi accolta, passaggi, e la voce del dizionario come fonte
  create temp table ed_nuove (id bigint, chiave text) on commit drop;
  with ins as (
    insert into ipotesi (esito_id, etichetta, stato, confidenza, origine, provenienza, stato_editoriale, id_esterno)
    select f.esito_id,
           case f.opera when 'LSJ' then 'Liddell–Scott–Jones' when 'analisi' then 'Analisi della forma' else 'Lewis & Short' end,
           'accolta', case when f.opera = 'analisi' then 2 else 3 end, 'etimo', 'perseus', 'importato', f.chiave
      from ed_firme f
     where not exists (select 1 from ipotesi h where h.id_esterno = f.chiave)
       and not exists (select 1 from ipotesi h where h.esito_id = f.esito_id and h.stato = 'accolta')
    on conflict do nothing
    returning id, id_esterno)
  insert into ed_nuove select id, id_esterno from ins;
  get diagnostics n = row_count;
  r := r || jsonb_build_object('etimologie_nuove', n);
  insert into relazione (ipotesi_id, esito_id, etimo_id, tipo, ordine, affisso, confidenza, provenienza, stato_editoriale, id_esterno)
  select e.id, v.esito_id, v.etimo_id, v.tipo, v.ordine, v.affisso, case when v.opera = 'analisi' then 2 else 3 end,
         'perseus', 'importato', v.chiave || '#' || v.ordine
    from ed_nuove e join ed_voluti v on v.chiave = e.chiave
  on conflict do nothing;
  insert into rimando (opera_id, sv, posizione, ipotesi_id)
  select o.id, f.sv, 'propone', e.id
    from ed_nuove e join ed_firme f on f.chiave = e.chiave join opera o on o.sigla = f.opera;
  r := r || jsonb_build_object('etimologie_dei_dizionari', (select jsonb_object_agg(lingua, quante) from (
           select l.lingua, count(*) as quante from ipotesi h join lessema l on l.id = h.esito_id
            where h.provenienza = 'perseus' group by 1) t));
  return r;
end $$;
comment on function importa_etimi_dizionari() is 'Etimologie del Lewis & Short e dell’LSJ (tag <etym>), e l’analisi della forma (prefisso e base), per le voci di latino e greco che non ne hanno altre: scritte solo dove cambiano.';
