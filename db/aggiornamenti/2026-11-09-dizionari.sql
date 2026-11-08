-- 9 novembre 2026: importa_dizionari() toglie le etimologie dei dizionari solo delle voci che se ne vanno davvero. Una
-- voce del Perseus che il pacchetto non ha più, ma che una catena di Wiktionary usa (orbatio, etimo dell'inglese
-- orbation) o che la redazione ha toccato, resta con le sue etimologie: prima si toglievano e importa_etimi_dizionari()
-- le rimetteva uguali a ogni import (576 ipotesi riscritte). Stesso testo di db/05_import_wiktionary.sql: se cambia lì,
-- si rigenera da lì. Ripetibile senza danni.

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
  drop table if exists d_via, d_vere;
  create temp table d_via on commit drop as
  select l.id from lessema l
   where l.provenienza = 'perseus' and l.stato_editoriale = 'importato'
     and (not exists (select 1 from stg_dizionario s where s.chiave = l.id_esterno)
          or exists (select 1 from lessema w where w.lingua = l.lingua and w.lemma = l.lemma and not w.ricostruito
                                              and w.provenienza <> 'perseus'));
  -- solo le voci che se ne vanno davvero perdono le etimologie: una voce che una catena di Wiktionary usa (orbatio,
  -- etimo dell'inglese orbation) o che la redazione ha toccato resta, e le sue etimologie con lei; prima si toglievano
  -- e importa_etimi_dizionari le rimetteva uguali a ogni import (576 ipotesi riscritte)
  create temp table d_vere on commit drop as
  select v.id from d_via v
   where not exists (select 1 from relazione x join ipotesi h on h.id = x.ipotesi_id
                      where (x.etimo_id = v.id or x.esito_id = v.id)
                        and not (h.provenienza = 'perseus' and h.stato_editoriale = 'importato'
                                 and x.provenienza = 'perseus' and x.stato_editoriale = 'importato'))
     and not exists (select 1 from ipotesi h where h.esito_id = v.id
                      and not (h.provenienza = 'perseus' and h.stato_editoriale = 'importato'))
     and not exists (select 1 from attestazione a where a.lessema_id = v.id)
     and not exists (select 1 from accezione c where c.lessema_id = v.id)
     and not exists (select 1 from connessione c where c.da_id = v.id or c.a_id = v.id)
     and not exists (select 1 from rimando m where m.lessema_id = v.id)
     and not exists (select 1 from glossa g where g.lessema_id = v.id
                      and not (g.provenienza in ('wikizionario', 'wikidata', 'traduzione-automatica')
                               and g.stato_editoriale = 'importato'));
  delete from ipotesi h
   where h.provenienza = 'perseus' and h.stato_editoriale = 'importato'
     and (h.esito_id in (select id from d_vere)
          or exists (select 1 from relazione x where x.ipotesi_id = h.id and x.etimo_id in (select id from d_vere)))
     and not exists (select 1 from relazione x where x.ipotesi_id = h.id
                      and (x.provenienza <> 'perseus' or x.stato_editoriale <> 'importato'));
  delete from lessema l using d_vere v where l.id = v.id and voce_intatta(l.id);
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
