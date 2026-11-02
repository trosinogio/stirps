-- 2 novembre 2026: indici puliti e pagine delle lingue più leggere. L'indice di una lingua segue il suo alfabeto (23
-- lettere per il latino, con J sotto I e U sotto V; 24 per il greco), i nomi propri hanno un indice a parte (p_nomi), i gruppi grandi pagine da 500 voci (p_pagina),
-- le iniziali stanno in colonne generate e indicizzate (chiave_indice, nome_proprio), l'elenco non chiama nodo_json()
-- per ogni voce e la testata usa lingua_json(). pulisci_wiktionary() toglie anche le voci che hanno solo glosse importate, così escono
-- le voci che il parser non considera più parole (lettere, simboli, sillabario cipriota, frammenti di testo).
-- Funzioni copiate da db/02_logica.sql e db/05_import_wiktionary.sql. Ripetibile senza danni.

-- La chiave dell'indice di una lingua: le prime due lettere della forma normalizzata, secondo l'alfabeto della lingua
-- (23 lettere latine, con J sotto I e U sotto V; 24 greche). «A-» raccoglie le parole di una lettera e quelle come
-- «a priori»; null per le parole che cominciano fuori dall'alfabeto (W latina, Ϝ greca), che restano fuori dall'indice.
-- È nella colonna generata lessema.chiave_indice: se cambia, la colonna va ricalcolata (update lessema set lemma = lemma).
create or replace function indice_iniziali(p_lingua text, p_forma text) returns text
language sql immutable parallel safe
return (with a as (select case when p_lingua ~ '^la(-|$)' then 'ABCDEFGHIKLMNOPQRSTVXYZ'
                               when p_lingua ~ '^grc(-|$)' then 'ΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩ' end as lettere,
                          case when p_lingua ~ '^la(-|$)' then translate(upper(p_forma), 'JU', 'IV') else upper(p_forma) end as f)
        select case when f is null or f = '' then null
                    when lettere is not null and strpos(lettere, left(f, 1)) = 0 then null
                    when substr(f, 2, 1) ~ '^[[:alpha:]]$' and (lettere is null or strpos(lettere, substr(f, 2, 1)) > 0) then left(f, 2)
                    else left(f, 1) || '-' end
          from a);
alter table lessema add column if not exists chiave_indice text
  generated always as (indice_iniziali(lingua, coalesce(nullif(norm(lemma), ''), lemma))) stored;
alter table lessema add column if not exists nome_proprio boolean
  generated always as (coalesce(pos, '') = 'np' or (pos is null and lemma ~ '^-?[[:upper:]]')) stored;
create index if not exists lessema_indice on lessema (lingua, nome_proprio, chiave_indice) include (stato_editoriale);

drop function if exists parole_lingua(text, text, boolean, text);
drop function if exists parole_lingua(text, text, boolean, text, boolean);
create or replace function parole_lingua(p_codice text, p_lingua text default 'it', p_anteprima boolean default false, p_iniziale text default null,
                              p_nomi boolean default false, p_pagina int default 1)
returns jsonb language sql stable as $$
-- l'indice per lettere: chiave_indice (le prime due lettere secondo l'alfabeto: 23 latine con J sotto I e U sotto V,
-- 24 greche) e nome_proprio sono colonne generate di lessema, indicizzate; i nomi propri hanno un indice a parte
with
ix as (select chiave_indice as ini2, left(chiave_indice, 1) as ini, count(*) as n
         from lessema where lingua = p_codice and nome_proprio = p_nomi and chiave_indice is not null
                        and visibile(stato_editoriale, p_anteprima)
        group by chiave_indice),
ini as (select ini, sum(n) as n, (ini !~ '^[[:alpha:]]') as simbolo from ix group by ini),
scelta as (select coalesce(upper(left(p_iniziale, 1)), case when (select sum(n) from ini) <= 400 then null
                                         -- si apre sulla prima iniziale vera: non su una I con una sola parola greca
                                         else (select ini from ini order by simbolo, n * 100 < (select sum(n) from ini), ini
                                                limit 1) end) as v),
-- un'iniziale con più di 2000 parole si sfoglia per le prime due lettere (Αβ, Αγ…): pagine leggere anche per il greco
sotto as (select x.ini2, x.n from ix x, scelta sc where x.ini = sc.v),
scelta2 as (select case when (select sum(n) from sotto) > 2000
                        then coalesce((select ini2 from sotto where ini2 = upper(p_iniziale)),
                                      (select ini2 from sotto order by ini2 like '_-', ini2 limit 1)) end as v),
