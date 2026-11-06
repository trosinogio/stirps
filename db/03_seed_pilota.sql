-- =====================================================================
--  Dizionario etimologico — seme pilota v0.4
--  Contenuti ILLUSTRATIVI per collaudare il modello: tutti in «bozza»,
--  da verificare sulle fonti prima di qualunque pubblicazione.
--  I rimandi bibliografici sono «s.v.» senza pagina.
-- =====================================================================

-- ---------------------------------------------------------------------
--  Strati e licenze
-- ---------------------------------------------------------------------
insert into strato (codice, nome, licenza, share_alike, attribuzione, url) values
('redazione',  'Redazione',                               'Riservata (licenza da definire)', false, null, null),
('wiktionary', 'Wiktionary, via Kaikki/wiktextract',      'CC BY-SA 4.0',                    true,
               'Contiene dati tratti da Wiktionary, distribuiti con licenza CC BY-SA 4.0.', 'https://kaikki.org'),
('wikizionario', 'Wikizionario, via Kaikki/wiktextract',  'CC BY-SA 4.0',                    true,
               'Contiene glosse tratte dal Wikizionario, distribuite con licenza CC BY-SA 4.0.', 'https://it.wiktionary.org'),
('frequencywords', 'FrequencyWords (OpenSubtitles 2018)', 'CC BY-SA 4.0',                    true,
               'Contiene frequenze d''uso tratte da FrequencyWords di Hermit Dave, distribuite con licenza CC BY-SA 4.0.', 'https://github.com/hermitdave/FrequencyWords'),
('rew',        'Meyer-Lübke, REW, 3ª ed. 1935',           'Pubblico dominio (UE)',           false, null, null),
('pianigiani', 'Pianigiani, Vocabolario etimologico, 1907', 'Pubblico dominio',              false, null, null);

-- ---------------------------------------------------------------------
--  Lingue (prima gli antenati, poi i discendenti)
-- ---------------------------------------------------------------------
insert into lingua (codice, nome, sigla, famiglia, ramo, iso639_3, antenato, varieta_di, ricostruita, anno_da, anno_a, lat, lon) values
('ine-pro', 'protoindoeuropeo', 'PIE',          'indoeuropea', null,          null,  null,      null, true,  null,  null, null,   null),
('itc-pro', 'protoitalico',     'protoital.',   'indoeuropea', 'italica',     null,  'ine-pro', null, true,  null,  null, null,   null),
('gem-pro', 'protogermanico',   'protogerm.',   'indoeuropea', 'germanica',   null,  'ine-pro', null, true,  null,  null, null,   null),
('sla-pro', 'protoslavo',       'protoslavo',   'indoeuropea', 'slava',       null,  'ine-pro', null, true,  null,  null, null,   null),
('la',      'latino',           'lat.',         'indoeuropea', 'italica',     'lat', 'itc-pro', null, false, -700,  600,  41.89,  12.49),
('la-vul',  'latino volgare',   'lat. volg.',   'indoeuropea', 'italica',     null,  null,      'la', false, 100,   700,  null,   null),
('la-med',  'latino medievale', 'lat. mediev.', 'indoeuropea', 'italica',     null,  null,      'la', false, 700,   1500, null,   null),
('grc',     'greco antico',     'gr. ant.',     'indoeuropea', 'ellenica',    'grc', 'ine-pro', null, false, -800,  600,  37.98,  23.73),
('sa',      'sanscrito',        'sscr.',        'indoeuropea', 'indoiranica', 'san', 'ine-pro', null, false, -1500, null, 30.00,  76.00),
('it',      'italiano',         'it.',          'indoeuropea', 'italica',     'ita', 'la',      null, false, 960,   null, 43.77,  11.25),
('fro',     'francese antico',  'fr. ant.',     'indoeuropea', 'italica',     'fro', 'la',      null, false, 842,   1400, 48.86,   2.35),
('fr',      'francese',         'fr.',          'indoeuropea', 'italica',     'fra', 'fro',     null, false, 1400,  null, 48.86,   2.35),
('es',      'spagnolo',         'sp.',          'indoeuropea', 'italica',     'spa', 'la',      null, false, 1200,  null, 40.42,  -3.70),
('pt',      'portoghese',       'port.',        'indoeuropea', 'italica',     'por', 'la',      null, false, 1200,  null, 38.72,  -9.14),
('ang',     'inglese antico',   'ingl. ant.',   'indoeuropea', 'germanica',   'ang', 'gem-pro', null, false, 450,   1150, 51.06,  -1.31),
('en',      'inglese',          'ingl.',        'indoeuropea', 'germanica',   'eng', 'ang',     null, false, 1500,  null, 51.51,  -0.13),
('de',      'tedesco',          'ted.',         'indoeuropea', 'germanica',   'deu', 'gem-pro', null, false, null,  null, 52.52,  13.40),
('ru',      'russo',            'russo',        'indoeuropea', 'slava',       'rus', 'sla-pro', null, false, null,  null, 55.76,  37.62),
('pal',     'medio persiano',   'medio pers.',  'indoeuropea', 'indoiranica', 'pal', null,      null, false, -300,  900,  29.94,  52.89),
('fa',      'persiano',         'pers.',        'indoeuropea', 'indoiranica', 'fas', 'pal',     null, false, 900,   null, 35.69,  51.39),
('ar',      'arabo',            'ar.',          'afroasiatica', 'semitica',   'ara', null,      null, false, null,  null, 33.31,  44.36);

-- ---------------------------------------------------------------------
--  Tipi di relazione e processi semantici
-- ---------------------------------------------------------------------
insert into tipo_relazione (codice, etichetta, categoria, ereditario, descrizione) values
('eredita',         'eredità (trafila popolare)', 'trasmissione', true,  'Passaggio per tradizione ininterrotta, con gli esiti fonetici regolari.'),
('variante',        'variante',                   'trasmissione', true,  'Forma alternativa della stessa parola nella stessa lingua: grafica, sincopata, ridotta. Una forma dialettale si collega con eredità o prestito.'),
('prestito',        'prestito',                   'trasmissione', false, 'Parola entrata da un''altra lingua.'),
('prestito_dotto',  'prestito dotto',             'trasmissione', false, 'Ripresa colta dal latino o dal greco, senza gli esiti della trafila popolare.'),
('semidotto',       'voce semidotta',             'trasmissione', false, 'Ripresa colta solo in parte adattata alla fonetica popolare.'),
('trasmissione',    'trasmissione non specificata', 'trasmissione', false, 'La stessa parola, per una via non precisata: eredità o prestito. È il «derived from» di Wiktionary al primo livello.'),
('generico',        'filiazione non specificata', 'indeterminata', false, 'Provenienza accertata ma natura del passaggio non specificata: entra negli alberi, non nei cognati né negli allotropi.'),
('derivazione',     'derivazione',                'formazione',   false, 'Formazione con prefissi o suffissi.'),
('composizione',    'composizione',               'formazione',   false, 'Unione di due o più elementi lessicali.'),
('retroformazione', 'retroformazione',            'formazione',   false, 'Formazione per sottrazione di un presunto affisso.'),
('accorciamento',   'accorciamento',              'formazione',   false, 'Riduzione di una parola più lunga (bici < bicicletta).'),
('deonimico',       'da nome proprio',            'formazione',   false, 'Parola tratta da un nome di persona o di luogo.'),
('calco',           'calco',                      'formazione',   false, 'Parola modellata su una parola straniera, tradotta nei suoi elementi.'),
('calco_semantico', 'calco semantico',            'influsso',     false, 'Significato nuovo assunto sul modello di una parola straniera.'),
('influsso',        'incrocio o influsso',        'influsso',     false, 'Contaminazione o analogia che rimodella una forma.'),
('paretimologia',   'paretimologia',              'influsso',     false, 'Rianalisi popolare per falsa associazione con un''altra parola.');

insert into processo_semantico (codice, etichetta, descrizione) values
('metafora',        'metafora',        'Trasferimento per somiglianza.'),
('metonimia',       'metonimia',       'Trasferimento per contiguità: il luogo per ciò che vi sta, il contenitore per il contenuto.'),
('sineddoche',      'sineddoche',      'La parte per il tutto, o il tutto per la parte.'),
('estensione',      'estensione',      'Il significato si allarga.'),
('restrizione',     'restrizione',     'Il significato si restringe.'),
('peggiorativo',    'peggioramento',   'Il significato assume una connotazione negativa (captivus → cattivo).'),
('migliorativo',    'miglioramento',   'Il significato assume una connotazione positiva.'),
('ellissi',         'ellissi',         'Un elemento del sintagma ne assorbe il significato (iecur ficatum → ficatum).'),
('tecnicizzazione', 'tecnicizzazione', 'Specializzazione in un lessico tecnico (ὀβελός «spiedo» → «segno critico»).'),
('antonomasia',     'antonomasia',     'Un nome proprio per un nome comune, o viceversa.'),
('eufemismo',       'eufemismo',       'Sostituzione attenuativa.');

