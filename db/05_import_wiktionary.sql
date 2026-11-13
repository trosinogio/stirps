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
  -- può ancora occuparlo; lo toglie pulisci_wiktionary(), che poi completa l'aggiornamento), e una voce sola per
  -- indirizzo: due voci che nello stesso aggiornamento andrebbero allo stesso indirizzo (gmw-pro/i) non passano entrambe
  with nuove as (
    select l.id, s.translit, slug_di(l.lingua, l.lemma, s.translit, l.omografo, l.ricostruito) as nuovo
      from lessema l join m_scelta s on s.id = l.id
     where l.provenienza = 'wiktionary' and l.stato_editoriale = 'importato'
       -- una traslitterazione che il pacchetto non dà più si toglie solo da un lemma in alfabeto latino: lì era un pezzo
       -- di glossa (tucca, «liquid lard(?)») e faceva l'indirizzo; per le altre scritture resta quella che c'è
       and (s.translit is not null or l.lemma ~ '^[A-Za-zÀ-ɏḀ-ỿ''’ .·-]+$')
       and l.translit is distinct from s.translit),
  libere as (
    select distinct on (n.nuovo) n.id, n.translit from nuove n
     where not exists (select 1 from lessema y where y.id <> n.id and y.slug = n.nuovo)
     order by n.nuovo, n.id)
  update lessema l set translit = f.translit from libere f where l.id = f.id;

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
  with nuove as (
    select l.id, s.translit, slug_di(l.lingua, l.lemma, s.translit, l.omografo, l.ricostruito) as nuovo
      from lessema l join stg_lessema s on s.chiave = l.id_esterno
     where s.translit is not null and l.translit is distinct from s.translit
       and l.provenienza = 'wiktionary' and l.stato_editoriale = 'importato'),
  libere as (
    select distinct on (n.nuovo) n.id, n.translit from nuove n
     where not exists (select 1 from lessema y where y.id <> n.id and y.slug = n.nuovo)
     order by n.nuovo, n.id)
  update lessema l set translit = f.translit from libere f where l.id = f.id;
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

create unlogged table if not exists stg_glossa_wikidata (lid text, lemma text, categoria text, glossa text, sensi int);
create unlogged table if not exists stg_glossa_tradotta (chiave text, originale text, testo text);
-- traduzioni e definizioni di Claude (import/definisci.py, dati/definizioni.tsv.gz): chiave della voce, glossa
-- d'origine, traduzione breve, definizione, modello; i campi vuoti dicono che il modello non conosceva la parola
create unlogged table if not exists stg_definizione (chiave text, originale text, traduzione text, definizione text, modello text);
create unlogged table if not exists stg_pronuncia (chiave text, dati text);   -- pronunce.tsv: chiave, JSON
create unlogged table if not exists stg_sensi (chiave text, dati text);   -- sensi.tsv: chiave, JSON
create unlogged table if not exists stg_forma (lingua text, forma text, lemma text, sostituisce text);   -- forme_it.tsv: forma flessa, lemma, t se è solo una riduzione
alter table stg_forma add column if not exists sostituisce text;

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

