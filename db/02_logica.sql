-- =====================================================================
--  Dizionario etimologico — logica: vincoli attivi, grafo, calcoli, API
-- =====================================================================

-- ---------------------------------------------------------------------
--  1. Trigger di integrità
-- ---------------------------------------------------------------------

-- Aggiorna il timestamp e rende immutabile la provenienza: rivedere un record
-- importato in CC BY-SA non lo trasforma in un record di redazione.
create function tocca() returns trigger language plpgsql as $$
begin
  if new.provenienza is distinct from old.provenienza then
    raise exception 'la provenienza non si cambia (%.%): per una voce di redazione si riscrive un record nuovo e si marca questo come «superato»',
      tg_table_name, old.id using errcode = 'check_violation';
  end if;
  new.aggiornato_il := now();
  return new;
end $$;

-- Apparato: registra ogni modifica con la riga prima e dopo
create function registra_storico() returns trigger language plpgsql as $$
begin
  if current_setting('app.import', true) = 'on' then return null; end if;   -- import massivo: lo storico è il file d'origine
  if tg_op = 'INSERT' then
    insert into storico (tabella, record_id, operazione, dopo)
    values (tg_table_name, new.id, 'I', to_jsonb(new));
  elsif tg_op = 'UPDATE' then
    insert into storico (tabella, record_id, operazione, prima, dopo)
    values (tg_table_name, new.id, 'U', to_jsonb(old), to_jsonb(new));
  else
    insert into storico (tabella, record_id, operazione, prima)
    values (tg_table_name, old.id, 'D', to_jsonb(old));
  end if;
  return null;
end $$;

-- L'indice dei nomi propri e derivati: oltre ai nomi (nome_proprio), ogni voce con la maiuscola nelle lingue che scrivono i
-- nomi comuni con la minuscola: aggettivi etnici e di luogo (Romanus, Danish, Παμφυλιακός), avverbi (Graece), cognomi
-- marcati come verbi. Non il tedesco e le lingue che scrivono con la maiuscola tutti i nomi, né le sigle (né il pronome I).
create or replace function nome_con_maiuscola(p_lingua text, p_lemma text, p_pos text) returns boolean
language sql immutable as $$
  select p_pos is not null and p_pos <> 'np' and p_lemma ~ '^-?[[:upper:]]' and p_lemma ~ '[[:lower:]]'   -- non le sigle (CD, USB)
     and p_lingua not in ('de', 'lb', 'gsw', 'bar', 'pdc', 'nds', 'nds-de', 'sxu', 'swg', 'ksh', 'cim', 'mhn', 'vmf', 'hrx',
                          'gmw-cfr', 'gmw-ecg', 'gmw-rfr', 'gmw-msc', 'yi')
     and p_lingua not like 'de-%'
$$;

create or replace function segna_nome_indice() returns trigger language plpgsql as $$
begin
  new.nome_indice := case when nome_con_maiuscola(new.lingua, new.lemma, new.pos) then true end;
  return new;
end $$;

drop trigger if exists lessema_nome_indice on lessema;
create trigger lessema_nome_indice before insert or update of lingua, lemma, pos on lessema
  for each row execute function segna_nome_indice();

do $$
declare t text;
begin
  foreach t in array array['lessema', 'accezione', 'ipotesi', 'relazione', 'attestazione', 'connessione', 'glossa', 'definizione'] loop
    execute format('create trigger %1$s_tocca before update on %1$s for each row execute function tocca()', t);
  end loop;
  foreach t in array array['lessema', 'accezione', 'ipotesi', 'relazione', 'attestazione', 'connessione', 'rimando', 'glossa', 'definizione'] loop
    execute format('create trigger %1$s_storico after insert or update or delete on %1$s for each row execute function registra_storico()', t);
  end loop;
end $$;

-- Il grafo non ammette cicli
create function impedisci_cicli() returns trigger language plpgsql as $$
declare v_etimo text; v_esito text;
begin
  if current_setting('app.import', true) = 'on' then return new; end if;   -- import massivo: cicli controllati alla fine
  if exists (
    with recursive giu(id) as (
      select new.esito_id
      union
      select r.esito_id from relazione r join giu on r.etimo_id = giu.id
    )
    select 1 from giu where id = new.etimo_id
  ) then
    select slug into v_etimo from lessema where id = new.etimo_id;
    select slug into v_esito from lessema where id = new.esito_id;
    raise exception 'ciclo: «%» discende già da «%»', v_etimo, v_esito using errcode = 'check_violation';
  end if;
  return new;
end $$;

create trigger relazione_senza_cicli
  before insert or update of etimo_id, esito_id on relazione
  for each row execute function impedisci_cicli();

-- Le condizioni della verifica che si possono contare (norme redazionali, «Fonti e citazioni»):
-- un'ipotesi verificata ha almeno un'opera della bibliografia che la propone o la accoglie, e due se la
-- certezza è 4. Le opere in rete (Wiktionary, Wikizionario, Etymonline, Logeion) non contano.
create function opere_a_sostegno(p_ipotesi bigint) returns int language sql stable as $$
  select count(distinct r.opera_id)::int
    from rimando r join opera o on o.id = r.opera_id
   where o.tipo <> 'in_rete' and r.posizione in ('propone', 'accoglie')
     and (r.ipotesi_id = p_ipotesi
          or r.relazione_id in (select x.id from relazione x where x.ipotesi_id = p_ipotesi))
$$;
comment on function opere_a_sostegno(bigint) is
  'Opere della bibliografia, non in rete, che propongono o accolgono l''ipotesi (anche su un suo passaggio).';

-- Il controllo è differito al commit, così ipotesi e rimandi si inseriscono nella stessa transazione
create function controlla_ipotesi_verificata() returns trigger language plpgsql as $$
declare v_ip bigint; v_etichetta text; v_certezza smallint; v_opere int;
begin
  if tg_table_name = 'ipotesi' then
    v_ip := new.id;
  else
    v_ip := coalesce(old.ipotesi_id, (select ipotesi_id from relazione where id = old.relazione_id));
  end if;
  select h.etichetta, h.confidenza into v_etichetta, v_certezza
    from ipotesi h where h.id = v_ip and h.stato_editoriale = 'verificato';
  if not found then return null; end if;
  v_opere := opere_a_sostegno(v_ip);
  if v_opere = 0 then
    raise exception 'ipotesi % «%»: un''ipotesi verificata deve citare almeno un''opera che la proponga o la accolga',
      v_ip, v_etichetta using errcode = 'check_violation';
  elsif v_certezza = 4 and v_opere < 2 then
    raise exception 'ipotesi % «%»: la certezza 4 chiede due opere che propongano o accolgano l''ipotesi',
      v_ip, v_etichetta using errcode = 'check_violation';
  end if;
  return null;
end $$;

create constraint trigger ipotesi_verificata_con_fonte
  after insert or update of stato_editoriale, confidenza on ipotesi
  deferrable initially deferred
  for each row when (new.stato_editoriale = 'verificato')
  execute function controlla_ipotesi_verificata();

create constraint trigger rimando_ultima_fonte
  after delete or update of ipotesi_id, relazione_id, posizione, opera_id on rimando
  deferrable initially deferred
  for each row execute function controlla_ipotesi_verificata();

-- ---------------------------------------------------------------------
--  2. Funzioni di base
-- ---------------------------------------------------------------------

-- Visibilità: «superato» mai; «bozza» solo in anteprima
create function visibile(s stato_editoriale, p_anteprima boolean) returns boolean
language sql immutable
return s <> 'superato' and (p_anteprima or s <> 'bozza');

-- Lingue da cui una lingua può ereditare: la catena degli antenati e le loro varietà
create function lingue_ascendenti(p_lingua text) returns setof text
language sql stable as $$
  with recursive su(codice) as (
    select coalesce(varieta_di, codice) from lingua where codice = p_lingua
    union
    select l.antenato from lingua l join su on l.codice = su.codice where l.antenato is not null
  )
  select codice from su
  union
  select l.codice from lingua l join su on l.varieta_di = su.codice
$$;

create function lx(p_slug text) returns bigint language plpgsql stable as $$
declare v bigint;
begin
  select id into v from lessema where slug = p_slug;
  if v is null then raise exception 'lessema non trovato: %', p_slug; end if;
  return v;
end $$;

create function ip(p_esito text, p_etichetta text default 'principale') returns bigint
language plpgsql stable as $$
declare v bigint;
begin
  select id into v from ipotesi where esito_id = lx(p_esito) and etichetta = p_etichetta;
  if v is null then raise exception 'ipotesi non trovata: % «%»', p_esito, p_etichetta; end if;
  return v;
