-- 6 novembre 2026: le ultime tre tabelle d'appoggio dell'import (glosse di Wikidata, glosse tradotte, definizioni)
-- diventano unlogged come le altre. Durante l'import le tabelle d'appoggio contengono tutto il pacchetto, e con
-- l'inglese il database passa per un picco di quasi il doppio della sua dimensione finale: le tabelle unlogged non
-- scrivono il WAL e su Neon stanno sul disco locale del calcolo. Svuotate a ogni import, non hanno nulla da perdere.
-- Stesso contenuto di db/05_import_wiktionary.sql. Ripetibile senza danni: su una tabella già unlogged non fa nulla.
alter table if exists stg_glossa_wikidata set unlogged;
alter table if exists stg_glossa_tradotta set unlogged;
alter table if exists stg_definizione set unlogged;