-- ===== Etimologie dai dizionari del Perseus (7 novembre 2026) =====
-- Il Lewis & Short e l'LSJ scrivono nel tag <etym> la base di molte voci (anguinus: anguis; ἀγυρτάζω: ἀγύρτης), i
-- composti (anguicomus: anguis-coma) e i prefissi (abduco: ab-duco). filtra_perseus.py --etimi li legge; qui diventano
-- ipotesi con la loro fonte, solo per le voci che non hanno altre etimologie, e solo dove esito ed etimi sono voci certe:
-- un lemma con più voci nella sua lingua (caro, tre voci) è ambiguo e resta fuori. Le righe con opera «Wikizionario» vengono
-- da etimi_wikizionario.py (le voci italiane: «dal latino avarus», «composto da ago e puntura»; i rimandi «vedi …» con
-- certezza 2), con provenienza wikizionario; vengono dopo i dizionari e prima dell'analisi. Le righe con opera «Wiktionnaire»
-- fanno lo stesso per le voci francesi (etimi_wiktionnaire.py), con provenienza wiktionnaire. Le righe con opera «analisi» vengono da
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
  -- solo le voci di Wiktionary e dei dizionari senza altre etimologie; per una voce, una sola voce del dizionario.
  -- Il confronto dei due Wiktionary (Wikizionario-concorda, -discorda, e così per il Wiktionnaire:
  -- confronta_wikizionario.py) vale invece per le voci con un'etimologia di Wiktionary intatta, mai per quelle che la
  -- redazione ha toccato
  delete from ed_voluti v using lessema l
   where l.id = v.esito_id
     and (l.provenienza not in ('wiktionary', 'perseus')
          or case when v.opera ~ '-(concorda|discorda)$'
                  then not exists (select 1 from ipotesi h where h.esito_id = v.esito_id and h.provenienza = 'wiktionary'
                                     and h.stato_editoriale = 'importato' and h.stato in ('accolta', 'alternativa'))
                       or exists (select 1 from ipotesi h where h.esito_id = v.esito_id
                                     and (h.stato_editoriale <> 'importato'
                                          or h.provenienza not in ('wiktionary', 'wikizionario', 'wiktionnaire')))
                  else exists (select 1 from ipotesi h where h.esito_id = v.esito_id
                                  and h.provenienza not in ('perseus', 'wikizionario', 'wiktionnaire'))
             end);
  delete from ed_voluti v using (
      select distinct on (esito_id) esito_id, chiave as prima from ed_voluti
       order by esito_id, opera = 'analisi', opera ~ '^(Wikizionario|Wiktionnaire)', chiave) m
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
  -- dove i due Wiktionary concordano non entra un'ipotesi: l'etimologia di Wiktionary cita anche il Wikizionario o il
  -- Wiktionnaire (passo 5)
  create temp table ed_concordi on commit drop as
    select esito_id, split_part(opera, '-', 1) as sigla, min(sv) as sv from ed_voluti where opera like '%-concorda' group by 1, 2;
  delete from ed_voluti where opera like '%-concorda';
  create temp table ed_firme on commit drop as
  select chiave, min(esito_id) as esito_id, min(opera) as opera, min(sv) as sv,
         string_agg(etimo_id || ':' || tipo || ':' || ordine || ':' || coalesce(affisso, ''), ',' order by ordine, etimo_id) as firma
    from ed_voluti group by chiave;
  alter table ed_firme add primary key (chiave);
  analyze ed_firme;

  -- 3. le etimologie dei dizionari che non servono più o sono cambiate, se nessuno le ha toccate
  delete from ipotesi h
   where h.provenienza in ('perseus', 'wikizionario', 'wiktionnaire') and h.stato_editoriale = 'importato'
     and not exists (
       select 1 from ed_firme f
        where f.chiave = h.id_esterno and f.esito_id = h.esito_id
          -- un disaccordo con Wiktionary è un'alternativa, il resto è accolto: se cambia, l'ipotesi si rifà
          and h.stato = (case when f.opera like '%-discorda' then 'alternativa' else 'accolta' end)::stato_ipotesi
          and f.firma = (select string_agg(x.etimo_id || ':' || x.tipo || ':' || x.ordine || ':' || coalesce(x.affisso, ''), ','
                                           order by x.ordine, x.etimo_id) from relazione x where x.ipotesi_id = h.id))
     and not exists (select 1 from relazione x where x.ipotesi_id = h.id
                      and (x.provenienza not in ('perseus', 'wikizionario', 'wiktionnaire') or x.stato_editoriale <> 'importato'));
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
           case when f.opera = 'LSJ' then 'Liddell–Scott–Jones' when f.opera = 'analisi' then 'Analisi della forma'
                when f.opera ~ '^(Wikizionario|Wiktionnaire)' then split_part(f.opera, '-', 1) else 'Lewis & Short' end,
           (case when f.opera like '%-discorda' then 'alternativa' else 'accolta' end)::stato_ipotesi,
           case when f.opera = 'analisi' or f.opera ~ '-(vedi|discorda)$' then 2 else 3 end, 'etimo',
           case when f.opera like 'Wikizionario%' then 'wikizionario' when f.opera like 'Wiktionnaire%' then 'wiktionnaire'
                else 'perseus' end, 'importato', f.chiave
      from ed_firme f
     where not exists (select 1 from ipotesi h where h.id_esterno = f.chiave)
       and (f.opera like '%-discorda' or not exists (select 1 from ipotesi h where h.esito_id = f.esito_id and h.stato = 'accolta'))
    on conflict do nothing
    returning id, id_esterno)
  insert into ed_nuove select id, id_esterno from ins;
  get diagnostics n = row_count;
  r := r || jsonb_build_object('etimologie_nuove', n);
  insert into relazione (ipotesi_id, esito_id, etimo_id, tipo, ordine, affisso, confidenza, provenienza, stato_editoriale, id_esterno)
  select e.id, v.esito_id, v.etimo_id, v.tipo, v.ordine, v.affisso,
         case when v.opera = 'analisi' or v.opera ~ '-(vedi|discorda)$' then 2 else 3 end,
         case when v.opera like 'Wikizionario%' then 'wikizionario' when v.opera like 'Wiktionnaire%' then 'wiktionnaire'
              else 'perseus' end, 'importato', v.chiave || '#' || v.ordine
    from ed_nuove e join ed_voluti v on v.chiave = e.chiave
  on conflict do nothing;
  insert into rimando (opera_id, sv, posizione, ipotesi_id)
  select o.id, f.sv, 'propone', e.id
    from ed_nuove e join ed_firme f on f.chiave = e.chiave
    join opera o on o.sigla = case when f.opera ~ '^(Wikizionario|Wiktionnaire)' then split_part(f.opera, '-', 1) else f.opera end;

  -- 5. dove i due Wiktionary concordano, l'etimologia accolta di Wiktionary cita anche il Wikizionario (o il
  --    Wiktionnaire). Il rimando porta la nota «concorda con Wiktionary», così si toglie se l'accordo cade, e non si
  --    toccano quelli della redazione
  create temp table ed_rimandi on commit drop as
    select h.id as ipotesi_id, c.sigla, c.sv
      from ed_concordi c
      join ipotesi h on h.esito_id = c.esito_id and h.stato = 'accolta' and h.provenienza = 'wiktionary'
                    and h.stato_editoriale = 'importato';
  delete from rimando m using opera o
   where o.id = m.opera_id and o.sigla in ('Wikizionario', 'Wiktionnaire') and m.nota = 'concorda con Wiktionary'
     and not exists (select 1 from ed_rimandi e where e.ipotesi_id = m.ipotesi_id and e.sigla = o.sigla
                                                  and e.sv is not distinct from m.sv);
  insert into rimando (opera_id, sv, posizione, nota, ipotesi_id)
  select o.id, e.sv, 'accoglie', 'concorda con Wiktionary', e.ipotesi_id
    from ed_rimandi e join opera o on o.sigla = e.sigla
   where not exists (select 1 from rimando m where m.ipotesi_id = e.ipotesi_id and m.opera_id = o.id
                                              and m.nota = 'concorda con Wiktionary');
  r := r || jsonb_build_object('concordanze', (select jsonb_object_agg(sigla, quante) from (
           select o.sigla, count(*) as quante from rimando m join opera o on o.id = m.opera_id
            where m.nota = 'concorda con Wiktionary' group by 1) t),
                               'discordanze', (select jsonb_object_agg(provenienza, quante) from (
           select h.provenienza, count(*) as quante from ipotesi h
            where h.provenienza in ('wikizionario', 'wiktionnaire') and h.stato = 'alternativa' group by 1) t));
  r := r || jsonb_build_object('etimologie_dei_dizionari', (select jsonb_object_agg(lingua, quante) from (
           select l.lingua, count(*) as quante from ipotesi h join lessema l on l.id = h.esito_id
            where h.provenienza in ('perseus', 'wikizionario', 'wiktionnaire') group by 1) t));
  return r;
