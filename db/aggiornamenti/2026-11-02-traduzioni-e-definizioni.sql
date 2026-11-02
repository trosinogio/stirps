-- 2 novembre 2026: traduzioni e definizioni di Claude. La tabella delle definizioni (una per voce e lingua, della
-- redazione o di un modello), lo strato «claude», la tabella d'appoggio; la traduzione di Claude viene prima di quella di
-- OPUS-MT, Wikidata prima di entrambe; la scheda porta la definizione. Funzioni copiate da db/02_logica.sql e
-- db/05_import_wiktionary.sql. Ripetibile senza danni.

create table if not exists definizione (
  id                bigint generated always as identity primary key,
  lessema_id        bigint not null references lessema on delete cascade,
  lingua            text not null references lingua,
  testo             text not null,
  provenienza       text not null default 'redazione' references strato,
  modello           text,
  stato_editoriale  stato_editoriale not null default 'bozza',
  creato_il         timestamptz not null default now(),
  aggiornato_il     timestamptz not null default now(),
  unique (lessema_id, lingua),
  check (testo = btrim(testo) and testo <> '')
);
comment on column definizione.modello is 'Il modello che l''ha scritta (claude-opus-5-5…), per le definizioni automatiche.';
create or replace trigger definizione_tocca before update on definizione for each row execute function tocca();
create or replace trigger definizione_storico after insert or update or delete on definizione
  for each row execute function registra_storico();

create table if not exists stg_definizione (chiave text, originale text, traduzione text, definizione text, modello text);

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
               and coalesce(d.originale, '') = coalesce(l.glossa, '') and l.stato_editoriale <> 'superato'
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
     where btrim(coalesce(d.definizione, '')) <> '' and coalesce(d.originale, '') = coalesce(l.glossa, '')
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
comment on function importa_definizioni() is 'Definizioni italiane scritte da Claude, per differenza: solo per la glossa da cui sono nate, e mai sopra quelle della redazione o rivedute.';

create or replace function nodo_json(p_id bigint, p_lingua text default 'it', p_anteprima boolean default false) returns jsonb
language sql stable as $$
  select jsonb_build_object('id', x.id, 'slug', x.slug, 'lingua', x.lingua,
           'lingua_nome', coalesce(etichetta_in('lingua', x.lingua, p_lingua), g.nome),
           'lingua_sigla', coalesce(etichetta_in('lingua', x.lingua, p_lingua, 'breve'), g.sigla),
           'ramo', g.ramo, 'lemma', x.lemma, 'ricostruito', x.ricostruito, 'translit', x.translit,
           'glossa', coalesce(t.testo, x.glossa),
           'glossa_lingua', case when t.testo is not null then t.lingua else x.glossa_lingua end,
           'glossa_automatica', coalesce(t.provenienza in ('traduzione-automatica', 'claude') and t.stato_editoriale = 'importato', false))
  from lessema x
  join lingua g on g.codice = x.lingua
  left join glossa t on t.lessema_id = x.id and t.accezione_id is null and t.lingua = p_lingua
                    and visibile(t.stato_editoriale, p_anteprima)
  where x.id = p_id
$$;

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

create or replace function scheda(p_slug text, p_anteprima boolean default false, p_lingua text default 'it')
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
