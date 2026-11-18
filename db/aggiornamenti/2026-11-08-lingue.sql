-- 8 novembre 2026: l'albero delle lingue. Le tabelle d'appoggio delle lingue e delle famiglie di Wiktionary e
-- importa_lingue_wiktionary(), stesso testo di db/05_import_wiktionary.sql: se cambia lì, si rigenera da lì.
-- Ripetibile senza danni.

-- Le lingue e le famiglie di Wiktionary (dati/lingue_wiktionary.tsv.gz, dati/famiglie_wiktionary.tsv.gz, da
-- import/lingue_wiktionary.py): completano famiglia, ramo, antenato e varietà delle lingue che non li hanno, e
-- correggono i nomi letti male («calque of Western Apache»). Solo dove manca: le lingue già classificate non cambiano.
create unlogged table if not exists stg_lingua_wikt (codice text, nome text, famiglia text, antenati text, madre text, tipo text,
                                                     wikidata text, nome_it text);
alter table stg_lingua_wikt add column if not exists wikidata text, add column if not exists nome_it text;
create unlogged table if not exists stg_famiglia_wikt (codice text, nome text, madre text);

create or replace function importa_lingue_wiktionary() returns jsonb
language plpgsql as $$
declare
  r jsonb := '{}';
  n int;
