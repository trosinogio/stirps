-- 7 novembre 2026: le etimologie del Lewis & Short e dell'LSJ (tag <etym>) e l'analisi della forma (prefisso e base) per
-- le voci di latino e greco senza etimologia: la tabella d'appoggio e importa_etimi_dizionari(); importa_dizionari()
-- toglie prima queste etimologie dalle voci del dizionario che vanno via; importa_wiktionary() e pulisci_wiktionary()
-- non danno due voci allo stesso indirizzo quando cambia la traslitterazione. Stesso testo di db/05_import_wiktionary.sql:
-- se cambia lì, si rigenera da lì. Ripetibile senza danni.

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
       and s.translit is not null and l.translit is distinct from s.translit),
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
-- un lemma con più voci nella sua lingua (caro, tre voci) è ambiguo e resta fuori. Le righe con opera «Wikizionario» vengono
-- da etimi_wikizionario.py (le voci italiane: «dal latino avarus», «composto da ago e puntura»; i rimandi «vedi …» con
-- certezza 2), con provenienza wikizionario; vengono dopo i dizionari e prima dell'analisi. Le righe con opera «analisi» vengono da
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
          or exists (select 1 from ipotesi h where h.esito_id = v.esito_id and h.provenienza not in ('perseus', 'wikizionario')));
  delete from ed_voluti v using (
      select distinct on (esito_id) esito_id, chiave as prima from ed_voluti
       order by esito_id, opera = 'analisi', opera like 'Wikizionario%', chiave) m
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
   where h.provenienza in ('perseus', 'wikizionario') and h.stato_editoriale = 'importato'
     and not exists (
       select 1 from ed_firme f
        where f.chiave = h.id_esterno and f.esito_id = h.esito_id
          and f.firma = (select string_agg(x.etimo_id || ':' || x.tipo || ':' || x.ordine || ':' || coalesce(x.affisso, ''), ','
                                           order by x.ordine, x.etimo_id) from relazione x where x.ipotesi_id = h.id))
     and not exists (select 1 from relazione x where x.ipotesi_id = h.id
                      and (x.provenienza not in ('perseus', 'wikizionario') or x.stato_editoriale <> 'importato'));
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
                when f.opera like 'Wikizionario%' then 'Wikizionario' else 'Lewis & Short' end,
           'accolta', case when f.opera in ('analisi', 'Wikizionario-vedi') then 2 else 3 end, 'etimo',
           case when f.opera like 'Wikizionario%' then 'wikizionario' else 'perseus' end, 'importato', f.chiave
      from ed_firme f
     where not exists (select 1 from ipotesi h where h.id_esterno = f.chiave)
       and not exists (select 1 from ipotesi h where h.esito_id = f.esito_id and h.stato = 'accolta')
    on conflict do nothing
    returning id, id_esterno)
  insert into ed_nuove select id, id_esterno from ins;
  get diagnostics n = row_count;
  r := r || jsonb_build_object('etimologie_nuove', n);
  insert into relazione (ipotesi_id, esito_id, etimo_id, tipo, ordine, affisso, confidenza, provenienza, stato_editoriale, id_esterno)
  select e.id, v.esito_id, v.etimo_id, v.tipo, v.ordine, v.affisso, case when v.opera in ('analisi', 'Wikizionario-vedi') then 2 else 3 end,
         case when v.opera like 'Wikizionario%' then 'wikizionario' else 'perseus' end, 'importato', v.chiave || '#' || v.ordine
    from ed_nuove e join ed_voluti v on v.chiave = e.chiave
  on conflict do nothing;
  insert into rimando (opera_id, sv, posizione, ipotesi_id)
  select o.id, f.sv, 'propone', e.id
    from ed_nuove e join ed_firme f on f.chiave = e.chiave
    join opera o on o.sigla = case when f.opera like 'Wikizionario%' then 'Wikizionario' else f.opera end;
  r := r || jsonb_build_object('etimologie_dei_dizionari', (select jsonb_object_agg(lingua, quante) from (
           select l.lingua, count(*) as quante from ipotesi h join lessema l on l.id = h.esito_id
            where h.provenienza in ('perseus', 'wikizionario') group by 1) t));
  return r;
end $$;
comment on function importa_etimi_dizionari() is 'Etimologie del Lewis & Short e dell’LSJ (tag <etym>), e l’analisi della forma (prefisso e base), per le voci di latino e greco che non ne hanno altre: scritte solo dove cambiano.';