end $$;

-- Etichetta di un vocabolario nella lingua richiesta, con ripiego sull'italiano
create function etichetta_in(p_voc text, p_codice text, p_lingua text, p_campo text default 'etichetta') returns text
language sql stable as $$
  select case p_campo when 'breve' then coalesce(e.breve, e.etichetta) when 'descrizione' then e.descrizione else e.etichetta end
  from etichetta_lingua e
  where e.vocabolario = p_voc and e.codice = p_codice and e.lingua in (p_lingua, 'it')
  order by (e.lingua = p_lingua) desc
  limit 1
$$;

-- Rappresentazione compatta di un nodo, nella lingua richiesta.
-- glossa_lingua dice in che lingua è davvero la glossa restituita.
create function nodo_json(p_id bigint, p_lingua text default 'it', p_anteprima boolean default false) returns jsonb
language sql stable as $$
  select jsonb_build_object('id', x.id, 'slug', x.slug, 'lingua', x.lingua,
           'lingua_nome', coalesce(etichetta_in('lingua', x.lingua, p_lingua), g.nome),
           'lingua_sigla', coalesce(etichetta_in('lingua', x.lingua, p_lingua, 'breve'), g.sigla),
           'ramo', g.ramo, 'lemma', x.lemma, 'ricostruito', x.ricostruito, 'translit', x.translit,
           'nome_proprio', x.nome_proprio or coalesce(x.nome_indice, false),   -- lo stemma nasconde i nomi propri e derivati
           'glossa', coalesce(t.testo, x.glossa),
           'glossa_lingua', case when t.testo is not null then t.lingua else x.glossa_lingua end,
           'glossa_automatica', coalesce(t.provenienza in ('traduzione-automatica', 'claude') and t.stato_editoriale = 'importato', false))
  from lessema x
  join lingua g on g.codice = x.lingua
  left join glossa t on t.lessema_id = x.id and t.accezione_id is null and t.lingua = p_lingua
                    and visibile(t.stato_editoriale, p_anteprima)
  where x.id = p_id
$$;

create function rimandi_json(p_tipo text, p_id bigint) returns jsonb language sql stable as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'opera', o.sigla, 'autore', o.autore, 'titolo', o.titolo, 'anno', o.anno,
           'sv', r.sv, 'locus', r.locus, 'posizione', r.posizione, 'nota', r.nota)
         order by o.anno nulls last, o.sigla), '[]'::jsonb)
  from rimando r join opera o on o.id = r.opera_id
  where (p_tipo = 'ipotesi'      and r.ipotesi_id      = p_id)
     or (p_tipo = 'relazione'    and r.relazione_id    = p_id)
     or (p_tipo = 'attestazione' and r.attestazione_id = p_id)
     or (p_tipo = 'accezione'    and r.accezione_id    = p_id)
     or (p_tipo = 'lessema'      and r.lessema_id      = p_id)
     or (p_tipo = 'connessione'  and r.connessione_id  = p_id)
$$;

-- ---------------------------------------------------------------------
--  3. Il grafo
-- ---------------------------------------------------------------------

-- Archi attivi, con categoria, stato dell'ipotesi e visibilità pubblica
create view arco as
select r.id, r.ipotesi_id, r.etimo_id, r.esito_id, r.tipo,
       t.categoria, t.ereditario, r.confidenza, h.stato as stato_ipotesi,
       (r.stato_editoriale <> 'bozza' and h.stato_editoriale <> 'bozza'
        and le.stato_editoriale <> 'bozza' and lx.stato_editoriale <> 'bozza') as pubblico
from relazione r
join ipotesi h        on h.id = r.ipotesi_id
join tipo_relazione t on t.codice = r.tipo
join lessema le       on le.id = r.etimo_id
join lessema lx       on lx.id = r.esito_id
where r.stato_editoriale <> 'superato' and h.stato_editoriale <> 'superato'
  and le.stato_editoriale <> 'superato' and lx.stato_editoriale <> 'superato';

-- Risalita: tutti gli antenati, con percorso, tipi e certezza della catena
-- (la catena vale quanto il suo anello più debole)
create function antenati(p_id bigint,
                         p_stati stato_ipotesi[] default '{accolta}',
                         p_anteprima boolean default false)
returns table (lessema_id bigint, profondita int, percorso bigint[], tipi text[],
               confidenza smallint, ipotesi bigint[])
language sql stable as $$
  with recursive su(lessema_id, profondita, percorso, tipi, confidenza, ipotesi) as (
    select a.etimo_id, 1, array[p_id, a.etimo_id], array[a.tipo], a.confidenza, array[a.ipotesi_id]
    from arco a
    where a.esito_id = p_id and a.categoria <> 'influsso'
      and a.stato_ipotesi = any(p_stati) and (p_anteprima or a.pubblico)
    union all
    select a.etimo_id, su.profondita + 1, su.percorso || a.etimo_id, su.tipi || a.tipo,
           least(su.confidenza, a.confidenza), su.ipotesi || a.ipotesi_id
    from su join arco a on a.esito_id = su.lessema_id
    where a.categoria <> 'influsso' and a.stato_ipotesi = any(p_stati) and (p_anteprima or a.pubblico)
      and not a.etimo_id = any(su.percorso) and su.profondita < 40
  )
  select * from su
$$;

-- Discesa: tutti i discendenti
create function discendenti(p_id bigint,
                            p_stati stato_ipotesi[] default '{accolta}',
                            p_anteprima boolean default false)
returns table (lessema_id bigint, profondita int, percorso bigint[], tipi text[], confidenza smallint)
language sql stable as $$
  with recursive giu(lessema_id, profondita, percorso, tipi, confidenza) as (
    select a.esito_id, 1, array[p_id, a.esito_id], array[a.tipo], a.confidenza
    from arco a
    where a.etimo_id = p_id and a.categoria <> 'influsso'
      and a.stato_ipotesi = any(p_stati) and (p_anteprima or a.pubblico)
    union all
    select a.esito_id, g.profondita + 1, g.percorso || a.esito_id, g.tipi || a.tipo,
           least(g.confidenza, a.confidenza)
    from giu g join arco a on a.etimo_id = g.lessema_id
    where a.categoria <> 'influsso' and a.stato_ipotesi = any(p_stati) and (p_anteprima or a.pubblico)
      and not a.esito_id = any(g.percorso) and g.profondita < 40
  )
  select * from giu
$$;

-- Cognati, calcolati e mai inseriti a mano.
--   stretto      = antenato comune raggiunto solo per trafila ereditaria (notte / nuit / night)
--   per_prestito = nel percorso c'è almeno un prestito (palazzo / palace)
-- Si seguono solo gli archi di trasmissione: un derivato o un calco non è
-- «la stessa parola». Le parole della stessa lingua sono allotropi, non cognati.
create function cognati(p_id bigint, p_anteprima boolean default false)
returns table (lessema_id bigint, tipo text, antenato_comune bigint, distanza int)
language sql stable as $$
  with recursive
  su(id, d, solo_ered, perc) as (
    select a.etimo_id, 1, a.ereditario, array[p_id, a.etimo_id]
    from arco a
    where a.esito_id = p_id and a.categoria = 'trasmissione' and a.stato_ipotesi = 'accolta'
      and (p_anteprima or a.pubblico)
    union all
    select a.etimo_id, su.d + 1, su.solo_ered and a.ereditario, su.perc || a.etimo_id
    from su join arco a on a.esito_id = su.id
    where a.categoria = 'trasmissione' and a.stato_ipotesi = 'accolta' and (p_anteprima or a.pubblico)
      and not a.etimo_id = any(su.perc)
  ),
  giu(antenato, d_su, ered_su, id, d, solo_ered, perc) as (
    select su.id, su.d, su.solo_ered, a.esito_id, 1, a.ereditario, array[su.id, a.esito_id]
    from su join arco a on a.etimo_id = su.id
    where a.categoria = 'trasmissione' and a.stato_ipotesi = 'accolta' and (p_anteprima or a.pubblico)
    union all
    select g.antenato, g.d_su, g.ered_su, a.esito_id, g.d + 1, g.solo_ered and a.ereditario, g.perc || a.esito_id
    from giu g join arco a on a.etimo_id = g.id
    where a.categoria = 'trasmissione' and a.stato_ipotesi = 'accolta' and (p_anteprima or a.pubblico)
      and not a.esito_id = any(g.perc)
  )
  select distinct on (g.id)
         g.id,
         case when g.ered_su and g.solo_ered then 'stretto' else 'per_prestito' end,
         g.antenato,
         g.d_su + g.d
  from giu g
  join lessema x on x.id = g.id
  where g.id <> p_id
    and not p_id = any(g.perc)
    and g.id not in (select id from su)
    and x.lingua <> (select lingua from lessema where id = p_id)
  order by g.id, (g.ered_su and g.solo_ered) desc, g.d_su + g.d
