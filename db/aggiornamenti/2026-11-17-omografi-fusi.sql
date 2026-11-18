-- L'abbinamento delle voci del pacchetto alle righe esistenti per lingua, lemma e numero d'omografo non prende più una
-- riga che un'altra voce del pacchetto ha già per identificativo: quando i numeri d'omografo cambiavano tra due
-- pacchetti, due radici omografe diverse (*kap-@head e *kap-@seize) finivano in una riga sola, con le loro famiglie
-- mescolate (260 voci il 17 novembre 2026). La funzione è rigenerata dal file canonico (db/05_import_wiktionary.sql).
-- E le traslitterazioni sbagliate delle forme ricostruite in alfabeto latino (*bʰōw-, «literally») e quelle fatte di HTML
-- si tolgono anche quando il pacchetto non ne dà una nuova.
-- Se l'indirizzo pulito è di un'altra voce (*bʰōw- e *bʰow-), la voce passa al primo numero d'omografo libero.
-- L'antenato di una lingua è quello del pacchetto anche dove ne ha già uno, e una famiglia non è una lingua madre.
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
  -- l'antenato è quello del pacchetto (la genealogia del parser), anche dove la lingua ne ha già uno: un antenato che
  -- saltava una fase (inglese < antico inglese, tedesco < protogermanico, russo < protoslavo, scritti a mano nel seme)
  -- faceva di un'eredità un legame generico, 70.845 eredità su 186.392 il 17 novembre 2026 (eredita_fuori_genealogia)
  update lingua l set antenato = s.antenato
    from stg_lingua s
   where l.codice = s.codice and s.antenato is not null and s.antenato <> l.codice
     and l.antenato is distinct from s.antenato
     and exists (select 1 from lingua x where x.codice = s.antenato);
  get diagnostics n = row_count;
  r := r || jsonb_build_object('antenati_dal_pacchetto', n);
  -- una famiglia non è una lingua madre: il galego-portoghese antico e lo svedese antico erano varietà di «lingua
  -- romanza (non precisata)» e delle germaniche settentrionali (il parser prendeva il prefisso del codice), e
  -- lingue_ascendenti(), che parte dalla madre, non arrivava al latino né al norreno
  update lingua l set varieta_di = null
    from stg_lingua s, lingua p
   where s.codice = l.codice and s.varieta_di is null and p.codice = l.varieta_di
     and p.nome like 'lingua % (non precisata)';
  get diagnostics n = row_count;
  r := r || jsonb_build_object('varieta_di_una_famiglia_tolte', n);
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
  -- per lingua, lemma e numero d'omografo solo una riga che nessun'altra voce del pacchetto ha già preso per
  -- identificativo: se i numeri d'omografo cambiano tra due pacchetti, *kap-@head (omografo 2 nel pacchetto nuovo)
  -- finiva nella riga di *kap-@seize (omografo 2 nel vecchio), e due radici diverse diventavano una famiglia sola (*kap-²,
  -- 3.929 parole; il 17 novembre 2026 260 voci fuse così). La voce senza riga entra come voce nuova, all'omografo libero.
  insert into m_les
  select s.chiave, l.id from stg_lessema s
    join lessema l on l.lingua = s.lingua and l.lemma = s.lemma and l.omografo = s.omografo
   where not exists (select 1 from m_les m where m.chiave = s.chiave)
     and not exists (select 1 from m_les m where m.id = l.id)
     and (l.id_esterno is null or l.id_esterno = s.chiave
          or not exists (select 1 from stg_lessema s2 where s2.chiave = l.id_esterno))
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
       -- di glossa (tucca, «liquid lard(?)») e faceva l'indirizzo; per le altre scritture resta quella che c'è. Anche da
       -- una forma ricostruita in alfabeto latino con pedici, lettere modificatrici e diacritici (*bʰōw-, «literally»:
       -- ine-pro/literally) e ovunque sia un pezzo di HTML (egy/i-class=latn-mention…)
       and (s.translit is not null or l.lemma ~ '^[A-Za-zÀ-ɏḀ-ỿ''’ .·-]+$' or l.translit ~ '[<>]'
            or (l.ricostruito and l.lemma ~ '^[A-Za-zÀ-ɏḀ-ỿɐ-ʯʰ-˿ᴀ-ᶿⱠ-Ɀ꜠-ꟿ₀-₉⁰-⁹ъьЪЬ\u0300-\u036f''’ .·()/⁽⁾~=+*-]+$'))
       and l.translit is distinct from s.translit),
  libere as (
    select distinct on (n.nuovo) n.id, n.translit from nuove n
     where not exists (select 1 from lessema y where y.id <> n.id and y.slug = n.nuovo)
     order by n.nuovo, n.id)
  update lessema l set translit = f.translit from libere f where l.id = f.id;
  -- se l'indirizzo senza la traslitterazione finta è di un'altra voce (*bʰōw- e *bʰow-: ine-pro/bhow), la voce passa al
  -- primo numero d'omografo libero, come una voce nuova qui sotto: altrimenti teneva ine-pro/literally (10 voci il
  -- 17 novembre 2026). Il numero resta finché l'indirizzo è occupato (pulisci_wiktionary(), passo 5)
  for rec in select l.id, l.omografo
               from lessema l join m_scelta s on s.id = l.id
              where l.provenienza = 'wiktionary' and l.stato_editoriale = 'importato'
                and s.translit is null and l.translit is not null
                and (l.lemma ~ '^[A-Za-zÀ-ɏḀ-ỿ''’ .·-]+$' or l.translit ~ '[<>]'
                     or (l.ricostruito and l.lemma ~ '^[A-Za-zÀ-ɏḀ-ỿɐ-ʯʰ-˿ᴀ-ᶿⱠ-Ɀ꜠-ꟿ₀-₉⁰-⁹ъьЪЬ\u0300-\u036f''’ .·()/⁽⁾~=+*-]+$'))
              order by l.id loop
    omo := rec.omografo;
    loop
      omo := omo + 1;
      exit when omo > rec.omografo + 9;
      begin
        update lessema set translit = null, omografo = omo where id = rec.id;
        exit;
      exception when unique_violation then
        null;
      end;
    end loop;
  end loop;

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
