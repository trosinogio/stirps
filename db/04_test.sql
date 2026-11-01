-- =====================================================================
--  Dizionario etimologico — collaudo
--  psql -v ON_ERROR_STOP=1 -f 04_test.sql   (si ferma al primo FALLITO)
--  I test che modificano dati lo fanno in una sottotransazione annullata.
-- =====================================================================
\set ON_ERROR_STOP on
\o /dev/null
set client_min_messages = notice;

create function pg_temp.verifica(p_ok boolean, p_cosa text) returns void language plpgsql as $$
begin
  if p_ok is true then raise notice 'OK      %', p_cosa;
  else raise exception 'FALLITO %', p_cosa; end if;
end $$;

-- esegue i comandi e pretende un errore (eventualmente con un codice preciso)
create function pg_temp.attendi_errore(p_sql text[], p_cosa text, p_codice text default null)
returns void language plpgsql as $$
declare s text;
begin
  begin
    foreach s in array p_sql loop execute s; end loop;
    raise exception using errcode = 'P0099', message = 'nessun errore';
  exception when others then
    if sqlstate = 'P0099' then raise exception 'FALLITO %: nessun errore sollevato', p_cosa; end if;
    if p_codice is not null and sqlstate <> p_codice then
      raise exception 'FALLITO %: atteso %, ottenuto % (%)', p_cosa, p_codice, sqlstate, sqlerrm;
    end if;
    raise notice 'OK      % → «%»', p_cosa, sqlerrm;
  end;
end $$;

-- esegue i comandi, pretende che riescano, poi annulla tutto
create function pg_temp.prova_e_annulla(p_sql text[], p_cosa text) returns void language plpgsql as $$
declare s text;
begin
  begin
    foreach s in array p_sql loop execute s; end loop;
    raise exception using errcode = 'P0098', message = 'annulla';
  exception when others then
    if sqlstate = 'P0098' then raise notice 'OK      %', p_cosa;
    else raise exception 'FALLITO %: %', p_cosa, sqlerrm; end if;
  end;
end $$;

-- ---------------------------------------------------------------------
\echo '— indirizzi e ricerca'
-- ---------------------------------------------------------------------
select pg_temp.verifica(
  (select count(*) from lessema where slug in
    ('it/zefiro', 'it/zefiro-2', 'la/palatium', 'la/palatium-2', 'ru/noc', 'ine-pro/nokwts', 'grc/obelos', 'ar/sifr')) = 8,
  'slug: omografi, traslitterazioni, forme ricostruite');
select pg_temp.verifica((select slug from cerca('obelos', 5, true) limit 1) = 'grc/obelos',
  'ricerca: «obelos» trova ὀβελός');
select pg_temp.verifica((select slug from cerca('οβελος', 5, true) limit 1) = 'grc/obelos',
  'ricerca: greco senza accenti e con ς finale');
select pg_temp.verifica((select slug from cerca('nokwts', 5, true) limit 1) = 'ine-pro/nokwts',
  'ricerca: «nokwts» trova *nókʷts');
select pg_temp.verifica((select slug from cerca('sifr', 5, true) limit 1) = 'ar/sifr',
  'ricerca: «sifr» trova صفر (ṣifr)');
select pg_temp.verifica(exists (select 1 from cerca('fegto', 5, true) where slug = 'it/fegato'),
  'ricerca: tollera un refuso («fegto»)');
select pg_temp.verifica(not exists (select 1 from cerca('fegato', 5)),
  'ricerca pubblica: le voci in bozza non compaiono');

-- ---------------------------------------------------------------------
\echo '— catene'
-- ---------------------------------------------------------------------
select pg_temp.verifica(
  (select array_agg(l.slug order by c.profondita)
     from antenati(lx('it/zero'), '{accolta}', true) c join lessema l on l.id = c.lessema_id)
  = array['it/zefiro-2', 'la-med/zephirum', 'ar/sifr', 'ar/sfr'],
  'catena: zero ← zefiro² ← zephirum ← ṣifr ← radice ṣ-f-r');
select pg_temp.verifica(
  (select array_agg(l.slug order by l.slug)
     from antenati(lx('it/fegato'), '{accolta}', true) c join lessema l on l.id = c.lessema_id)
  = array['grc/sykoton', 'la/ficatum', 'la/ficus'],
  'catena: fegato ← ficatum ← ficus + calco su συκωτόν');