end $$;
comment on function importa_etimi_dizionari() is 'Etimologie del Lewis & Short e dell’LSJ (tag <etym>), del Wikizionario, del Wiktionnaire e l’analisi della forma, per le voci che non ne hanno altre; il confronto dei due Wiktionary (rimando dove concordano, alternativa con certezza 2 dove discordano): scritte solo dove cambiano.';

-- ===== Stime della prima attestazione dai dizionari del Perseus (novembre 2026, import/DATAZIONI.md) =====
-- Per ogni voce del Lewis & Short e dell'LSJ, l'autore datato più antico tra quelli citati (datatore_dizionari.py),
-- con la datazione di Wikidata. Entrano come attestazioni con stima = true: «almeno dal 184 a.C. — Plauto, secondo il
-- Lewis & Short».
create unlogged table if not exists stg_autore (lingua text, ident text, nome text, anno_da int, anno_a int, precisione text, wikidata text);
create unlogged table if not exists stg_stima (
  chiave text, lingua text, lemma text, anno int, precisione text, autore text, opera text, fonte text, confidenza int);

-- Le stime vanno solo dove la voce è certa: la voce del dizionario stessa (id_esterno), oppure un lemma che ha una sola
-- voce nel dizionario e una sola nella sua lingua. Gli omografi ambigui (caro, tre voci nel Lewis & Short) restano senza.
create or replace function importa_stime() returns jsonb
language plpgsql as $$
declare
  r jsonb := '{}';
  n int;