-- ---------------------------------------------------------------------
--  Template di Wiktionary → tipi di relazione
-- ---------------------------------------------------------------------
insert into mappa_wiktionary (template, tipo, origine, uso) values
('inh',          'eredita',         null,         'Ereditato.'),
('inh+',         'eredita',         null,         'Ereditato, con testo introduttivo.'),
('bor',          'prestito',        null,         'Prestito.'),
('bor+',         'prestito',        null,         'Prestito, con testo introduttivo.'),
('lbor',         'prestito_dotto',  null,         'Prestito dotto.'),
('slbor',        'semidotto',       null,         'Prestito semidotto.'),
('ubor',         'prestito',        null,         'Prestito non adattato.'),
('obor',         'prestito',        null,         'Prestito ortografico.'),
('der',          'generico',        null,         'Legame indeterminato: Wiktionary lo usa sia per la stessa parola per via non precisata sia per le derivazioni, quindi non basta per dire che sia la stessa parola.'),
('der+',         'generico',        null,         'Come der, con testo introduttivo.'),
('cal',          'calco',           null,         'Calco.'),
('calque',       'calco',           null,         'Calco (forma estesa del nome).'),
('sl',           'calco_semantico', null,         'Calco semantico.'),
('psm',          'calco',           null,         'Adattamento fono-semantico: da rivedere caso per caso.'),
('bf',           'retroformazione', null,         'Retroformazione.'),
('clipping',     'accorciamento',   null,         'Accorciamento.'),
('af',           'derivazione',     null,         'Affissazione; se gli elementi sono parole autonome è composizione: da rivedere.'),
('affix',        'derivazione',     null,         'Come af.'),
('suffix',       'derivazione',     null,         'Suffissazione.'),
('prefix',       'derivazione',     null,         'Prefissazione.'),
('compound',     'composizione',    null,         'Composto.'),
('blend',        'composizione',    null,         'Parola macedonia.'),
('named-after',  'deonimico',       null,         'Da nome proprio.'),
('onom',         null,              'onomatopea', 'Onomatopea: ipotesi senza archi.'),
('onomatopoeic', null,              'onomatopea', 'Come onom.'),
('unk',          null,              'ignota',     'Origine ignota: ipotesi senza archi.'),
('unc',          null,              null,         'Segnala incertezza: abbassare la confidenza dell''ipotesi.'),
('dbt',          null,              null,         'Allotropo dichiarato: nessun arco, serve a confrontare gli allotropi calcolati.'),
('cog',          null,              null,         'Cognato dichiarato: nessun arco, serve a confrontare i cognati calcolati.'),
('m',            null,              null,         'Semplice menzione: nessun arco.');

-- ---------------------------------------------------------------------
--  Bibliografia
-- ---------------------------------------------------------------------
-- Bibliografia: le opere su cui la redazione verifica le voci. Quelle con modello_url sono consultabili in rete
-- e generano i collegamenti «Da consultare» delle voci nelle lingue indicate.
insert into opera (sigla, autore, titolo, edizione, anno, editore, url, pubblico_dominio, ambito, lingue, modello_url, tipo, nota) values
-- italiano
('DELI', 'Manlio Cortelazzo, Paolo Zolli', 'Il nuovo etimologico. DELI – Dizionario etimologico della lingua italiana', '2ª ed. a cura di Manlio Cortelazzo e Michele A. Cortelazzo', 1999, 'Zanichelli', null, false, 'italiano', '{it}', null, 'etimologico', null),
('Nocentini', 'Alberto Nocentini, con la collaborazione di Alessandro Parenti', 'l''Etimologico. Vocabolario della lingua italiana', null, 2010, 'Le Monnier', null, false, 'italiano', '{it}', null, 'etimologico', null),
('DEI', 'Carlo Battisti, Giovanni Alessio', 'Dizionario etimologico italiano', null, 1950, 'Barbèra', null, false, 'italiano', '{it}', null, 'etimologico', '5 volumi, 1950–1957'),
('VEI', 'Angelico Prati', 'Vocabolario etimologico italiano', null, 1951, 'Garzanti', null, false, 'italiano', '{it}', null, 'etimologico', null),
('LEI', null, 'Lessico etimologico italiano', null, 1979, 'Reichert', null, false, 'italiano', '{it,roa-oit,vec,nap,scn,lmo,lij,fur,sc}', null, 'etimologico', 'fondato da Max Pfister; in corso di pubblicazione dal 1979'),
('Pianigiani', 'Ottorino Pianigiani', 'Vocabolario etimologico della lingua italiana', null, 1907, 'Albrighi, Segati e C.', 'https://www.etimo.it', true, 'italiano', '{it}', 'https://www.etimo.it/?term={lemma}', 'etimologico', 'superato in molti punti, utile come testimonianza storica'),
('GDLI', 'Salvatore Battaglia, poi Giorgio Bàrberi Squarotti', 'Grande dizionario della lingua italiana', null, 1961, 'UTET', null, false, 'italiano', '{it}', null, 'storico', '21 volumi, 1961–2002, con supplementi'),
('TLIO', 'Opera del Vocabolario Italiano (CNR)', 'Tesoro della Lingua Italiana delle Origini', null, 1997, 'OVI-CNR', 'http://tlio.ovi.cnr.it', false, 'italiano', '{it,roa-oit}', null, 'storico', 'in corso'),
('Treccani', 'Istituto della Enciclopedia Italiana', 'Vocabolario Treccani', null, null, 'Treccani', 'https://www.treccani.it/vocabolario/', false, 'italiano', '{it}', 'https://www.treccani.it/vocabolario/{lemma}/', 'lessico', null),
-- lingue romanze
('REW', 'Wilhelm Meyer-Lübke', 'Romanisches etymologisches Wörterbuch', '3ª ed.', 1935, 'Winter', null, true, 'romanzo', '{la,la-vul,it,fr,fro,es,pt,ca,oc,pro,ro}', null, 'etimologico', null),
('FEW', 'Walther von Wartburg', 'Französisches etymologisches Wörterbuch', null, 1922, 'Klopp, Teubner, Zbinden', null, false, 'romanzo', '{fr,fro,frm,oc,pro}', null, 'etimologico', '25 volumi, 1922–2002'),
('TLFi', 'ATILF – CNRS e Université de Lorraine', 'Trésor de la langue française informatisé', null, null, 'CNRTL', 'https://www.cnrtl.fr', false, 'romanzo', '{fr}', 'https://www.cnrtl.fr/etymologie/{lemma}', 'lessico', 'sezione «étymologie»'),
('DCECH', 'Joan Corominas, José A. Pascual', 'Diccionario crítico etimológico castellano e hispánico', null, 1980, 'Gredos', null, false, 'romanzo', '{es}', null, 'etimologico', '6 volumi, 1980–1991'),
('DLE', 'Real Academia Española', 'Diccionario de la lengua española', '23ª ed.', 2014, 'Espasa', 'https://dle.rae.es', false, 'romanzo', '{es}', 'https://dle.rae.es/{lemma}', 'lessico', null),
('Machado', 'José Pedro Machado', 'Dicionário etimológico da língua portuguesa', '3ª ed.', 1977, 'Livros Horizonte', null, false, 'romanzo', '{pt}', null, 'etimologico', null),
('Priberam', null, 'Dicionário Priberam da Língua Portuguesa', null, null, 'Priberam Informática', 'https://dicionario.priberam.org', false, 'romanzo', '{pt}', 'https://dicionario.priberam.org/{lemma}', 'lessico', null),
-- latino
('Walde–Hofmann', 'Alois Walde, Johann Baptist Hofmann', 'Lateinisches etymologisches Wörterbuch', '3ª ed.', 1938, 'Winter', null, true, 'latino', '{la}', null, 'etimologico', '2 volumi e indici, 1938–1956; pubblico dominio nell''Unione europea dal 2025'),
('Ernout–Meillet', 'Alfred Ernout, Antoine Meillet', 'Dictionnaire étymologique de la langue latine. Histoire des mots', '4ª ed.', 1959, 'Klincksieck', null, false, 'latino', '{la}', null, 'etimologico', null),
('de Vaan', 'Michiel de Vaan', 'Etymological Dictionary of Latin and the other Italic Languages', null, 2008, 'Brill', null, false, 'latino', '{la,itc-pro,osc,xum}', null, 'etimologico', null),
('ThLL', 'Bayerische Akademie der Wissenschaften', 'Thesaurus Linguae Latinae', null, 1900, 'Teubner, poi De Gruyter', 'https://thesaurus.badw.de', false, 'latino', '{la}', null, 'lessico', 'in corso; ad accesso aperto'),
('OLD', 'P. G. W. Glare (a cura di)', 'Oxford Latin Dictionary', '2ª ed.', 2012, 'Oxford University Press', null, false, 'latino', '{la}', null, 'lessico', null),
('Lewis–Short', 'Charlton T. Lewis, Charles Short', 'A Latin Dictionary', null, 1879, 'Clarendon Press', null, true, 'latino', '{la}', null, 'lessico', 'consultabile in Logeion'),
('Du Cange', 'Charles du Fresne du Cange', 'Glossarium mediae et infimae latinitatis', 'ed. accresciuta', 1883, 'L. Favre', 'http://ducange.enc.sorbonne.fr', true, 'latino', '{la-med,la-lat,la-eme}', null, 'lessico', '10 volumi, 1883–1887'),
-- greco
('Beekes', 'Robert Beekes, con la collaborazione di Lucien van Beek', 'Etymological Dictionary of Greek', null, 2010, 'Brill', null, false, 'greco', '{grc,grk-pro}', null, 'etimologico', null),
('Chantraine', 'Pierre Chantraine', 'Dictionnaire étymologique de la langue grecque. Histoire des mots', null, 1968, 'Klincksieck', null, false, 'greco', '{grc}', null, 'etimologico', '1968–1980; nuova edizione con supplemento, 2009'),
('Frisk', 'Hjalmar Frisk', 'Griechisches etymologisches Wörterbuch', null, 1960, 'Winter', null, false, 'greco', '{grc}', null, 'etimologico', '3 volumi, 1960–1972'),
('LSJ', 'Henry George Liddell, Robert Scott, Henry Stuart Jones', 'A Greek-English Lexicon', '9ª ed.', 1940, 'Clarendon Press', null, true, 'greco', '{grc}', null, 'lessico', 'consultabile in Logeion'),
-- indoeuropeo
('IEW', 'Julius Pokorny', 'Indogermanisches etymologisches Wörterbuch', null, 1959, 'Francke', null, false, 'indoeuropeo', '{ine-pro}', null, 'etimologico', '2 volumi, 1959–1969'),
('LIV²', 'Helmut Rix e altri', 'LIV. Lexikon der indogermanischen Verben', '2ª ed.', 2001, 'Reichert', null, false, 'indoeuropeo', '{ine-pro}', null, 'etimologico', null),
('NIL', 'Dagmar S. Wodtko, Britta Irslinger, Carolin Schneider', 'Nomina im indogermanischen Lexikon', null, 2008, 'Winter', null, false, 'indoeuropeo', '{ine-pro}', null, 'etimologico', null),
-- lingue germaniche
('Kroonen', 'Guus Kroonen', 'Etymological Dictionary of Proto-Germanic', null, 2013, 'Brill', null, false, 'germanico', '{gem-pro}', null, 'etimologico', null),
('Kluge', 'Friedrich Kluge, Elmar Seebold', 'Etymologisches Wörterbuch der deutschen Sprache', '25ª ed.', 2011, 'De Gruyter', null, false, 'germanico', '{de,gmh,goh}', null, 'etimologico', null),
('Pfeifer', 'Wolfgang Pfeifer e altri', 'Etymologisches Wörterbuch des Deutschen', null, 1989, 'Akademie-Verlag', 'https://www.dwds.de', false, 'germanico', '{de}', 'https://www.dwds.de/wb/etymwb/{lemma}', 'etimologico', 'nel Digitales Wörterbuch der deutschen Sprache (DWDS)'),
('OED', null, 'Oxford English Dictionary', '3ª ed. in rete', null, 'Oxford University Press', 'https://www.oed.com', false, 'germanico', '{en,enm,ang}', 'https://www.oed.com/search/dictionary/?scope=Entries&q={lemma}', 'storico', 'in corso; su abbonamento'),
('AHD', null, 'The American Heritage Dictionary of the English Language', '5ª ed.', 2011, 'Houghton Mifflin Harcourt', 'https://www.ahdictionary.com', false, 'germanico', '{en}', 'https://www.ahdictionary.com/word/search.html?q={lemma}', 'lessico', 'con le radici indoeuropee di Calvert Watkins in appendice'),
('Watkins', 'Calvert Watkins', 'The American Heritage Dictionary of Indo-European Roots', '3ª ed.', 2011, 'Houghton Mifflin Harcourt', null, false, 'indoeuropeo', '{ine-pro}', null, 'etimologico', null),
-- lingue slave
('Vasmer', 'Max Vasmer', 'Russisches etymologisches Wörterbuch', null, 1950, 'Winter', null, false, 'slavo', '{ru,orv,sla-pro}', null, 'etimologico', '3 volumi, 1950–1958; traduzione russa di O. N. Trubačëv, 1964–1973'),
('Derksen', 'Rick Derksen', 'Etymological Dictionary of the Slavic Inherited Lexicon', null, 2008, 'Brill', null, false, 'slavo', '{sla-pro}', null, 'etimologico', null),
-- lingue indoiraniche
('EWAia', 'Manfred Mayrhofer', 'Etymologisches Wörterbuch des Altindoarischen', null, 1986, 'Winter', null, false, 'indoiranico', '{sa}', null, 'etimologico', '3 volumi, 1986–2001'),
('Monier-Williams', 'Monier Monier-Williams', 'A Sanskrit-English Dictionary', null, 1899, 'Clarendon Press', 'https://www.sanskrit-lexicon.uni-koeln.de', true, 'indoiranico', '{sa}', null, 'lessico', 'nei Cologne Digital Sanskrit Dictionaries'),
-- lingue semitiche e arabismi
('Lane', 'Edward William Lane', 'An Arabic-English Lexicon', null, 1863, 'Williams and Norgate', null, true, 'semitico', '{ar}', null, 'lessico', '8 volumi, 1863–1893'),
('Pellegrini', 'Giovan Battista Pellegrini', 'Gli arabismi nelle lingue neolatine con speciale riguardo all''Italia', null, 1972, 'Paideia', null, false, 'semitico', '{ar,it}', null, 'etimologico', null),
-- risorse in rete
('Logeion', 'University of Chicago', 'Logeion', null, null, 'University of Chicago', 'https://logeion.uchicago.edu', false, 'rete', '{la,grc}', 'https://logeion.uchicago.edu/{lemma}', 'in_rete', 'raccoglie Lewis & Short, LSJ e altri lessici'),
('Wikizionario', null, 'Wikizionario', null, null, 'Wikimedia Foundation', 'https://it.wiktionary.org', false, 'rete', '{it,la}', 'https://it.wiktionary.org/wiki/{lemma}', 'in_rete', 'CC BY-SA 4.0; fonte delle glosse italiane'),
('Wiktionary', null, 'Wiktionary', null, null, 'Wikimedia Foundation', 'https://en.wiktionary.org', false, 'rete', '{}', null, 'in_rete', 'CC BY-SA 4.0; fonte delle etimologie importate'),
('Etymonline', 'Douglas Harper', 'Online Etymology Dictionary', null, null, null, 'https://www.etymonline.com', false, 'rete', '{en}', 'https://www.etymonline.com/word/{lemma}', 'in_rete', 'divulgativo'),
('FrequencyWords', 'Hermit Dave', 'FrequencyWords', null, 2018, null, 'https://github.com/hermitdave/FrequencyWords', false, 'rete', '{}', null, 'in_rete', 'CC BY-SA 4.0; frequenze d''uso da OpenSubtitles 2018');

