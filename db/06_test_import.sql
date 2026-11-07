-- =====================================================================
--  Dizionario etimologico — collaudo dell'import da Wiktionary
--  Si esegue dopo aver caricato import/esempio/ con import/collauda.sh.
-- =====================================================================
\set ON_ERROR_STOP on
\o /dev/null
set client_min_messages = notice;

create function pg_temp.verifica(p_ok boolean, p_cosa text) returns void language plpgsql as $$
begin
  if p_ok is true then raise notice 'OK      %', p_cosa;
  else raise exception 'FALLITO %', p_cosa; end if;
end $$;

create function pg_temp.antenati_slug(p text) returns text[] language sql as $$
  select array_agg(l.slug order by a.profondita, l.slug) from antenati(lx(p), '{accolta,alternativa}', true) a join lessema l on l.id = a.lessema_id
$$;

\echo '— catene'
select pg_temp.verifica(pg_temp.antenati_slug('it/carne') @> array['la/caro', 'itc-pro/karo'],
  'carne < caro < *karō: la catena si legge dal testo');
select pg_temp.verifica((select forma_citata from relazione where esito_id = lx('it/carne') and etimo_id = lx('la/caro')) = 'carnem',
  'la forma citata conserva la grafia di Wiktionary (carnem)');
select pg_temp.verifica(pg_temp.antenati_slug('it/carne') @> array[(select slug from lessema where id_esterno = 'enwikt:ine-pro:*(s)ker-@cut')],
  'la catena arriva alla radice dichiarata, *(s)ker- «tagliare», non al nodo generico delle omografe');
select pg_temp.verifica((select tipo from relazione where esito_id = lx('itc-pro/karo')
                                and etimo_id = (select id from lessema where id_esterno = 'enwikt:ine-pro:*(s)ker-@cut')) in ('derivazione', 'generico'),
  'dalla radice si arriva per formazione o per legame indeterminato, mai per eredità: niente falsi allotropi');
select pg_temp.verifica(pg_temp.antenati_slug('it/abate') @> array['la/abbas', 'arc/abba']
                        and pg_temp.antenati_slug('it/abate') && array['grc/abba', 'grc/abbas'],
  'abate < latino tardo abbās < greco ἀββα, ἀββᾶς < aramaico: il latino tardo confluisce nel latino');

\echo '— alternative e incertezza'
select pg_temp.verifica(
  (select h.stato = 'accolta' and h.confidenza = 2 from ipotesi h where h.esito_id = lx('it/terrazzo') and h.etichetta = 'Wiktionary'),
  'terrazzo: «From terra, or from *terraceus» è l’unica ipotesi: accolta, ma solo possibile (certezza 2)');
select pg_temp.verifica(
  (select h.stato = 'accolta' and h.confidenza = 3 from ipotesi h where h.esito_id = lx('it/chiaroscuro') and h.etichetta = 'Wiktionary'),
  'chiaroscuro: «oscuro (“dark, obscure”)» non è un dubbio, le glosse tra virgolette non contano');
select pg_temp.verifica(
  exists (select 1 from ipotesi h join lessema l on l.id = h.esito_id
           where l.lingua = 'it' and l.lemma = 'curva' and h.stato = 'accolta' and h.origine = 'ignota'),
  'curva: «Unknown» è un’ipotesi accolta di origine ignota, non un vuoto');
select pg_temp.verifica(
  (select array_agg(e.lemma order by r.ordine) from relazione r join lessema e on e.id = r.etimo_id
    join ipotesi h on h.id = r.ipotesi_id and h.stato = 'accolta' where r.esito_id = lx('it/fotografia')) = array['foto-', '-grafia']
  and exists (select 1 from relazione r join lessema e on e.id = r.etimo_id join lessema x on x.id = r.esito_id
               where x.lingua = 'it' and x.lemma = 'foto-' and e.lingua = 'grc'),
  'fotografia = foto- + -grafia: una formazione di soli elementi si lega agli elementi, e foto- risale al greco');
select pg_temp.verifica(
  (select tipo from relazione where esito_id = lx('la-vul/terraceus') and etimo_id = lx('la/terra')) = 'generico',
  '*terraceus < terra: tra due parole diverse del latino non c’è eredità');
select pg_temp.verifica(
  exists (select 1 from ipotesi h where h.esito_id = lx('it/cicisbeo') and h.origine = 'onomatopea')
  and not exists (select 1 from relazione r where r.esito_id = lx('it/cicisbeo')),
  'cicisbeo: onomatopea, nessun etimo');

\echo '— formazioni'
select pg_temp.verifica(
  (select tipo = 'derivazione' and affisso = '-avo' from relazione where esito_id = lx('it/centavo') and etimo_id = lx('it/cento')),
  'centavo < cento + -avo: derivazione, l’affisso resta testo dell’arco');
select pg_temp.verifica(
  (select tipo = 'derivazione' and affisso = 'retro-' from relazione where esito_id = lx('it/retrovirus') and etimo_id = lx('it/virus')),
  'retrovirus < retro- + virus');
select pg_temp.verifica(
  (select tipo from relazione where esito_id = lx('it/torta-2') and etimo_id = lx('it/torto')) = 'retroformazione',
  'torta² < torto: retroformazione, e il secondo etimo di torta è un omografo');

\echo '— la redazione prevale'
select pg_temp.verifica(
  (select stato from ipotesi where esito_id = lx('it/fegato') and etichetta = 'principale') = 'accolta'
  and (select stato from ipotesi where esito_id = lx('it/fegato') and etichetta = 'Wiktionary') = 'alternativa',
  'fegato: l’ipotesi di redazione resta accolta, quella di Wiktionary entra come alternativa');
select pg_temp.verifica((select provenienza from lessema where slug = 'it/fegato') = 'redazione',
  'il lessema di redazione non cambia provenienza');
