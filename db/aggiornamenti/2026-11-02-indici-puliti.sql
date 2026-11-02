-- 2 novembre 2026: indici puliti. L'indice di una lingua segue il suo alfabeto (23 lettere per il latino, con J sotto I
-- e U sotto V; 24 per il greco); pulisci_wiktionary() toglie anche le voci che hanno solo glosse importate, così escono
-- le voci che il parser non considera più parole (lettere, simboli, sillabario cipriota, frammenti di testo).
-- Funzioni copiate da db/02_logica.sql e db/05_import_wiktionary.sql. Ripetibile senza danni.

create or replace function parole_lingua(p_codice text, p_lingua text default 'it', p_anteprima boolean default false, p_iniziale text default null)
returns jsonb language sql stable as $$
with
-- l'indice segue l'alfabeto della lingua: 23 lettere per il latino (J sotto I, U sotto V, come nella grafia classica),
-- 24 per il greco; le parole che cominciano con altro restano voci, ma fuori dall'indice
al as (select case when p_codice ~ '^la(-|$)' then 'ABCDEFGHIKLMNOPQRSTVXYZ'
                   when p_codice ~ '^grc(-|$)' then 'ΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩ' end as lettere),
lf as (select l.*, case when p_codice ~ '^la(-|$)' then translate(upper(coalesce(nullif(l.lemma_norm, ''), l.lemma)), 'JU', 'IV')
                        else upper(coalesce(nullif(l.lemma_norm, ''), l.lemma)) end as f
       from lessema l where l.lingua = p_codice and visibile(l.stato_editoriale, p_anteprima)),
-- le prime due lettere: le parole di una lettera sola e quelle come «a priori» o «a-» stanno nel gruppo «A-»
lx as (select l.*, left(l.f, 1) as ini,
              case when substr(l.f, 2, 1) ~ '^[[:alpha:]]$' and (al.lettere is null or strpos(al.lettere, substr(l.f, 2, 1)) > 0)
                   then left(l.f, 2) else left(l.f, 1) || '-' end as ini2
       from lf l, al
      where al.lettere is null or strpos(al.lettere, left(l.f, 1)) > 0),
ini as (select ini, count(*) as n, (ini !~ '^[[:alpha:]]') as simbolo from lx group by ini),
scelta as (select coalesce(upper(left(p_iniziale, 1)), case when (select count(*) from lx) <= 400 then null
                                         -- si apre sulla prima iniziale vera: non su una I con una sola parola greca
                                         else (select ini from ini order by simbolo, n * 100 < (select count(*) from lx), ini
                                                limit 1) end) as v),
-- un'iniziale con più di 2000 parole si sfoglia per le prime due lettere (Αβ, Αγ…): pagine leggere anche per il greco
sotto as (select x.ini2, count(*) as n from lx x, scelta sc where x.ini = sc.v group by x.ini2),
scelta2 as (select case when (select sum(n) from sotto) > 2000
                        then coalesce((select ini2 from sotto where ini2 = upper(p_iniziale)),
                                      (select ini2 from sotto order by ini2 like '_-', ini2 limit 1)) end as v)
select jsonb_build_object(
  'totale', (select count(*) from lf),
  'iniziale', (select v from scelta),
  'iniziali', coalesce((select jsonb_agg(jsonb_build_object('iniziale', ini, 'n', n) order by simbolo, ini) from ini), '[]'::jsonb),
  'sottoiniziale', (select v from scelta2),
  'sottoiniziali', case when (select v from scelta2) is null then '[]'::jsonb
                        else (select jsonb_agg(jsonb_build_object('iniziale', ini2, 'n', n) order by ini2) from sotto) end,
  'parole', coalesce((select jsonb_agg(nodo_json(x.id, p_lingua, p_anteprima) order by x.lemma_norm, x.lemma)
                        from lx x, scelta sc, scelta2 s2
                       where (sc.v is null or x.ini = sc.v) and (s2.v is null or x.ini2 = s2.v)), '[]'::jsonb))
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