-- ---------------------------------------------------------------------
--  Lessemi
-- ---------------------------------------------------------------------
insert into lessema (lingua, lemma, pos, glossa) values
('it', 'fegato',   's.m.', 'organo che secerne la bile'),
('it', 'notte',    's.f.', 'parte del giorno senza luce solare'),
('it', 'vizio',    's.m.', 'abitudine riprovevole; difetto'),
('it', 'vezzo',    's.m.', 'abitudine; atteggiamento grazioso o lezioso'),
('it', 'causa',    's.f.', 'ciò che produce un effetto; processo'),
('it', 'cosa',     's.f.', 'oggetto, entità qualsiasi'),
('it', 'pensare',  'v.',   'formare idee con la mente'),
('it', 'pesare',   'v.',   'misurare il peso'),
('it', 'zero',     's.m.', 'numero nullo; la cifra 0'),
('it', 'zefiro',   's.m.', 'vento di ponente'),
('it', 'cifra',    's.f.', 'segno numerico; somma; codice segreto'),
('it', 'obelisco', 's.m.', 'monolito a pilastro rastremato verso l''alto'),
('it', 'obelo',    's.m.', 'segno critico dei filologi (†, ÷)'),
('it', 'obolo',    's.m.', 'antica moneta greca; piccola offerta'),
('it', 'dracma',   's.f.', 'moneta greca'),
('it', 'andare',   'v.',   'muoversi, spostarsi'),
('it', 'sincero',  'agg.', 'che non finge; schietto'),
('it', 'palazzo',  's.m.', 'edificio grande e signorile'),
('it', 'vecchio',  'agg.', 'che ha molti anni'),
('it', 'orecchio', 's.m.', 'organo dell''udito');

insert into lessema (lingua, lemma, omografo, pos, glossa, obsoleto, nota) values
('it', 'zefiro', 2, 's.m.', 'antica forma di «zero»', true, 'Omografo di zefiro «vento di ponente».');

insert into lessema (lingua, lemma, pos, glossa) values
('la', 'ficatum',   's.n.',  'fegato (d''animale ingrassato con fichi)'),
('la', 'ficus',     's.f.',  'fico'),
('la', 'nox',       's.f.',  'notte'),
('la', 'vitium',    's.n.',  'difetto, vizio'),
('la', 'causa',     's.f.',  'causa, motivo; processo'),
('la', 'pensare',   'v.',    'pesare con cura; ponderare'),
('la', 'obeliscus', 's.m.',  'obelisco'),
('la', 'obelus',    's.m.',  'segno critico'),
('la', 'obolus',    's.m.',  'obolo'),
('la', 'drachma',   's.f.',  'dracma'),
('la', 'ambulare',  'v.',    'camminare, passeggiare'),
('la', 'ambire',    'v.',    'andare intorno; brigare'),
('la', 'sincerus',  'agg.',  'puro, intatto, schietto'),
('la', 'sine',      'prep.', 'senza'),
('la', 'cera',      's.f.',  'cera'),
('la', 'palatium',  's.n.',  'reggia, palazzo imperiale'),
('la', 'vetus',     'agg.',  'vecchio'),
('la', 'vetulus',   'agg.',  'vecchiotto'),
('la', 'auris',     's.f.',  'orecchio'),
('la', 'auricula',  's.f.',  'orecchietta');