begin
  if not exists (select 1 from stg_stima) then
    return jsonb_build_object('saltato', 'tabella di appoggio vuota');
  end if;
  perform set_config('app.import', 'on', true);

  insert into autore (lingua, sigla, nome, anno_da, anno_a, precisione, wikidata, fonte)
  select lingua, ident, nome, anno_da, anno_a, precisione::precisione_data, wikidata, 'Wikidata'
    from stg_autore where exists (select 1 from lingua g where g.codice = stg_autore.lingua)
  on conflict (lingua, sigla) do update
     set nome = excluded.nome, anno_da = excluded.anno_da, anno_a = excluded.anno_a, precisione = excluded.precisione,
         wikidata = excluded.wikidata
   where (autore.nome, autore.anno_da, autore.anno_a, autore.precisione, autore.wikidata)
         is distinct from (excluded.nome, excluded.anno_da, excluded.anno_a, excluded.precisione, excluded.wikidata)
     and autore.fonte = 'Wikidata';
  get diagnostics n = row_count;
  r := r || jsonb_build_object('autori', n);

  -- il bersaglio: la voce del dizionario stessa, o l'unica voce della lingua per un lemma che ha una sola stima.
  -- Con join e tabelle piccole precalcolate: una sottoquery correlata per riga costava dieci minuti
  create temp table st_unica on commit drop as
    select l.lingua, l.lemma, min(l.id) as id
      from lessema l
      join (select lingua, lemma from stg_stima group by 1, 2 having count(*) = 1) p
        on p.lingua = l.lingua and p.lemma = l.lemma
     where not l.ricostruito
     group by 1, 2 having count(*) = 1;
  create index on st_unica (lingua, lemma);
  analyze st_unica;
  create temp table st_nuove on commit drop as
  with bersaglio as (
    select s.*, coalesce(d.id, u.id) as lessema_id
      from stg_stima s
      left join lessema d on d.id_esterno = s.chiave
      left join st_unica u on u.lingua = s.lingua and u.lemma = s.lemma)
  select lessema_id, 'stima:' || chiave as id_esterno, autore, anno, precisione::precisione_data as precisione, fonte,
         'https://scaife.perseus.org/library/urn:cts:' || case when lingua = 'la' then 'latinLit' else 'greekLit' end
           || ':' || opera || '/' as url,
         least(greatest(confidenza, 1), 4) as confidenza
    from bersaglio where lessema_id is not null;
  create index on st_nuove (id_esterno);

  -- le stime importate che non valgono più (o sono cambiate) si tolgono; le uguali restano dove sono
  delete from attestazione a
   where a.provenienza = 'perseus' and a.stima and a.stato_editoriale = 'importato' and a.id_esterno like 'stima:%'
     and not exists (select 1 from st_nuove x where x.id_esterno = a.id_esterno and x.lessema_id = a.lessema_id
                       and x.autore = a.testo and x.anno = a.anno_da and x.precisione = a.precisione
                       and x.fonte = a.banca_dati and x.url is not distinct from a.url and x.confidenza = a.confidenza);
  get diagnostics n = row_count;
  r := r || jsonb_build_object('stime_tolte', n);
  insert into attestazione (lessema_id, testo, tipo, anno_da, precisione, banca_dati, url, stima, confidenza,
                            provenienza, stato_editoriale, id_esterno)
  select x.lessema_id, x.autore, 'lessicografica', x.anno, x.precisione, x.fonte, x.url, true, x.confidenza,
         'perseus', 'importato', x.id_esterno
    from st_nuove x
   where not exists (select 1 from attestazione a where a.id_esterno = x.id_esterno and a.lessema_id = x.lessema_id);
  get diagnostics n = row_count;
  r := r || jsonb_build_object('stime_nuove', n,
    'stime', (select count(*) from attestazione where provenienza = 'perseus' and stima));
  return r;
end $$;
comment on function importa_stime() is 'Stime della prima attestazione dai dizionari del Perseus: l''autore datato più antico citato nella voce, solo dove la voce è certa.';

-- ===== Traduzioni e definizioni di Claude (novembre 2026) =====
insert into strato (codice, nome, licenza, share_alike, attribuzione, url) values
('claude', 'Claude (Anthropic), traduzioni e definizioni automatiche', 'CC BY-SA 4.0', true,
 'Traduzioni e definizioni italiane scritte da Claude, il modello di Anthropic, a partire dalle glosse di Wiktionary e dei dizionari del Perseus e, per le radici, dai loro discendenti; automatiche, finché la redazione non le rivede. Restano con la licenza CC BY-SA 4.0 delle fonti.',
 'https://www.anthropic.com/claude')
on conflict (codice) do update set nome = excluded.nome, licenza = excluded.licenza, share_alike = excluded.share_alike,
                                   attribuzione = excluded.attribuzione, url = excluded.url;
insert into etichetta_lingua (vocabolario, codice, lingua, etichetta, breve, descrizione) values
('strato', 'claude', 'en', 'Claude (Anthropic), machine translations and definitions', 'CC BY-SA 4.0',
 'Italian translations and definitions written by Claude, Anthropic’s model, from the glosses of Wiktionary and of the Perseus dictionaries and, for roots, from their descendants; automatic until the editors review them. They keep the CC BY-SA 4.0 licence of their sources.')
on conflict (vocabolario, codice, lingua) do update set etichetta = excluded.etichetta, breve = excluded.breve,
                                                       descrizione = excluded.descrizione;

-- Dopo importa_glosse_aggiuntive(): le definizioni di Claude per le voci importate, per differenza. Valgono solo per
-- la glossa da cui sono nate; una definizione della redazione, o una rivista, non si tocca.
create or replace function importa_definizioni() returns jsonb
language plpgsql as $$
declare
  n int;
  tolte int;
  nuove int;
begin
  perform set_config('app.import', 'on', true);
  create temp table cand_def on commit drop as
    select distinct on (l.id) l.id, btrim(d.definizione) as testo, nullif(d.modello, '') as modello
      from stg_definizione d join lessema l on l.id_esterno = d.chiave
     where btrim(coalesce(d.definizione, '')) <> '' and (coalesce(d.originale, '') in ('', coalesce(l.glossa, '')))
       and l.stato_editoriale <> 'superato'
     order by l.id, d.modello;
  create index on cand_def (id);
  delete from definizione f
   where f.provenienza = 'claude' and f.stato_editoriale = 'importato'
     and not exists (select 1 from cand_def c where c.id = f.lessema_id and c.testo = f.testo
                                                and c.modello is not distinct from f.modello);
  get diagnostics tolte = row_count;
  insert into definizione (lessema_id, lingua, testo, provenienza, modello, stato_editoriale)
  select id, 'it', testo, 'claude', modello, 'importato' from cand_def
  on conflict (lessema_id, lingua) do nothing;
  get diagnostics nuove = row_count;
  select count(*) into n from definizione where provenienza = 'claude';
  return jsonb_build_object('claude', n, 'nuove', nuove, 'tolte', tolte);
