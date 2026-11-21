-- Il protosemitico ha due notazioni in Wiktionary, *ʾil- e *ʔil- (e *ʿayn- e *ʕayn-): dal 20 novembre 2026 il parser
-- scrive solo la seconda (NOTAZIONE_SEMITICA in import/wiktionary.py). Le voci già nel database con la prima cambiano
-- notazione qui, prima dell'import, e restano la stessa riga con le loro definizioni, glosse e legami: altrimenti l'import
-- creava una voce nuova e la definizione di Claude passava dalla vecchia alla nuova (7 definizioni «cadute» nella prova
-- su Neon del 20 novembre). Solo le voci intatte di Wiktionary.
-- Dove c'erano già tutte e due le notazioni (*ʾil- e *ʔil-), la vecchia è un doppione: la sua definizione e la sua glossa di
-- Claude passano alla nuova, se lì mancano (altrimenti si tolgono), e la voce vecchia, rimasta intatta, la toglie la
-- pulizia dell'import. Con lo storico sospeso, come nell'import: non è lavoro della redazione.
-- Ripetibile: dopo il primo giro non trova più niente.
select set_config('app.import', 'on', true);

create temp table if not exists notazione_semitica (vecchia bigint primary key, nuova bigint);
truncate notazione_semitica;
insert into notazione_semitica
select l.id, x.id
  from lessema l
  left join lessema x on x.id_esterno = translate(l.id_esterno, 'ʾʿ', 'ʔʕ')
 where l.lingua in ('sem-pro', 'sem-wes-pro', 'afa-pro')
   and l.id_esterno ~ '[ʾʿ]'
   and l.provenienza = 'wiktionary' and l.stato_editoriale = 'importato';

-- 1. i doppioni: definizione e glossa di Claude alla voce nuova, se lì mancano; altrimenti via
update definizione d set lessema_id = n.nuova
  from notazione_semitica n
 where n.nuova is not null and d.lessema_id = n.vecchia and d.stato_editoriale = 'importato'
   and not exists (select 1 from definizione y where y.lessema_id = n.nuova and y.lingua = d.lingua);
delete from definizione d using notazione_semitica n
 where n.nuova is not null and d.lessema_id = n.vecchia and d.stato_editoriale = 'importato';
update glossa g set lessema_id = n.nuova
  from notazione_semitica n
 where n.nuova is not null and g.lessema_id = n.vecchia and g.accezione_id is null
   and g.provenienza = 'claude' and g.stato_editoriale = 'importato'
   and not exists (select 1 from glossa y where y.lessema_id = n.nuova and y.lingua = g.lingua and y.accezione_id is null);
delete from glossa g using notazione_semitica n
 where n.nuova is not null and g.lessema_id = n.vecchia and g.accezione_id is null
   and g.provenienza = 'claude' and g.stato_editoriale = 'importato';

-- 2. le altre cambiano notazione, se nessun'altra voce ha già quel lemma e quel numero d'omografo
update lessema l
   set id_esterno = translate(l.id_esterno, 'ʾʿ', 'ʔʕ'),
       lemma = translate(l.lemma, 'ʾʿ', 'ʔʕ')
  from notazione_semitica n
 where n.vecchia = l.id and n.nuova is null
   and not exists (select 1 from lessema x where x.lingua = l.lingua and x.id <> l.id
                     and x.lemma = translate(l.lemma, 'ʾʿ', 'ʔʕ') and x.omografo = l.omografo);