insert into lessema (lingua, lemma, omografo, pos, glossa) values
('la', 'Palatium', 2, 'np', 'il colle Palatino');

insert into lessema (lingua, lemma, ricostruito, pos, glossa) values
('la-vul', 'veclus',   true,  'agg.', 'vecchio'),
('la-vul', 'oricla',   false, 's.f.', 'orecchio'),
('la-vul', 'ambitare', true,  'v.',   'andare intorno'),
('la-med', 'zephirum', false, 's.n.', 'zero'),
('la-med', 'cifra',    false, 's.f.', 'zero; cifra');

insert into lessema (lingua, lemma, translit, pos, glossa) values
('grc', 'συκωτόν',   'sykōtón',   'agg.', '(fegato) ingrassato con fichi'),
('grc', 'ὀβελός',    'obelós',    's.m.', 'spiedo'),
('grc', 'ὀβελίσκος', 'obelískos', 's.m.', 'spiedino; obelisco'),
('grc', 'ὀβολός',    'obolós',    's.m.', 'obolo, moneta'),
('grc', 'δραχμή',    'drachmḗ',   's.f.', 'manciata; dracma'),
('grc', 'δράσσομαι', 'drássomai', 'v.',   'afferrare con la mano'),
('grc', 'νύξ',       'nýx',       's.f.', 'notte'),
('ar',  'صفر',       'ṣifr',      's.m.', 'vuoto; zero'),
('ar',  'درهم',      'dirham',    's.m.', 'dirham, moneta'),
('ru',  'ночь',      'nočʹ',      's.f.', 'notte'),
('pal', 'drahm',     null,        's.',   'dracma, moneta'),
('fro', 'palais',    null,        's.m.', 'palazzo'),
('fr',  'palais',    null,        's.m.', 'palazzo'),
('fr',  'nuit',      null,        's.f.', 'notte'),
('fr',  'foie',      null,        's.m.', 'fegato'),
('es',  'noche',     null,        's.f.', 'notte'),
('pt',  'noite',     null,        's.f.', 'notte'),
('ang', 'niht',      null,        's.f.', 'notte'),
('en',  'night',     null,        's.',   'notte'),
('en',  'palace',    null,        's.',   'palazzo'),
('de',  'Nacht',     null,        's.f.', 'notte');

-- Due lessemi dallo strato Wiktionary, per collaudare licenze e visibilità
insert into lessema (lingua, lemma, pos, glossa, provenienza, stato_editoriale, id_esterno) values
('es', 'hígado', 's.m.', 'fegato', 'wiktionary', 'importato', 'en.wiktionary.org/wiki/hígado'),
('pt', 'fígado', 's.m.', 'fegato', 'wiktionary', 'importato', 'en.wiktionary.org/wiki/fígado');

insert into lessema (lingua, lemma, translit, ricostruito, pos, glossa) values
('ine-pro', 'nókʷts', null,   true, 's.f.', 'notte'),
('ine-pro', 'sem-',   null,   true, 'rad.', 'uno'),
('ine-pro', 'ḱerh₃-', null,   true, 'rad.', 'crescere'),
('gem-pro', 'nahts',  null,   true, 's.f.', 'notte'),
('sla-pro', 'noťь',   'noťĭ', true, 's.f.', 'notte');

-- ---------------------------------------------------------------------
--  Accezioni (alberi di significato)
-- ---------------------------------------------------------------------
insert into accezione (lessema_id, n, glossa) values
(lx('la/ficatum'),  1, 'ingrassato con fichi (iecur ficatum)'),
(lx('grc/obelos'),  1, 'spiedo'),
(lx('grc/drachme'), 1, 'manciata');

insert into accezione (lessema_id, n, glossa, ambito, deriva_da, processo)
select lx(v.slug), 2, v.glossa, v.ambito, a.id, v.processo
from (values
  ('la/ficatum',  'fegato',                          null,          'ellissi'),
  ('grc/obelos',  'segno critico per i versi spuri', 'filologia',   'tecnicizzazione'),
  ('grc/drachme', 'dracma, moneta',                  'numismatica', 'metonimia')
) v(slug, glossa, ambito, processo)
join accezione a on a.lessema_id = lx(v.slug) and a.n = 1;

-- ---------------------------------------------------------------------
--  Relazioni
-- ---------------------------------------------------------------------

-- fegato: calco + derivazione + ellissi; due cognati arrivano dallo strato Wiktionary
select collega('la/ficatum', 'la/ficus',    'derivazione', p_affisso => '-atum');
select collega('la/ficatum', 'grc/sykoton', 'calco',
               p_nota => 'Calco di συκωτόν (ἧπαρ): il fegato delle bestie ingrassate con i fichi.');
select collega('it/fegato',  'la/ficatum',  'eredita', p_forma => 'ficatu(m)',
               p_nota => 'La ritrazione dell''accento (*fìcatu, *fècatu) è discussa.');
select collega('fr/foie',    'la/ficatum',  'eredita');
select collega('es/higado',  'la/ficatum',  'eredita', p_provenienza => 'wiktionary', p_stato_editoriale => 'importato');
select collega('pt/figado',  'la/ficatum',  'eredita', p_provenienza => 'wiktionary', p_stato_editoriale => 'importato');

-- notte: cognati in otto lingue da *nókʷts
select collega('la/nox',        'ine-pro/nokwts', 'eredita');
select collega('it/notte',      'la/nox',         'eredita', p_forma => 'noctem');
select collega('fr/nuit',       'la/nox',         'eredita', p_forma => 'noctem');
select collega('es/noche',      'la/nox',         'eredita', p_forma => 'noctem');
select collega('pt/noite',      'la/nox',         'eredita', p_forma => 'noctem');
select collega('gem-pro/nahts', 'ine-pro/nokwts', 'eredita');
select collega('ang/niht',      'gem-pro/nahts',  'eredita');
select collega('en/night',      'ang/niht',       'eredita');
select collega('de/nacht',      'gem-pro/nahts',  'eredita');
select collega('sla-pro/noti',  'ine-pro/nokwts', 'eredita');
select collega('ru/noc',        'sla-pro/noti',   'eredita');
select collega('grc/nyx',       'ine-pro/nokwts', 'eredita');

-- allotropi classici: trafila popolare contro via dotta
select collega('it/vizio',   'la/vitium',  'prestito_dotto');
select collega('it/vezzo',   'la/vitium',  'eredita', p_forma => 'vitiu(m)');
select collega('it/causa',   'la/causa',   'prestito_dotto');
select collega('it/cosa',    'la/causa',   'eredita');
select collega('it/pensare', 'la/pensare', 'prestito_dotto');
select collega('it/pesare',  'la/pensare', 'eredita', p_nota => 'Riduzione regolare di -ns- a -s-.');
update relazione set processo = 'metafora'
 where esito_id = lx('it/pensare') and etimo_id = lx('la/pensare');

-- zero e cifra: lo stesso arabo per due vie medievali
select collega('la-med/zephirum', 'ar/sifr',          'prestito');
select collega('it/zefiro-2',     'la-med/zephirum',  'prestito');
select collega('it/zero',         'it/zefiro-2',      'variante',
               p_nota => 'Forma ridotta, attraverso il veneziano zevero.');
select collega('la-med/cifra',    'ar/sifr',          'prestito');
select collega('it/cifra',        'la-med/cifra',     'prestito');

-- la famiglia di ὀβελός: origine ignota, tre rami, una connessione culturale
insert into ipotesi (esito_id, etichetta, stato, confidenza, origine, nota) values
(lx('grc/obelos'), 'etimo ignoto',   'accolta',     3, 'ignota',
 'Nessuna etimologia indoeuropea convincente.'),
(lx('grc/obelos'), 'voce pre-greca', 'alternativa', 2, 'sostrato',
 'L''alternanza β/δ (dorico ὀδελός) è stata indicata come tratto pre-greco. Da verificare.');

select collega('grc/obeliskos', 'grc/obelos',    'derivazione', p_affisso => '-ίσκος',
               p_nota => 'Diminutivo: «spiedino», poi i monoliti egizi.');
select collega('grc/obolos',    'grc/obelos',    'variante',
               p_nota => 'Gli spiedi come unità di valore premonetaria.');
select collega('la/obeliscus',  'grc/obeliskos', 'prestito');
select collega('it/obelisco',   'la/obeliscus',  'prestito_dotto');
select collega('la/obelus',     'grc/obelos',    'prestito');
select collega('it/obelo',      'la/obelus',     'prestito_dotto');
select collega('la/obolus',     'grc/obolos',    'prestito');
select collega('it/obolo',      'la/obolus',     'prestito_dotto');
select collega('grc/drachme',   'grc/drassomai', 'derivazione');
select collega('la/drachma',    'grc/drachme',   'prestito');
select collega('it/dracma',     'la/drachma',    'prestito_dotto');
select collega('pal/drahm',     'grc/drachme',   'prestito');
select collega('ar/dirham',     'pal/drahm',     'prestito');