end $$;
comment on function importa_definizioni() is 'Definizioni italiane scritte da Claude, per differenza: solo per la glossa da cui sono nate (o per la voce, se nate senza glossa), e mai sopra quelle della redazione o rivedute.';

-- La pronuncia, per differenza: si scrive solo ciò che cambia, e si tolgono le pronunce di Wiktionary di voci che non
-- ne hanno più. Una pronuncia della redazione (provenienza diversa) non si tocca.
create or replace function importa_pronunce() returns jsonb
language plpgsql as $$
declare
  nuove int;
  cambiate int;
  tolte int;
begin
  perform set_config('app.import', 'on', true);
  create temp table cand_pr on commit drop as
    select distinct on (l.id) l.id, coalesce(s.dati::jsonb -> 'i', '[]'::jsonb) as ipa, s.dati::jsonb ->> 's' as sill,
           s.dati::jsonb ->> 'a' as audio
      from stg_pronuncia s join lessema l on l.id_esterno = s.chiave
     where s.dati is not null and s.dati <> ''
     order by l.id;
  create index on cand_pr (id);
  analyze cand_pr;
  delete from pronuncia p
   where p.provenienza = 'wiktionary' and not exists (select 1 from cand_pr c where c.id = p.lessema_id);
  get diagnostics tolte = row_count;
  update pronuncia p set ipa = c.ipa, sillabazione = c.sill, audio = c.audio
    from cand_pr c
   where c.id = p.lessema_id and p.provenienza = 'wiktionary'
     and (p.ipa, p.sillabazione, p.audio) is distinct from (c.ipa, c.sill, c.audio);
  get diagnostics cambiate = row_count;
  insert into pronuncia (lessema_id, ipa, sillabazione, audio)
  select id, ipa, sill, audio from cand_pr
  on conflict (lessema_id) do nothing;
  get diagnostics nuove = row_count;
  return jsonb_build_object('nuove', nuove, 'cambiate', cambiate, 'tolte', tolte);
end $$;
comment on function importa_pronunce() is 'Pronunce di Wiktionary per differenza (IPA, sillabazione, audio); quelle della redazione non si toccano.';

-- La riga delle forme e le accezioni, per differenza, come le pronunce: quelle della redazione non si toccano.
create or replace function importa_sensi() returns jsonb
language plpgsql as $$
declare
  nuove int;
  cambiate int;
  tolte int;
begin
  perform set_config('app.import', 'on', true);
  create temp table cand_se on commit drop as
    select distinct on (l.id) l.id, s.dati::jsonb ->> 't' as testa, coalesce(s.dati::jsonb -> 's', '[]'::jsonb) as sensi
      from stg_sensi s join lessema l on l.id_esterno = s.chiave
     where s.dati is not null and s.dati <> ''
     order by l.id;
  create index on cand_se (id);
  analyze cand_se;
  delete from sensi x
   where x.provenienza = 'wiktionary' and not exists (select 1 from cand_se c where c.id = x.lessema_id);
  get diagnostics tolte = row_count;
  update sensi x set testa = c.testa, sensi = c.sensi
    from cand_se c
   where c.id = x.lessema_id and x.provenienza = 'wiktionary' and (x.testa, x.sensi) is distinct from (c.testa, c.sensi);
  get diagnostics cambiate = row_count;
  insert into sensi (lessema_id, testa, sensi)
  select id, testa, sensi from cand_se
  on conflict (lessema_id) do nothing;
  get diagnostics nuove = row_count;
  return jsonb_build_object('nuove', nuove, 'cambiate', cambiate, 'tolte', tolte);
end $$;
comment on function importa_sensi() is 'Riga delle forme e accezioni di Wiktionary per differenza; quelle della redazione non si toccano.';

-- Le forme flesse più frequenti e i loro lemmi, per l'analisi di un testo (analizza_testo()): per differenza, solo i
-- lemmi che sono voci. Senza il file (un pacchetto vecchio) la tabella resta com'è.
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

-- ===== Lingue e famiglie di Wiktionary (8 novembre 2026) =====
-- Le lingue e le famiglie di Wiktionary (dati/lingue_wiktionary.tsv.gz, dati/famiglie_wiktionary.tsv.gz, da
-- import/lingue_wiktionary.py): completano famiglia, ramo, antenato e varietà delle lingue che non li hanno, e
-- correggono i nomi letti male («calque of Western Apache»). Solo dove manca: le lingue già classificate non cambiano.
create unlogged table if not exists stg_lingua_wikt (codice text, nome text, famiglia text, antenati text, madre text, tipo text,
                                                     wikidata text, nome_it text);
alter table stg_lingua_wikt add column if not exists wikidata text, add column if not exists nome_it text;
create unlogged table if not exists stg_famiglia_wikt (codice text, nome text, madre text);

create or replace function importa_lingue_wiktionary() returns jsonb
language plpgsql as $$
declare
  r jsonb := '{}';
  n int;
