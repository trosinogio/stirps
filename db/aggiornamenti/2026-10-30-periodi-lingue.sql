-- 30 ottobre 2026: periodi delle lingue per la linea del tempo.
-- Datazioni convenzionali e approssimative: dalla prima testimonianza scritta per le lingue attestate,
-- gli intervalli di solito citati per le protolingue. Collocano nel tempo i nodi senza attestazione: non sono date delle parole.
-- anno_a vuoto: lingua ancora in uso. Ripetibile senza danni.
comment on column lingua.anno_da is 'Inizio convenzionale del periodo della lingua (prima testimonianza scritta, o intervallo ricostruito per le protolingue).';
comment on column lingua.anno_a  is 'Fine convenzionale del periodo; vuoto se la lingua è ancora in uso.';

update lingua g set anno_da = v.da, anno_a = v.a
  from (values
    -- protolingue
    ('ine-pro', -4500, -2500), ('itc-pro', -1500, -800), ('gem-pro', -500, 200), ('gmw-pro', 100, 600),
    ('cel-pro', -1300, -800), ('grk-pro', -2200, -1600), ('iir-pro', -2500, -1800), ('sla-pro', -500, 800),
    -- latino e lingue dell'Italia antica
    ('itc-ola', -700, -100), ('la', -700, 600), ('la-vul', 100, 700), ('la-lat', 200, 600),
    ('la-med', 600, 1500), ('la-new', 1500, 1900), ('la-ecc', 200, 1900),
    ('ett', -700, 50), ('osc', -500, 100), ('xum', -400, -100), ('cel-gau', -300, 500),
    -- greco
    ('gmy', -1450, -1150), ('grc', -800, 600), ('grc-koi', -300, 600), ('gkm', 600, 1453), ('el', 1453, null),
    -- germanico
    ('got', 300, 800), ('frk', 250, 900), ('lng', 568, 1000), ('goh', 750, 1050), ('gmh', 1050, 1350), ('de', 1350, null),
    ('ang', 450, 1150), ('enm', 1150, 1500), ('en', 1500, null), ('non', 700, 1350),
    ('odt', 500, 1150), ('dum', 1150, 1500), ('nl', 1500, null),
    -- romanzo
    ('fro', 842, 1400), ('frm', 1400, 1600), ('fr', 1400, null), ('pro', 1000, 1500), ('oc', 1500, null),
    ('osp', 950, 1500), ('es', 1200, null), ('roa-opt', 1175, 1500), ('pt', 1200, null), ('ca', 1150, null),
    ('roa-oit', 960, 1500), ('it', 960, null), ('scn', 1230, null), ('nap', 1300, null), ('vec', 1200, null),
    ('lmo', 1250, null), ('lij', 1250, null), ('sc', 1080, null), ('fur', 1300, null), ('ro', 1521, null),
    -- semitico, egiziano, iranico, indiano
    ('akk', -2500, 100), ('egy', -3200, 400), ('cop', 200, 1700), ('arc', -900, 700), ('hbo', -1000, 400), ('he', -1000, null),
    ('ar', 350, null), ('am', 1300, null), ('peo', -600, -300), ('pal', -300, 900), ('fa-cls', 900, 1700), ('fa', 900, null),
    ('sa', -1500, null), ('hi', 1500, null),
    -- altre
    ('ota', 1300, 1928), ('tr', 1300, null), ('sq', 1462, null), ('hu', 1192, null),
    ('cu', 860, 1100), ('orv', 1000, 1400), ('ru', 1700, null), ('pl', 1270, null), ('cs', 1300, null), ('sh', 1100, null),
    ('sga', 600, 900), ('mga', 900, 1200), ('ga', 1200, null), ('eu', 1545, null), ('fi', 1540, null),
    ('hy', 405, null), ('ka', 430, null), ('zh', -1250, null), ('ja', 700, null), ('ms', 1300, null),
    ('tpw', 1500, 1800), ('nci', 1300, 1800), ('qu', 1560, null)
  ) as v(codice, da, a)
 where g.codice = v.codice and (g.anno_da is distinct from v.da or g.anno_a is distinct from v.a);