select pg_temp.verifica(
  (select count(*) from lessema where lemma = 'cifra' and lingua in ('la', 'la-med')) = 1,
  'la cifra di Wiktionary (latino) si riconosce nel lat. mediev. cifra del seme: nessun doppione');
select pg_temp.verifica(
  (select nota_lingua from ipotesi where esito_id = lx('it/carne') and etichetta = 'Wiktionary') = 'en',
  'le note di Wiktionary dichiarano la loro lingua');

\echo '— calcoli sui dati importati'
select pg_temp.verifica(
  exists (select 1 from mv_allotropi where (a_id, b_id) in ((lx('it/posare'), lx('it/pausare')), (lx('it/pausare'), lx('it/posare')))),
  'posare e pausare: allotropi dallo stesso pauso (latino tardo e latino sono la stessa voce)');
select pg_temp.verifica((select count(*) from v_validazione_wiktionary) = 5, 'la vista di validazione risponde');

\echo '— chiusura delle catene (latino e francese antico)'
select pg_temp.verifica(
  exists (select 1 from ipotesi h join relazione r on r.ipotesi_id = h.id
           where h.esito_id = lx('la/caro') and h.id_esterno = 'enwikt:la:caro#wikt' and r.etimo_id = lx('itc-pro/karo') and r.tipo = 'eredita'),
  'caro ha la sua etimologia dalla voce latina: eredità da *karō');
select pg_temp.verifica(
  not exists (select 1 from antenati(lx('it/carne'), '{accolta}', true) a join lessema l on l.id = a.lessema_id
               where l.lingua = 'ine-pro' and 'generico' = any(a.tipi))
  and exists (select 1 from antenati(lx('it/carne'), '{accolta}', true) a join lessema l on l.id = a.lessema_id where l.lingua = 'ine-pro'),
  'carne arriva alla radice indoeuropea senza legami indeterminati');
select pg_temp.verifica(
  exists (select 1 from mv_allotropi where (a_id, b_id) in ((lx('it/burro'), lx('it/butirro')), (lx('it/butirro'), lx('it/burro')))),
  'burro e butirro sono allotropi: la voce del francese antico bure dichiara l’eredità da butyrum');
select pg_temp.verifica(
  (select string_agg(e.slug, ',') from relazione r join lessema e on e.id = r.etimo_id where r.esito_id = lx('it/fondare') and r.provenienza = 'wiktionary') = 'la/fundo-2'
  and (select string_agg(e.slug, ',') from relazione r join lessema e on e.id = r.etimo_id where r.esito_id = lx('it/fondere') and r.provenienza = 'wiktionary') = 'la/fundo',
  'omografi latini: fondare da fundō² (fundāre), fondere da fundō¹ (fundere), distinti dall’infinito citato');
select pg_temp.verifica(
  (select tipo from relazione where esito_id = lx('la/apertus') and etimo_id = lx('la/aperio')) = 'derivazione'
  and not exists (select 1 from mv_allotropi where (a_id, b_id) in ((lx('it/aperto'), lx('it/aprire')), (lx('it/aprire'), lx('it/aperto')))),
  'il participio resta una parola: aperto < apertus < aperiō per derivazione, e aperto non è allotropo di aprire');
select pg_temp.verifica(
  (select tipo from relazione where esito_id = lx('la/illorum') and etimo_id = lx('la/ille')) = 'generico'
  and not exists (select 1 from mv_allotropi where (a_id, b_id) in ((lx('it/egli'), lx('it/loro')), (lx('it/loro'), lx('it/egli')))),
  'loro < illōrum, forma di ille: legame indeterminato, e loro non è allotropo di egli');

\echo '— chiusura sul greco antico'
select pg_temp.verifica(pg_temp.antenati_slug('it/burro') @> array['grc/bouturon', 'grc/bous', 'grc/turos'],
  'burro < butyrum < βούτυρον, composto di βοῦς «vacca» e τυρός «formaggio»: la chiusura legge le voci greche');
select pg_temp.verifica(pg_temp.antenati_slug('it/burro') @> array['ine-pro/tuh2ros', 'ine-pro/gwows'],
  'con più passaggi la catena prosegue dentro il greco fino al protoindoeuropeo: *gʷṓws «vacca», *tuh₂-ró-s «formaggio»');
select pg_temp.verifica(not exists (select 1 from relazione x join ipotesi h on h.id = x.ipotesi_id
                                     where x.esito_id = lx('grk-pro/gwous') and h.stato = 'accolta' and x.etimo_id <> lx('ine-pro/gwows')),
  'un inciso tra parentesi («compare Mycenaean qo-o») non interrompe la catena: *gʷous < *gʷṓws');
select pg_temp.verifica((select count(*) from lessema where lingua = 'grc' and slug ~ '[^ -~]') = 0,
  'le parole greche citate senza traslitterazione hanno comunque un indirizzo in caratteri latini');
select pg_temp.verifica((select count(*) from lessema where lingua = 'arc' and slug like 'arc/abba%') = 1,
  'una sola voce aramaica per אבא: i segni vocalici non creano doppioni');

\echo '— latino e greco interi (--intere la,grc)'
select pg_temp.verifica(lx('la/carus') is not null
                        and not exists (select 1 from relazione x where x.etimo_id = lx('la/carus') and x.provenienza = 'wiktionary'),
  'una voce latina che nessuna catena italiana raggiunge entra lo stesso: cārus');
select pg_temp.verifica(pg_temp.antenati_slug('la/carus') @> array['itc-pro/karos', 'ine-pro/keh2ros'],
  'e porta con sé la sua catena: cārus < *kāros < *kéh₂ros');
select pg_temp.verifica(pg_temp.antenati_slug('la/fundus') @> array['itc-pro/fundos', 'ine-pro/bhudhmnos'],
  'fundus < *fundos < *bʰudʰ-(m)n-o-s: anche le voci intere chiudono le catene fino al protoindoeuropeo');
