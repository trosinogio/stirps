-- 9 novembre 2026: le etimologie del Wiktionnaire per le voci francesi (import/etimi_wiktionnaire.py) e il confronto dei
-- due Wiktionary per il francese, come per l'italiano: lo strato, le opere (il Wiktionnaire, e il DMF e il DEAF accanto
-- al TLFi e al FEW per la redazione) e importa_etimi_dizionari(). La funzione ha lo stesso testo di
-- db/05_import_wiktionary.sql: se cambia lì, si rigenera da lì. Ripetibile senza danni.
insert into strato (codice, nome, licenza, share_alike, attribuzione, url) values
('wiktionnaire', 'Wiktionnaire, via Kaikki/wiktextract', 'CC BY-SA 4.0', true,
 'Contiene etimologie tratte dal Wiktionnaire, distribuite con licenza CC BY-SA 4.0.', 'https://fr.wiktionary.org')
on conflict (codice) do nothing;

insert into opera (sigla, autore, titolo, edizione, anno, editore, url, pubblico_dominio, ambito, lingue, modello_url, tipo, nota) values
('DMF', 'ATILF – CNRS e Université de Lorraine', 'Dictionnaire du Moyen Français (1330–1500)', null, null, 'ATILF', 'http://www.atilf.fr/dmf', false, 'romanzo', '{frm}', null, 'lessico', 'in rete'),
('DEAF', 'Kurt Baldinger, Frankwalt Möhren, Thomas Städtler', 'Dictionnaire étymologique de l''ancien français', null, 1971, 'Niemeyer, De Gruyter; Heidelberger Akademie der Wissenschaften', 'https://deaf-server.adw.uni-heidelberg.de', false, 'romanzo', '{fro}', null, 'etimologico', 'a stampa dal 1971, poi DEAFél in rete'),
('Wiktionnaire', null, 'Wiktionnaire', null, null, 'Wikimedia Foundation', 'https://fr.wiktionary.org', false, 'rete', '{fr}', 'https://fr.wiktionary.org/wiki/{lemma}', 'in_rete', 'CC BY-SA 4.0; fonte delle etimologie francesi, a confronto con Wiktionary')
on conflict (sigla) do nothing;

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
