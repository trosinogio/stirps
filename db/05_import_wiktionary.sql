-- =====================================================================
--  Dizionario etimologico — import da Wiktionary (via Kaikki/wiktextract)
--  Si esegue dopo 01–03. Il caricamento completo lo fa import/importa.sh:
--  scarica, filtra, analizza, carica le tabelle di appoggio, poi chiama
--  importa_wiktionary(). Si può rilanciare: è idempotente.
--
--  Regole di fusione
--  - Tutto entra come strato «wiktionary» (CC BY-SA 4.0), stato «importato».
--  - I record di redazione non si toccano mai; quelli importati che un
--    redattore ha portato a «rivisto» o «verificato» neppure.
--  - Se una parola ha già un'ipotesi accolta, quella di Wiktionary entra
--    come alternativa: la redazione prevale.
--  - Un'«eredità» tra lingue che non stanno in linea genealogica diventa
--    filiazione indeterminata.
--  - I lemmi dei dizionari del Perseus (Lewis & Short, LSJ) entrano come
--    strato «perseus» solo dove Wiktionary non ha la parola (importa_dizionari,
--    in fondo); quando Wiktionary la aggiunge, la voce del dizionario le cede
--    il posto, se nessuno l'ha toccata.
--  - Si scrive solo ciò che cambia: le righe uguali restano dove sono, perché
--    ogni riga riscritta occupa spazio fino al vacuum.
-- =====================================================================

create unlogged table if not exists stg_lingua (
  codice text primary key, nome_it text, sigla_it text, nome_en text, sigla_en text,
  famiglia text, ramo text, antenato text, varieta_di text, ricostruita boolean, lat numeric, lon numeric);
create unlogged table if not exists stg_lessema (
  chiave text primary key, lingua text, lemma text, omografo int, ricostruito boolean, translit text, pos text, glossa text);
create unlogged table if not exists stg_ipotesi (
  chiave text primary key, esito text, etichetta text, stato stato_ipotesi, confidenza int, origine origine_tipo, nota text);
create unlogged table if not exists stg_relazione (
  chiave text primary key, ipotesi text, esito text, etimo text, tipo text, ordine int, forma text, affisso text, confidenza int);
create unlogged table if not exists stg_doppione (a text, b text);
create unlogged table if not exists stg_radice (lessema text, radice text);
create unlogged table if not exists stg_attestazione (
  chiave text primary key, lessema text, anno_da int, anno_a int, precisione precisione_data);
-- glosse italiane dal Wikizionario: una per parola, lingua e parte del discorso (ordine = posizione della voce)
create unlogged table if not exists stg_wikizionario (lingua text, parola text, pos text, ordine int, glossa text);
create index if not exists stg_wikizionario_parola on stg_wikizionario (lingua, parola);

-- Una voce importata che nessuno ha toccato: senza passaggi, ipotesi, attestazioni, accezioni, connessioni, rimandi
-- e glosse della redazione (le glosse importate non contano). Solo una voce così si può togliere a un nuovo import.
create or replace function voce_intatta(p_id bigint) returns boolean
language sql stable as $$
  select not exists (select 1 from relazione x where x.etimo_id = p_id or x.esito_id = p_id)
     and not exists (select 1 from ipotesi h where h.esito_id = p_id)
     and not exists (select 1 from attestazione a where a.lessema_id = p_id)
     and not exists (select 1 from accezione c where c.lessema_id = p_id)
     and not exists (select 1 from connessione c where c.da_id = p_id or c.a_id = p_id)
     and not exists (select 1 from rimando m where m.lessema_id = p_id)
     and not exists (select 1 from glossa g where g.lessema_id = p_id
                      and not (g.provenienza in ('wikizionario', 'wikidata', 'traduzione-automatica')
                               and g.stato_editoriale = 'importato'))
$$;

create or replace function importa_wiktionary() returns jsonb
language plpgsql as $$
declare
  r jsonb := '{}'::jsonb;
  n int;
  n2 int;
  rec record;
  omo int;
  nuovo bigint;
  t0 timestamptz := clock_timestamp();