select pg_temp.verifica((select count(*) from lessema where lingua = 'la' and slug like 'la/fundo%') >= 2,
  'gli omografi latini entrano ciascuno con la sua etimologia (fundō, fundere e fundō, fundāre)');
select pg_temp.verifica(pg_temp.antenati_slug('la/levir') @> array['ine-pro/dayh2wer']
                        and pg_temp.antenati_slug('grc/daer') @> array['ine-pro/dayh2wer'],
  'lēvir e δαήρ, «cognato», entrano interi e si ritrovano nella stessa radice *dayh₂wḗr');
select pg_temp.verifica(not exists (select 1 from lessema where slug in ('la/baba', 'la-vul/baba')),
  'una forma ricostruita che nessuna catena cita resta fuori, anche con il latino intero (*baba)');
select pg_temp.verifica((select glossa from lessema where slug = 'la/caros') = 'heavy sleep, stupor, torpor'
                        and not exists (select 1 from ipotesi where esito_id = lx('la/caros')),
  'un lemma latino senza etimologia entra lo stesso, con la sua glossa e senza catena: la lingua è completa (cāros)');
select pg_temp.verifica(not exists (select 1 from lessema where lemma in ('A', '☉', 'Ϝ')) and lx('la/carus') is not null,
  'non sono parole e restano fuori: lettere isolate (A, Ϝ) e simboli (☉)');
select pg_temp.verifica(
  (select chiave_indice is null from lessema where lingua = 'grc' and lemma = 'ϝοῖκος')
  and exists (select 1 from lessema l join lingua g on g.codice = l.lingua
               where l.lemma = '𐠀𐠙' and l.lingua = 'grc-arp' and g.varieta_di = 'grc' and l.chiave_indice is not null),
  'ϝοῖκος resta una voce del greco, fuori dall''indice a 24 lettere; il sillabario cipriota è greco arcadocipriota, con il suo indice');

\echo '— glosse italiane dal Wikizionario e prime attestazioni'
select pg_temp.verifica(
  (select testo from glossa where lessema_id = lx('it/carne') and lingua = 'it' and provenienza = 'wikizionario') like 'l''insieme dei tessuti muscolari%',
  'carne ha una glossa italiana dal Wikizionario');
select pg_temp.verifica(
  (nodo_json(lx('it/carne'), 'it', true)->>'glossa_lingua') = 'it' and (nodo_json(lx('it/carne'), 'en', true)->>'glossa_lingua') = 'en',
  'l’interfaccia italiana mostra la glossa italiana, quella inglese resta inglese');
select pg_temp.verifica(
  (select testo from glossa where lessema_id = lx('la/caro') and lingua = 'it') = 'carne',
  'anche gli etimi hanno la glossa italiana: lat. caro «carne»');
select pg_temp.verifica(
  not exists (select 1 from glossa where lessema_id in (lx('it/torta'), lx('it/torta-2')) and provenienza = 'wikizionario'),
  'due omografi con la stessa parte del discorso (torta, torta²): nessuna glossa indovinata');
select pg_temp.verifica(
  not exists (select 1 from glossa where lessema_id = lx('it/fegato') and provenienza = 'wikizionario'),
  'fegato ha già la glossa italiana di redazione: il Wikizionario non la duplica');
select pg_temp.verifica(
  exists (select 1 from jsonb_array_elements(scheda('it/carne', true, 'it')->'strati') x where x->>'codice' = 'wikizionario'),
  'la voce cita il Wikizionario tra le fonti quando ne mostra le glosse');
create temp table glosse_prima as select count(*) as n from glossa where provenienza = 'wikizionario';
select importa_glosse_wikizionario();
select pg_temp.verifica((select count(*) from glossa where provenienza = 'wikizionario') = (select n from glosse_prima),
  'reimport delle glosse idempotente');
select pg_temp.verifica(
  (select anno_da = 1590 and precisione = 'esatta' and provenienza = 'wiktionary' from attestazione where lessema_id = lx('it/pizza')),
  'pizza: prima attestazione 1590, secondo Wiktionary');

\echo '— glosse aggiuntive: Wikidata e traduzione automatica'
-- come nel caricamento: le glosse aggiuntive vengono sempre dopo quelle del Wikizionario
select importa_glosse_aggiuntive();
select pg_temp.verifica((select testo || '|' || provenienza from glossa where lessema_id = lx('it/pausare') and lingua = 'it') = 'fare una pausa|wikidata',
  'una definizione di Wikidata per una parola italiana senza glossa, con la stessa parte del discorso');
select pg_temp.verifica(not exists (select 1 from glossa where lessema_id = lx('it/centavo') and lingua = 'it' and provenienza = 'wikidata'),
  'Wikidata non entra se la parte del discorso non corrisponde (aggettivo per un sostantivo)');
select pg_temp.verifica(not exists (select 1 from glossa where lessema_id = lx('it/cento') and lingua = 'it' and provenienza = 'wikidata'),
  'una «glossa» di Wikidata che comincia con la maiuscola è un''etichetta, non una definizione: non entra');
select pg_temp.verifica((select testo || '|' || provenienza from glossa where lessema_id = lx('la/mobilis') and lingua = 'it') = 'mobile, sciolto|traduzione-automatica',
  'la traduzione automatica dà una glossa italiana a un etimo che non ne ha, dichiarata come tale');
select pg_temp.verifica((select testo || '|' || provenienza from glossa where lessema_id = lx('la/caro') and lingua = 'it') = 'carne|wikizionario',
  'la traduzione automatica non scavalca il Wikizionario');
select pg_temp.verifica((nodo_json(lx('la/mobilis'), 'it')->>'glossa_automatica')::boolean
                        and not (nodo_json(lx('la/caro'), 'it')->>'glossa_automatica')::boolean,
  'le glosse tradotte automaticamente sono segnate come tali');