insert into connessione (da_id, a_id, tipo, descrizione) values
(lx('grc/drachme'), lx('grc/obolos'), 'culturale',
 'Sei oboli fanno una dracma: secondo la tradizione antica, una «manciata» di spiedi.');

-- archi ancorati a un'accezione precisa dell'etimo
update relazione r set etimo_accezione_id = a.id
from accezione a
where a.lessema_id = r.etimo_id and a.n = 2
  and ((r.etimo_id = lx('grc/obelos')  and r.esito_id = lx('la/obelus'))
    or (r.etimo_id = lx('la/ficatum')  and r.esito_id in (lx('it/fegato'), lx('fr/foie')))
    or (r.etimo_id = lx('grc/drachme') and r.esito_id in (lx('la/drachma'), lx('pal/drahm'))));

-- andare: due ipotesi alternative, nessuna accolta
select collega('la-vul/ambitare', 'la/ambire', 'derivazione', p_affisso => '-itare');
select collega('it/andare', 'la/ambulare', 'eredita',
               p_ipotesi => 'da ambulare', p_stato => 'alternativa', p_confidenza => 2,
               p_nota => 'Trafila fonetica irregolare, discussa.');
select collega('it/andare', 'la-vul/ambitare', 'eredita',
               p_ipotesi => 'da *ambitare', p_stato => 'alternativa', p_confidenza => 2);

-- sincero: ipotesi accolta ma incerta, e un falso mito registrato come tale
select collega('it/sincero',  'la/sincerus',   'prestito_dotto');
select collega('la/sincerus', 'ine-pro/sem',   'composizione', p_ipotesi => 'di una sola crescita',
               p_confidenza => 2, p_ordine => 1, p_nota => 'Confronto con procerus «alto». Da verificare.');
select collega('la/sincerus', 'ine-pro/kerh3', 'composizione', p_ipotesi => 'di una sola crescita',
               p_confidenza => 2, p_ordine => 2);
select collega('la/sincerus', 'la/sine', 'composizione', p_ipotesi => 'sine cera',
               p_stato => 'respinta', p_confidenza => 1, p_ordine => 1);
select collega('la/sincerus', 'la/cera', 'composizione', p_ipotesi => 'sine cera',
               p_stato => 'respinta', p_confidenza => 1, p_ordine => 2);
update ipotesi
   set diffusa = true,
       nota = 'Paretimologia diffusa: le statue «senza cera», cioè non ritoccate. Respinta dagli etimologisti.'
 where id = ip('la/sincerus', 'sine cera');

-- palazzo: dal nome di un colle; cognato stretto in francese, per prestito in inglese
select collega('la/palatium', 'la/palatium-2', 'deonimico',
               p_nota => 'Dal colle su cui sorgeva la residenza degli imperatori.');
update relazione set processo = 'metonimia'
 where esito_id = lx('la/palatium') and etimo_id = lx('la/palatium-2');
select collega('it/palazzo', 'la/palatium', 'eredita', p_forma => 'palatiu(m)');
select collega('fro/palais', 'la/palatium', 'eredita');
select collega('fr/palais',  'fro/palais',  'eredita');
select collega('en/palace',  'fro/palais',  'prestito', p_nota => 'Attraverso l''anglonormanno.');

-- vecchio e orecchio: le forme volgari e le prove dell'Appendix Probi
select collega('la/vetulus',    'la/vetus',     'derivazione', p_affisso => '-ulus');
select collega('la-vul/veclus', 'la/vetulus',   'variante', p_nota => 'Sincope della vocale postonica.');
select collega('it/vecchio',    'la-vul/veclus', 'eredita');
select collega('la/auricula',   'la/auris',     'derivazione', p_affisso => '-icula');
select collega('la-vul/oricla', 'la/auricula',  'variante', p_nota => 'Sincope e monottongazione di au in o.');
select collega('it/orecchio',   'la-vul/oricla', 'eredita');

-- ---------------------------------------------------------------------
--  Attestazioni
-- ---------------------------------------------------------------------
insert into attestazione (lessema_id, forma_attestata, testo, rif, tipo, anno_da, anno_a, precisione, citazione, nota) values
(lx('la-vul/veclus'),   'veclus',   'Appendix Probi', null, 'grammaticale', 200, 600, 'intervallo',
 'vetulus non veclus', 'Datazione dell''Appendix discussa.'),
(lx('la-vul/oricla'),   'oricla',   'Appendix Probi', null, 'grammaticale', 200, 600, 'intervallo',
 'auris non oricla', 'Datazione dell''Appendix discussa.'),
(lx('la-med/zephirum'), 'zephirum', 'Leonardo Fibonacci, Liber abaci', null, 'letteraria', 1202, null, 'esatta',
 null, 'Prima redazione; il testo conservato è la revisione del 1228.'),
(lx('la/obelus'),       'obelus',   'Isidoro di Siviglia, Etymologiae', 'I 21', 'letteraria', 615, 636, 'intervallo',
 null, null);

-- ---------------------------------------------------------------------
--  Rimandi (solo dove la posizione della fonte è pacifica)
-- ---------------------------------------------------------------------
insert into rimando (opera_id, sv, posizione, ipotesi_id)
select o.id, v.sv, v.posizione::posizione_fonte, ip(v.esito, v.etichetta)
from (values
  ('DELI', 'fegato',  'accoglie', 'it/fegato', 'principale'),
  ('REW',  'fīcātum', 'accoglie', 'it/fegato', 'principale'),
  ('DELI', 'vezzo',   'accoglie', 'it/vezzo',  'principale'),
  ('DELI', 'zero',    'accoglie', 'it/zero',   'principale'),
  ('DELI', 'andare',  'discute',  'it/andare', 'da ambulare'),
  ('DELI', 'andare',  'discute',  'it/andare', 'da *ambitare')
) v(sigla, sv, posizione, esito, etichetta)
join opera o on o.sigla = v.sigla;


-- =====================================================================
--  Famiglie per radice (v0.2): quattro radici indoeuropee e una semitica
-- =====================================================================

insert into lessema (lingua, lemma, ricostruito, pos, glossa) values
('ine-pro', 'ped-',       true, 'rad.', 'camminare, mettere il piede'),
('ine-pro', 'pṓds',       true, 's.m.', 'piede'),
('ine-pro', 'méh₂tēr',    true, 's.f.', 'madre'),
('ine-pro', 'h₂stḗr',     true, 's.m.', 'stella'),
('ine-pro', 'h₂stérleh₂', true, 's.f.', 'stella (forma derivata)'),
('ine-pro', 'gʷem-',      true, 'rad.', 'venire, andare'),
('gem-pro', 'fōts',       true, 's.m.', 'piede'),
('gem-pro', 'mōdēr',      true, 's.f.', 'madre'),
('gem-pro', 'sternǭ',     true, 's.m.', 'stella'),
('gem-pro', 'sterzǭ',     true, 's.m.', 'stella'),
('gem-pro', 'kwemaną',    true, 'v.',   'venire'),
('sla-pro', 'mati',       true, 's.f.', 'madre');

insert into lessema (lingua, lemma, pos, glossa) values
('la', 'pes',        's.m.', 'piede'),
('la', 'pedalis',    'agg.', 'del piede'),
('la', 'podium',     's.n.', 'basamento, podio'),
('la', 'mater',      's.f.', 'madre'),
('la', 'maternus',   'agg.', 'materno'),
('la', 'matrix',     's.f.', 'femmina da riproduzione; utero; registro'),
('la', 'metropolis', 's.f.', 'città capitale'),
('la', 'stella',     's.f.', 'stella'),
('la', 'astrum',     's.n.', 'astro, costellazione'),
('la', 'venire',     'v.',   'venire'),
('la', 'basis',      's.f.', 'base'),
('it', 'piede',      's.m.', 'arto inferiore; base'),
('it', 'pedale',     's.m.', 'leva azionata col piede'),
('it', 'podio',      's.m.', 'piattaforma rialzata'),
('it', 'poggio',     's.m.', 'piccola altura'),
('it', 'madre',      's.f.', 'genitrice'),
('it', 'materno',    'agg.', 'della madre'),
('it', 'matrice',    's.f.', 'stampo; origine; registro'),
('it', 'metropoli',  's.f.', 'grande città'),
('it', 'stella',     's.f.', 'corpo celeste luminoso'),
('it', 'astro',      's.m.', 'corpo celeste'),
('it', 'disastro',   's.m.', 'sciagura grave'),
('it', 'venire',     'v.',   'muoversi verso chi parla'),
('it', 'base',       's.f.', 'parte che sostiene'),
('fr', 'pied',       's.m.', 'piede'),
('fr', 'pédale',     's.f.', 'pedale'),
('fr', 'mère',       's.f.', 'madre'),
('fr', 'étoile',     's.f.', 'stella'),
('fr', 'désastre',   's.m.', 'disastro'),
('fr', 'venir',      'v.',   'venire'),
('fr', 'zéro',       's.m.', 'zero'),
('fr', 'chiffre',    's.m.', 'cifra'),
('es', 'pie',        's.m.', 'piede'),
('es', 'madre',      's.f.', 'madre'),
('es', 'estrella',   's.f.', 'stella'),
('es', 'venir',      'v.',   'venire'),
('pt', 'pé',         's.m.', 'piede'),
('pt', 'mãe',        's.f.', 'madre'),
('pt', 'estrela',    's.f.', 'stella'),
('pt', 'vir',        'v.',   'venire'),
('ang', 'fōt',       's.m.', 'piede'),
('ang', 'mōdor',     's.f.', 'madre'),
('ang', 'steorra',   's.m.', 'stella'),
('ang', 'cuman',     'v.',   'venire'),
('en', 'foot',       's.',   'piede'),
('en', 'pedal',      's.',   'pedale'),
('en', 'podium',     's.',   'podio'),
('en', 'mother',     's.',   'madre'),
('en', 'star',       's.',   'stella'),
('en', 'disaster',   's.',   'disastro'),
('en', 'come',       'v.',   'venire'),
('en', 'zero',       's.',   'zero'),
('en', 'cipher',     's.',   'cifra; codice'),
('de', 'Fuß',        's.m.', 'piede'),
('de', 'Mutter',     's.f.', 'madre'),
('de', 'Stern',      's.m.', 'stella'),
('de', 'kommen',     'v.',   'venire');