begin
  -- storico e controllo dei cicli per riga sospesi in questa transazione
  perform set_config('app.import', 'on', true);

  -- 1. lingue nuove, con genealogia e nome inglese
  insert into lingua (codice, nome, sigla, famiglia, ramo, ricostruita, lat, lon)
  select s.codice, coalesce(s.nome_it, s.codice), coalesce(s.sigla_it, s.codice), s.famiglia, s.ramo,
         coalesce(s.ricostruita, false), s.lat, s.lon
    from stg_lingua s
   where not exists (select 1 from lingua l where l.codice = s.codice);
  get diagnostics n = row_count;
  r := r || jsonb_build_object('lingue_nuove', n);
  update lingua l set antenato = s.antenato
    from stg_lingua s
   where l.codice = s.codice and l.antenato is null and s.antenato is not null and s.antenato <> l.codice
     and exists (select 1 from lingua x where x.codice = s.antenato);
  update lingua l set varieta_di = s.varieta_di
    from stg_lingua s
   where l.codice = s.codice and l.varieta_di is null and l.antenato is null and s.varieta_di is not null
     and s.varieta_di <> l.codice and exists (select 1 from lingua x where x.codice = s.varieta_di);
  update lingua l set famiglia = coalesce(l.famiglia, p.famiglia), ramo = coalesce(l.ramo, p.ramo)
    from lingua p
   where l.varieta_di = p.codice and (l.famiglia is null or l.ramo is null);
  insert into etichetta_lingua (vocabolario, codice, lingua, etichetta, breve)
  select 'lingua', s.codice, 'en', coalesce(s.nome_en, s.codice), s.sigla_en from stg_lingua s
  on conflict do nothing;

  -- 2. lessemi: prima quelli già noti, poi i nuovi.
  -- Le voci dei dizionari (Perseus) che nessuno ha toccato cedono il posto quando Wiktionary ha la stessa parola:
  -- così la voce di Wiktionary prende il suo indirizzo. Quelle toccate restano, e Wiktionary le abbina per forma esatta
  delete from lessema l
   using stg_lessema s
   where s.lingua = l.lingua and s.lemma = l.lemma and not s.ricostruito
     and l.provenienza = 'perseus' and l.stato_editoriale = 'importato' and voce_intatta(l.id);
  get diagnostics n = row_count;
  r := r || jsonb_build_object('voci_dei_dizionari_cedute', n);
  create temp table m_les (chiave text primary key, id bigint not null) on commit drop;
  insert into m_les select s.chiave, l.id from stg_lessema s join lessema l on l.id_esterno = s.chiave;
  insert into m_les
  select s.chiave, l.id from stg_lessema s
    join lessema l on l.lingua = s.lingua and l.lemma = s.lemma and l.omografo = s.omografo
   where not exists (select 1 from m_les m where m.chiave = s.chiave)
  on conflict do nothing;
  -- la stessa parola registrata in una varietà (lat. mediev. zephirum) o nella lingua madre (lat. zephirum)
  insert into m_les
  select s.chiave, min(l.id) from stg_lessema s
    join lingua gs on gs.codice = s.lingua
    join lessema l on l.lemma_norm = norm(s.lemma) and l.omografo = s.omografo
    join lingua gl on gl.codice = l.lingua
   where not exists (select 1 from m_les m where m.chiave = s.chiave)
     and l.lingua <> s.lingua and (gl.varieta_di = s.lingua or gs.varieta_di = l.lingua)
     and (l.provenienza not in ('wiktionary', 'perseus') or l.lemma = s.lemma)
   group by s.chiave having count(*) = 1
  on conflict do nothing;
  -- la forma normalizzata (senza maiuscole né accenti) abbina solo le voci della redazione, scritte a mano:
  -- tra voci di Wiktionary e dei dizionari maiuscola e accento distinguono parole diverse (Τύρος, la città;
  -- τυρός, il formaggio)
  insert into m_les
  select s.chiave, min(l.id) from stg_lessema s
    join lessema l on l.lingua = s.lingua and l.lemma_norm = norm(s.lemma) and l.omografo = s.omografo
   where not exists (select 1 from m_les m where m.chiave = s.chiave)
     and l.provenienza not in ('wiktionary', 'perseus')
   group by s.chiave having count(*) = 1
  on conflict do nothing;
  -- una voce dei dizionari rimasta perché la redazione l'ha toccata: Wiktionary la abbina per lingua e lemma, se da
  -- tutte e due le parti la forma è una sola (il numero d'omografo può essere diverso: Carus² accanto a carus)
  insert into m_les
  select s.chiave, min(l.id) from stg_lessema s
    join lessema l on l.lingua = s.lingua and l.lemma = s.lemma and l.provenienza = 'perseus'
   where not exists (select 1 from m_les m where m.chiave = s.chiave) and not s.ricostruito
   group by s.chiave
  having count(*) = 1
     and (select count(*) from stg_lessema s2 where s2.lingua = s.lingua and s2.lemma = s.lemma) = 1
  on conflict do nothing;
  get diagnostics n = row_count;
  select count(*) into n2 from m_les;
  r := r || jsonb_build_object('lessemi_gia_presenti', n2);

  -- se più righe di Wiktionary portano alla stessa voce, vale quella della voce stessa (id_esterno), poi la prima:
  -- sempre la stessa, così un nuovo import non riscrive la voce
  create temp table m_scelta on commit drop as
    select distinct on (m.id) m.id, s.glossa, s.pos, s.translit
      from m_les m join stg_lessema s on s.chiave = m.chiave join lessema x on x.id = m.id
     order by m.id, (s.chiave = x.id_esterno) desc, s.chiave collate "C";
  update lessema l
     set glossa = coalesce(s.glossa, l.glossa), pos = coalesce(s.pos, l.pos)
    from m_scelta s
   where l.id = s.id and l.provenienza = 'wiktionary' and l.stato_editoriale = 'importato'
     and (l.glossa is distinct from coalesce(s.glossa, l.glossa) or l.pos is distinct from coalesce(s.pos, l.pos));
  get diagnostics n = row_count;
  r := r || jsonb_build_object('lessemi_aggiornati', n);
  -- la traslitterazione cambia l'indirizzo: si aggiorna solo se il nuovo indirizzo è libero (un doppione superato
  -- può ancora occuparlo; lo toglie pulisci_wiktionary(), che poi completa l'aggiornamento)
  update lessema l
     set translit = s.translit
    from m_scelta s
   where l.id = s.id and l.provenienza = 'wiktionary' and l.stato_editoriale = 'importato'
     and s.translit is not null and l.translit is distinct from s.translit
     and not exists (select 1 from lessema y where y.id <> l.id
                      and y.slug = slug_di(l.lingua, l.lemma, s.translit, l.omografo, l.ricostruito));

  with ins as (
    insert into lessema (lingua, lemma, omografo, ricostruito, translit, pos, glossa, glossa_lingua,
                         provenienza, stato_editoriale, id_esterno)
    select s.lingua, s.lemma, s.omografo, s.ricostruito, s.translit, s.pos, s.glossa, 'en',
           'wiktionary', 'importato', s.chiave
      from stg_lessema s
     where not exists (select 1 from m_les m where m.chiave = s.chiave)
       and s.lemma is not null and s.lemma = btrim(s.lemma) and s.lemma <> '' and s.lemma !~ '^\*'
    on conflict do nothing
    returning id, id_esterno)
  insert into m_les select id_esterno, id from ins;
  get diagnostics n = row_count;
  r := r || jsonb_build_object('lessemi_nuovi', n);

  -- indirizzi già occupati da una parola diversa: si passa all'omografo successivo
  n := 0;
  for rec in select s.* from stg_lessema s
              where not exists (select 1 from m_les m where m.chiave = s.chiave)
                and s.lemma is not null and s.lemma = btrim(s.lemma) and s.lemma <> '' and s.lemma !~ '^\*' loop
    omo := rec.omografo;
    loop
      omo := omo + 1;
      exit when omo > rec.omografo + 9;
      begin
        insert into lessema (lingua, lemma, omografo, ricostruito, translit, pos, glossa, glossa_lingua,
                             provenienza, stato_editoriale, id_esterno)
        values (rec.lingua, rec.lemma, omo, rec.ricostruito, rec.translit, rec.pos, rec.glossa, 'en',
                'wiktionary', 'importato', rec.chiave)
        returning id into nuovo;
        insert into m_les values (rec.chiave, nuovo);
        n := n + 1;
        exit;
      exception when unique_violation then
        null;
      end;
    end loop;
  end loop;
  r := r || jsonb_build_object('omografi_creati', n);

  -- 3. ipotesi: la redazione prevale, Wiktionary entra come alternativa
  -- ipotesi importate rimaste attaccate alla voce sbagliata (un abbinamento troppo largo di un import precedente):
  -- se nessuno le ha toccate si tolgono, e più sotto si ricreano sulla voce giusta
  delete from ipotesi h
   using stg_ipotesi s, m_les le
   where h.id_esterno = s.chiave and le.chiave = s.esito and h.esito_id <> le.id
     and h.provenienza = 'wiktionary' and h.stato_editoriale = 'importato'
     and not exists (select 1 from rimando m where m.ipotesi_id = h.id)
     and not exists (select 1 from relazione x where x.ipotesi_id = h.id
                      and (x.provenienza <> 'wiktionary' or x.stato_editoriale <> 'importato'));
  get diagnostics n = row_count;
  r := r || jsonb_build_object('ipotesi_spostate', n);
  create temp table m_ip (chiave text primary key, id bigint not null) on commit drop;
  insert into m_ip select s.chiave, h.id from stg_ipotesi s join ipotesi h on h.id_esterno = s.chiave;
  update ipotesi h
     set stato = v.stato, confidenza = v.confidenza, origine = v.origine, nota = v.nota, nota_lingua = 'en'
    from (select h2.id,
                 case when s.stato = 'accolta' and exists (select 1 from ipotesi x where x.esito_id = h2.esito_id
                                                                                     and x.stato = 'accolta' and x.id <> h2.id)
                      then 'alternativa'::stato_ipotesi else s.stato end as stato,
                 s.confidenza, s.origine, s.nota
            from stg_ipotesi s join m_ip m on m.chiave = s.chiave join ipotesi h2 on h2.id = m.id
           where h2.provenienza = 'wiktionary' and h2.stato_editoriale = 'importato') v
   where h.id = v.id
     and (h.stato, h.confidenza, h.origine, h.nota, h.nota_lingua)
         is distinct from (v.stato, v.confidenza, v.origine, v.nota, 'en');
  get diagnostics n = row_count;
  r := r || jsonb_build_object('ipotesi_aggiornate', n);

  with ins as (
    insert into ipotesi (esito_id, etichetta, stato, confidenza, origine, nota, nota_lingua, provenienza, stato_editoriale, id_esterno)
    select le.id, s.etichetta,
           case when s.stato = 'accolta' and exists (select 1 from ipotesi x where x.esito_id = le.id and x.stato = 'accolta')
                then 'alternativa'::stato_ipotesi else s.stato end,
           s.confidenza, s.origine, s.nota, 'en', 'wiktionary', 'importato', s.chiave
      from stg_ipotesi s join m_les le on le.chiave = s.esito
     where not exists (select 1 from m_ip m where m.chiave = s.chiave)
    on conflict do nothing
    returning id, id_esterno)
  insert into m_ip select id_esterno, id from ins;
  select count(*) into n from m_ip;
  select count(*) into n2 from ipotesi h join m_ip m on m.id = h.id where h.stato = 'alternativa';
  r := r || jsonb_build_object('ipotesi', n, 'ipotesi_alternative', n2);

  -- 4. archi: si rinfrescano solo quelli delle ipotesi ancora «importato». Un'ipotesi che la redazione ha
  --    rivisto o verificato resta com'è, con tutti i suoi archi, anche quelli che nessuno ha toccato.
  --    Per differenza: si tolgono gli archi importati che Wiktionary non dà più (o dà diversi) e si aggiungono i nuovi
  create temp table asc_l on commit drop as
    select l.codice, a.a as ascendente from lingua l cross join lateral lingue_ascendenti(l.codice) as a(a);
  create index on asc_l (codice, ascendente);
  create temp table archi_nuovi on commit drop as
  select distinct on (h.id, e.id, t.tipo)
         h.id as ipotesi_id, h.esito_id, e.id as etimo_id, t.tipo, s.ordine, s.forma, s.affisso, s.confidenza,
         s.chiave, s.tipo as tipo_dichiarato
    from stg_relazione s
    join m_ip mi on mi.chiave = s.ipotesi
    join ipotesi h on h.id = mi.id
    join m_les me on me.chiave = s.etimo
    join lessema e on e.id = me.id
    join lessema lx on lx.id = h.esito_id
    cross join lateral (select case when s.tipo = 'eredita'
                                     and not exists (select 1 from asc_l a where a.codice = lx.lingua and a.ascendente = e.lingua)
                                    then 'generico' else s.tipo end as tipo) t
   where e.id <> h.esito_id
     and h.provenienza = 'wiktionary' and h.stato_editoriale = 'importato'
   order by h.id, e.id, t.tipo, s.chiave;
  create index on archi_nuovi (ipotesi_id, etimo_id, tipo);
  analyze archi_nuovi;

  delete from relazione x using m_ip m, ipotesi h
   where x.ipotesi_id = m.id and h.id = m.id
     and h.provenienza = 'wiktionary' and h.stato_editoriale = 'importato'
     and x.provenienza = 'wiktionary' and x.stato_editoriale = 'importato'
     and not exists (select 1 from archi_nuovi a
                      where a.ipotesi_id = x.ipotesi_id and a.etimo_id = x.etimo_id and a.tipo = x.tipo
                        and a.esito_id = x.esito_id and a.ordine = x.ordine and a.confidenza = x.confidenza
                        and a.forma is not distinct from x.forma_citata and a.affisso is not distinct from x.affisso
                        and a.chiave is not distinct from x.id_esterno);
  get diagnostics n = row_count;
  r := r || jsonb_build_object('archi_tolti', n);

  insert into relazione (ipotesi_id, esito_id, etimo_id, tipo, ordine, forma_citata, affisso, confidenza,
                         provenienza, stato_editoriale, id_esterno)
  select a.ipotesi_id, a.esito_id, a.etimo_id, a.tipo, a.ordine, a.forma, a.affisso, a.confidenza,
         'wiktionary', 'importato', a.chiave
    from archi_nuovi a
   where not exists (select 1 from relazione x where x.ipotesi_id = a.ipotesi_id and x.etimo_id = a.etimo_id and x.tipo = a.tipo)
  on conflict do nothing;
  get diagnostics n = row_count;
  r := r || jsonb_build_object('archi_aggiunti', n);
  select count(*), count(*) filter (where a.tipo = 'generico' and a.tipo_dichiarato = 'eredita')
    into n, n2
    from archi_nuovi a
   where exists (select 1 from relazione x where x.ipotesi_id = a.ipotesi_id and x.etimo_id = a.etimo_id and x.tipo = a.tipo
                                            and x.provenienza = 'wiktionary' and x.stato_editoriale = 'importato');
  r := r || jsonb_build_object('archi', n, 'eredita_fuori_genealogia', n2);

  -- 5. cicli che coinvolgono archi di redazione (quelli tra archi importati li toglie il parser)
  n := 0;
  for rec in select x.id, x.etimo_id, x.esito_id from relazione x
              where x.provenienza = 'wiktionary' and x.stato_editoriale = 'importato'
                and exists (select 1 from relazione y
                             where y.provenienza <> 'wiktionary'
                               and (y.etimo_id in (x.etimo_id, x.esito_id) or y.esito_id in (x.etimo_id, x.esito_id))) loop
    if exists (with recursive giu(id) as (
                 select rec.esito_id
                 union
                 select r2.esito_id from relazione r2 join giu on r2.etimo_id = giu.id)
               select 1 from giu where id = rec.etimo_id) then
      delete from relazione where id = rec.id;
      n := n + 1;
    end if;
  end loop;
  r := r || jsonb_build_object('archi_tolti_per_cicli', n);

  -- 6. dichiarazioni di Wiktionary per la validazione
  delete from wiktionary_doppione;
  insert into wiktionary_doppione (a_id, b_id)
  select distinct least(a.id, b.id), greatest(a.id, b.id)
    from stg_doppione s join m_les a on a.chiave = s.a join m_les b on b.chiave = s.b
   where a.id <> b.id;
  delete from wiktionary_radice;
  insert into wiktionary_radice (lessema_id, radice_id)
  select distinct a.id, b.id from stg_radice s join m_les a on a.chiave = s.lessema join m_les b on b.chiave = s.radice
   where a.id <> b.id;

  -- 7. prime attestazioni (template etydate e «first attested» nella prosa): datazioni di seconda mano
  delete from attestazione a using m_les m
   where a.lessema_id = m.id and a.provenienza = 'wiktionary' and a.stato_editoriale = 'importato'
     and a.id_esterno like 'enwikt:%';
  insert into attestazione (lessema_id, testo, tipo, anno_da, anno_a, precisione, provenienza, stato_editoriale, id_esterno)
  select m.id, 'Wiktionary', 'lessicografica', s.anno_da, s.anno_a, s.precisione, 'wiktionary', 'importato', s.chiave
    from stg_attestazione s join m_les m on m.chiave = s.lessema
   where not exists (select 1 from attestazione a where a.lessema_id = m.id and a.provenienza <> 'wiktionary');
  get diagnostics n = row_count;
  r := r || jsonb_build_object('attestazioni', n);

  r := r || jsonb_build_object('secondi', round(extract(epoch from clock_timestamp() - t0)::numeric, 1));
  return r;
end $$;

-- Glosse italiane dal Wikizionario, come traduzioni (tabella glossa) con la loro provenienza.
-- Si assegna una glossa solo se la parte del discorso combacia, oppure se la parola non ha omografi e il
-- Wikizionario ne dà una sola parte del discorso; nei casi ambigui niente. La redazione non si tocca.
-- Una glossa importata di rango più basso (Wikidata, traduzione automatica) lascia il posto a quella del Wikizionario;
-- le altre le aggiorna importa_glosse_aggiuntive(). Quelle riviste dalla redazione restano.
create or replace function importa_glosse_wikizionario() returns jsonb
language plpgsql as $$
declare n int; r jsonb;
begin
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
  fratelli as (select lingua, lemma, wpos, count(*) as n from tutti group by 1, 2, 3),
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
  join fratelli f on f.lingua = x.lingua and f.lemma = x.lemma and f.wpos is not distinct from x.wpos
  where (x.wpos is not null and w.pos = x.wpos and f.n = 1)            -- stessa parte del discorso, senza omografi
     or (x.wpos is null and o.n = 1                                    -- etimo senza parte del discorso e senza omografi:
         and (select count(distinct w2.pos) from stg_wikizionario w2   -- il Wikizionario deve darne una sola
               where w2.lingua = x.lingua and w2.parola = x.lemma) = 1)
  order by x.id, w.ordine;

  delete from glossa g using cand c
   where g.lessema_id = c.id and g.lingua = 'it' and g.accezione_id is null
     and g.provenienza in ('wikidata', 'traduzione-automatica') and g.stato_editoriale = 'importato';
  insert into glossa (lessema_id, lingua, testo, provenienza, stato_editoriale)
  select id, 'it', glossa, 'wikizionario', 'importato' from cand
  on conflict (lessema_id, lingua) where accezione_id is null
  do update set testo = excluded.testo
  where glossa.provenienza = 'wikizionario' and glossa.stato_editoriale = 'importato' and glossa.testo <> excluded.testo;

  select jsonb_build_object(
    'glosse_italiane', (select count(*) from glossa where provenienza = 'wikizionario'),
    'per_lingua', (select jsonb_object_agg(lingua, quante) from (
        select l.lingua, count(*) as quante from glossa g join lessema l on l.id = g.lessema_id
         where g.provenienza = 'wikizionario' group by 1 order by 2 desc limit 8) t))
    into r;
  return r;
end $$;

-- Quanto i calcoli concordano con quello che Wiktionary dichiara
create or replace view v_validazione_wiktionary as
with dich as (select d.a_id, d.b_id from wiktionary_doppione d),
calc as (select m.a_id, m.b_id from mv_allotropi m),
rad as (
  select w.lessema_id, w.radice_id,
         exists (select 1 from antenati(w.lessema_id, '{accolta,alternativa}', true) a where a.lessema_id = w.radice_id) as raggiunta
    from wiktionary_radice w)
select 'allotropi dichiarati da Wiktionary' as misura, (select count(*) from dich)::text as valore
union all select 'di questi, trovati anche dal calcolo', (select count(*) from dich d join calc c using (a_id, b_id))::text
union all select 'allotropi calcolati in totale', (select count(*) from calc)::text
union all select 'radici dichiarate da Wiktionary', (select count(*) from rad)::text
union all select 'di queste, raggiunte dalle catene', (select count(*) from rad where raggiunta)::text;

-- Pulizia dopo un import completo: toglie ciò che Wiktionary non dice più (chiavi che il parser non genera più),
-- ma solo dove nessuno ha messo mano. Va chiamata dopo importa_wiktionary(), con le tabelle di appoggio piene
-- dell'import completo: con un import parziale toglierebbe troppo, perciò non la chiama l'import stesso.
create or replace function pulisci_wiktionary() returns jsonb
language plpgsql as $$
declare
  r jsonb := '{}';
  n int;
  rec record;
begin
  if (select count(*) from stg_lessema) < 1000 then
    raise exception 'tabelle di appoggio vuote o parziali: la pulizia richiede un import completo';
  end if;
  perform set_config('app.import', 'on', true);

  -- 1. ipotesi importate che Wiktionary non dà più: senza fonti e senza archi toccati dalla redazione
  --    (cancellarle porta via a cascata i loro archi importati)
  delete from ipotesi h
   where h.provenienza = 'wiktionary' and h.stato_editoriale = 'importato' and h.id_esterno is not null
     and not exists (select 1 from stg_ipotesi s where s.chiave = h.id_esterno)
     and not exists (select 1 from rimando m where m.ipotesi_id = h.id)
     and not exists (select 1 from relazione x where x.ipotesi_id = h.id
                      and (x.provenienza <> 'wiktionary' or x.stato_editoriale <> 'importato'
                           or exists (select 1 from rimando m where m.relazione_id = x.id)));
  get diagnostics n = row_count;
  r := r || jsonb_build_object('ipotesi_tolte', n);

  -- 2. se l'ipotesi accolta era una di quelle, torna accolta quella che Wiktionary indica ora
  with da_promuovere as (
    select distinct on (h.esito_id) h.id
      from ipotesi h join stg_ipotesi s on s.chiave = h.id_esterno
     where s.stato = 'accolta' and h.stato = 'alternativa'
       and h.provenienza = 'wiktionary' and h.stato_editoriale = 'importato'
       and not exists (select 1 from ipotesi x where x.esito_id = h.esito_id and x.stato = 'accolta')
     order by h.esito_id, h.id)
  update ipotesi h set stato = 'accolta' from da_promuovere p where h.id = p.id;
  get diagnostics n = row_count;
  r := r || jsonb_build_object('ipotesi_tornate_accolte', n);

  -- 3. voci importate rimaste senza legami (per esempio i doppioni con i segni vocalici, o le voci che il parser non
  --    considera più parole): le glosse importate, anche tradotte, non le trattengono
  delete from lessema l
   where l.provenienza = 'wiktionary' and l.stato_editoriale = 'importato' and l.id_esterno is not null
     and not exists (select 1 from stg_lessema s where s.chiave = l.id_esterno)
     and voce_intatta(l.id);
  get diagnostics n = row_count;
  r := r || jsonb_build_object('lessemi_tolti', n);

  -- 4. le traslitterazioni rimaste in sospeso perché l'indirizzo era occupato da un doppione ora tolto
  update lessema l
     set translit = s.translit
    from stg_lessema s
   where s.chiave = l.id_esterno and s.translit is not null and l.translit is distinct from s.translit
     and l.provenienza = 'wiktionary' and l.stato_editoriale = 'importato'
     and not exists (select 1 from lessema y where y.id <> l.id
                      and y.slug = slug_di(l.lingua, l.lemma, s.translit, l.omografo, l.ricostruito));
  get diagnostics n = row_count;
  r := r || jsonb_build_object('traslitterazioni_completate', n);

  -- 5. i numeri di omografo dati solo perché l'indirizzo era occupato da un doppione ora tolto: si tolgono,
  --    così gli indirizzi dipendono dai dati e non dalla storia del database
  n := 0;
  for rec in select l.id, s.omografo from lessema l join stg_lessema s on s.chiave = l.id_esterno
              where l.omografo > s.omografo and l.provenienza = 'wiktionary' and l.stato_editoriale = 'importato'
              order by l.id loop
    begin
      update lessema set omografo = rec.omografo where id = rec.id;
      n := n + 1;
    exception when unique_violation then
      null;                                  -- l'indirizzo è ancora occupato: il numero resta
    end;
  end loop;
  r := r || jsonb_build_object('omografi_rinumerati', n);
  return r;
end $$;
comment on function pulisci_wiktionary() is 'Dopo un import completo: toglie ipotesi e voci importate che Wiktionary non dà più, se nessuno le ha toccate.';

-- ===== Glosse aggiuntive: Wikidata e traduzione automatica (ottobre 2026) =====
insert into strato (codice, nome, licenza, share_alike, attribuzione, url) values
('wikidata', 'Wikidata, lessemi', 'CC0 1.0', false,
 'Contiene definizioni tratte dai lessemi di Wikidata, nel pubblico dominio (CC0).', 'https://www.wikidata.org/wiki/Wikidata:Lexicographical_data'),
('traduzione-automatica', 'Traduzione automatica delle glosse inglesi', 'CC BY-SA 4.0', true,
 'Glosse italiane tradotte automaticamente dalle glosse inglesi di Wiktionary e dei dizionari del Perseus (modello OPUS-MT di Argos Translate), verificate con la traduzione di ritorno e con un dizionario rovesciato.', null)
on conflict (codice) do nothing;

create table if not exists stg_glossa_wikidata (lid text, lemma text, categoria text, glossa text, sensi int);
create table if not exists stg_glossa_tradotta (chiave text, originale text, testo text);

-- Dopo il Wikizionario: definizioni di Wikidata per le parole italiane che non ne hanno (stessa parte del discorso,
-- niente omografi), poi traduzioni automatiche per gli etimi che non hanno una glossa italiana. Per differenza: le
-- glosse uguali restano, quelle che non valgono più si tolgono, le nuove si aggiungono.
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
       and not exists (select 1 from glossa g where g.lessema_id = l.id and g.lingua = 'it' and g.accezione_id is null
                        and not (g.provenienza = 'wikidata' and g.stato_editoriale = 'importato'))
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
  delete from glossa g
   where g.provenienza = 'wikidata' and g.stato_editoriale = 'importato'
     and not exists (select 1 from cand_wd c where c.id = g.lessema_id and c.glossa = g.testo);
  insert into glossa (lessema_id, lingua, testo, provenienza, stato_editoriale)
  select id, 'it', glossa, 'wikidata', 'importato' from cand_wd
  on conflict (lessema_id, lingua) where accezione_id is null do nothing;
  select count(*) into n from glossa where provenienza = 'wikidata';
  r := r || jsonb_build_object('wikidata', n);

  create temp table cand_tr on commit drop as
    select distinct on (l.id) l.id, btrim(t.testo) as testo
      from stg_glossa_tradotta t join lessema l on l.id_esterno = t.chiave
     where l.lingua <> 'it' and coalesce(l.glossa_lingua, '') <> 'it' and btrim(coalesce(t.testo, '')) <> ''
     order by l.id, btrim(t.testo);
  create index on cand_tr (id);
  delete from glossa g
   where g.provenienza = 'traduzione-automatica' and g.stato_editoriale = 'importato'
     and not exists (select 1 from cand_tr c where c.id = g.lessema_id and c.testo = g.testo);
  insert into glossa (lessema_id, lingua, testo, provenienza, stato_editoriale)
  select id, 'it', testo, 'traduzione-automatica', 'importato' from cand_tr
  on conflict (lessema_id, lingua) where accezione_id is null do nothing;
  select count(*) into n from glossa where provenienza = 'traduzione-automatica';
  r := r || jsonb_build_object('traduzione_automatica', n);
  return r;
end $$;
comment on function importa_glosse_aggiuntive() is 'Glosse italiane di rango più basso: definizioni di Wikidata e traduzioni automatiche, solo dove mancano.';

-- ===== Dizionari del Perseus: Lewis & Short e Liddell–Scott–Jones (novembre 2026) =====
-- Lemmi e glosse inglesi dei due dizionari, per le parole latine e greche che Wiktionary non ha. Le voci entrano come
-- strato «perseus», senza etimologia: la redazione può aggiungerla, e allora la voce resta anche quando Wiktionary
-- arriva alla stessa parola (che la abbina per forma esatta, come le sue).
insert into strato (codice, nome, licenza, share_alike, attribuzione, url) values
('perseus', 'Perseus Digital Library, Lewis & Short e Liddell–Scott–Jones', 'CC BY-SA 4.0', true,
 'Contiene lemmi e glosse di A Latin Dictionary (Charlton T. Lewis e Charles Short, 1879) e di A Greek-English Lexicon (Henry George Liddell, Robert Scott, Henry Stuart Jones, 9ª ed., 1940), nell’edizione digitale del Perseus Digital Library (Tufts University, http://www.perseus.tufts.edu/), distribuita con licenza CC BY-SA 4.0 dal repository github.com/PerseusDL/lexica.',
 'https://github.com/PerseusDL/lexica')
on conflict (codice) do update set nome = excluded.nome, licenza = excluded.licenza, share_alike = excluded.share_alike,
                                   attribuzione = excluded.attribuzione, url = excluded.url;
insert into etichetta_lingua (vocabolario, codice, lingua, etichetta, breve, descrizione) values
('strato', 'perseus', 'en', 'Perseus Digital Library, Lewis & Short and Liddell–Scott–Jones', 'CC BY-SA 4.0',
 'Contains headwords and glosses from A Latin Dictionary (Charlton T. Lewis and Charles Short, 1879) and A Greek-English Lexicon (Henry George Liddell, Robert Scott, Henry Stuart Jones, 9th ed., 1940), in the digital edition of the Perseus Digital Library (Tufts University, http://www.perseus.tufts.edu/), distributed under CC BY-SA 4.0 from the github.com/PerseusDL/lexica repository.')
on conflict (vocabolario, codice, lingua) do update set etichetta = excluded.etichetta, breve = excluded.breve,
                                                       descrizione = excluded.descrizione;

-- le stesse colonne di stg_lessema (ricostruito è sempre falso)
create unlogged table if not exists stg_dizionario (
  chiave text primary key, lingua text, lemma text, omografo int, ricostruito boolean, translit text, pos text, glossa text);

-- Dopo pulisci_wiktionary(): aggiorna le voci dei dizionari che nessuno ha toccato, aggiunge i lemmi che non ci sono
-- (né in Wiktionary con la stessa forma, né nella redazione con la stessa forma normalizzata) e toglie quelli che il
-- pacchetto non ha più. Un indirizzo già occupato da un'altra parola (φορός e φόρος danno entrambi grc/phoros) passa
-- al numero d'omografo libero successivo; le voci già presenti tengono il loro.
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

  -- 2. voci che il pacchetto non ha più (perché ora le ha Wiktionary, o perché il filtro le scarta), se intatte
  delete from lessema l
   where l.provenienza = 'perseus' and l.stato_editoriale = 'importato'
     and (not exists (select 1 from stg_dizionario s where s.chiave = l.id_esterno)
          or exists (select 1 from lessema w where w.lingua = l.lingua and w.lemma = l.lemma and not w.ricostruito
                                              and w.provenienza <> 'perseus'))
     and voce_intatta(l.id);
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