$$;

-- Allotropi: stessa lingua, stesso antenato raggiunto per vie diverse di
-- trasmissione (vizio / vezzo, zero / cifra). Precalcolati in vista materializzata.
create materialized view mv_allotropi as
with recursive su(origine, id, d, perc, solo_anteprima) as (
  select l.id, a.etimo_id, 1, array[l.id, a.etimo_id], not a.pubblico
  from lessema l join arco a on a.esito_id = l.id
  where a.categoria = 'trasmissione' and a.stato_ipotesi = 'accolta'
  union all
  select su.origine, a.etimo_id, su.d + 1, su.perc || a.etimo_id, su.solo_anteprima or not a.pubblico
  from su join arco a on a.esito_id = su.id
  where a.categoria = 'trasmissione' and a.stato_ipotesi = 'accolta'
    and not a.etimo_id = any(su.perc)
),
coppie as (
  select x.origine as a_id, y.origine as b_id, x.id as antenato,
         x.d + y.d as distanza, (x.solo_anteprima or y.solo_anteprima) as solo_anteprima
  from su x
  join su y on y.id = x.id and x.origine < y.origine
  join lessema la on la.id = x.origine
  join lessema lb on lb.id = y.origine
  where la.lingua = lb.lingua
    and not exists (select 1 from su z where z.origine = x.origine and z.id = y.origine)
    and not exists (select 1 from su z where z.origine = y.origine and z.id = x.origine)
)
select distinct on (a_id, b_id) a_id, b_id, antenato, distanza, solo_anteprima
from coppie
order by a_id, b_id, distanza;

create unique index mv_allotropi_coppia on mv_allotropi (a_id, b_id);

-- Famiglie: ogni capostipite (nodo senza antenati accolti) con tutti i suoi discendenti.
-- Precalcolate: a 100 mila lessemi ricalcolarle a ogni pagina costerebbe decine di secondi.
-- Da rinfrescare dopo import e modifiche: refresh materialized view concurrently mv_famiglia
create materialized view mv_famiglia as
with recursive
capo as (
  select l.id from lessema l
  where l.stato_editoriale <> 'superato'
    and not exists (select 1 from arco a
                     where a.esito_id = l.id and a.stato_ipotesi = 'accolta' and a.categoria <> 'influsso')
),
-- si visitano le parole, non i percorsi: ogni parola entra una volta per profondità (union, senza il cammino),
-- così una famiglia con molte strade convergenti (i composti dotti: -logia, -grafia) resta lineare. I cicli
-- li impedisce già il vincolo sugli archi; il limite di profondità è solo una cintura di sicurezza
fam(capo, id, prof, pubblico) as (
  select c.id, a.esito_id, 1, a.pubblico
  from capo c join arco a on a.etimo_id = c.id
  where a.stato_ipotesi = 'accolta' and a.categoria <> 'influsso'
  union
  select f.capo, a.esito_id, f.prof + 1, f.pubblico and a.pubblico
  from fam f join arco a on a.etimo_id = f.id
  where a.stato_ipotesi = 'accolta' and a.categoria <> 'influsso' and f.prof < 40
)
select capo, id, bool_or(pubblico) as pubblico, min(prof) as profondita
from fam
group by capo, id;

create unique index mv_famiglia_pk on mv_famiglia (capo, id);
create index mv_famiglia_membro on mv_famiglia (id);

-- ---------------------------------------------------------------------
--  4. Ricerca: tollerante a diacritici, scritture e asterischi
-- ---------------------------------------------------------------------
create function cerca(q text, n int default 20, p_anteprima boolean default false)
returns table (id bigint, slug text, lemma text, lingua text, ricostruito boolean,
               glossa text, punteggio real)
language sql stable as $$
  with qn as (select norm(q) as v)
  select l.id, l.slug, l.lemma, l.lingua, l.ricostruito, l.glossa,
         greatest(similarity(l.lemma_norm, qn.v), coalesce(similarity(l.translit_norm, qn.v), 0))
  from lessema l, qn
  where visibile(l.stato_editoriale, p_anteprima)
    and (l.lemma_norm % qn.v or l.translit_norm % qn.v
         or l.lemma_norm like qn.v || '%' or l.translit_norm like qn.v || '%')
  order by (l.lemma_norm = qn.v or coalesce(l.translit_norm = qn.v, false)) desc,
           greatest(similarity(l.lemma_norm, qn.v), coalesce(similarity(l.translit_norm, qn.v), 0)) desc,
           l.lemma
  limit n
$$;

-- Ricerca universale: per lemma (in qualunque scrittura) e per significato,
-- nelle glosse della lingua d'interfaccia. «liver» trova fegato, foie, hígado.
create function cerca_universale(q text, p_lingua text default 'it', n int default 20, p_anteprima boolean default false)
returns table (id bigint, slug text, punteggio real, per_significato boolean, voce jsonb)
language sql stable as $$
  with qn as (select norm(q) as v),
  qr as (select v, regexp_replace(v, '([\\^$|+])', '\\\1', 'g') as rx from qn),
  per_lemma as (
    select l.id,
           (case when l.lemma_norm = qr.v or l.translit_norm = qr.v then 3
                 -- parole che cominciano così: conta la somiglianza, ma soprattutto quanto la parola è usata
                 when l.lemma_norm like qr.v || '%' or l.translit_norm like qr.v || '%'
                   then 2 + 0.4 * greatest(similarity(l.lemma_norm, qr.v), coalesce(similarity(l.translit_norm, qr.v), 0))
                          + 0.6 * coalesce(1 - ln(f.rango) / ln(50001), 0)
                 else greatest(similarity(l.lemma_norm, qr.v), coalesce(similarity(l.translit_norm, qr.v), 0)) end)::real as p,
           false as sig
    from lessema l cross join qr
    left join frequenza f on f.lingua = l.lingua and f.forma = l.lemma
    where visibile(l.stato_editoriale, p_anteprima) and length(qr.v) > 0
      and (l.lemma_norm % qr.v or l.translit_norm % qr.v
           or l.lemma_norm like qr.v || '%' or l.translit_norm like qr.v || '%')
  ),
  per_significato as (
    select t.lessema_id as id, (case when norm(t.testo) ~ ('(^| )' || qr.rx || '( |$)') then 1.5 else 1.1 end)::real as p, true as sig
    from glossa t join lessema l on l.id = t.lessema_id, qr
    where t.accezione_id is null and t.lingua = p_lingua and length(qr.v) >= 3
      and visibile(t.stato_editoriale, p_anteprima) and visibile(l.stato_editoriale, p_anteprima)
      and norm(t.testo) like '%' || qr.v || '%' and norm(t.testo) ~ ('(^| )' || qr.rx)
    union all
    select l.id, (case when norm(l.glossa) ~ ('(^| )' || qr.rx || '( |$)') then 1.5 else 1.1 end)::real, true
    from lessema l, qr
    where l.glossa_lingua = p_lingua and length(qr.v) >= 3 and visibile(l.stato_editoriale, p_anteprima)
      and norm(l.glossa) like '%' || qr.v || '%' and norm(l.glossa) ~ ('(^| )' || qr.rx)
  ),
  migliori as (
    select distinct on (id) id, p, sig
    from (select * from per_lemma union all select * from per_significato) x
    order by id, p desc
  )
  select m.id, x.slug, m.p, m.sig, nodo_json(m.id, p_lingua, p_anteprima)
  from migliori m join lessema x on x.id = m.id
  left join frequenza f on f.lingua = x.lingua and f.forma = x.lemma
  order by m.p desc, f.rango nulls last, x.lemma
  limit n
$$;