select pg_temp.verifica(not exists (select 1 from antenati(lx('it/andare'), '{accolta}', true)),
  'andare: nessuna ipotesi accolta, catena canonica vuota');
select pg_temp.verifica(
  (select count(distinct lessema_id) from antenati(lx('it/andare'), '{accolta,alternativa}', true)) = 3,
  'andare: con le alternative compaiono ambulare, *ambitare, ambire');
select pg_temp.verifica(
  (select confidenza from antenati(lx('it/andare'), '{accolta,alternativa}', true) c
     join lessema l on l.id = c.lessema_id where l.slug = 'la/ambire') = 2,
  'certezza della catena = anello più debole (ambire: arco certo, ipotesi possibile)');
select pg_temp.verifica(
  (select array_agg(l.slug order by l.slug)
     from discendenti(lx('grc/obelos'), '{accolta}', true) d join lessema l on l.id = d.lessema_id
    where l.lingua = 'it')
  = array['it/obelisco', 'it/obelo', 'it/obolo'],
  'discendenti di ὀβελός in italiano: obelisco, obelo, obolo (la dracma è solo una connessione)');

-- ---------------------------------------------------------------------
\echo '— cognati e allotropi (calcolati)'
-- ---------------------------------------------------------------------
select pg_temp.verifica(
  (select array_agg(l.slug order by l.slug)
     from cognati(lx('it/notte'), true) g join lessema l on l.id = g.lessema_id
    where g.tipo = 'stretto' and not l.ricostruito)
  = array['ang/niht', 'de/nacht', 'en/night', 'es/noche', 'fr/nuit', 'grc/nyx', 'pt/noite', 'ru/noc'],
  'cognati di notte: otto lingue, solo per eredità');
select pg_temp.verifica(
  (select a.slug from cognati(lx('it/notte'), true) g
     join lessema l on l.id = g.lessema_id join lessema a on a.id = g.antenato_comune
    where l.slug = 'en/night') = 'ine-pro/nokwts',
  'notte / night: antenato comune *nókʷts');
select pg_temp.verifica(
  (select a.slug from cognati(lx('it/notte'), true) g
     join lessema l on l.id = g.lessema_id join lessema a on a.id = g.antenato_comune
    where l.slug = 'fr/nuit') = 'la/nox',
  'notte / nuit: antenato comune nox');
select pg_temp.verifica(
  (select string_agg(l.slug || ':' || g.tipo, ' ' order by l.slug)
     from cognati(lx('it/palazzo'), true) g join lessema l on l.id = g.lessema_id)
  = 'en/palace:per_prestito fr/palais:stretto fro/palais:stretto',
  'palazzo: palais cognato stretto, palace parente per prestito');
select pg_temp.verifica(
  (select array_agg(l.slug order by l.slug)
     from cognati(lx('it/fegato'), true) g join lessema l on l.id = g.lessema_id)
  = array['es/higado', 'fr/foie', 'pt/figado'],
  'cognati di fegato: il calco su συκωτόν non conta');
select pg_temp.verifica(
  (select array_agg(least(la.lemma, lb.lemma) || '/' || greatest(la.lemma, lb.lemma)
                    order by least(la.lemma, lb.lemma))
     from mv_allotropi m join lessema la on la.id = m.a_id join lessema lb on lb.id = m.b_id
    where la.lingua = 'it' and not la.obsoleto and not lb.obsoleto)
  = array['causa/cosa', 'cifra/zero', 'obelo/obolo', 'pensare/pesare', 'podio/poggio', 'vezzo/vizio'],
  'allotropi italiani: causa/cosa, cifra/zero, obelo/obolo, pensare/pesare, podio/poggio, vezzo/vizio');
select pg_temp.verifica(
  not exists (select 1 from mv_allotropi
               where (a_id, b_id) in ((lx('it/obelisco'), lx('it/obelo')), (lx('it/obelo'), lx('it/obelisco')))),
  'obelisco e obelo non sono allotropi: obelisco viene da un derivato');
select pg_temp.verifica(
  exists (select 1 from mv_allotropi where a_id = lx('la-med/zephirum') and b_id = lx('la-med/cifra')),
  'il doppione zero/cifra esisteva già nel latino medievale (zephirum/cifra)');

-- ---------------------------------------------------------------------
\echo '— vincoli'
-- ---------------------------------------------------------------------
select pg_temp.attendi_errore(array[
  $q$insert into ipotesi (esito_id, etichetta, stato) values (lx('it/fegato'), 'seconda', 'accolta')$q$],
  'una sola ipotesi accolta per lessema', '23505');