create temp table glosse_xmin as select id, xmin::text as x from glossa;
select importa_glosse_wikizionario();
select importa_glosse_aggiuntive();
select pg_temp.verifica((select count(*) from glossa where provenienza in ('wikidata', 'traduzione-automatica')) = 2,
  'un nuovo import delle glosse rimette le stesse glosse aggiuntive, senza doppioni');
select pg_temp.verifica(
  (select count(*) from glosse_xmin p join glossa g on g.id = p.id and g.xmin::text = p.x) = (select count(*) from glosse_xmin)
  and (select count(*) from glossa) = (select count(*) from glosse_xmin),
  'e non riscrive nessuna glossa');

\echo '— reimport'
-- con gli stessi dati un nuovo import non riscrive niente: ogni riga riscritta occupa spazio fino al vacuum
create temp table righe_prima as
  select 'lessema' as t, id, xmin::text as x from lessema where provenienza = 'wiktionary'
  union all select 'ipotesi', id, xmin::text from ipotesi where provenienza = 'wiktionary'
  union all select 'relazione', id, xmin::text from relazione where provenienza = 'wiktionary';
select importa_wiktionary();
select pg_temp.verifica(
  (select count(*) from righe_prima p
    where p.x is distinct from case p.t when 'lessema' then (select xmin::text from lessema where id = p.id)
                                        when 'ipotesi' then (select xmin::text from ipotesi where id = p.id)
                                        else (select xmin::text from relazione where id = p.id) end) = 0
  and (select count(*) from righe_prima) > 100,
  'un nuovo import con gli stessi dati non riscrive nessuna voce, ipotesi o arco: lo spazio non cresce');
create temp table prima as select count(*) as n from relazione where provenienza = 'wiktionary';
update relazione set stato_editoriale = 'rivisto'
 where esito_id = lx('it/carne') and etimo_id = lx('la/caro') and provenienza = 'wiktionary';
select importa_wiktionary();
select pg_temp.verifica((select count(*) from relazione where provenienza = 'wiktionary') = (select n from prima),
  'reimport idempotente: stesso numero di archi');
select pg_temp.verifica(
  (select count(*) from relazione where esito_id = lx('it/carne') and etimo_id = lx('la/caro')) = 1
  and (select stato_editoriale from relazione where esito_id = lx('it/carne') and etimo_id = lx('la/caro')) = 'rivisto',
  'un arco rivisto dalla redazione sopravvive al reimport, senza doppioni');

-- un'ipotesi verificata dalla redazione, i cui archi sono rimasti «importato», non perde la sua catena
create temp table verificata as
  select h.id, (select count(*) from relazione x where x.ipotesi_id = h.id) as archi
    from ipotesi h where h.esito_id = lx('it/burro') and h.provenienza = 'wiktionary' and h.stato = 'accolta' limit 1;
insert into rimando (opera_id, sv, posizione, ipotesi_id)
  select (select id from opera where sigla = 'DELI'), 'burro', 'accoglie', id from verificata;
update ipotesi set stato_editoriale = 'verificato' where id = (select id from verificata);
select importa_wiktionary();
select pg_temp.verifica(
  (select archi from verificata) > 0
  and (select count(*) from relazione x join verificata v on v.id = x.ipotesi_id) = (select archi from verificata),
  'un''ipotesi verificata conserva al reimport i suoi archi importati');

-- un abbinamento largo non deve fondere parole diverse: Τύρος (la città) non è τυρός (il formaggio).
-- Come in produzione: la città c'è già quando il formaggio arriva per la prima volta
delete from relazione where etimo_id = lx('grc/turos') or esito_id = lx('grc/turos');
delete from lessema where id = lx('grc/turos');
insert into lessema (lingua, lemma, omografo, ricostruito, translit, glossa, glossa_lingua, provenienza, stato_editoriale, id_esterno)
  values ('grc', 'Τύρος', 1, false, 'Túros', 'Tyre', 'en', 'wiktionary', 'importato', 'enwikt:grc:Τύρος');
select importa_wiktionary();
select pg_temp.verifica(
  (select count(*) from lessema where lingua = 'grc' and lemma = 'τυρός') = 1
  and (select glossa from lessema where lingua = 'grc' and lemma = 'Τύρος') = 'Tyre'
  and (select bool_or(e.lemma = 'τυρός') and not bool_or(e.lemma = 'Τύρος')
         from relazione x join lessema e on e.id = x.etimo_id where x.esito_id = lx('grc/bouturon')),
  'un nuovo import non fonde parole diverse per maiuscola o accento: Τύρος non è τυρός');

\echo '— dizionari del Perseus (Lewis & Short, LSJ)'
select pg_temp.verifica(
  (select l.provenienza = 'perseus' and l.glossa = 'grasshopper, locust, cricket' and l.glossa_lingua = 'en'
          and l.stato_editoriale = 'importato' and l.translit = 'akrís' and l.id_esterno = 'perseus:lsj:n3486'
     from lessema l where l.slug = 'grc/akris')
  and not exists (select 1 from ipotesi where esito_id = lx('grc/akris')),
  'un lemma che ha solo il dizionario entra con la sua glossa, come strato «perseus», senza catena: ἀκρίς, «cavalletta»');
select pg_temp.verifica(
  (select lemma from lessema where slug = 'grc/akris-2') = 'ἄκρις'
  and (select provenienza from lessema where slug = 'la/carus') = 'wiktionary'
  and (select lemma || ' ' || provenienza from lessema where slug = 'la/carus-2') = 'Carus perseus',
  'due parole con lo stesso indirizzo (ἀκρίς e ἄκρις, carus e Carus): la nuova prende il numero d''omografo libero');