-- Indice per la pagina iniziale, nella lingua richiesta: le radici più ampie
-- (dichiarate e provvisorie), le lingue con i conteggi, i totali.
create function indice(p_lingua text default 'it', p_anteprima boolean default false, p_limite int default 40) returns jsonb
language sql stable as $$
with
fam as (
  select f.capo, f.id from mv_famiglia f
  join lessema c on c.id = f.capo join lessema x on x.id = f.id
  where (p_anteprima or f.pubblico) and visibile(c.stato_editoriale, p_anteprima) and visibile(x.stato_editoriale, p_anteprima)
),
rad as (
  select f.capo as id, count(*) as discendenti, count(distinct x.lingua) as lingue
  from fam f join lessema x on x.id = f.id
  group by f.capo
),
radd as (
  select r.*, l.lemma,
         (l.ricostruito or coalesce(l.pos = 'rad.', false)
          or exists (select 1 from ipotesi h where h.esito_id = l.id and h.stato = 'accolta' and h.origine <> 'etimo')) as dichiarata
  from rad r join lessema l on l.id = r.id
),
scelte as (
  (select * from radd where dichiarata order by discendenti desc, lemma limit p_limite)
  union all
  (select * from radd where not dichiarata order by discendenti desc, lemma limit p_limite)
),
rami as (
  select f.capo, coalesce(g.ramo, 'proto') as ramo, count(*) as n
  from fam f join scelte sc on sc.id = f.capo join lessema x on x.id = f.id join lingua g on g.codice = x.lingua
  group by 1, 2
)
select jsonb_build_object(
  'radici', coalesce((select jsonb_agg(nodo_json(sc.id, p_lingua, p_anteprima) || jsonb_build_object(
      'dichiarata', sc.dichiarata, 'discendenti', sc.discendenti, 'lingue', sc.lingue,
      'rami', (select jsonb_object_agg(ra.ramo, ra.n) from rami ra where ra.capo = sc.id))
      order by sc.dichiarata desc, sc.discendenti desc, sc.lemma) from scelte sc), '[]'::jsonb),
  'lingue', coalesce((select jsonb_agg(jsonb_build_object(
      'codice', g.codice,
      'nome', coalesce(etichetta_in('lingua', g.codice, p_lingua), g.nome),
      'sigla', coalesce(etichetta_in('lingua', g.codice, p_lingua, 'breve'), g.sigla),
      'famiglia', g.famiglia, 'famiglia_nome', coalesce(etichetta_in('famiglia', g.famiglia, p_lingua), g.famiglia),
      'ramo', coalesce(g.ramo, 'proto'), 'ramo_nome', etichetta_in('ramo', coalesce(g.ramo, 'proto'), p_lingua),
      'antenato', g.antenato, 'varieta_di', g.varieta_di, 'n', c.n)
      order by g.codice)
      from lingua g
      join (select lingua, count(*) as n from lessema where visibile(stato_editoriale, p_anteprima) group by lingua) c
        on c.lingua = g.codice), '[]'::jsonb),
  'totali', jsonb_build_object(
      'lessemi', (select count(*) from lessema where visibile(stato_editoriale, p_anteprima)),
      'lingue', (select count(distinct lingua) from lessema where visibile(stato_editoriale, p_anteprima)),
      'radici', (select count(*) from radd where dichiarata),
      'capostipiti', (select count(*) from radd where not dichiarata))
)
$$;

-- Elenco completo delle radici, a pagine (dichiarate oppure provvisorie)
create function elenco_radici(p_lingua text default 'it', p_anteprima boolean default false,
                              p_dichiarate boolean default true, p_pagina int default 1, p_per_pagina int default 100,
                              p_capo_lingua text default null)
returns jsonb language sql stable as $$
-- l'indice delle radici: i capostipiti (di una sola lingua con p_capo_lingua), dalla famiglia più grande; per ciascuno fino a
-- quattro parole della lingua del lettore che ne discendono, le più usate per prime (il rango d'uso vale per la prima voce
-- di una forma, non per gli omografi); e, per scegliere, quanti capostipiti ha ogni lingua
with
fam as (
  select f.capo, f.id from mv_famiglia f
  join lessema c on c.id = f.capo join lessema x on x.id = f.id
  where (p_anteprima or f.pubblico) and visibile(c.stato_editoriale, p_anteprima) and visibile(x.stato_editoriale, p_anteprima)
),
rad as (
  select f.capo as id, count(*) as discendenti, count(distinct x.lingua) as lingue
  from fam f join lessema x on x.id = f.id group by f.capo
),
radd as (
  select r.*, l.lemma, l.lingua
  from rad r join lessema l on l.id = r.id
  where (l.ricostruito or coalesce(l.pos = 'rad.', false)
         or exists (select 1 from ipotesi h where h.esito_id = l.id and h.stato = 'accolta' and h.origine <> 'etimo')) = p_dichiarate
),
scelte as (select * from radd where p_capo_lingua is null or lingua = p_capo_lingua),
pagina as (select * from scelte order by discendenti desc, lemma offset (greatest(p_pagina, 1) - 1) * p_per_pagina limit p_per_pagina),
esempi as (
  select pg.id, (
    select jsonb_agg(e.lemma order by e.rango nulls last, e.prof, e.lemma) from (
      select x.lemma, min(case when x.omografo = 1 then q.rango end) as rango, min(f.profondita) as prof
      from mv_famiglia f join lessema x on x.id = f.id
      left join frequenza q on q.lingua = x.lingua and q.forma = x.lemma
      where f.capo = pg.id and x.id <> pg.id and x.lingua = p_lingua and not x.nome_proprio and x.nome_indice is not true
        and (p_anteprima or f.pubblico) and visibile(x.stato_editoriale, p_anteprima)
      group by x.lemma
      order by rango nulls last, prof, x.lemma limit 4) e) as esempi
  from pagina pg
)
select jsonb_build_object(
  'totale', (select count(*) from scelte),
  'pagina', greatest(p_pagina, 1), 'per_pagina', p_per_pagina, 'capo_lingua', p_capo_lingua,
  'gruppi', coalesce((select jsonb_agg(jsonb_build_object('lingua', g.lingua, 'n', g.n,
                        'nome', coalesce(etichetta_in('lingua', g.lingua, p_lingua), l.nome)) order by g.n desc, g.lingua)
                      from (select lingua, count(*) as n from radd group by lingua) g join lingua l on l.codice = g.lingua), '[]'::jsonb),
  'radici', coalesce((select jsonb_agg(nodo_json(pg.id, p_lingua, p_anteprima) || jsonb_build_object(
      'discendenti', pg.discendenti, 'lingue', pg.lingue, 'esempi', coalesce(e.esempi, '[]'::jsonb)) order by pg.discendenti desc, pg.lemma)
    from pagina pg join esempi e on e.id = pg.id), '[]'::jsonb))
$$;

-- Le parole di una lingua per iniziale: con 70 mila parole un elenco unico non è una pagina
create function parole_lingua(p_codice text, p_lingua text default 'it', p_anteprima boolean default false, p_iniziale text default null,
                              p_nomi boolean default false, p_pagina int default 1)
returns jsonb language sql stable as $$
-- l'indice per lettere: chiave_indice (le prime due lettere secondo l'alfabeto: 23 latine con J sotto I e U sotto V,
-- 24 greche) e nome_proprio sono colonne generate di lessema, indicizzate; i nomi propri e derivati hanno un indice a parte:
-- i nomi (nome_proprio) e le altre voci con la maiuscola (nome_indice, un indice parziale piccolo)
with
ix as (select ini2, left(ini2, 1) as ini, sum(n) as n from (
         select chiave_indice as ini2, count(*) as n
           from lessema where lingua = p_codice and nome_proprio = p_nomi and chiave_indice is not null
                          and visibile(stato_editoriale, p_anteprima)
          group by chiave_indice
         union all
         select chiave_indice, (case when p_nomi then 1 else -1 end) * count(*)
           from lessema where lingua = p_codice and nome_indice and chiave_indice is not null
                          and visibile(stato_editoriale, p_anteprima)
          group by chiave_indice) x
        group by ini2 having sum(n) > 0),
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
            where l.lingua = p_codice and l.chiave_indice is not null
              and ((l.nome_proprio = p_nomi and l.nome_indice is not true) or (p_nomi and l.nome_indice))
              and visibile(l.stato_editoriale, p_anteprima)
              and (sc.v is null or left(l.chiave_indice, 1) = sc.v) and (s2.v is null or l.chiave_indice = s2.v)),
pagine as (select (rn - 1) / 500 + 1 as n, (array_agg(lemma order by rn))[1] as da, (array_agg(lemma order by rn desc))[1] as a
             from gruppo group by 1),
pg as (select least(greatest(coalesce(p_pagina, 1), 1), greatest((select max(n) from pagine), 1)) as n),
tot as (select count(*) filter (where not nome_proprio and nome_indice is not true) as parole,
               count(*) filter (where nome_proprio or nome_indice) as nomi
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
                          'glossa_automatica', coalesce(t.provenienza in ('traduzione-automatica', 'claude') and t.stato_editoriale = 'importato', false))
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
create function lingua_json(p_codice text, p_lingua text default 'it', p_anteprima boolean default false)
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