begin
  if not exists (select 1 from stg_lingua_wikt) then
    return jsonb_build_object('saltato', 'tabella di appoggio vuota');
  end if;
  perform set_config('app.import', 'on', true);
  drop table if exists lw_nomi, lw_base, lw_classe, lw_antenato;
  -- i nomi delle famiglie e dei rami più comuni; le altre famiglie tengono il nome inglese di Wiktionary
  create temp table lw_nomi (codice text primary key, livello text, it text, en text) on commit drop;
  insert into lw_nomi values
    ('ine', 'famiglia', 'indoeuropea', 'Indo-European'), ('afa', 'famiglia', 'afroasiatica', 'Afroasiatic'),
    ('nic', 'famiglia', 'niger-congo', 'Niger-Congo'), ('map', 'famiglia', 'austronesiana', 'Austronesian'),
    ('aus-pam', 'famiglia', 'pama-nyunga', 'Pama-Nyungan'), ('aql', 'famiglia', 'algica', 'Algic'),
    ('urj', 'famiglia', 'uralica', 'Uralic'), ('sit', 'famiglia', 'sinotibetana', 'Sino-Tibetan'),
    ('trk', 'famiglia', 'turca', 'Turkic'), ('qfa-dny', 'famiglia', 'dene-jenisseiana', 'Dene-Yeniseian'),
    ('azc', 'famiglia', 'uto-azteca', 'Uto-Aztecan'), ('aav', 'famiglia', 'austroasiatica', 'Austroasiatic'),
    ('sal', 'famiglia', 'salish', 'Salishan'), ('dra', 'famiglia', 'dravidica', 'Dravidian'),
    ('iro', 'famiglia', 'irochese', 'Iroquoian'), ('nai-sca', 'famiglia', 'siouan-catawba', 'Siouan-Catawban'),
    ('qfa-xgs', 'famiglia', 'serbi-mongolica', 'Serbi-Mongolic'), ('tuw', 'famiglia', 'tungusa', 'Tungusic'),
    ('esx', 'famiglia', 'eschimo-aleutina', 'Eskimo-Aleut'), ('ssa', 'famiglia', 'nilo-sahariana', 'Nilo-Saharan'),
    ('cau-nec', 'famiglia', 'caucasica nordorientale', 'Northeast Caucasian'), ('tup', 'famiglia', 'tupi', 'Tupian'),
    ('qfa-tak', 'famiglia', 'tai-kadai', 'Kra-Dai'), ('sai-car', 'famiglia', 'caribe', 'Cariban'),
    ('nai-mus', 'famiglia', 'muskogean', 'Muskogean'), ('awd', 'famiglia', 'arawak', 'Arawakan'),
    ('wak', 'famiglia', 'wakash', 'Wakashan'), ('ccs', 'famiglia', 'cartvelica', 'Kartvelian'),
    ('myn', 'famiglia', 'maya', 'Mayan'), ('qfa-cka', 'famiglia', 'ciukoto-kamciatka', 'Chukotko-Kamchatkan'),
    ('cau-nwc', 'famiglia', 'caucasica nordoccidentale', 'Northwest Caucasian'), ('qfa-hur', 'famiglia', 'hurro-urartea', 'Hurro-Urartian'),
    ('euq', 'famiglia', 'vasconica', 'Vasconic'), ('jpx', 'famiglia', 'giapponica', 'Japonic'),
    ('qfa-kor', 'famiglia', 'coreanica', 'Koreanic'), ('qwe', 'famiglia', 'quechua', 'Quechuan'),
    ('qfa-tyn', 'famiglia', 'tirrenica', 'Tyrsenian'), ('crp', 'famiglia', 'creola o pidgin', 'Creole or pidgin'),
    ('art', 'famiglia', 'artificiale', 'Constructed'), ('sgn', 'famiglia', 'lingua dei segni', 'Sign language'),
    ('qfa-iso', 'famiglia', 'isolata', 'Isolate'), ('mul', 'famiglia', 'translingue', 'Translingual'),
    ('qfa-cnt', 'famiglia', 'di contatto', 'Contact language'),
    ('itc', 'ramo', 'italica', 'Italic'), ('gem', 'ramo', 'germanica', 'Germanic'), ('grk', 'ramo', 'ellenica', 'Hellenic'),
    ('sla', 'ramo', 'slava', 'Slavic'), ('bat', 'ramo', 'baltica', 'Baltic'), ('cel', 'ramo', 'celtica', 'Celtic'),
    ('iir', 'ramo', 'indoiranica', 'Indo-Iranian'), ('hyx', 'ramo', 'armena', 'Armenian'), ('sqj', 'ramo', 'albanese', 'Albanian'),
    ('ine-ana', 'ramo', 'anatolica', 'Anatolian'), ('ine-toc', 'ramo', 'tocaria', 'Tocharian'),
    ('sem', 'ramo', 'semitica', 'Semitic'), ('ber', 'ramo', 'berbera', 'Berber'), ('egx', 'ramo', 'egizia', 'Egyptian'),
    ('cus', 'ramo', 'cuscitica', 'Cushitic'), ('cdc', 'ramo', 'ciadica', 'Chadic'), ('trk-ogz', 'ramo', 'oghuz', 'Oghuz'),
    -- sottofamiglie, per il nome di un codice di famiglia usato come lingua («lingua romanza (non precisata)»)
    ('roa', 'sotto', 'romanza', 'Romance'), ('gmw', 'sotto', 'germanica occidentale', 'West Germanic'),
    ('gmq', 'sotto', 'germanica settentrionale', 'North Germanic'), ('gme', 'sotto', 'germanica orientale', 'East Germanic'),
    ('zle', 'sotto', 'slava orientale', 'East Slavic'), ('zlw', 'sotto', 'slava occidentale', 'West Slavic'),
    ('zls', 'sotto', 'slava meridionale', 'South Slavic'), ('inc', 'sotto', 'indoaria', 'Indo-Aryan'),
    ('ira', 'sotto', 'iranica', 'Iranian'), ('cel-bry', 'sotto', 'britannica', 'Brythonic'), ('cel-gae', 'sotto', 'gaelica', 'Goidelic'),
    ('sem-ara', 'sotto', 'aramaica', 'Aramaic'), ('sem-can', 'sotto', 'cananaica', 'Canaanite');

  -- 1. ogni lingua alla sua lingua piena (latino volgare › latino classico › latino) e alla sua famiglia
  create temp table lw_base on commit drop as
  with recursive su (codice, cur, prof) as (
    select l.codice, l.codice, 0 from lingua l
    union all
    select s.codice, w.madre, s.prof + 1
      from su s join stg_lingua_wikt w on w.codice = s.cur
     where w.tipo = 'etimologica' and coalesce(w.madre, '') <> '' and s.prof < 8)
  select distinct on (s.codice) s.codice, s.cur as piena,
         case when s.codice in ('mul', 'mul-tax') then 'mul'
              when f.codice is not null then s.cur
              -- una protolingua che Wiktionary non elenca (aav-pro): la famiglia del suo codice
              when w.codice is null and s.cur like '%-pro' then
                (select g.codice from stg_famiglia_wikt g where g.codice = left(s.cur, -4))
              else nullif(w.famiglia, '') end as fam
    from su s left join stg_lingua_wikt w on w.codice = s.cur left join stg_famiglia_wikt f on f.codice = s.cur
   order by s.codice, s.prof desc;

  -- 2. la catena delle famiglie (roa-itr › roa › itc › ine): la famiglia in cima, e il ramo più preciso che ha un nome
  create temp table lw_classe on commit drop as
  with recursive fc (codice, fam, prof) as (
    select b.codice, b.fam, 0 from lw_base b where b.fam is not null
    union all
    select c.codice, f.madre, c.prof + 1
      from fc c join stg_famiglia_wikt f on f.codice = c.fam
     where coalesce(f.madre, '') <> '' and f.madre <> 'qfa-not' and c.prof < 20),
  cima as (select distinct on (codice) codice, fam from fc order by codice, prof desc),
  ramo as (select distinct on (fc.codice) fc.codice, n.it, n.en
             from fc join lw_nomi n on n.codice = fc.fam and n.livello = 'ramo' order by fc.codice, fc.prof)
  select c.codice, coalesce(nf.it, f.nome, c.fam) as famiglia, coalesce(nf.en, f.nome, c.fam) as famiglia_en,
         r.it as ramo, r.en as ramo_en
    from cima c left join lw_nomi nf on nf.codice = c.fam and nf.livello = 'famiglia'
    left join stg_famiglia_wikt f on f.codice = c.fam
    left join ramo r on r.codice = c.codice;

  update lingua l set famiglia = c.famiglia from lw_classe c where c.codice = l.codice and l.famiglia is null;
  get diagnostics n = row_count;
  r := r || jsonb_build_object('famiglie_assegnate', n);
  update lingua l set ramo = c.ramo
    from lw_classe c where c.codice = l.codice and l.ramo is null and c.ramo is not null and l.famiglia = c.famiglia;
  get diagnostics n = row_count;
  r := r || jsonb_build_object('rami_assegnati', n);
  insert into etichetta_lingua (vocabolario, codice, lingua, etichetta)
  select distinct 'famiglia', famiglia, 'en', famiglia_en from lw_classe where famiglia is not null
  union
  select distinct 'ramo', ramo, 'en', ramo_en from lw_classe where ramo is not null
  on conflict do nothing;
  -- i rami si leggono al maschile, come Italico e Germanico
  insert into etichetta_lingua (vocabolario, codice, lingua, etichetta) values
    ('ramo', 'albanese', 'it', 'Albanese'), ('ramo', 'anatolica', 'it', 'Anatolico'), ('ramo', 'armena', 'it', 'Armeno'),
    ('ramo', 'baltica', 'it', 'Baltico'), ('ramo', 'berbera', 'it', 'Berbero'), ('ramo', 'celtica', 'it', 'Celtico'),
    ('ramo', 'ciadica', 'it', 'Ciadico'), ('ramo', 'cuscitica', 'it', 'Cuscitico'), ('ramo', 'egizia', 'it', 'Egizio'),
    ('ramo', 'tocaria', 'it', 'Tocario'), ('ramo', 'oghuz', 'it', 'Oghuz')
  on conflict do nothing;

  -- 3. l'antenato, dove manca: il primo antenato di Wiktionary che è una lingua del dizionario, risalendo anche
  --    attraverso gli antenati che non lo sono (catalano › catalano antico › latino volgare › latino)
  create temp table lw_antenato on commit drop as
  with recursive an (codice, cur, prof) as (
    select l.codice, btrim(a), 1
      from lingua l join stg_lingua_wikt w on w.codice = l.codice
      cross join lateral unnest(string_to_array(nullif(w.antenati, ''), ',')) a
     where l.antenato is null and l.varieta_di is null
    union all
    select an.codice, x.prossimo, an.prof + 1
      from an join stg_lingua_wikt w2 on w2.codice = an.cur
      cross join lateral (select btrim(a2) as prossimo from unnest(string_to_array(nullif(w2.antenati, ''), ',')) a2
                          union all select w2.madre where w2.tipo = 'etimologica' and coalesce(w2.madre, '') <> '') x
     where an.prof < 6 and not exists (select 1 from lingua g where g.codice = an.cur))
  select distinct on (an.codice) an.codice, an.cur as antenato
    from an join lingua g on g.codice = an.cur
   where an.cur <> an.codice and g.antenato is distinct from an.codice and g.varieta_di is distinct from an.codice
   order by an.codice, an.prof;
  update lingua l set antenato = a.antenato from lw_antenato a where a.codice = l.codice and l.antenato is null;
  get diagnostics n = row_count;
  r := r || jsonb_build_object('antenati_assegnati', n);

  -- 4. le lingue etimologiche sono varietà della loro lingua piena (latino volgare del latino), se non hanno altro
  update lingua l set varieta_di = b.piena
    from lw_base b
   where b.codice = l.codice and l.varieta_di is null and l.antenato is null and b.piena <> l.codice
     and exists (select 1 from lingua g where g.codice = b.piena)
     -- solo di una lingua vera: il galiziano-portoghese non è una varietà della famiglia romanza
     and exists (select 1 from stg_lingua_wikt w where w.codice = b.piena and w.tipo <> 'etimologica');
  get diagnostics n = row_count;
  r := r || jsonb_build_object('varieta_assegnate', n);

  -- 5. i nomi letti male dal testo dei modelli: il nome canonico di Wiktionary; poi, per le lingue che hanno ancora
  --    il nome inglese (quelle che il parser non cura), il nome italiano di Wikidata (Basque → basco)
  update lingua l set nome = case when l.codice = 'mul-tax' then 'nomi scientifici' else w.nome end
    from stg_lingua_wikt w
   where w.codice = l.codice
     and ((l.codice = 'mul-tax' and l.nome <> 'nomi scientifici')
          or (l.nome <> w.nome and (l.nome ~* '^(borrowed from|calque of|learned borrowing|semi-learned|orthographic borrowing|unadapted borrowing|partial calque|semantic loan|taxonomic name)'
                                   or l.nome ~ '-$' or l.nome = l.codice)));
  get diagnostics n = row_count;
  r := r || jsonb_build_object('nomi_corretti', n);
  update lingua l set nome = w.nome_it
    from stg_lingua_wikt w
   where w.codice = l.codice and l.nome = w.nome and coalesce(w.nome_it, '') <> '' and w.nome_it <> l.nome;
  get diagnostics n = row_count;
  r := r || jsonb_build_object('nomi_italiani', n);
  -- «Old Sicilian», «Middle Low German»: il nome italiano della lingua, con antico o medio
  update lingua l set nome = x.nome || case when m[1] = 'Old' then ' antico' else ' medio' end
    from (select codice, regexp_match(nome, '^(Old|Middle) (.+)$') as m from lingua) y
    join stg_lingua_wikt w on w.nome = y.m[2] and w.tipo <> 'etimologica'
    join lingua x on x.codice = w.codice and x.nome <> w.nome
   where y.codice = l.codice and y.m is not null and l.nome ~ '^(Old|Middle) ';
  -- un codice di famiglia usato come lingua (roa, gmw: «una lingua romanza») prende il nome della famiglia
  update lingua l set nome = case when n.it is null then f.nome else 'lingua ' || n.it || ' (non precisata)' end
    from stg_famiglia_wikt f left join lw_nomi n on n.codice = f.codice
   where f.codice = l.codice and l.nome = l.codice;
  update etichetta_lingua e set etichetta = case when e.codice = 'mul-tax' then 'taxonomic names' else w.nome end
    from stg_lingua_wikt w
   where e.vocabolario = 'lingua' and e.lingua = 'en' and e.codice = w.codice and e.etichetta <> w.nome
     and (e.etichetta ~* '^(borrowed from|calque of|learned borrowing|semi-learned|orthographic borrowing|unadapted borrowing|partial calque|semantic loan|taxonomic name)'
          or e.etichetta ~ '-$');
  r := r || jsonb_build_object('senza_famiglia', (select count(*) from lingua g where g.famiglia is null
                                                     and exists (select 1 from lessema x where x.lingua = g.codice)));
  return r;
end $$;
comment on function importa_lingue_wiktionary() is 'Famiglia, ramo, antenato, varietà e nome delle lingue dai dati di Wiktionary, solo dove mancano.';

-- ===== Aree di significato delle radici (8 novembre 2026) =====
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