insert into lessema (lingua, lemma, translit, pos, glossa) values
('grc', 'πούς',       'poús',       's.m.', 'piede'),
('grc', 'πόδιον',     'pódion',     's.n.', 'piedino; base'),
('grc', 'μήτηρ',      'mḗtēr',      's.f.', 'madre'),
('grc', 'πόλις',      'pólis',      's.f.', 'città'),
('grc', 'μητρόπολις', 'mētrópolis', 's.f.', 'città madre di una colonia'),
('grc', 'ἀστήρ',      'astḗr',      's.m.', 'stella'),
('grc', 'ἄστρον',     'ástron',     's.n.', 'astro, costellazione'),
('grc', 'βαίνω',      'baínō',      'v.',   'camminare, andare'),
('grc', 'βάσις',      'básis',      's.f.', 'passo; base'),
('sa',  'पद्',         'pád',        's.m.', 'piede'),
('sa',  'मातृ',        'mātṛ́',       's.f.', 'madre'),
('sa',  'गच्छति',      'gácchati',   'v.',   'va'),
('ru',  'мать',       'matʹ',       's.f.', 'madre'),
('ar',  'ص ف ر',      'ṣ-f-r',      'rad.', 'essere vuoto');

-- *ped- «piede»: legge di Grimm, un allotropo italiano, un prestito che torna indietro
select collega('ine-pro/pods',  'ine-pro/ped',  'derivazione', p_nota => 'Nome radicale, con grado allungato.');
select collega('la/pes',        'ine-pro/pods', 'eredita');
select collega('it/piede',      'la/pes',       'eredita', p_forma => 'pede(m)');
select collega('fr/pied',       'la/pes',       'eredita', p_forma => 'pedem');
select collega('es/pie',        'la/pes',       'eredita', p_forma => 'pedem');
select collega('pt/pe',         'la/pes',       'eredita', p_forma => 'pedem');
select collega('la/pedalis',    'la/pes',       'derivazione', p_affisso => '-alis');
select collega('it/pedale',     'la/pedalis',   'prestito_dotto');
select collega('fr/pedale',     'it/pedale',    'prestito');
select collega('en/pedal',      'fr/pedale',    'prestito');
select collega('gem-pro/fots',  'ine-pro/pods', 'eredita', p_nota => 'p > f per la legge di Grimm.');
select collega('ang/fot',       'gem-pro/fots', 'eredita');
select collega('en/foot',       'ang/fot',      'eredita');
select collega('de/fuss',       'gem-pro/fots', 'eredita');
select collega('grc/pous',      'ine-pro/pods', 'eredita');
select collega('grc/podion',    'grc/pous',     'derivazione', p_affisso => '-ιον', p_nota => 'Diminutivo.');
select collega('la/podium',     'grc/podion',   'prestito');
select collega('it/podio',      'la/podium',    'prestito_dotto');
select collega('it/poggio',     'la/podium',    'eredita', p_forma => 'podiu(m)', p_nota => 'Esito popolare del nesso -dj-.');
select collega('en/podium',     'la/podium',    'prestito');
select collega('sa/pad',        'ine-pro/pods', 'eredita');

-- *méh₂tēr «madre»: la stessa parola in nove lingue, e i derivati dotti
insert into ipotesi (esito_id, etichetta, stato, confidenza, origine, nota) values
(lx('ine-pro/meh2ter'), 'linguaggio infantile', 'accolta', 2, 'espressiva',
 'Forse dalla sillaba infantile *mā- con il suffisso dei nomi di parentela *-tēr. Da verificare.');
select collega('la/mater',       'ine-pro/meh2ter', 'eredita');
select collega('it/madre',       'la/mater',        'eredita', p_forma => 'matre(m)');
select collega('fr/mere',        'la/mater',        'eredita', p_forma => 'matrem');
select collega('es/madre',       'la/mater',        'eredita', p_forma => 'matrem');
select collega('pt/mae',         'la/mater',        'eredita', p_forma => 'matrem');
select collega('la/maternus',    'la/mater',        'derivazione', p_affisso => '-nus');
select collega('it/materno',     'la/maternus',     'prestito_dotto');
select collega('la/matrix',      'la/mater',        'derivazione', p_affisso => '-ix');
select collega('it/matrice',     'la/matrix',       'prestito_dotto');
select collega('gem-pro/moder',  'ine-pro/meh2ter', 'eredita');
select collega('ang/modor',      'gem-pro/moder',   'eredita');
select collega('en/mother',      'ang/modor',       'eredita');
select collega('de/mutter',      'gem-pro/moder',   'eredita');
select collega('grc/meter',      'ine-pro/meh2ter', 'eredita');
select collega('grc/metropolis', 'grc/meter',       'composizione', p_ordine => 1);
select collega('grc/metropolis', 'grc/polis',       'composizione', p_ordine => 2);
select collega('la/metropolis',  'grc/metropolis',  'prestito');
select collega('it/metropoli',   'la/metropolis',   'prestito_dotto');
select collega('sla-pro/mati',   'ine-pro/meh2ter', 'eredita');
select collega('ru/mat',         'sla-pro/mati',    'eredita');
select collega('sa/matr',        'ine-pro/meh2ter', 'eredita');

-- *h₂stḗr «stella»: stella e star nella stessa famiglia per vie diverse;
-- disastro parte dall'italiano e arriva all'inglese
select collega('ine-pro/h2sterleh2', 'ine-pro/h2ster', 'derivazione', p_affisso => '*-leh₂',
               p_confidenza => 2, p_nota => 'Formazione con suffisso diminutivo. Da verificare.');
select collega('la/stella',      'ine-pro/h2sterleh2', 'eredita', p_confidenza => 2,
               p_nota => 'Attraverso il protoitalico *stērlā.');
select collega('it/stella',      'la/stella',      'eredita');
select collega('fr/etoile',      'la/stella',      'eredita', p_forma => '*stēla', p_nota => 'Attraverso il francese antico esteile.');
select collega('es/estrella',    'la/stella',      'eredita');
select collega('es/estrella',    'la/astrum',      'influsso', p_confidenza => 2, p_nota => 'La -r- si spiega forse con astrum.');
select collega('pt/estrela',     'la/stella',      'eredita');
select collega('pt/estrela',     'la/astrum',      'influsso', p_confidenza => 2, p_nota => 'Come lo spagnolo estrella.');
select collega('gem-pro/sterno', 'ine-pro/h2ster', 'eredita', p_nota => 'Con suffisso nasale.');
select collega('gem-pro/sterzo', 'ine-pro/h2ster', 'eredita', p_nota => 'Variante presupposta dall''inglese.');
select collega('ang/steorra',    'gem-pro/sterzo', 'eredita');
select collega('en/star',        'ang/steorra',    'eredita');
select collega('de/stern',       'gem-pro/sterno', 'eredita');
select collega('grc/aster',      'ine-pro/h2ster', 'eredita');
select collega('grc/astron',     'grc/aster',      'derivazione');
select collega('la/astrum',      'grc/astron',     'prestito');
select collega('it/astro',       'la/astrum',      'prestito_dotto');
select collega('it/disastro',    'it/astro',       'derivazione', p_affisso => 'dis-',
               p_nota => '«Cattiva stella»: dis- peggiorativo.');
select collega('fr/desastre',    'it/disastro',    'prestito');
select collega('en/disaster',    'fr/desastre',    'prestito');