-- un gruppo con più di 500 voci si divide in pagine, con le parole guida come nei dizionari a stampa (κάβαισος – καθαίρω)
gruppo as (select l.id, l.slug, l.lingua, l.lemma, l.ricostruito, l.translit, l.glossa, l.glossa_lingua,
                  row_number() over (order by l.lemma_norm, l.lemma, l.id) as rn
             from lessema l, scelta sc, scelta2 s2
            where l.lingua = p_codice and l.nome_proprio = p_nomi and l.chiave_indice is not null
              and visibile(l.stato_editoriale, p_anteprima)
              and (sc.v is null or left(l.chiave_indice, 1) = sc.v) and (s2.v is null or l.chiave_indice = s2.v)),
pagine as (select (rn - 1) / 500 + 1 as n, (array_agg(lemma order by rn))[1] as da, (array_agg(lemma order by rn desc))[1] as a
             from gruppo group by 1),
pg as (select least(greatest(coalesce(p_pagina, 1), 1), greatest((select max(n) from pagine), 1)) as n),
tot as (select count(*) filter (where not nome_proprio) as parole, count(*) filter (where nome_proprio) as nomi
          from lessema where lingua = p_codice and visibile(stato_editoriale, p_anteprima))
select jsonb_build_object(
  'totale', (select case when p_nomi then nomi else parole end from tot),
  'totale_parole', (select parole from tot),
  'totale_nomi', (select nomi from tot),
  'iniziale', (select v from scelta),
  'iniziali', coalesce((select jsonb_agg(jsonb_build_object('iniziale', ini, 'n', n) order by simbolo, ini) from ini), '[]'::jsonb),
  'sottoiniziale', (select v from scelta2),
  'pagina', (select n from pg),
  'pagine', case when (select count(*) from pagine) > 1
                 then (select jsonb_agg(jsonb_build_object('da', da, 'a', a) order by n) from pagine) else '[]'::jsonb end,
  'sottoiniziali', case when (select v from scelta2) is null then '[]'::jsonb
                        else (select jsonb_agg(jsonb_build_object('iniziale', ini2, 'n', n) order by ini2) from sotto) end,
  -- gli stessi campi di nodo_json(), ma la lingua si legge una volta sola
  'parole', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'slug', x.slug, 'lingua', x.lingua,
                          'lingua_nome', g.nome, 'lingua_sigla', g.sigla, 'ramo', g.ramo, 'lemma', x.lemma,
                          'ricostruito', x.ricostruito, 'translit', x.translit, 'glossa', coalesce(t.testo, x.glossa),
                          'glossa_lingua', case when t.testo is not null then t.lingua else x.glossa_lingua end,
                          'glossa_automatica', coalesce(t.provenienza = 'traduzione-automatica' and t.stato_editoriale = 'importato', false))
                        order by x.rn)
                        from gruppo x
                        cross join (select coalesce(etichetta_in('lingua', codice, p_lingua), nome) as nome,
                                           coalesce(etichetta_in('lingua', codice, p_lingua, 'breve'), sigla) as sigla, ramo
                                      from lingua where codice = p_codice) g
                        left join glossa t on t.lessema_id = x.id and t.accezione_id is null and t.lingua = p_lingua
                                          and visibile(t.stato_editoriale, p_anteprima)
                       where (x.rn - 1) / 500 + 1 = (select n from pg)), '[]'::jsonb))
$$;

-- La testata della pagina di una lingua, senza calcolare l'indice di tutto il dizionario
create or replace function lingua_json(p_codice text, p_lingua text default 'it', p_anteprima boolean default false)
returns jsonb language sql stable as $$
  select jsonb_build_object(
      'codice', g.codice,
      'nome', coalesce(etichetta_in('lingua', g.codice, p_lingua), g.nome),
      'sigla', coalesce(etichetta_in('lingua', g.codice, p_lingua, 'breve'), g.sigla),
      'famiglia', g.famiglia, 'famiglia_nome', coalesce(etichetta_in('famiglia', g.famiglia, p_lingua), g.famiglia),
      'ramo', coalesce(g.ramo, 'proto'), 'ramo_nome', etichetta_in('ramo', coalesce(g.ramo, 'proto'), p_lingua),
      'antenato', g.antenato, 'varieta_di', g.varieta_di,
      'antenato_nome', (select coalesce(etichetta_in('lingua', a.codice, p_lingua), a.nome) from lingua a where a.codice = g.antenato),
      'varieta_di_nome', (select coalesce(etichetta_in('lingua', v.codice, p_lingua), v.nome) from lingua v where v.codice = g.varieta_di))
  from lingua g
  where g.codice = p_codice and exists (select 1 from lessema l where l.lingua = g.codice and visibile(l.stato_editoriale, p_anteprima))
$$;

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