select pg_temp.verifica(
  (select glossa from lessema where slug = 'la/abactus') is null
  and (select glossa from lessema where slug = 'la/abactus-2') = 'a driving away, robbing',
  'gli omografi del dizionario entrano nel suo ordine (abactus¹, abactus²)');
select pg_temp.verifica(
  not exists (select 1 from lessema where provenienza = 'perseus' and lemma in ('carus', 'levir', 'τυρός', 'δαήρ'))
  and (select count(*) from lessema where lingua = 'la' and lemma = 'levir') = 1,
  'i lemmi che Wiktionary ha già restano fuori, anche se il pacchetto li elenca (carus, lēvir, τυρός, δαήρ)');
select pg_temp.verifica(
  exists (select 1 from jsonb_array_elements(scheda('grc/akris', true, 'it')->'strati') x
           where x->>'codice' = 'perseus' and x->>'licenza' = 'CC BY-SA 4.0' and x->>'attribuzione' like '%perseus.tufts.edu%')
  and exists (select 1 from jsonb_array_elements(scheda('grc/akris', true, 'en')->'strati') x
               where x->>'codice' = 'perseus' and x->>'attribuzione' like 'Contains headwords%'),
  'la pagina della voce cita il Perseus e la licenza CC BY-SA 4.0, in italiano e in inglese');
create temp table d_prima as select id, slug, glossa from lessema where provenienza = 'perseus';
select pg_temp.verifica(
  (select (r->>'voci_nuove')::int = 0 and (r->>'voci_tolte')::int = 0 and (r->>'voci_aggiornate')::int = 0
     from importa_dizionari() r)
  and (select count(*) from lessema l join d_prima p on p.id = l.id and p.slug = l.slug
                                                    and p.glossa is not distinct from l.glossa) = (select count(*) from d_prima)
  and (select count(*) from lessema where provenienza = 'perseus') = (select count(*) from d_prima),
  'un nuovo import dei dizionari non cambia niente: stesse voci, stessi indirizzi');
insert into stg_glossa_tradotta values ('perseus:lsj:n3486', 'grasshopper, locust, cricket', 'cavalletta, locusta, grillo'),
                                       ('perseus:lsj:n3485', 'hill-top', 'cima');   -- tradotta da una glossa che non c'è più
select importa_glosse_wikizionario();
select importa_glosse_aggiuntive();
select pg_temp.verifica(
  (select testo from glossa where lessema_id = lx('grc/akris') and lingua = 'it' and provenienza = 'traduzione-automatica')
    = 'cavalletta, locusta, grillo'
  and (nodo_json(lx('grc/akris'), 'it')->>'glossa_automatica')::boolean,
  'anche le voci dei dizionari ricevono la glossa tradotta, segnata ≈');
select pg_temp.verifica(not exists (select 1 from glossa where lessema_id = lx('grc/akris-2') and lingua = 'it'),
  'una traduzione fatta da una glossa inglese diversa da quella di oggi non si usa (ἄκρις: «hill-top», non «hill-top, mountain peak»)');
-- Wiktionary arriva a una parola che c'era solo nel dizionario
insert into stg_lessema (chiave, lingua, lemma, omografo, ricostruito, translit, pos, glossa)
  values ('enwikt:grc:βαβαί', 'grc', 'βαβαί', 1, false, 'babaí', 'inter.', 'bless me!');
select importa_wiktionary();
select importa_dizionari();
select pg_temp.verifica(
  (select provenienza || ' ' || lemma from lessema where slug = 'grc/babai') = 'wiktionary βαβαί'
  and not exists (select 1 from lessema where provenienza = 'perseus' and lemma = 'βαβαί'),
  'quando Wiktionary arriva a una parola del dizionario, la voce del dizionario gli cede il posto e l''indirizzo (βαβαί)');
-- … e a una che la redazione ha già toccato
insert into glossa (lessema_id, lingua, testo, provenienza, stato_editoriale)
  values (lx('la/carus-2'), 'it', 'cognome romano', 'redazione', 'rivisto');
insert into stg_lessema (chiave, lingua, lemma, omografo, ricostruito, translit, pos, glossa)
  values ('enwikt:la:Carus', 'la', 'Carus', 1, false, null, 'np', 'a Roman cognomen');
select importa_wiktionary();
select importa_dizionari();
select pg_temp.verifica(
  (select count(*) from lessema where lingua = 'la' and lemma = 'Carus') = 1
  and (select provenienza from lessema where slug = 'la/carus-2') = 'perseus'
  and (select testo from glossa where lessema_id = lx('la/carus-2') and lingua = 'it') = 'cognome romano',
  'una voce del dizionario toccata dalla redazione resta, e Wiktionary la abbina senza doppioni (Carus)');
delete from stg_dizionario where chiave = 'perseus:ls:n8';
select importa_dizionari();
select pg_temp.verifica(
  not exists (select 1 from lessema where id_esterno = 'perseus:ls:n8')
  and (select glossa from lessema where slug = 'la/abactus-2') = 'a driving away, robbing',
  'una voce del dizionario che il pacchetto non ha più si toglie, se nessuno l''ha toccata; le altre restano dove sono');

\echo '— stime della prima attestazione dai dizionari'
select pg_temp.verifica(
  (select a.stima and a.anno_da = -184 and a.testo = 'Plauto' and a.banca_dati = 'Lewis & Short' and a.confidenza = 3
          and a.url like 'https://scaife.perseus.org/library/urn:cts:latinLit:phi0119%'
     from attestazione a where a.lessema_id = lx('la/carus') and a.id_esterno like 'stima:%')
  and exists (select 1 from autore where lingua = 'la' and sigla = 'phi0119' and nome = 'Plauto'),
  'carus: almeno dal 184 a.C., Plauto secondo il Lewis & Short, con il link all''opera; l''autore è nella tabella autore');