-- ---------------------------------------------------------------------
--  5. La scheda: tutta la voce in un solo documento JSON.
--  Il frontend fa una query per pagina: select scheda('it/fegato')
-- ---------------------------------------------------------------------
create function scheda(p_slug text, p_anteprima boolean default false, p_lingua text default 'it')
returns jsonb language sql stable as $$
with
l   as (select * from lessema where slug = p_slug and visibile(stato_editoriale, p_anteprima)),
gl  as (select t.* from glossa t join l on t.lessema_id = l.id
        where t.accezione_id is null and t.lingua = p_lingua and visibile(t.stato_editoriale, p_anteprima)),
df  as (select d.* from definizione d join l on d.lessema_id = l.id
        where d.lingua in (p_lingua, 'it') and visibile(d.stato_editoriale, p_anteprima)
        order by d.lingua = p_lingua desc limit 1),
ip  as (select h.* from ipotesi h join l on h.esito_id = l.id
        where visibile(h.stato_editoriale, p_anteprima)),
rel as (select r.*, t.etichetta as tipo_etichetta, t.categoria
        from relazione r
        join ip on ip.id = r.ipotesi_id
        join tipo_relazione t on t.codice = r.tipo
        join lessema e on e.id = r.etimo_id
        where visibile(r.stato_editoriale, p_anteprima) and visibile(e.stato_editoriale, p_anteprima)),
cat as (select * from antenati((select id from l), '{accolta}', p_anteprima)),
dis as (select * from discendenti((select id from l), '{accolta}', p_anteprima)),
cog as (select * from cognati((select id from l), p_anteprima)),
allo as (select case when m.a_id = l.id then m.b_id else m.a_id end as altro, m.antenato
         from mv_allotropi m, l
         where (m.a_id = l.id or m.b_id = l.id) and (p_anteprima or not m.solo_anteprima)),
acc as (select a.*, t.testo as glossa_t
        from accezione a join l on a.lessema_id = l.id
        left join glossa t on t.accezione_id = a.id and t.lingua = p_lingua and visibile(t.stato_editoriale, p_anteprima)
        where visibile(a.stato_editoriale, p_anteprima)),
att as (select a.* from attestazione a join l on a.lessema_id = l.id where visibile(a.stato_editoriale, p_anteprima)),
con as (select c.*, case when c.da_id = l.id then c.a_id else c.da_id end as altro
        from connessione c, l
        where (c.da_id = l.id or c.a_id = l.id) and visibile(c.stato_editoriale, p_anteprima)),
miti as (select h.*, x.slug as esito_slug
         from ipotesi h join lessema x on x.id = h.esito_id
         where h.stato = 'respinta' and h.diffusa and visibile(h.stato_editoriale, p_anteprima)
           and h.esito_id in (select id from l union select lessema_id from cat)),
prov as (
  select provenienza from l   union select provenienza from ip  union select provenienza from rel
  union select provenienza from acc union select provenienza from att union select provenienza from con
  union select provenienza from gl union select provenienza from df
  union select x.provenienza from lessema x
        where x.id in (select lessema_id from cat union select lessema_id from cog
                       union select altro from allo union select altro from con)
  -- anche le glosse delle parole collegate mostrate nella pagina (catena, sorelle, allotropi) vanno attribuite
  union select t.provenienza from glossa t
        where t.lingua = p_lingua and t.accezione_id is null
          and t.lessema_id in (select lessema_id from cat union select lessema_id from cog
                               union select altro from allo union select altro from con))
select jsonb_build_object(
  'lingua_richiesta', p_lingua,
  'lingua_redazione', (select valore from impostazione where chiave = 'lingua_redazione'),
  'lessema', jsonb_build_object(
      'id', l.id, 'slug', l.slug, 'lingua', l.lingua,
      'lingua_nome', coalesce(etichetta_in('lingua', l.lingua, p_lingua), (select nome from lingua where codice = l.lingua)),
      'lingua_sigla', coalesce(etichetta_in('lingua', l.lingua, p_lingua, 'breve'), (select sigla from lingua where codice = l.lingua)),
      'ramo', (select ramo from lingua where codice = l.lingua),
      'lemma', l.lemma, 'ricostruito', l.ricostruito, 'translit', l.translit, 'pos', l.pos,
      'glossa', coalesce((select testo from gl), l.glossa),
      'glossa_lingua', case when exists (select 1 from gl) then p_lingua else l.glossa_lingua end,
      'glossa_automatica', exists (select 1 from gl where gl.provenienza in ('traduzione-automatica', 'claude') and gl.stato_editoriale = 'importato'),
      -- la definizione nella lingua della pagina, o in italiano (le definizioni automatiche si scrivono solo in italiano)
      'definizione', (select d.testo from df d), 'definizione_lingua', (select d.lingua from df d),
      'definizione_automatica', (select d.provenienza = 'claude' and d.stato_editoriale = 'importato' from df d),
      'definizione_modello', (select d.modello from df d where d.provenienza = 'claude'),
      'obsoleto', l.obsoleto, 'nota', l.nota,
      'stato_editoriale', l.stato_editoriale, 'provenienza', l.provenienza,
      -- per il collegamento a Wiktionary: il nome inglese della lingua (le varietà stanno nella voce della lingua madre)
      'wiktionary_lingua', (select coalesce(etichetta_in('lingua', coalesce(g.varieta_di, g.codice), 'en'), g.nome)
                              from lingua g where g.codice = l.lingua)),
  'accezioni', coalesce((select jsonb_agg(jsonb_build_object(
      'id', a.id, 'n', a.n, 'glossa', coalesce(a.glossa_t, a.glossa),
      'glossa_lingua', case when a.glossa_t is not null then p_lingua else a.glossa_lingua end,
      'ambito', a.ambito, 'deriva_da', a.deriva_da, 'processo', a.processo,
      'processo_etichetta', coalesce(etichetta_in('processo', a.processo, p_lingua), (select etichetta from processo_semantico where codice = a.processo)),
      'anno_da', a.anno_da, 'anno_a', a.anno_a, 'precisione', a.precisione)
      order by a.n) from acc a), '[]'::jsonb),
  'ipotesi', coalesce((select jsonb_agg(jsonb_build_object(
      'id', h.id, 'etichetta', h.etichetta, 'stato', h.stato, 'confidenza', h.confidenza,
      'origine', h.origine, 'diffusa', h.diffusa, 'nota', h.nota, 'nota_lingua', h.nota_lingua,
      'provenienza', h.provenienza, 'stato_editoriale', h.stato_editoriale,
      'relazioni', coalesce((select jsonb_agg(jsonb_build_object(
          'tipo', r.tipo,
          'tipo_etichetta', coalesce(etichetta_in('tipo_relazione', r.tipo, p_lingua, 'breve'), r.tipo_etichetta),
          'categoria', r.categoria,
          'etimo', nodo_json(r.etimo_id, p_lingua, p_anteprima), 'forma_citata', r.forma_citata, 'affisso', r.affisso,
          'ordine', r.ordine, 'confidenza', r.confidenza, 'processo', r.processo,
          'processo_etichetta', coalesce(etichetta_in('processo', r.processo, p_lingua), (select etichetta from processo_semantico where codice = r.processo)),
          'etimo_accezione', (select coalesce(t.testo, a.glossa) from accezione a
                                left join glossa t on t.accezione_id = a.id and t.lingua = p_lingua
                               where a.id = r.etimo_accezione_id),
          'anno_da', r.anno_da, 'anno_a', r.anno_a, 'luogo', r.luogo, 'nota', r.nota,
          'provenienza', r.provenienza, 'rimandi', rimandi_json('relazione', r.id))
          order by r.ordine, r.id) from rel r where r.ipotesi_id = h.id), '[]'::jsonb),
      'rimandi', rimandi_json('ipotesi', h.id))
      order by h.stato, h.confidenza desc, h.id) from ip h), '[]'::jsonb),
  'catena', coalesce((select jsonb_agg(nodo_json(c.lessema_id, p_lingua, p_anteprima) || jsonb_build_object(
      'profondita', c.profondita, 'esito', c.percorso[c.profondita],
      'tipo', c.tipi[c.profondita],
      'tipo_etichetta', etichetta_in('tipo_relazione', c.tipi[c.profondita], p_lingua, 'breve'),
      'confidenza_catena', c.confidenza,
      -- la prima attestazione del nodo: le date entrano nella catena
      'attestata', (select jsonb_build_object('anno_da', a.anno_da, 'anno_a', a.anno_a, 'precisione', a.precisione, 'stima', a.stima)
                      from attestazione a where a.lessema_id = c.lessema_id and visibile(a.stato_editoriale, p_anteprima)
                     order by a.anno_da limit 1),
      -- la data del passaggio dal nodo all'esito, se una fonte la dà: è un'altra cosa dalla prima attestazione
      -- (norme redazionali, «Date e prime attestazioni»), e la pagina la mostra accanto al tipo di passaggio
      'passaggio_data', (select jsonb_build_object('anno_da', x.anno_da, 'anno_a', x.anno_a, 'precisione', x.precisione)
                           from relazione x
                          where x.ipotesi_id = c.ipotesi[c.profondita] and x.etimo_id = c.lessema_id
                            and x.esito_id = c.percorso[c.profondita] and x.tipo = c.tipi[c.profondita]
                            and x.anno_da is not null))
      order by c.profondita, c.lessema_id) from cat c), '[]'::jsonb),
  'discendenti', coalesce((select jsonb_agg(nodo_json(d.lessema_id, p_lingua, p_anteprima) || jsonb_build_object(
      'profondita', d.profondita, 'etimo', d.percorso[d.profondita], 'tipo', d.tipi[d.profondita],
      'tipo_etichetta', etichetta_in('tipo_relazione', d.tipi[d.profondita], p_lingua, 'breve'))
      order by d.profondita, d.lessema_id) from dis d), '[]'::jsonb),
  'cognati', coalesce((select jsonb_agg(nodo_json(g.lessema_id, p_lingua, p_anteprima) || jsonb_build_object(
      'tipo', g.tipo, 'antenato_comune', nodo_json(g.antenato_comune, p_lingua, p_anteprima), 'distanza', g.distanza)
      order by g.tipo desc, g.distanza, g.lessema_id) from cog g), '[]'::jsonb),
  'allotropi', coalesce((select jsonb_agg(nodo_json(a.altro, p_lingua, p_anteprima) || jsonb_build_object(
      'antenato_comune', nodo_json(a.antenato, p_lingua, p_anteprima))) from allo a), '[]'::jsonb),
  'attestazioni', coalesce((select jsonb_agg(jsonb_build_object(
      'forma_attestata', a.forma_attestata, 'testo', a.testo, 'rif', a.rif, 'tipo', a.tipo,
      'banca_dati', a.banca_dati, 'url', a.url, 'anno_da', a.anno_da, 'anno_a', a.anno_a,
      'precisione', a.precisione, 'citazione', a.citazione, 'nota', a.nota, 'provenienza', a.provenienza,
      'stima', a.stima, 'confidenza', a.confidenza,
      'rimandi', rimandi_json('attestazione', a.id))
      order by a.anno_da) from att a), '[]'::jsonb),
  'connessioni', coalesce((select jsonb_agg(nodo_json(c.altro, p_lingua, p_anteprima) || jsonb_build_object(
      'tipo', c.tipo, 'descrizione', c.descrizione)) from con c), '[]'::jsonb),
  'falsi_miti', coalesce((select jsonb_agg(jsonb_build_object(
      'riguarda', m.esito_slug, 'etichetta', m.etichetta, 'nota', m.nota)) from miti m), '[]'::jsonb),
  'strati', coalesce((select jsonb_agg(jsonb_build_object(
      'codice', s.codice,
      'nome', coalesce(etichetta_in('strato', s.codice, p_lingua), s.nome),
      'licenza', coalesce(etichetta_in('strato', s.codice, p_lingua, 'breve'), s.licenza),
      'share_alike', s.share_alike,
      'attribuzione', coalesce(etichetta_in('strato', s.codice, p_lingua, 'descrizione'), s.attribuzione))
      order by s.codice)
      from strato s where s.codice in (select provenienza from prov)), '[]'::jsonb),
  -- opere consultabili in rete per la lingua della voce (le forme ricostruite non stanno nei dizionari)
  'consultabili', coalesce((select jsonb_agg(jsonb_build_object(
      'sigla', o.sigla, 'titolo', o.titolo, 'autore', o.autore, 'anno', o.anno, 'modello', o.modello_url, 'tipo', o.tipo)
      order by case o.tipo when 'etimologico' then 0 when 'storico' then 1 when 'lessico' then 2 else 3 end, o.sigla)
      from opera o join lingua g on g.codice = l.lingua
      where o.modello_url is not null and not l.ricostruito
        and (l.lingua = any(o.lingue) or g.varieta_di = any(o.lingue))
        -- il Wikizionario non ha tutte le parole: lo si collega solo se ne viene la glossa, cioè se la pagina esiste
        and (o.sigla <> 'Wikizionario'
             or exists (select 1 from glossa gw where gw.lessema_id = l.id and gw.provenienza = 'wikizionario'))), '[]'::jsonb)
)
from l
$$;

