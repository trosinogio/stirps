-- 2 novembre 2026: fase 0 delle prime attestazioni. Un'attestazione può essere una stima (terminus ante quem trovato in
-- automatico), con la sua confidenza, e una stima non può essere «verificata»; la scheda lo dice. La tabella degli autori
-- citati dai dizionari, con la datazione. Scheda copiata da db/02_logica.sql. Ripetibile senza danni.

alter table attestazione add column if not exists stima boolean not null default false;
alter table attestazione add column if not exists confidenza smallint check (confidenza between 1 and 4);
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'attestazione_stima_non_verificata') then
    alter table attestazione add constraint attestazione_stima_non_verificata check (not (stima and stato_editoriale = 'verificato'));
  end if;
end $$;
comment on column attestazione.stima is 'Terminus ante quem trovato in automatico (corpus, citazioni di un dizionario): la parola è attestata almeno da allora. Non è la prima attestazione finché la redazione non la verifica sulla fonte, e una stima non può essere «verificata».';
comment on column attestazione.confidenza is 'Per le stime: 4 sicura · 3 probabile · 2 possibile · 1 dubbia (per esempio un anno isolato in un corpus OCR).';

-- Gli autori citati dai dizionari (Lewis & Short, LSJ) con la loro datazione: dall'autore più antico citato in una voce
-- si ricava una stima della prima attestazione. La sigla è quella del dizionario, per lingua (Plaut., Hom.).
create table if not exists autore (
  lingua      text not null references lingua,
  sigla       text not null,
  nome        text not null,
  anno_da     int,
  anno_a      int,
  precisione  precisione_data not null default 'circa',
  wikidata    text,
  fonte       text,
  primary key (lingua, sigla),
  check (anno_a is null or anno_da is null or anno_a >= anno_da)
);
comment on table autore is 'Autori citati dai dizionari, con la datazione (anni interi, negativi a.C.) e la sua fonte.';

create or replace function scheda(p_slug text, p_anteprima boolean default false, p_lingua text default 'it')
returns jsonb language sql stable as $$
with
l   as (select * from lessema where slug = p_slug and visibile(stato_editoriale, p_anteprima)),
gl  as (select t.* from glossa t join l on t.lessema_id = l.id
        where t.accezione_id is null and t.lingua = p_lingua and visibile(t.stato_editoriale, p_anteprima)),
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
  union select provenienza from gl
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
      'glossa_automatica', exists (select 1 from gl where gl.provenienza = 'traduzione-automatica' and gl.stato_editoriale = 'importato'),
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