select pg_temp.verifica(
  (select a.precisione = 'secolo' and a.anno_da = -701 and a.confidenza = 2
     from attestazione a where a.lessema_id = lx('grc/akris-2') and a.stima),
  'una voce del dizionario riceve la sua stima (ἄκρις: Omero, VIII sec. a.C., confidenza 2 per la data per secolo)');
select pg_temp.verifica(not exists (select 1 from attestazione a where a.lessema_id = lx('la/caro') and a.stima),
  'un lemma con più voci nel dizionario (caro) non riceve stime: non si sa a quale voce vadano');
create temp table stime_xmin as select id, xmin::text as x from attestazione where stima;
select importa_stime();
select pg_temp.verifica(
  (select count(*) from stime_xmin p join attestazione a on a.id = p.id and a.xmin::text = p.x) = (select count(*) from stime_xmin)
  and (select count(*) from attestazione where stima) = (select count(*) from stime_xmin),
  'un nuovo import delle stime con gli stessi dati non riscrive niente');
delete from stg_stima where lemma = 'carus';
select importa_stime();
select pg_temp.verifica(not exists (select 1 from attestazione a where a.lessema_id = lx('la/carus') and a.stima),
  'una stima che il pacchetto non ha più si toglie');

\echo '— traduzioni e definizioni di Claude'
truncate stg_definizione;
insert into stg_definizione
select l.id_esterno, coalesce(l.glossa, ''), v.t, v.d, 'claude-opus-5-5'
  from lessema l
  join (values ('la/mobilis', 'mobile, movibile', 'Che si può muovere o spostare; in senso figurato, mutevole.'),
               ('la/caro', 'carne', 'La carne, come sostanza del corpo e come cibo.'),
               ('it/pausare', 'sostare', 'Fare una pausa, interrompere per breve tempo un’attività.'),
               ('it/centavo', 'centavo', 'Moneta divisionale di vari paesi dell’America Latina.')) v(s, t, d) on l.slug = v.s;
insert into stg_definizione
select id_esterno, 'una glossa che non c''è più', 'caro', 'Definizione nata da un''altra glossa.', 'claude-opus-5-5'
  from lessema where slug = 'la/carus';
-- una definizione nata senza glossa (una radice, *tréyes) resta quando la voce riceve una glossa («three»)
insert into stg_definizione
select id_esterno, '', null, 'Definizione nata senza glossa.', 'claude-opus-5-5'
  from lessema where glossa is not null and provenienza = 'wiktionary'
   and slug not in ('la/mobilis', 'la/caro', 'it/pausare', 'it/centavo', 'la/carus') order by slug limit 1;
select importa_glosse_aggiuntive();
select importa_definizioni();
select pg_temp.verifica(exists (select 1 from definizione where testo = 'Definizione nata senza glossa.' and provenienza = 'claude'),
  'una definizione nata senza glossa resta quando la voce riceve una glossa');
select pg_temp.verifica((select testo || '|' || provenienza from glossa where lessema_id = lx('la/mobilis') and lingua = 'it') = 'mobile, movibile|claude'
                        and (nodo_json(lx('la/mobilis'), 'it')->>'glossa_automatica')::boolean,
  'la traduzione di Claude prende il posto di quella di OPUS-MT, ed è segnata come automatica');
select pg_temp.verifica((select testo || '|' || provenienza from glossa where lessema_id = lx('la/caro') and lingua = 'it') = 'carne|wikizionario'
                        and exists (select 1 from definizione where lessema_id = lx('la/caro') and provenienza = 'claude'),
  'Claude non scavalca la glossa del Wikizionario, ma la definizione entra');
select pg_temp.verifica((select testo || '|' || provenienza from glossa where lessema_id = lx('it/pausare') and lingua = 'it') = 'fare una pausa|wikidata',
  'per una parola italiana la definizione breve di Wikidata viene prima della traduzione di Claude');
select pg_temp.verifica(not exists (select 1 from glossa where lessema_id = lx('it/centavo') and provenienza = 'claude')
                        and exists (select 1 from definizione where lessema_id = lx('it/centavo')),
  'per una parola italiana una «traduzione» uguale al lemma non diventa glossa; la definizione sì');
select pg_temp.verifica(not exists (select 1 from definizione where lessema_id = lx('la/carus'))
                        and not exists (select 1 from glossa where lessema_id = lx('la/carus') and provenienza = 'claude'),
  'una definizione nata da un''altra glossa non entra: aspetta quella nuova');
select pg_temp.verifica(
  (select l->>'definizione' = 'Che si può muovere o spostare; in senso figurato, mutevole.' and (l->>'definizione_automatica')::boolean
          and l->>'definizione_modello' = 'claude-opus-5-5' and l->>'definizione_lingua' = 'it'
     from (select scheda('la/mobilis')->'lessema' as l) x)
  and exists (select 1 from jsonb_array_elements(scheda('la/mobilis')->'strati') e where e->>'codice' = 'claude'),
  'la scheda porta la definizione, automatica, con il modello; lo strato di Claude è tra le fonti della pagina');
select pg_temp.verifica((scheda('la/mobilis', false, 'en')->'lessema'->>'definizione_lingua') = 'it',
  'sul sito inglese la definizione resta in italiano, dichiarata come tale');
create temp table definizioni_xmin as select id, xmin::text as x from definizione;
create temp table glosse_claude_xmin as select id, xmin::text as x from glossa where provenienza = 'claude';
select importa_glosse_aggiuntive();
select importa_definizioni();
select pg_temp.verifica(
  (select count(*) from definizione d join definizioni_xmin x on x.id = d.id and x.x = d.xmin::text) = (select count(*) from definizioni_xmin)
  and (select count(*) from definizione) = (select count(*) from definizioni_xmin)
  and (select count(*) from glossa g join glosse_claude_xmin x on x.id = g.id and x.x = g.xmin::text) = (select count(*) from glosse_claude_xmin),
  'un nuovo import delle definizioni con gli stessi dati non riscrive niente');
