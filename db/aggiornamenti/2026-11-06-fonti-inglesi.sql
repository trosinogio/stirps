-- 6 novembre 2026: le fonti centrali per l'inglese. Ogni voce inglese rimanda, tra le opere «da consultare», all'OED,
-- all'American Heritage Dictionary e all'Online Etymology Dictionary (che c'era già); le radici indoeuropee di
-- Calvert Watkins entrano in bibliografia. Sono collegamenti e citazioni: i testi di queste opere sono protetti e non
-- si importano. Stesso contenuto di db/03_seed_pilota.sql. Ripetibile senza danni.

update opera set modello_url = 'https://www.oed.com/search/dictionary/?scope=Entries&q={lemma}'
 where sigla = 'OED' and modello_url is null;

insert into opera (sigla, autore, titolo, edizione, anno, editore, url, pubblico_dominio, ambito, lingue, modello_url, tipo, nota) values
('AHD', null, 'The American Heritage Dictionary of the English Language', '5ª ed.', 2011, 'Houghton Mifflin Harcourt', 'https://www.ahdictionary.com', false, 'germanico', '{en}', 'https://www.ahdictionary.com/word/search.html?q={lemma}', 'lessico', 'con le radici indoeuropee di Calvert Watkins in appendice'),
('Watkins', 'Calvert Watkins', 'The American Heritage Dictionary of Indo-European Roots', '3ª ed.', 2011, 'Houghton Mifflin Harcourt', null, false, 'indoeuropeo', '{ine-pro}', null, 'etimologico', null)
on conflict (sigla) do nothing;