select pg_temp.attendi_errore(array[
  $q$insert into relazione (ipotesi_id, esito_id, etimo_id, tipo) values (ip('it/fegato'), lx('it/notte'), lx('la/nox'), 'eredita')$q$],
  'arco e ipotesi devono riguardare lo stesso esito', '23503');
select pg_temp.attendi_errore(array[
  $q$select collega('la/ficatum', 'it/fegato', 'prestito', p_ipotesi => 'prova', p_stato => 'alternativa')$q$],
  'niente cicli nel grafo', '23514');
select pg_temp.attendi_errore(array[
  $q$update ipotesi set stato_editoriale = 'verificato' where id = ip('la/sincerus', 'sine cera')$q$,
  'set constraints all immediate'],
  'ipotesi verificata senza fonti: rifiutata', '23514');
select pg_temp.prova_e_annulla(array[
  $q$update ipotesi set stato_editoriale = 'verificato' where id = ip('it/fegato')$q$,
  'set constraints all immediate'],
  'ipotesi verificata con fonte (DELI, REW): accettata');
select pg_temp.attendi_errore(array[
  $q$delete from rimando where ipotesi_id = ip('it/fegato')$q$,
  $q$update ipotesi set stato_editoriale = 'verificato' where id = ip('it/fegato')$q$,
  'set constraints all immediate'],
  'tolte le fonti, la verifica non regge', '23514');
select pg_temp.attendi_errore(array[
  $q$update lessema set provenienza = 'redazione' where slug = 'es/higado'$q$],
  'la provenienza Wiktionary non si cancella con una modifica', '23514');
select pg_temp.attendi_errore(array[
  $q$insert into lessema (lingua, lemma) values ('la', 'Palatium')$q$],
  'omografi: lo slug resta univoco', '23505');
select pg_temp.attendi_errore(array[
  $q$insert into lessema (lingua, lemma, ricostruito) values ('la', '*ficatum', true)$q$],
  'l''asterisco non si scrive nel lemma', '23514');

-- ---------------------------------------------------------------------
\echo '— controlli di qualità'
-- ---------------------------------------------------------------------
select pg_temp.verifica(
  exists (select 1 from v_anomalie where controllo = 'ricostruito_attestato' and lessema_id = lx('la-vul/veclus')),
  'anomalie: *veclus è ricostruito ma l''Appendix Probi lo attesta');
select pg_temp.verifica(
  exists (select 1 from v_anomalie where controllo = 'formazione_tra_lingue' and lessema_id = lx('la/sincerus')),
  'anomalie: sincerus composto direttamente da radici indoeuropee');
select pg_temp.prova_e_annulla(array[
  $q$select collega('it/zero', 'ar/sifr', 'eredita', p_ipotesi => 'prova', p_stato => 'alternativa')$q$,
  $q$select pg_temp.verifica(exists (select 1 from v_anomalie where controllo = 'eredita_incoerente' and lessema_id = lx('it/zero')), '  ↳ v_anomalie segnala l''arco')$q$],
  'anomalie: un''«eredità» dall''arabo all''italiano viene segnalata');
select pg_temp.verifica((select count(distinct lessema_id) from v_anomalie) = 2,
  'anomalie: nel seme ce ne sono solo due, entrambe volute');
select pg_temp.verifica((select falso_etimo from v_falsi_miti where slug = 'la/sincerus') = 'sine + cera',
  'falsi miti: «sine cera» registrato e respinto');

-- ---------------------------------------------------------------------
\echo '— scheda (il JSON per il frontend)'
-- ---------------------------------------------------------------------
select pg_temp.verifica(scheda('it/fegato') is null,
  'scheda pubblica: una voce in bozza non esce');
select pg_temp.verifica(
  scheda('es/higado') is not null and jsonb_array_length(scheda('es/higado') -> 'catena') = 0,
  'scheda pubblica: la voce importata esce, ma senza antenati ancora in bozza');
select pg_temp.verifica(
  jsonb_array_length(scheda('it/fegato', true) -> 'catena') = 3
  and jsonb_array_length(scheda('it/fegato', true) -> 'cognati') = 3
  and (scheda('it/fegato', true) -> 'strati') @> '[{"codice": "wiktionary"}]',
  'scheda in anteprima: catena, cognati e attribuzione CC BY-SA per i dati Wiktionary');