update definizione set testo = 'Che si muove; mutevole, incostante.', stato_editoriale = 'rivisto' where lessema_id = lx('la/mobilis');
truncate stg_definizione;
select importa_glosse_aggiuntive();
select importa_definizioni();
select pg_temp.verifica(
  (select testo = 'Che si muove; mutevole, incostante.' and provenienza = 'claude' from definizione where lessema_id = lx('la/mobilis'))
  and not (scheda('la/mobilis')->'lessema'->>'definizione_automatica')::boolean
  and not exists (select 1 from definizione where lessema_id = lx('la/caro')),
  'una definizione rivista dalla redazione resta, senza il segno ≈; quelle che il pacchetto non ha più si tolgono');
select pg_temp.verifica((select testo || '|' || provenienza from glossa where lessema_id = lx('la/mobilis') and lingua = 'it') = 'mobile, sciolto|traduzione-automatica',
  'senza la traduzione di Claude torna quella di OPUS-MT');


\echo '— pronunce'
truncate stg_pronuncia;
insert into stg_pronuncia
select id_esterno, '{"i": [["/ˈka.ro/", "Classical-Latin"], ["[ˈkaː.ro]", "Ecclesiastical-Latin"]], "s": "ca‧ro", "a": "LL-caro.wav"}'
  from lessema where slug = 'la/caro';
select importa_pronunce();
select pg_temp.verifica((select ipa->0->>0 || '|' || (ipa->1->>1) || '|' || sillabazione || '|' || audio from pronuncia where lessema_id = lx('la/caro'))
                        = '/ˈka.ro/|Ecclesiastical-Latin|ca‧ro|LL-caro.wav',
  'la pronuncia entra: le trascrizioni IPA con la varietà, la sillabazione, l''audio');
select pg_temp.verifica((select (r->>'nuove')::int + (r->>'cambiate')::int from (select importa_pronunce() as r) x) = 0,
  'una pronuncia uguale non si riscrive');
truncate stg_pronuncia;
create temp table esito_pronunce as select importa_pronunce() as r;   -- la cancellazione si vede dall'istruzione dopo
select pg_temp.verifica((select (r->>'tolte')::int from esito_pronunce) = 1
                        and not exists (select 1 from pronuncia where lessema_id = lx('la/caro')),
  'una pronuncia che Wiktionary non dà più si toglie');


\echo '— sensi'
truncate stg_sensi;
insert into stg_sensi
select id_esterno, '{"t": "carō f (genitive carnis); third declension", "s": [["flesh, meat", ""], ["the body", "figuratively"]]}'
  from lessema where slug = 'la/caro';
select importa_sensi();
select pg_temp.verifica((select testa || '|' || (sensi->1->>1) from sensi where lessema_id = lx('la/caro')) = 'carō f (genitive carnis); third declension|figuratively',
  'la riga delle forme e le accezioni con le etichette d''uso entrano');
select pg_temp.verifica((select (r->>'nuove')::int + (r->>'cambiate')::int from (select importa_sensi() as r) x) = 0,
  'accezioni uguali non si riscrivono');

\echo '— traslitterazioni nuove'
do $$
begin
  insert into lessema (lingua, lemma, omografo, translit, provenienza, stato_editoriale, id_esterno)
    values ('grc', 'ζζα', 1, 'zza', 'wiktionary', 'importato', 'prova:zza'), ('grc', 'ζζβ', 1, 'zzb', 'wiktionary', 'importato', 'prova:zzb');
  insert into stg_lessema (chiave, lingua, lemma, omografo, ricostruito, translit)
    values ('prova:zza', 'grc', 'ζζα', 1, false, 'zzz'), ('prova:zzb', 'grc', 'ζζβ', 1, false, 'zzz');
  perform importa_wiktionary();
  perform pg_temp.verifica((select count(*) from lessema where slug = 'grc/zzz') = 1,
    'due voci che con la traslitterazione nuova andrebbero allo stesso indirizzo: ne cambia una, e l''import non si ferma');
  raise exception using errcode = 'P0098', message = 'annulla';
exception when sqlstate 'P0098' then null;
end $$;

\echo '— etimologie dei dizionari e analisi della forma'
select pg_temp.verifica(
  (select h.etichetta = 'Lewis & Short' and h.stato = 'accolta' and h.confidenza = 3 and h.provenienza = 'perseus'
          and (select string_agg(e.lemma || ':' || x.tipo, ',') from relazione x join lessema e on e.id = x.etimo_id
                where x.ipotesi_id = h.id) = 'carus:derivazione'
          and exists (select 1 from rimando m join opera o on o.id = m.opera_id
                       where m.ipotesi_id = h.id and o.sigla = 'Lewis–Short' and m.sv = 'Carus')
     from ipotesi h where h.esito_id = lx('la/carus-2')),
  'una voce senza etimologia riceve quella del dizionario, citato come fonte (Carus ← carus, Lewis & Short); l''analisi della forma cede al dizionario');
select pg_temp.verifica(
  (select h.etichetta = 'Analisi della forma' and h.confidenza = 2
          and (select x.affisso || x.confidenza from relazione x where x.ipotesi_id = h.id) = 're-2'
          and not exists (select 1 from rimando m where m.ipotesi_id = h.id)
     from ipotesi h where h.esito_id = lx('la/moveo') and h.provenienza = 'perseus'),
  'l''analisi della forma entra con certezza 2, senza fonte, con il prefisso come affisso');
select pg_temp.verifica(
  not exists (select 1 from ipotesi h where h.provenienza = 'perseus'
                 and h.esito_id in (lx('la/mobilis'), lx('la/abactus-2'), lx('grc/akris-2'))),
  'niente etimologia dei dizionari dove Wiktionary ne dà una (mobilis) o dove l''etimo non è tra le voci (abactus ← abigo, ἄκρις ← ἄκρος)');