begin
  if not exists (select 1 from stg_lingua_wikt) then
    return jsonb_build_object('saltato', 'tabella di appoggio vuota');
  end if;
  perform set_config('app.import', 'on', true);
  drop table if exists lw_nomi, lw_base, lw_classe, lw_antenato;
  -- i nomi delle famiglie e dei rami più comuni; le altre famiglie tengono il nome inglese di Wiktionary
  create temp table lw_nomi (codice text primary key, livello text, it text, en text) on commit drop;
  insert into lw_nomi values
    ('ine', 'famiglia', 'indoeuropea', 'Indo-European'), ('afa', 'famiglia', 'afroasiatica', 'Afroasiatic'),
    ('nic', 'famiglia', 'niger-congo', 'Niger-Congo'), ('map', 'famiglia', 'austronesiana', 'Austronesian'),
    ('aus-pam', 'famiglia', 'pama-nyunga', 'Pama-Nyungan'), ('aql', 'famiglia', 'algica', 'Algic'),
    ('urj', 'famiglia', 'uralica', 'Uralic'), ('sit', 'famiglia', 'sinotibetana', 'Sino-Tibetan'),
    ('trk', 'famiglia', 'turca', 'Turkic'), ('qfa-dny', 'famiglia', 'dene-jenisseiana', 'Dene-Yeniseian'),
    ('azc', 'famiglia', 'uto-azteca', 'Uto-Aztecan'), ('aav', 'famiglia', 'austroasiatica', 'Austroasiatic'),
    ('sal', 'famiglia', 'salish', 'Salishan'), ('dra', 'famiglia', 'dravidica', 'Dravidian'),
    ('iro', 'famiglia', 'irochese', 'Iroquoian'), ('nai-sca', 'famiglia', 'siouan-catawba', 'Siouan-Catawban'),
    ('qfa-xgs', 'famiglia', 'serbi-mongolica', 'Serbi-Mongolic'), ('tuw', 'famiglia', 'tungusa', 'Tungusic'),
    ('esx', 'famiglia', 'eschimo-aleutina', 'Eskimo-Aleut'), ('ssa', 'famiglia', 'nilo-sahariana', 'Nilo-Saharan'),
    ('cau-nec', 'famiglia', 'caucasica nordorientale', 'Northeast Caucasian'), ('tup', 'famiglia', 'tupi', 'Tupian'),
    ('qfa-tak', 'famiglia', 'tai-kadai', 'Kra-Dai'), ('sai-car', 'famiglia', 'caribe', 'Cariban'),
    ('nai-mus', 'famiglia', 'muskogean', 'Muskogean'), ('awd', 'famiglia', 'arawak', 'Arawakan'),
    ('wak', 'famiglia', 'wakash', 'Wakashan'), ('ccs', 'famiglia', 'cartvelica', 'Kartvelian'),
    ('myn', 'famiglia', 'maya', 'Mayan'), ('qfa-cka', 'famiglia', 'ciukoto-kamciatka', 'Chukotko-Kamchatkan'),
    ('cau-nwc', 'famiglia', 'caucasica nordoccidentale', 'Northwest Caucasian'), ('qfa-hur', 'famiglia', 'hurro-urartea', 'Hurro-Urartian'),
    ('euq', 'famiglia', 'vasconica', 'Vasconic'), ('jpx', 'famiglia', 'giapponica', 'Japonic'),
    ('qfa-kor', 'famiglia', 'coreanica', 'Koreanic'), ('qwe', 'famiglia', 'quechua', 'Quechuan'),
    ('qfa-tyn', 'famiglia', 'tirrenica', 'Tyrsenian'), ('crp', 'famiglia', 'creola o pidgin', 'Creole or pidgin'),
    ('art', 'famiglia', 'artificiale', 'Constructed'), ('sgn', 'famiglia', 'lingua dei segni', 'Sign language'),
    ('qfa-iso', 'famiglia', 'isolata', 'Isolate'), ('mul', 'famiglia', 'translingue', 'Translingual'),
    ('qfa-cnt', 'famiglia', 'di contatto', 'Contact language'),
    ('itc', 'ramo', 'italica', 'Italic'), ('gem', 'ramo', 'germanica', 'Germanic'), ('grk', 'ramo', 'ellenica', 'Hellenic'),
    ('sla', 'ramo', 'slava', 'Slavic'), ('bat', 'ramo', 'baltica', 'Baltic'), ('cel', 'ramo', 'celtica', 'Celtic'),
    ('iir', 'ramo', 'indoiranica', 'Indo-Iranian'), ('hyx', 'ramo', 'armena', 'Armenian'), ('sqj', 'ramo', 'albanese', 'Albanian'),
    ('ine-ana', 'ramo', 'anatolica', 'Anatolian'), ('ine-toc', 'ramo', 'tocaria', 'Tocharian'),
    ('sem', 'ramo', 'semitica', 'Semitic'), ('ber', 'ramo', 'berbera', 'Berber'), ('egx', 'ramo', 'egizia', 'Egyptian'),
    ('cus', 'ramo', 'cuscitica', 'Cushitic'), ('cdc', 'ramo', 'ciadica', 'Chadic'), ('trk-ogz', 'ramo', 'oghuz', 'Oghuz'),
    -- sottofamiglie, per il nome di un codice di famiglia usato come lingua («lingua romanza (non precisata)»)
    ('roa', 'sotto', 'romanza', 'Romance'), ('gmw', 'sotto', 'germanica occidentale', 'West Germanic'),
    ('gmq', 'sotto', 'germanica settentrionale', 'North Germanic'), ('gme', 'sotto', 'germanica orientale', 'East Germanic'),
    ('zle', 'sotto', 'slava orientale', 'East Slavic'), ('zlw', 'sotto', 'slava occidentale', 'West Slavic'),
    ('zls', 'sotto', 'slava meridionale', 'South Slavic'), ('inc', 'sotto', 'indoaria', 'Indo-Aryan'),
    ('ira', 'sotto', 'iranica', 'Iranian'), ('cel-bry', 'sotto', 'britannica', 'Brythonic'), ('cel-gae', 'sotto', 'gaelica', 'Goidelic'),
    ('sem-ara', 'sotto', 'aramaica', 'Aramaic'), ('sem-can', 'sotto', 'cananaica', 'Canaanite');

  -- 1. ogni lingua alla sua lingua piena (latino volgare › latino classico › latino) e alla sua famiglia
  create temp table lw_base on commit drop as
  with recursive su (codice, cur, prof) as (
    select l.codice, l.codice, 0 from lingua l
    union all
    select s.codice, w.madre, s.prof + 1
      from su s join stg_lingua_wikt w on w.codice = s.cur
     where w.tipo = 'etimologica' and coalesce(w.madre, '') <> '' and s.prof < 8)
  select distinct on (s.codice) s.codice, s.cur as piena,
         case when s.codice in ('mul', 'mul-tax') then 'mul'
              when f.codice is not null then s.cur
              -- una protolingua che Wiktionary non elenca (aav-pro): la famiglia del suo codice
              when w.codice is null and s.cur like '%-pro' then
                (select g.codice from stg_famiglia_wikt g where g.codice = left(s.cur, -4))
              else nullif(w.famiglia, '') end as fam
    from su s left join stg_lingua_wikt w on w.codice = s.cur left join stg_famiglia_wikt f on f.codice = s.cur
   order by s.codice, s.prof desc;

  -- 2. la catena delle famiglie (roa-itr › roa › itc › ine): la famiglia in cima, e il ramo più preciso che ha un nome
  create temp table lw_classe on commit drop as
  with recursive fc (codice, fam, prof) as (
    select b.codice, b.fam, 0 from lw_base b where b.fam is not null
    union all
    select c.codice, f.madre, c.prof + 1
      from fc c join stg_famiglia_wikt f on f.codice = c.fam
     where coalesce(f.madre, '') <> '' and f.madre <> 'qfa-not' and c.prof < 20),
  cima as (select distinct on (codice) codice, fam from fc order by codice, prof desc),
  ramo as (select distinct on (fc.codice) fc.codice, n.it, n.en
             from fc join lw_nomi n on n.codice = fc.fam and n.livello = 'ramo' order by fc.codice, fc.prof)
  select c.codice, coalesce(nf.it, f.nome, c.fam) as famiglia, coalesce(nf.en, f.nome, c.fam) as famiglia_en,
         r.it as ramo, r.en as ramo_en
    from cima c left join lw_nomi nf on nf.codice = c.fam and nf.livello = 'famiglia'
    left join stg_famiglia_wikt f on f.codice = c.fam
    left join ramo r on r.codice = c.codice;

  update lingua l set famiglia = c.famiglia from lw_classe c where c.codice = l.codice and l.famiglia is null;
  get diagnostics n = row_count;
  r := r || jsonb_build_object('famiglie_assegnate', n);
  update lingua l set ramo = c.ramo
    from lw_classe c where c.codice = l.codice and l.ramo is null and c.ramo is not null and l.famiglia = c.famiglia;
  get diagnostics n = row_count;
  r := r || jsonb_build_object('rami_assegnati', n);
  insert into etichetta_lingua (vocabolario, codice, lingua, etichetta)
  select distinct 'famiglia', famiglia, 'en', famiglia_en from lw_classe where famiglia is not null
  union
  select distinct 'ramo', ramo, 'en', ramo_en from lw_classe where ramo is not null
  on conflict do nothing;
  -- i rami si leggono al maschile, come Italico e Germanico
  insert into etichetta_lingua (vocabolario, codice, lingua, etichetta) values
    ('ramo', 'albanese', 'it', 'Albanese'), ('ramo', 'anatolica', 'it', 'Anatolico'), ('ramo', 'armena', 'it', 'Armeno'),
    ('ramo', 'baltica', 'it', 'Baltico'), ('ramo', 'berbera', 'it', 'Berbero'), ('ramo', 'celtica', 'it', 'Celtico'),
    ('ramo', 'ciadica', 'it', 'Ciadico'), ('ramo', 'cuscitica', 'it', 'Cuscitico'), ('ramo', 'egizia', 'it', 'Egizio'),
    ('ramo', 'tocaria', 'it', 'Tocario'), ('ramo', 'oghuz', 'it', 'Oghuz')
  on conflict do nothing;

  -- 3. l'antenato, dove manca: il primo antenato di Wiktionary che è una lingua del dizionario, risalendo anche
  --    attraverso gli antenati che non lo sono (catalano › catalano antico › latino volgare › latino)
  create temp table lw_antenato on commit drop as
  with recursive an (codice, cur, prof) as (
    select l.codice, btrim(a), 1
      from lingua l join stg_lingua_wikt w on w.codice = l.codice
      cross join lateral unnest(string_to_array(nullif(w.antenati, ''), ',')) a
     where l.antenato is null and l.varieta_di is null
    union all
    select an.codice, x.prossimo, an.prof + 1
      from an join stg_lingua_wikt w2 on w2.codice = an.cur
      cross join lateral (select btrim(a2) as prossimo from unnest(string_to_array(nullif(w2.antenati, ''), ',')) a2
                          union all select w2.madre where w2.tipo = 'etimologica' and coalesce(w2.madre, '') <> '') x
     where an.prof < 6 and not exists (select 1 from lingua g where g.codice = an.cur))
  select distinct on (an.codice) an.codice, an.cur as antenato
    from an join lingua g on g.codice = an.cur
   where an.cur <> an.codice and g.antenato is distinct from an.codice and g.varieta_di is distinct from an.codice
   order by an.codice, an.prof;
  update lingua l set antenato = a.antenato from lw_antenato a where a.codice = l.codice and l.antenato is null;
  get diagnostics n = row_count;
  r := r || jsonb_build_object('antenati_assegnati', n);

  -- 4. le lingue etimologiche sono varietà della loro lingua piena (latino volgare del latino), se non hanno altro
  update lingua l set varieta_di = b.piena
    from lw_base b
   where b.codice = l.codice and l.varieta_di is null and l.antenato is null and b.piena <> l.codice
     and exists (select 1 from lingua g where g.codice = b.piena)
     -- solo di una lingua vera: il galiziano-portoghese non è una varietà della famiglia romanza
     and exists (select 1 from stg_lingua_wikt w where w.codice = b.piena and w.tipo <> 'etimologica');
  get diagnostics n = row_count;
  r := r || jsonb_build_object('varieta_assegnate', n);

  -- 5. i nomi letti male dal testo dei modelli: il nome canonico di Wiktionary; poi, per le lingue che hanno ancora
  --    il nome inglese (quelle che il parser non cura), il nome italiano di Wikidata (Basque → basco)
  update lingua l set nome = case when l.codice = 'mul-tax' then 'nomi scientifici' else w.nome end
    from stg_lingua_wikt w
   where w.codice = l.codice
     and ((l.codice = 'mul-tax' and l.nome <> 'nomi scientifici')
          or (l.nome <> w.nome and (l.nome ~* '^(borrowed from|calque of|learned borrowing|semi-learned|orthographic borrowing|unadapted borrowing|partial calque|semantic loan|taxonomic name)'
                                   or l.nome ~ '-$' or l.nome = l.codice)));
  get diagnostics n = row_count;
  r := r || jsonb_build_object('nomi_corretti', n);
  update lingua l set nome = w.nome_it
    from stg_lingua_wikt w
   where w.codice = l.codice and l.nome = w.nome and coalesce(w.nome_it, '') <> '' and w.nome_it <> l.nome;
  get diagnostics n = row_count;
  r := r || jsonb_build_object('nomi_italiani', n);
  -- «Old Sicilian», «Middle Low German»: il nome italiano della lingua, con antico o medio
  update lingua l set nome = x.nome || case when m[1] = 'Old' then ' antico' else ' medio' end
    from (select codice, regexp_match(nome, '^(Old|Middle) (.+)$') as m from lingua) y
    join stg_lingua_wikt w on w.nome = y.m[2] and w.tipo <> 'etimologica'
    join lingua x on x.codice = w.codice and x.nome <> w.nome
   where y.codice = l.codice and y.m is not null and l.nome ~ '^(Old|Middle) ';
  -- i nomi che Wikidata dà a un'altra lingua (zle-mru «antica lingua slava orientale», come orv; zlw-ocs «storia della
  -- lingua ceca»; quattro lingue «ruteno») o non dà: il nome curato, solo dove la lingua ha ancora il nome inglese,
  -- quello di Wikidata o il codice (18 novembre 2026)
  update lingua l set nome = c.it
    from (values ('orv', 'antico slavo orientale'), ('zle-mru', 'russo medio'), ('zle-muk', 'ucraino medio'),
                 ('zle-mbe', 'bielorusso medio'), ('zle-ort', 'ruteno antico'), ('rue', 'ruteno dei Carpazi'),
                 ('rsk', 'ruteno pannonico'), ('zle-ono', 'antico novgorodiano'), ('zle-ops', 'antico pskoviano'),
                 ('zlw-ocs', 'ceco antico'), ('czk', 'giudeo-ceco'), ('svm', 'slavomolisano'), ('zlw-slv', 'slovinzo'),
                 ('zls-chs-ru', 'slavo ecclesiastico russo'), ('zls-chs-uk', 'slavo ecclesiastico ucraino'),
                 ('zls-chs-sr', 'slavo ecclesiastico serbo'), ('zls-chs-hr', 'slavo ecclesiastico croato'),
                 ('zls-chs-bg', 'slavo ecclesiastico bulgaro'), ('zls-chs-mk', 'slavo ecclesiastico macedone'),
                 ('zls-chs-cs', 'slavo ecclesiastico ceco'), ('zls-chs-ro', 'slavo ecclesiastico romeno'),
                 ('fa-cls', 'persiano classico'), ('okz', 'khmer antico'), ('pnb', 'punjabi occidentale'),
                 ('xlg', 'ligure preromano'), ('es-MX', 'spagnolo del Messico'), ('fr-lou', 'francese della Louisiana'))
         as c(codice, it)
    join stg_lingua_wikt w on w.codice = c.codice
   where l.codice = c.codice and l.nome <> c.it
     and (l.nome = w.nome or l.nome = coalesce(w.nome_it, '') or l.nome = l.codice
          or l.nome ~* '^(borrowed from|calque of|learned borrowing) ');
  get diagnostics n = row_count;
  r := r || jsonb_build_object('nomi_curati', n);
  -- un codice di famiglia usato come lingua (roa, gmw: «una lingua romanza») prende il nome della famiglia
  update lingua l set nome = case when n.it is null then f.nome else 'lingua ' || n.it || ' (non precisata)' end
    from stg_famiglia_wikt f left join lw_nomi n on n.codice = f.codice
   where f.codice = l.codice and l.nome = l.codice;
  update etichetta_lingua e set etichetta = case when e.codice = 'mul-tax' then 'taxonomic names' else w.nome end
    from stg_lingua_wikt w
   where e.vocabolario = 'lingua' and e.lingua = 'en' and e.codice = w.codice and e.etichetta <> w.nome
     and (e.etichetta ~* '^(borrowed from|calque of|learned borrowing|semi-learned|orthographic borrowing|unadapted borrowing|partial calque|semantic loan|taxonomic name)'
          or e.etichetta ~ '-$');
  r := r || jsonb_build_object('senza_famiglia', (select count(*) from lingua g where g.famiglia is null
                                                     and exists (select 1 from lessema x where x.lingua = g.codice)));
  return r;
end $$;
comment on function importa_lingue_wiktionary() is 'Famiglia, ramo, antenato, varietà e nome delle lingue dai dati di Wiktionary, solo dove mancano.';