select pg_temp.verifica(
  (scheda('it/fegato', true) #>> '{ipotesi,0,relazioni,0,etimo_accezione}') = 'fegato',
  'scheda di fegato: l''arco parte dall''accezione «fegato» di ficatum (ellissi)');
select pg_temp.verifica(
  (scheda('it/sincero', true) #>> '{falsi_miti,0,etichetta}') = 'sine cera',
  'scheda di sincero: il falso mito risale dalla catena latina');
select pg_temp.verifica(
  (select count(*) from jsonb_array_elements(scheda('it/andare', true) -> 'ipotesi') e
    where e ->> 'stato' = 'alternativa') = 2,
  'scheda di andare: due ipotesi alternative, nessuna accolta');
select pg_temp.verifica(
  (scheda('it/obelo', true) #>> '{allotropi,0,antenato_comune,slug}') = 'grc/obelos',
  'scheda di obelo: allotropo di obolo, antenato comune ὀβελός');

-- ---------------------------------------------------------------------
\echo '— apparato'
-- ---------------------------------------------------------------------
select pg_temp.prova_e_annulla(array[
  $q$set local app.utente = 'giovanni'$q$,
  $q$update lessema set glossa = 'organo addominale che secerne la bile' where slug = 'it/fegato'$q$,
  $q$select pg_temp.verifica(exists (select 1 from storico where tabella = 'lessema' and record_id = lx('it/fegato') and operazione = 'U' and prima ->> 'glossa' = 'organo che secerne la bile' and dopo ->> 'glossa' like 'organo addominale%' and utente = 'giovanni'), '  ↳ storico: riga prima/dopo con autore')$q$],
  'apparato: modifica registrata con riga prima e dopo e con l''autore');


-- ---------------------------------------------------------------------
\echo '— radici (v0.2)'
-- ---------------------------------------------------------------------
select pg_temp.verifica(
  (select dichiarata and discendenti >= 20 and lingue >= 10 from v_radici where slug = 'ine-pro/ped'),
  'radici: *ped- è una radice dichiarata con oltre venti discendenti in più di dieci lingue');
select pg_temp.verifica((select dichiarata from v_radici where slug = 'ar/sfr'),
  'radici: la radice semitica ṣ-f-r vale come quelle indoeuropee');
select pg_temp.verifica((select not dichiarata from v_radici where slug = 'la/vitium'),
  'radici: vitium è un capostipite provvisorio, l’etimologia va ancora risalita');
select pg_temp.verifica(
  (select count(*) from discendenti(lx('ine-pro/h2ster'), '{accolta}', true) d
     join lessema l on l.id = d.lessema_id where l.slug in ('en/star', 'en/disaster', 'it/stella', 'it/astro')) = 4,
  'famiglia di *h₂stḗr: star e disaster, stella e astro, per vie diverse');
select pg_temp.verifica(
  (select array_agg(l.slug order by l.slug)
     from cognati(lx('it/madre'), true) g join lessema l on l.id = g.lessema_id
    where g.tipo = 'stretto' and not l.ricostruito and l.lingua in ('ru', 'sa', 'en', 'grc'))
  = array['en/mother', 'grc/meter', 'ru/mat', 'sa/matr'],
  'cognati di madre: mother, μήτηρ, мать, mātṛ́');
select pg_temp.verifica(
  not exists (select 1 from cognati(lx('it/madre'), true) g join lessema l on l.id = g.lessema_id
               where l.slug in ('la/maternus', 'la/matrix', 'grc/metropolis')),
  'cognati di madre: i derivati (maternus, matrix, μητρόπολις) sono famiglia, non cognati');
select pg_temp.verifica(
  exists (select 1 from mv_allotropi
           where (a_id, b_id) in ((lx('en/zero'), lx('en/cipher')), (lx('en/cipher'), lx('en/zero')))),
  'allotropi inglesi: zero e cipher, dalla stessa parola araba');
select pg_temp.verifica((select slug from cerca('fuss', 5, true) limit 1) = 'de/fuss',
  'ricerca: «fuss» trova Fuß');
select pg_temp.verifica((select slug from cerca('мать', 5, true) limit 1) = 'ru/mat',
  'ricerca: cirillico diretto');


-- ---------------------------------------------------------------------
\echo '— multilinguismo (v0.3)'
-- ---------------------------------------------------------------------
select pg_temp.verifica(
  (select s->'lessema'->>'glossa' = 'liver' and s->'lessema'->>'glossa_lingua' = 'en' and s->'lessema'->>'lingua_nome' = 'Italian'
     from (select scheda('it/fegato', true, 'en') s) x),
  'scheda in inglese: glossa, lingua della glossa e nome della lingua tradotti');
select pg_temp.verifica(
  (select s->'lessema'->>'glossa' = 'organo che secerne la bile' and s->'lessema'->>'glossa_lingua' = 'it'
     from (select scheda('it/fegato', true, 'fr') s) x),
  'ripiego dichiarato: senza glossa francese torna quella di base, con la sua lingua');
select pg_temp.verifica(
  (select s#>>'{ipotesi,0,relazioni,0,tipo_etichetta}' = 'inherited' and s#>>'{catena,0,glossa}' like 'liver%'
     from (select scheda('it/fegato', true, 'en') s) x),
  'scheda in inglese: tipi di arco e glosse degli antenati tradotti');
select pg_temp.verifica(
  (select s#>>'{ipotesi,0,relazioni,0,etimo_accezione}' = 'liver' from (select scheda('it/fegato', true, 'en') s) x),
  'scheda in inglese: anche le accezioni hanno la loro traduzione');
select pg_temp.verifica(
  (select array_agg(slug order by slug) from cerca_universale('liver', 'en', 20, true) where per_significato)
  @> array['es/higado', 'fr/foie', 'it/fegato', 'la/ficatum', 'pt/figado'],
  'ricerca per significato: «liver» trova fegato, foie, hígado, fígado, ficatum');
select pg_temp.verifica((select slug from cerca_universale('mother', 'en', 20, true) limit 1) = 'en/mother',
  'ricerca universale: la corrispondenza sul lemma viene prima di quella sul significato');
select pg_temp.verifica(
  exists (select 1 from cerca_universale('madre', 'it', 20, true) where slug = 'la/mater' and per_significato),
  'ricerca per significato in italiano: «madre» trova mater');
select pg_temp.verifica(
  (select count(*) from cerca_universale('liver', 'it', 20, true)) = 0,
  'la ricerca per significato usa solo le glosse della lingua d’interfaccia');
select pg_temp.verifica(
  (select i #>> '{radici,0,lingua_nome}' = 'Proto-Indo-European'
          and exists (select 1 from jsonb_array_elements(i->'lingue') l where l->>'codice' = 'it' and l->>'nome' = 'Italian')
     from (select indice('en', true) i) x),
  'indice in inglese: radici e lingue con i nomi tradotti');
select pg_temp.verifica((select (indice('it', false)->'totali'->>'lessemi')::int) = 2,
  'indice pubblico: solo i due lessemi importati, il resto è in bozza');
select pg_temp.attendi_errore(array[
  $q$insert into glossa (lessema_id, lingua, testo) values (lx('it/fegato'), 'en', 'liver (again)')$q$],
  'una sola glossa per lessema e lingua', '23505');
select pg_temp.prova_e_annulla(array[
  $q$insert into glossa (lessema_id, lingua, testo) values (lx('it/fegato'), 'it', 'fegato')$q$,
  $q$select pg_temp.verifica(exists (select 1 from v_anomalie where controllo = 'traduzione_nella_lingua_di_base'), '  ↳ v_anomalie segnala la traduzione superflua')$q$],
  'anomalie: una traduzione nella lingua della glossa di base viene segnalata');

\echo '— bibliografia e opere da consultare (v0.5)'
select pg_temp.verifica((select count(*) from opera) >= 40, 'la bibliografia raccoglie le opere di riferimento di ogni ambito');
select pg_temp.verifica(
  (select array_agg(x->>'sigla' order by x->>'sigla') from jsonb_array_elements(scheda('it/fegato', true, 'it')->'consultabili') x) @> array['Pianigiani', 'Treccani'],
  'fegato si può consultare nel Treccani e nel Pianigiani');
select pg_temp.verifica(
  exists (select 1 from jsonb_array_elements(scheda('la/ficatum', true, 'it')->'consultabili') x where x->>'sigla' = 'Logeion'),
  'ficatum si può consultare in Logeion');
select pg_temp.verifica(
  jsonb_array_length(scheda('ine-pro/ped', true, 'it')->'consultabili') = 0,
  'le forme ricostruite non rimandano a dizionari in rete');
select pg_temp.verifica(
  (scheda('la-med/cifra', true, 'it')->'lessema'->>'wiktionary_lingua') = 'Latin',
  'il latino medievale rimanda alla voce latina di Wiktionary');

\echo '— collaudo completato'