select pg_temp.verifica(
  (select h.etichetta = 'Wikizionario' and h.provenienza = 'wikizionario' and h.confidenza = 3
          and exists (select 1 from rimando m join opera o on o.id = m.opera_id where m.ipotesi_id = h.id and o.sigla = 'Wikizionario')
     from ipotesi h where h.esito_id = lx('it/oscuro'))
  and (select h.confidenza from ipotesi h where h.esito_id = lx('it/torto') and h.provenienza = 'wikizionario') = 2,
  'una voce italiana senza etimologia riceve quella del Wikizionario, citato come fonte; un rimando «vedi» vale certezza 2');
select pg_temp.verifica(
  exists (select 1 from rimando m join opera o on o.id = m.opera_id join ipotesi h on h.id = m.ipotesi_id
           where h.esito_id = lx('it/carne') and h.stato = 'accolta' and h.provenienza = 'wiktionary'
             and o.sigla = 'Wikizionario' and m.posizione = 'accoglie' and m.nota = 'concorda con Wiktionary')
  and not exists (select 1 from ipotesi h where h.esito_id = lx('it/carne') and h.provenienza = 'wikizionario'),
  'dove i due Wiktionary concordano (carne < caro), l''etimologia di Wiktionary cita anche il Wikizionario');
select pg_temp.verifica(
  (select h.stato = 'alternativa' and h.confidenza = 2
          and (select x.etimo_id from relazione x where x.ipotesi_id = h.id) = lx('la/illi')
     from ipotesi h where h.esito_id = lx('it/loro') and h.provenienza = 'wikizionario')
  and (select h.provenienza from ipotesi h where h.esito_id = lx('it/loro') and h.stato = 'accolta') = 'wiktionary'
  and not exists (select 1 from ipotesi h where h.esito_id = lx('it/disastro') and h.provenienza = 'wikizionario'),
  'dove discordano, il Wikizionario entra come alternativa con certezza 2 (loro < illi); mai sulle voci della redazione (disastro)');
create temp table ed_prima as select id, xmin::text as v from ipotesi where provenienza in ('perseus', 'wikizionario');
create temp table rim_prima as select id, xmin::text as v from rimando where nota = 'concorda con Wiktionary';
select pg_temp.verifica(
  (select (r->>'etimologie_nuove')::int + (r->>'etimologie_tolte')::int from (select importa_etimi_dizionari() as r) x) = 0
  and not exists (select 1 from ipotesi h join ed_prima p on p.id = h.id where h.xmin::text <> p.v)
  and (select count(*) from rimando m join rim_prima p on p.id = m.id and p.v = m.xmin::text)
      = (select count(*) from rimando where nota = 'concorda con Wiktionary'),
  'un nuovo import delle etimologie dei dizionari non riscrive niente, nemmeno i rimandi dei due Wiktionary');
do $$
begin
  insert into ipotesi (esito_id, etichetta, stato, confidenza, origine, provenienza, stato_editoriale, id_esterno)
    values (lx('la/moveo'), 'Wiktionary', 'alternativa', 3, 'etimo', 'wiktionary', 'importato', 'prova:moveo#wikt');
  insert into stg_ipotesi (chiave, esito, etichetta, stato, confidenza, origine)
    values ('prova:moveo#wikt', 'prova:moveo', 'Wiktionary', 'accolta', 3, 'etimo');
  perform importa_etimi_dizionari();
  perform pg_temp.verifica(
    (select stato from ipotesi where id_esterno = 'prova:moveo#wikt') = 'accolta'
    and not exists (select 1 from ipotesi where esito_id = lx('la/moveo') and provenienza = 'perseus'),
    'quando Wiktionary dà un''etimologia, l''analisi della forma lascia il posto e quella di Wiktionary diventa accolta');
  raise exception using errcode = 'P0098', message = 'annulla';
exception when sqlstate 'P0098' then null;
end $$;

\echo '— lingue: famiglia, ramo, antenato e nome da Wiktionary'
do $$
begin
  insert into lingua (codice, nome, sigla) values ('eu', 'Basque', 'eu'), ('ca', 'Catalan', 'ca'), ('xx-prova', 'calque of Prova', 'xx')
  on conflict do nothing;
  truncate stg_lingua_wikt, stg_famiglia_wikt;
  insert into stg_famiglia_wikt values ('euq', 'Vasconic', ''), ('ine', 'Indo-European', ''), ('itc', 'Italic', 'ine'),
    ('roa', 'Romance', 'itc');
  insert into stg_lingua_wikt values ('eu', 'Basque', 'euq', '', '', '', 'Q8752', 'basco'),
    ('ca', 'Catalan', 'roa', 'roa-oca', '', '', 'Q7026', 'catalano'), ('roa-oca', 'Old Catalan', '', '', 'la', 'etimologica', '', ''),
    ('xx-prova', 'Prova', 'euq', '', '', '', '', '');
  perform importa_lingue_wiktionary();
  perform pg_temp.verifica(
    (select famiglia = 'vasconica' and nome = 'basco' from lingua where codice = 'eu')
    and (select famiglia = 'indoeuropea' and ramo = 'italica' and antenato = 'la' from lingua where codice = 'ca')
    and (select nome = 'Prova' from lingua where codice = 'xx-prova')
    and (select famiglia from lingua where codice = 'la') = 'indoeuropea',
    'le lingue senza famiglia la prendono da Wiktionary (basco: vasconica; catalano: italica, dal latino attraverso il catalano antico), i nomi letti male si correggono, quelle già classificate non cambiano');
  raise exception using errcode = 'P0098', message = 'annulla';
exception when sqlstate 'P0098' then null;
end $$;
truncate stg_lingua_wikt, stg_famiglia_wikt;

\echo '— collaudo dell’import completato'