-- *gʷem- «venire»: le labiovelari diventano v in latino, k in germanico, b in greco
select collega('la/venire',       'ine-pro/gwem',     'eredita', p_nota => 'Dal presente *gʷm̥-yé-, attraverso il protoitalico *gʷenjō.');
select collega('it/venire',       'la/venire',        'eredita');
select collega('fr/venir',        'la/venire',        'eredita');
select collega('es/venir',        'la/venire',        'eredita');
select collega('pt/vir',          'la/venire',        'eredita');
select collega('gem-pro/kwemana', 'ine-pro/gwem',     'eredita');
select collega('ang/cuman',       'gem-pro/kwemana',  'eredita');
select collega('en/come',         'ang/cuman',        'eredita');
select collega('de/kommen',       'gem-pro/kwemana',  'eredita');
select collega('grc/baino',       'ine-pro/gwem',     'eredita', p_nota => 'Dal presente *gʷm̥-yé-: gʷ > b in greco.');
select collega('grc/basis',       'grc/baino',        'derivazione', p_affisso => '-σις');
select collega('la/basis',        'grc/basis',        'prestito');
select collega('it/base',         'la/basis',         'prestito_dotto');
select collega('sa/gacchati',     'ine-pro/gwem',     'eredita', p_nota => 'Dal presente *gʷm̥-sḱé-.');

-- ṣ-f-r: una radice semitica trattata come quelle indoeuropee
select collega('ar/sifr',    'ar/sfr',       'derivazione', p_affisso => 'schema fiʿl',
               p_nota => 'Nome tratto dalla radice triconsonantica «essere vuoto».');
select collega('fr/zero',    'it/zero',      'prestito');
select collega('en/zero',    'it/zero',      'prestito', p_nota => 'Forse attraverso il francese zéro.');
select collega('fr/chiffre', 'la-med/cifra', 'prestito', p_nota => 'O attraverso l''italiano cifra.');
select collega('en/cipher',  'la-med/cifra', 'prestito', p_nota => 'Attraverso il francese antico cifre.');


-- =====================================================================
--  Multilinguismo (v0.3)
-- =====================================================================
insert into impostazione (chiave, valore) values ('lingua_redazione', 'it');

-- glosse inglesi di tutti i lessemi del seme
insert into glossa (lessema_id, lingua, testo)
select lx(v.slug), 'en', v.testo from (values
  ('ang/cuman', 'to come'),
  ('ang/fot', 'foot'),
  ('ang/modor', 'mother'),
  ('ang/niht', 'night'),
  ('ang/steorra', 'star'),
  ('ar/dirham', 'dirham (coin)'),
  ('ar/sfr', 'to be empty'),
  ('ar/sifr', 'empty; zero'),
  ('de/fuss', 'foot'),
  ('de/kommen', 'to come'),
  ('de/mutter', 'mother'),
  ('de/nacht', 'night'),
  ('de/stern', 'star'),
  ('en/cipher', 'figure; code'),
  ('en/come', 'to come'),
  ('en/disaster', 'disaster'),
  ('en/foot', 'foot'),
  ('en/mother', 'mother'),
  ('en/night', 'night'),
  ('en/palace', 'palace'),
  ('en/pedal', 'pedal'),
  ('en/podium', 'podium'),
  ('en/star', 'star'),
  ('en/zero', 'zero'),
  ('es/estrella', 'star'),
  ('es/higado', 'liver'),
  ('es/madre', 'mother'),
  ('es/noche', 'night'),
  ('es/pie', 'foot'),
  ('es/venir', 'to come'),
  ('fr/chiffre', 'figure, digit'),
  ('fr/desastre', 'disaster'),
  ('fr/etoile', 'star'),
  ('fr/foie', 'liver'),
  ('fr/mere', 'mother'),
  ('fr/nuit', 'night'),
  ('fr/palais', 'palace'),
  ('fr/pedale', 'pedal'),
  ('fr/pied', 'foot'),
  ('fr/venir', 'to come'),
  ('fr/zero', 'zero'),
  ('fro/palais', 'palace'),
  ('gem-pro/fots', 'foot'),
  ('gem-pro/kwemana', 'to come'),
  ('gem-pro/moder', 'mother'),
  ('gem-pro/nahts', 'night'),
  ('gem-pro/sterno', 'star'),
  ('gem-pro/sterzo', 'star'),
  ('grc/aster', 'star'),
  ('grc/astron', 'star, constellation'),
  ('grc/baino', 'to walk, to go'),
  ('grc/basis', 'step; base'),
  ('grc/drachme', 'handful; drachma'),
  ('grc/drassomai', 'to grasp with the hand'),
  ('grc/meter', 'mother'),
  ('grc/metropolis', 'mother city of a colony'),
  ('grc/nyx', 'night'),
  ('grc/obeliskos', 'small spit; obelisk'),
  ('grc/obelos', 'spit, skewer'),
  ('grc/obolos', 'obol (coin)'),
  ('grc/podion', 'little foot; base'),
  ('grc/polis', 'city'),
  ('grc/pous', 'foot'),
  ('grc/sykoton', '(liver) fattened with figs'),
  ('ine-pro/gwem', 'to come, to go'),
  ('ine-pro/h2ster', 'star'),
  ('ine-pro/h2sterleh2', 'star (derived form)'),
  ('ine-pro/kerh3', 'to grow'),
  ('ine-pro/meh2ter', 'mother'),
  ('ine-pro/nokwts', 'night'),
  ('ine-pro/ped', 'to walk, to step'),
  ('ine-pro/pods', 'foot'),
  ('ine-pro/sem', 'one'),
  ('it/andare', 'to go, to move'),
  ('it/astro', 'heavenly body'),
  ('it/base', 'base, supporting part'),
  ('it/causa', 'cause; lawsuit'),
  ('it/cifra', 'digit; sum; cipher'),
  ('it/cosa', 'thing'),
  ('it/disastro', 'disaster'),
  ('it/dracma', 'drachma (Greek coin)'),
  ('it/fegato', 'liver'),
  ('it/madre', 'mother'),
  ('it/materno', 'maternal'),
  ('it/matrice', 'mould; source; register'),
  ('it/metropoli', 'metropolis, big city'),
  ('it/notte', 'night'),
  ('it/obelisco', 'obelisk'),
  ('it/obelo', 'obelus, the critical sign (†, ÷)'),
  ('it/obolo', 'obol; small contribution'),
  ('it/orecchio', 'ear'),
  ('it/palazzo', 'palace; large building'),
  ('it/pedale', 'pedal'),
  ('it/pensare', 'to think'),
  ('it/pesare', 'to weigh'),
  ('it/piede', 'foot; base'),
  ('it/podio', 'podium'),
  ('it/poggio', 'hillock, knoll'),
  ('it/sincero', 'sincere, frank'),
  ('it/stella', 'star'),
  ('it/vecchio', 'old'),
  ('it/venire', 'to come'),
  ('it/vezzo', 'habit; affectation, charm'),
  ('it/vizio', 'vice; defect'),
  ('it/zefiro', 'west wind'),
  ('it/zefiro-2', 'old form of “zero”'),
  ('it/zero', 'zero'),
  ('la/ambire', 'to go around; to canvass'),
  ('la/ambulare', 'to walk, to stroll'),
  ('la/astrum', 'star, constellation'),
  ('la/auricula', 'little ear'),
  ('la/auris', 'ear'),
  ('la/basis', 'base'),
  ('la/causa', 'cause, reason; lawsuit'),
  ('la/cera', 'wax'),
  ('la/drachma', 'drachma'),
  ('la/ficatum', 'liver (of an animal fattened on figs)'),
  ('la/ficus', 'fig'),
  ('la/mater', 'mother'),
  ('la/maternus', 'maternal'),
  ('la/matrix', 'breeding female; womb; register'),
  ('la/metropolis', 'capital city'),
  ('la/nox', 'night'),
  ('la/obeliscus', 'obelisk'),
  ('la/obelus', 'critical sign (obelus)'),
  ('la/obolus', 'obol'),
  ('la/palatium', 'palace, imperial residence'),
  ('la/palatium-2', 'the Palatine Hill'),
  ('la/pedalis', 'of the foot'),
  ('la/pensare', 'to weigh carefully; to ponder'),
  ('la/pes', 'foot'),
  ('la/podium', 'platform, podium'),
  ('la/sincerus', 'pure, whole, sincere'),
  ('la/sine', 'without'),
  ('la/stella', 'star'),
  ('la/venire', 'to come'),
  ('la/vetulus', 'oldish, a little old'),
  ('la/vetus', 'old'),
  ('la/vitium', 'defect, vice'),
  ('la-med/cifra', 'zero; figure'),
  ('la-med/zephirum', 'zero'),
  ('la-vul/ambitare', 'to go around'),
  ('la-vul/oricla', 'ear'),
  ('la-vul/veclus', 'old'),
  ('pal/drahm', 'drachma (coin)'),
  ('pt/estrela', 'star'),
  ('pt/figado', 'liver'),
  ('pt/mae', 'mother'),
  ('pt/noite', 'night'),
  ('pt/pe', 'foot'),
  ('pt/vir', 'to come'),
  ('ru/mat', 'mother'),
  ('ru/noc', 'night'),
  ('sa/gacchati', 'goes'),
  ('sa/matr', 'mother'),
  ('sa/pad', 'foot'),
  ('sla-pro/mati', 'mother'),
  ('sla-pro/noti', 'night')
) v(slug, testo);