-- ---------------------------------------------------------------------
--  6. Controlli di qualità e collezioni
-- ---------------------------------------------------------------------
-- Coda di verifica: le parole italiane più usate la cui etimologia non è ancora verificata sulle fonti
create view v_da_verificare as
select l.id, l.slug, l.lemma, f.rango, l.stato_editoriale, l.provenienza,
       (select h.etichetta from ipotesi h where h.esito_id = l.id and h.stato = 'accolta' limit 1) as ipotesi_accolta,
       (select count(*) from rimando r join ipotesi h on h.id = r.ipotesi_id where h.esito_id = l.id) as rimandi
from lessema l
join frequenza f on f.lingua = l.lingua and f.forma = l.lemma
where l.lingua = 'it' and l.stato_editoriale in ('bozza', 'importato', 'rivisto');

create view v_anomalie as
select 'eredita_incoerente' as controllo, r.id as relazione_id, lx.id as lessema_id,
       format('%s ← %s: «%s» non è tra le lingue da cui «%s» può ereditare',
              lx.slug, le.slug, le.lingua, lx.lingua) as dettaglio
from relazione r join lessema le on le.id = r.etimo_id join lessema lx on lx.id = r.esito_id
where r.tipo = 'eredita' and le.lingua not in (select lingue_ascendenti(lx.lingua))
union all
select 'formazione_tra_lingue', r.id, lx.id,
       format('%s ← %s (%s): la formazione avviene dentro una lingua; manca un passaggio intermedio?',
              lx.slug, le.slug, r.tipo)
from relazione r
join tipo_relazione t on t.codice = r.tipo
join lessema le on le.id = r.etimo_id join lingua ge on ge.codice = le.lingua
join lessema lx on lx.id = r.esito_id join lingua gx on gx.codice = lx.lingua
where t.categoria = 'formazione' and r.tipo <> 'calco'
  and coalesce(ge.varieta_di, ge.codice) <> coalesce(gx.varieta_di, gx.codice)
union all
select 'dotto_da_lingua_non_classica', r.id, lx.id,
       format('%s ← %s: voce dotta da una lingua che non è latino o greco', lx.slug, le.slug)
from relazione r
join lessema le on le.id = r.etimo_id join lingua ge on ge.codice = le.lingua
join lessema lx on lx.id = r.esito_id
where r.tipo in ('prestito_dotto', 'semidotto') and coalesce(ge.varieta_di, ge.codice) not in ('la', 'grc')
union all
select 'ricostruito_attestato', null, l.id,
       format('%s è marcato come ricostruito ma risulta attestato: togliere l''asterisco?', l.slug)
from lessema l
where l.ricostruito and exists (select 1 from attestazione a where a.lessema_id = l.id)
union all
select 'ipotesi_senza_archi', null, h.esito_id,
       format('ipotesi «%s» su %s: origine «etimo» ma nessun arco', h.etichetta,
              (select slug from lessema where id = h.esito_id))
from ipotesi h
where h.origine = 'etimo' and not exists (select 1 from relazione r where r.ipotesi_id = h.id)
union all
select 'archi_in_ipotesi_senza_etimo', null, h.esito_id,
       format('ipotesi «%s» su %s: origine «%s» ma con archi', h.etichetta,
              (select slug from lessema where id = h.esito_id), h.origine)
from ipotesi h
where h.origine <> 'etimo' and exists (select 1 from relazione r where r.ipotesi_id = h.id)
union all
select 'traduzione_nella_lingua_di_base', null, l.id,
       format('%s: glossa «%s» tradotta nella lingua della glossa di base', l.slug, t.lingua)
from glossa t join lessema l on l.id = t.lessema_id
where t.accezione_id is null and t.lingua = l.glossa_lingua
union all
select 'slug_non_ascii', null, l.id,
       format('%s: indirizzo con caratteri non latini, manca la traslitterazione?', l.slug)
