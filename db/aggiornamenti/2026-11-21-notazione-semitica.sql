-- Il protosemitico ha due notazioni in Wiktionary, *ʾil- e *ʔil- (e *ʿayn- e *ʕayn-): dal 20 novembre 2026 il parser
-- scrive solo la seconda (NOTAZIONE_SEMITICA in import/wiktionary.py). Le voci già nel database con la prima cambiano
-- notazione qui, prima dell'import, e restano la stessa riga con le loro definizioni, glosse e legami: altrimenti l'import
-- creava una voce nuova e la definizione di Claude passava dalla vecchia alla nuova (7 definizioni «cadute» nella prova
-- su Neon del 20 novembre). Solo le voci intatte di Wiktionary, e solo se la voce con la notazione nuova non c'è già.
-- Ripetibile: dopo il primo giro non trova più niente.
update lessema l
   set id_esterno = translate(l.id_esterno, 'ʾʿ', 'ʔʕ'),
       lemma = translate(l.lemma, 'ʾʿ', 'ʔʕ')
 where l.lingua in ('sem-pro', 'sem-wes-pro', 'afa-pro')
   and l.id_esterno ~ '[ʾʿ]'
   and l.provenienza = 'wiktionary' and l.stato_editoriale = 'importato'
   and not exists (select 1 from lessema x where x.id_esterno = translate(l.id_esterno, 'ʾʿ', 'ʔʕ'))
   and not exists (select 1 from lessema x where x.lingua = l.lingua and x.id <> l.id
                     and x.lemma = translate(l.lemma, 'ʾʿ', 'ʔʕ') and x.omografo = l.omografo);