insert into glossa (lessema_id, accezione_id, lingua, testo)
select a.lessema_id, a.id, 'en', v.testo
from (values
  ('grc/drachme', 1, 'handful'),
  ('grc/drachme', 2, 'drachma (coin)'),
  ('grc/obelos',  1, 'spit, skewer'),
  ('grc/obelos',  2, 'critical sign marking spurious lines'),
  ('la/ficatum',  1, 'fattened with figs (iecur ficatum)'),
  ('la/ficatum',  2, 'liver')
) v(slug, n, testo)
join accezione a on a.lessema_id = lx(v.slug) and a.n = v.n;

-- etichette dei vocabolari: nomi e sigle delle lingue
insert into etichetta_lingua (vocabolario, codice, lingua, etichetta, breve) values
('lingua', 'ine-pro', 'en', 'Proto-Indo-European', 'PIE'),
('lingua', 'itc-pro', 'en', 'Proto-Italic',        'PIt.'),
('lingua', 'gem-pro', 'en', 'Proto-Germanic',      'PGmc.'),
('lingua', 'sla-pro', 'en', 'Proto-Slavic',        'PSl.'),
('lingua', 'la',      'en', 'Latin',               'Lat.'),
('lingua', 'la-vul',  'en', 'Vulgar Latin',        'VL'),
('lingua', 'la-med',  'en', 'Medieval Latin',      'ML'),
('lingua', 'grc',     'en', 'Ancient Greek',       'Gk.'),
('lingua', 'sa',      'en', 'Sanskrit',            'Skt.'),
('lingua', 'it',      'en', 'Italian',             'It.'),
('lingua', 'fro',     'en', 'Old French',          'OFr.'),
('lingua', 'fr',      'en', 'French',              'Fr.'),
('lingua', 'es',      'en', 'Spanish',             'Sp.'),
('lingua', 'pt',      'en', 'Portuguese',          'Port.'),
('lingua', 'ang',     'en', 'Old English',         'OE'),
('lingua', 'en',      'en', 'English',             'Eng.'),
('lingua', 'de',      'en', 'German',              'Ger.'),
('lingua', 'ru',      'en', 'Russian',             'Russ.'),
('lingua', 'pal',     'en', 'Middle Persian',      'MPers.'),
('lingua', 'fa',      'en', 'Persian',             'Pers.'),
('lingua', 'ar',      'en', 'Arabic',              'Ar.');

-- rami e famiglie (anche in italiano: non hanno una colonna di base)
insert into etichetta_lingua (vocabolario, codice, lingua, etichetta) values
('ramo', 'proto', 'it', 'Protolingua comune'),     ('ramo', 'proto', 'en', 'Common proto-language'),
('ramo', 'italica', 'it', 'Italico'),              ('ramo', 'italica', 'en', 'Italic'),
('ramo', 'ellenica', 'it', 'Ellenico'),            ('ramo', 'ellenica', 'en', 'Hellenic'),
('ramo', 'germanica', 'it', 'Germanico'),          ('ramo', 'germanica', 'en', 'Germanic'),
('ramo', 'slava', 'it', 'Slavo'),                  ('ramo', 'slava', 'en', 'Slavic'),
('ramo', 'indoiranica', 'it', 'Indoiranico'),      ('ramo', 'indoiranica', 'en', 'Indo-Iranian'),
('ramo', 'semitica', 'it', 'Semitico'),            ('ramo', 'semitica', 'en', 'Semitic'),
('famiglia', 'indoeuropea', 'it', 'Indoeuropea'),  ('famiglia', 'indoeuropea', 'en', 'Indo-European'),
('famiglia', 'afroasiatica', 'it', 'Afroasiatica'), ('famiglia', 'afroasiatica', 'en', 'Afroasiatic');

-- tipi di relazione: etichetta lunga, forma breve per l'interfaccia, descrizione
insert into etichetta_lingua (vocabolario, codice, lingua, etichetta, breve, descrizione) values
('tipo_relazione', 'eredita',         'it', 'eredità (trafila popolare)', 'eredità',          null),
('tipo_relazione', 'variante',        'it', 'variante',                   'variante',         null),
('tipo_relazione', 'prestito',        'it', 'prestito',                   'prestito',         null),
('tipo_relazione', 'prestito_dotto',  'it', 'prestito dotto',             'prestito dotto',   null),
('tipo_relazione', 'semidotto',       'it', 'voce semidotta',             'voce semidotta',   null),
('tipo_relazione', 'trasmissione',    'it', 'trasmissione non specificata', 'via non precisata', null),
('tipo_relazione', 'generico',        'it', 'filiazione non specificata', 'legame indeterminato', null),
('tipo_relazione', 'derivazione',     'it', 'derivazione',                'derivazione',      null),
('tipo_relazione', 'composizione',    'it', 'composizione',               'composizione',     null),
('tipo_relazione', 'retroformazione', 'it', 'retroformazione',            'retroformazione',  null),
('tipo_relazione', 'accorciamento',   'it', 'accorciamento',              'accorciamento',    null),
('tipo_relazione', 'deonimico',       'it', 'da nome proprio',            'da nome proprio',  null),
('tipo_relazione', 'calco',           'it', 'calco',                      'calco',            null),
('tipo_relazione', 'calco_semantico', 'it', 'calco semantico',            'calco semantico',  null),
('tipo_relazione', 'influsso',        'it', 'incrocio o influsso',        'influsso',         null),
('tipo_relazione', 'paretimologia',   'it', 'paretimologia',              'paretimologia',    null),
('tipo_relazione', 'eredita',         'en', 'inheritance (popular descent)', 'inherited',     'Uninterrupted transmission, with regular sound changes.'),
('tipo_relazione', 'variante',        'en', 'variant',                    'variant',          'Alternative form of the same word in the same language: spelling, syncopated, reduced. A dialect form is linked by inheritance or borrowing.'),
('tipo_relazione', 'prestito',        'en', 'borrowing',                  'borrowed',         'Word taken from another language.'),
('tipo_relazione', 'prestito_dotto',  'en', 'learned borrowing',          'learned borrowing', 'Scholarly borrowing from Latin or Greek, without popular sound changes.'),
('tipo_relazione', 'semidotto',       'en', 'semi-learned word',          'semi-learned',     'Learned borrowing only partly adapted to popular phonology.'),
('tipo_relazione', 'trasmissione',    'en', 'unspecified transmission',   'route unspecified', 'The same word, by an unspecified route: inheritance or borrowing.'),
('tipo_relazione', 'generico',        'en', 'unspecified descent',        'indeterminate link', 'A link of descent whose nature is not specified: it may be the same word or a derivation.'),
('tipo_relazione', 'derivazione',     'en', 'derivation',                 'derivation',       'Formation with prefixes or suffixes.'),
('tipo_relazione', 'composizione',    'en', 'compound',                   'compound',         'Union of two or more lexical elements.'),
('tipo_relazione', 'retroformazione', 'en', 'back-formation',             'back-formation',   'Formation by removing a supposed affix.'),
('tipo_relazione', 'accorciamento',   'en', 'clipping',                   'clipping',         'Shortening of a longer word.'),
('tipo_relazione', 'deonimico',       'en', 'from a proper name',         'from a name',      'Word taken from a personal or place name.'),
('tipo_relazione', 'calco',           'en', 'calque',                     'calque',           'Word modelled on a foreign word, translated element by element.'),
('tipo_relazione', 'calco_semantico', 'en', 'semantic calque',            'semantic calque',  'New meaning taken on from a foreign word.'),
('tipo_relazione', 'influsso',        'en', 'contamination or influence', 'influence',        'Blending or analogy that reshapes a form.'),
('tipo_relazione', 'paretimologia',   'en', 'folk etymology',             'folk etymology',   'Popular reanalysis through false association with another word.');

insert into etichetta_lingua (vocabolario, codice, lingua, etichetta) values
('processo', 'metafora', 'en', 'metaphor'),         ('processo', 'metonimia', 'en', 'metonymy'),
('processo', 'sineddoche', 'en', 'synecdoche'),     ('processo', 'estensione', 'en', 'broadening'),
('processo', 'restrizione', 'en', 'narrowing'),     ('processo', 'peggiorativo', 'en', 'pejoration'),
('processo', 'migliorativo', 'en', 'amelioration'), ('processo', 'ellissi', 'en', 'ellipsis'),
('processo', 'tecnicizzazione', 'en', 'technical specialization'),
('processo', 'antonomasia', 'en', 'antonomasia'),   ('processo', 'eufemismo', 'en', 'euphemism');

insert into etichetta_lingua (vocabolario, codice, lingua, etichetta, breve, descrizione) values
('strato', 'redazione',  'en', 'Editorial team', 'Reserved (licence to be defined)', null),
('strato', 'wiktionary', 'en', 'Wiktionary, via Kaikki/wiktextract', 'CC BY-SA 4.0',
 'Contains data from Wiktionary, distributed under CC BY-SA 4.0.'),
('strato', 'wikizionario', 'en', 'Italian Wiktionary, via Kaikki/wiktextract', 'CC BY-SA 4.0',
   'Contains glosses from the Italian Wiktionary, distributed under CC BY-SA 4.0.'),
('strato', 'rew',        'en', 'Meyer-Lübke, REW, 3rd ed. 1935', 'Public domain (EU)', null),
('strato', 'pianigiani', 'en', 'Pianigiani, Vocabolario etimologico, 1907', 'Public domain', null);

refresh materialized view mv_allotropi;
refresh materialized view mv_famiglia;