from lessema l
where l.slug ~ '[^ -~]';

create view v_falsi_miti as
select h.id as ipotesi_id, l.slug, l.lemma, h.etichetta, h.nota,
       (select string_agg(e.lemma, ' + ' order by r.ordine)
          from relazione r join lessema e on e.id = r.etimo_id
         where r.ipotesi_id = h.id) as falso_etimo,
       (select h2.etichetta from ipotesi h2
         where h2.esito_id = h.esito_id and h2.stato = 'accolta') as ipotesi_accolta
from ipotesi h join lessema l on l.id = h.esito_id
where h.stato = 'respinta' and h.diffusa;

-- Radici e capostipiti: ogni nodo senza antenati accolti che ha discendenti.
-- Il dizionario si sfoglia da qui, in qualunque lingua e famiglia.
--   dichiarata = forma ricostruita, radice formale (pos «rad.», come *ped- o
--                l'arabo ṣ-f-r) oppure origine dichiarata senza etimo (ignota,
--                sostrato, onomatopea, espressiva)
--   provvisoria = l'etimologia non è ancora stata risalita
-- La famiglia comprende trasmissioni e formazioni: stella e star stanno nella
-- stessa famiglia anche se non sono la stessa parola.
create view v_radici as
select l.id, l.slug, l.lemma, l.lingua, l.ricostruito, l.glossa,
       (l.ricostruito or coalesce(l.pos = 'rad.', false)
        or exists (select 1 from ipotesi h
                    where h.esito_id = l.id and h.stato = 'accolta' and h.origine <> 'etimo')) as dichiarata,
       count(*) as discendenti,
       count(distinct x.lingua) as lingue
from mv_famiglia f
join lessema l on l.id = f.capo
join lessema x on x.id = f.id
group by l.id, l.slug, l.lemma, l.lingua, l.ricostruito, l.glossa, l.pos;

-- ---------------------------------------------------------------------
--  7. Funzione di servizio per la redazione
--  collega('it/fegato', 'la/ficatum', 'eredita'): crea l'arco e, se manca,
--  l'ipotesi che lo contiene
-- ---------------------------------------------------------------------
create function collega(
  p_esito text, p_etimo text, p_tipo text,
  p_ipotesi text default 'principale',
  p_stato stato_ipotesi default 'accolta',
  p_confidenza int default 3,
  p_forma text default null,
  p_ordine int default 1,
  p_affisso text default null,
  p_nota text default null,
  p_provenienza text default 'redazione',
  p_stato_editoriale stato_editoriale default 'bozza'
) returns bigint language plpgsql as $$
declare v_esito bigint := lx(p_esito); v_etimo bigint := lx(p_etimo); v_ip bigint; v_rel bigint;
begin
  select id into v_ip from ipotesi where esito_id = v_esito and etichetta = p_ipotesi;
  if v_ip is null then
    insert into ipotesi (esito_id, etichetta, stato, confidenza, provenienza, stato_editoriale)
    values (v_esito, p_ipotesi, p_stato, p_confidenza, p_provenienza, p_stato_editoriale)
    returning id into v_ip;
  end if;
  insert into relazione (ipotesi_id, esito_id, etimo_id, tipo, ordine, forma_citata, affisso,
                         confidenza, nota, provenienza, stato_editoriale)
  values (v_ip, v_esito, v_etimo, p_tipo, p_ordine, p_forma, p_affisso,
          p_confidenza, p_nota, p_provenienza, p_stato_editoriale)
  returning id into v_rel;
  return v_rel;
end $$;

-- ===== Analisi di un testo (8 novembre 2026) =====
-- Le parole di un testo per lingua d'origine, come la «distribuzione etimologica» di Teodorescu, Bolea e Teodorescu
-- (IEEE HPEC 2025). Ogni forma va ai suoi lemmi (forma_lemma, o la forma stessa se è un lemma); per ogni lemma si risale
-- la catena accolta finché resta nella lingua del testo (o in una sua varietà: l'italiano antico è italiano), e la prima
-- lingua diversa è l'origine, raggruppata per lingua madre (il latino volgare sotto il latino). La via d'ingresso viene
-- dal tipo di quel passaggio: popolare (eredità), dotta (prestito dotto, semidotto), prestito, altro. Una forma con più
-- lemmi possibili conta per ciascuno in parti uguali; un lemma senza un'origine nota va a parte. Una forma che è solo una
-- riduzione o una grafia senza accento (dalla = da + la, piu = più: forma_lemma.sostituisce) conta per i lemmi a cui
-- rimanda e non per la voce omonima; e una voce omonima senza etimologia non conta quando la forma ha un lemma (ha: avere).
create function analizza_testo(p_lingua text, p_forme text[], p_conteggi int[], p_lang text default 'it',
                               p_anteprima boolean default false)
returns jsonb language sql stable as $$
with recursive
forme as (
  select lower(f) as forma, sum(coalesce(c, 1))::numeric as n
    from unnest(p_forme, p_conteggi) as u(f, c)
   where f is not null and btrim(f) <> ''
   group by 1),
lemmi as (
  select f.forma, fl.lemma from forme f join forma_lemma fl on fl.lingua = p_lingua and fl.forma = f.forma
  union
  select f.forma, f.forma from forme f
   where not exists (select 1 from forma_lemma fl where fl.lingua = p_lingua and fl.forma = f.forma and fl.sostituisce)
     -- una voce omonima senza etimologia non ruba peso al lemma della forma (ha: avere, non la voce ha; sono: essere)
     and (not exists (select 1 from forma_lemma fl where fl.lingua = p_lingua and fl.forma = f.forma)
          or exists (select 1 from lessema l join ipotesi h on h.esito_id = l.id and h.stato = 'accolta'
                      where l.lingua = p_lingua and l.lemma = f.forma and not l.ricostruito))),
voci as (
  select x.forma, l.id, l.lemma, l.slug
    from lemmi x
    join lessema l on l.lingua = p_lingua and l.lemma = x.lemma and not l.ricostruito
                  and visibile(l.stato_editoriale, p_anteprima)),
pesi as (
  select v.id, v.lemma, v.slug, sum(f.n / (select count(*) from voci w where w.forma = v.forma)) as peso
    from voci v join forme f on f.forma = v.forma
   group by v.id, v.lemma, v.slug),
salita (voce, id, prof, lingua, tipo) as (
  select p.id, p.id, 0, p_lingua, null::text from pesi p
  union all
  select s.voce, x.etimo_id, s.prof + 1, coalesce(g.varieta_di, g.codice), x.tipo
    from salita s
    join ipotesi h on h.esito_id = s.id and h.stato = 'accolta' and visibile(h.stato_editoriale, p_anteprima)
    join relazione x on x.ipotesi_id = h.id and x.ordine = 1
    join lessema e on e.id = x.etimo_id
    join lingua g on g.codice = e.lingua
   where s.lingua = p_lingua and s.prof < 12),
uscita as (
  select distinct on (voce) voce, lingua, tipo from salita where lingua <> p_lingua order by voce, prof),
classi as (
  select p.id, p.lemma, p.slug, p.peso, u.lingua,
         case when u.tipo = 'eredita' then 'popolare'
              when u.tipo in ('prestito_dotto', 'semidotto') then 'dotta'
              when u.tipo in ('prestito', 'calco') then 'prestito'
              when u.tipo is not null then 'altro' end as via
    from pesi p left join uscita u on u.voce = p.id),
per_lingua as (
  select c.lingua, sum(c.peso) as peso, count(*) as lemmi,
         jsonb_build_object('popolare', round(coalesce(sum(c.peso) filter (where c.via = 'popolare'), 0), 2),
                            'dotta', round(coalesce(sum(c.peso) filter (where c.via = 'dotta'), 0), 2),
                            'prestito', round(coalesce(sum(c.peso) filter (where c.via = 'prestito'), 0), 2),
                            'altro', round(coalesce(sum(c.peso) filter (where c.via = 'altro'), 0), 2)) as vie,
         (select jsonb_agg(jsonb_build_object('lemma', e.lemma, 'slug', e.slug, 'peso', round(e.peso, 2)) order by e.peso desc, e.lemma)
            from (select * from classi d where d.lingua is not distinct from c.lingua order by d.peso desc, d.lemma limit 8) e) as esempi
    from classi c
   group by c.lingua)
select jsonb_build_object(
  'occorrenze', (select coalesce(sum(n), 0) from forme),
  'forme', (select count(*) from forme),
  'riconosciute', (select coalesce(sum(f.n), 0) from forme f where exists (select 1 from voci v where v.forma = f.forma)),
  'lemmi', (select count(*) from pesi),
  'origini', coalesce((
     select jsonb_agg(jsonb_build_object('codice', p.lingua, 'nome', coalesce(etichetta_in('lingua', p.lingua, p_lang), g.nome),
                                         'ramo', g.ramo, 'peso', round(p.peso, 2), 'lemmi', p.lemmi, 'vie', p.vie,
                                         'esempi', p.esempi) order by p.peso desc)
       from per_lingua p join lingua g on g.codice = p.lingua), '[]'::jsonb),
  'senza_origine', coalesce((
     select jsonb_build_object('peso', round(p.peso, 2), 'lemmi', p.lemmi, 'esempi', p.esempi)
       from per_lingua p where p.lingua is null), jsonb_build_object('peso', 0, 'lemmi', 0, 'esempi', '[]'::jsonb)),
  'sconosciute', coalesce((
     select jsonb_agg(x.forma order by x.n desc, x.forma)
       from (select f.forma, f.n from forme f where not exists (select 1 from voci v where v.forma = f.forma)
              order by f.n desc, f.forma limit 40) x), '[]'::jsonb));
$$;
comment on function analizza_testo(text, text[], int[], text, boolean) is
  'Le parole di un testo per lingua d''origine e via d''ingresso, risalendo le catene accolte (pagina «Analizza un testo»).';

-- L'indice delle radici per area di significato (8 novembre 2026): le forme ricostruite in cima a una famiglia, di una
-- protolingua. Senza area: per ogni area le radici con più discendenti (p_in_vista), e quante sono. Con un'area: tutte le
-- sue radici in ordine alfabetico, a pagine, con le iniziali. Per ogni radice fino a quattro parole della lingua del
-- lettore che ne discendono, come in elenco_radici().
create or replace function indice_radici(p_lingua text default 'it', p_anteprima boolean default false,
                                         p_capo_lingua text default 'ine-pro', p_area text default null,
                                         p_pagina int default 1, p_per_pagina int default 200, p_in_vista int default 8)
returns jsonb language sql stable as $$
with
capi as (
  select f.capo as id, count(*) as discendenti, count(distinct x.lingua) as lingue
    from mv_famiglia f join lessema c on c.id = f.capo join lessema x on x.id = f.id
   where c.ricostruito and (p_anteprima or f.pubblico)
     and visibile(c.stato_editoriale, p_anteprima) and visibile(x.stato_editoriale, p_anteprima)
   group by f.capo),
tutti as (
  select k.*, l.lemma, l.lingua, coalesce(a.area, '') as area, lower(left(nullif(l.lemma_norm, ''), 1)) as iniziale,
         coalesce(l.lemma_norm, l.lemma) as ordine
    from capi k join lessema l on l.id = k.id left join area_radice a on a.lessema_id = k.id),
scelte as (select * from tutti where lingua = p_capo_lingua),
vista as (
  select * from (
    select s.*, row_number() over (partition by s.area order by s.discendenti desc, s.ordine) as pos
      from scelte s where p_area is null) v
   where pos <= p_in_vista
  union all
  select s.*, 0 from scelte s where s.area = p_area
   order by 1 offset 0),
pagina as (
  select * from vista where p_area is null
  union all
  select * from (select * from vista where p_area is not null order by ordine, lemma
                  offset (greatest(p_pagina, 1) - 1) * p_per_pagina limit p_per_pagina) x),
esempi as (
  select pg.id, (
    select jsonb_agg(e.lemma order by e.rango nulls last, e.prof, e.lemma) from (
      select x.lemma, min(case when x.omografo = 1 then q.rango end) as rango, min(f.profondita) as prof
        from mv_famiglia f join lessema x on x.id = f.id
        left join frequenza q on q.lingua = x.lingua and q.forma = x.lemma
       where f.capo = pg.id and x.id <> pg.id and x.lingua = p_lingua and not x.nome_proprio and x.nome_indice is not true
         and (p_anteprima or f.pubblico) and visibile(x.stato_editoriale, p_anteprima)
       group by x.lemma
       order by rango nulls last, prof, x.lemma limit 4) e) as esempi
    from pagina pg),
voce as (
  select pg.area, pg.id, pg.discendenti, pg.ordine, pg.lemma,
         nodo_json(pg.id, p_lingua, p_anteprima) || jsonb_build_object('discendenti', pg.discendenti, 'lingue', pg.lingue,
           'esempi', coalesce(e.esempi, '[]'::jsonb), 'area', nullif(pg.area, ''), 'iniziale', pg.iniziale) as j
    from pagina pg join esempi e on e.id = pg.id)
select jsonb_build_object(
  'capo_lingua', p_capo_lingua, 'area', p_area, 'pagina', greatest(p_pagina, 1), 'per_pagina', p_per_pagina,
  'totale', (select count(*) from scelte),
  'gruppi', coalesce((select jsonb_agg(jsonb_build_object('lingua', g.lingua, 'n', g.n,
                        'nome', coalesce(etichetta_in('lingua', g.lingua, p_lingua), l.nome)) order by g.n desc, g.lingua)
                      from (select lingua, count(*) as n from tutti group by lingua) g join lingua l on l.codice = g.lingua), '[]'::jsonb),
  'aree', coalesce((select jsonb_agg(jsonb_build_object('area', x.area, 'n', x.n,
                       'nome', case when p_lingua = 'it' then a.it else a.en end) order by coalesce(a.ordine, 99))
                    from (select area, count(*) as n from scelte group by area) x
                    left join area_semantica a on a.codice = x.area), '[]'::jsonb),
  'iniziali', case when p_area is null then '[]'::jsonb else coalesce((
      select jsonb_agg(jsonb_build_object('iniziale', i.iniziale, 'n', i.n, 'pagina', i.pagina) order by i.iniziale)
        from (select iniziale, count(*) as n,
                     min((rn - 1) / p_per_pagina + 1) as pagina
                from (select iniziale, row_number() over (order by ordine, lemma) as rn from scelte where area = p_area) r
               group by iniziale) i), '[]'::jsonb) end,
  'sezioni', case when p_area is not null then '[]'::jsonb else coalesce((
      select jsonb_agg(jsonb_build_object('area', x.area, 'n', x.n,
                         'nome', case when p_lingua = 'it' then a.it else a.en end,
                         'radici', (select jsonb_agg(v.j order by v.discendenti desc, v.ordine) from voce v where v.area = x.area))
                       order by coalesce(a.ordine, 99))
        from (select area, count(*) as n from scelte group by area) x left join area_semantica a on a.codice = x.area), '[]'::jsonb) end,
  'radici', case when p_area is null then '[]'::jsonb
                 else coalesce((select jsonb_agg(v.j order by v.ordine, v.lemma) from voce v), '[]'::jsonb) end)
$$;
comment on function indice_radici(text, boolean, text, text, int, int, int) is
  'L''indice delle radici ricostruite di una protolingua, per area di significato e, dentro un''area, in ordine alfabetico.';

-- L'area di significato di una radice scelta dalla redazione (editor, sezione «Area di significato»): confermare l'area
-- di Claude o sceglierne un'altra la rende della redazione, e l'import non la tocca più. area_radice non ha un id: la
-- modifica entra nello storico con l'id della voce. Si tolgono solo con la voce: senza area, l'import rimetterebbe
-- quella di Claude.
create or replace function imposta_area_radice(p_lessema bigint, p_area text) returns boolean
language plpgsql as $$
declare
  v_prima jsonb;
  v_dopo jsonb;
begin
  if not exists (select 1 from lessema where id = p_lessema and ricostruito) then
    raise exception 'un''area di significato ce l''hanno solo le forme ricostruite' using errcode = 'P0001';
  end if;
  select to_jsonb(a) into v_prima from area_radice a where a.lessema_id = p_lessema;
  insert into area_radice (lessema_id, area, provenienza, modello) values (p_lessema, p_area, 'redazione', null)
  on conflict (lessema_id) do update set area = excluded.area, provenienza = 'redazione', modello = null;
  select to_jsonb(a) into v_dopo from area_radice a where a.lessema_id = p_lessema;
  if v_prima is distinct from v_dopo then
    insert into storico (tabella, record_id, operazione, prima, dopo)
    values ('area_radice', p_lessema, case when v_prima is null then 'I' else 'U' end, v_prima, v_dopo);
    return true;
  end if;
  return false;
end $$;
comment on function imposta_area_radice(bigint, text) is
  'L’area di una radice scelta o confermata dalla redazione: provenienza redazione, con la riga prima e dopo nello storico.';
