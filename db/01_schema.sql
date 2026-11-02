-- =====================================================================
--  Stirps, dizionario etimologico per radici — schema dati v0.5
--  PostgreSQL ≥ 14 (collaudato su 16). Compatibile con Neon.
--  Ordine di esecuzione: 01_schema → 02_logica → 03_seed_pilota → 04_test
-- =====================================================================

create extension if not exists pg_trgm;

-- ---------------------------------------------------------------------
--  Tipi enumerati: stati interni, insiemi chiusi
-- ---------------------------------------------------------------------
create type stato_editoriale as enum ('importato', 'bozza', 'rivisto', 'verificato', 'superato');
create type stato_ipotesi    as enum ('accolta', 'alternativa', 'minoritaria', 'respinta');
create type precisione_data  as enum ('esatta', 'circa', 'ante', 'post', 'intervallo', 'secolo');
create type posizione_fonte  as enum ('propone', 'accoglie', 'discute', 'respinge', 'attesta');
create type origine_tipo     as enum ('etimo', 'onomatopea', 'espressiva', 'ignota', 'sostrato');

-- ---------------------------------------------------------------------
--  Normalizzazione per ricerca e slug (immutabile: serve alle colonne generate)
--  minuscole → NFKD (ʷ→w, ₃→3) → via i segni combinanti (accenti greci,
--  diacritici latini, harakat arabe) → ς→σ → via asterischi e punteggiatura
-- ---------------------------------------------------------------------
create function norm(t text) returns text
language sql immutable strict parallel safe
return trim(regexp_replace(
  translate(
    regexp_replace(
      normalize(
        replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(lower(t),
          'ß', 'ss'), 'æ', 'ae'), 'œ', 'oe'), 'þ', 'th'), 'ð', 'd'), 'ı', 'i'),
          'ʃ', 'sh'), 'ʒ', 'zh'), 'ŋ', 'ng'), 'ɣ', 'gh'),
        NFKD),
      '[\u0300-\u036f\u064b-\u065f\u0670\u200b-\u200d\u2060\ufeff]', '', 'g'),
    'ςøłđħəɛɔɨʉɪʊɑʿʾʼʹʺʕʔˀ''’‘"*()[]{}<>-‐–—.,;:!?·/',
    'σoldheeoiuiua'),
  '\s+', ' ', 'g'));

comment on function norm(text) is
  'Forma normalizzata per ricerca e slug: «ὀβελός»→«οβελοσ», «*nókʷts»→«nokwts», «ṣifr»→«sifr», «Fuß»→«fuss», «*pnéwmə»→«pnewme», «ʕarab»→«arab».';

-- L'indirizzo di una voce: lingua/forma normalizzata, con il trattino degli affissi (it/foto-, it/-grafia: non
-- coincidono con le parole foto e grafia) e il numero d'omografo (it/zefiro-2). Le radici ricostruite non hanno
-- trattino (ine-pro/sek). È la sola fonte della regola: la usano la colonna slug e i controlli dell'import.
-- La chiave dell'indice di una lingua: le prime due lettere della forma normalizzata, secondo l'alfabeto della lingua
-- (23 lettere latine, con J sotto I e U sotto V; 24 greche). «A-» raccoglie le parole di una lettera e quelle come
-- «a priori»; null per le parole che cominciano fuori dall'alfabeto (W latina, ϝοῖκος con la lettera epicorica), che
-- restano voci ma fuori dall'indice.
-- È nella colonna generata lessema.chiave_indice: se cambia, la colonna va ricalcolata (update lessema set lemma = lemma).
create or replace function indice_iniziali(p_lingua text, p_forma text) returns text
language sql immutable parallel safe
return (with a as (select case when p_lingua ~ '^la(-|$)' then 'ABCDEFGHIKLMNOPQRSTVXYZ'
                               -- il greco arcadocipriota ha il sillabario: si indicizza per segni
                               when p_lingua ~ '^grc(-|$)' and p_lingua <> 'grc-arp' then 'ΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩ' end as lettere,
                          case when p_lingua ~ '^la(-|$)' then translate(upper(p_forma), 'JU', 'IV') else upper(p_forma) end as f)
        select case when f is null or f = '' then null
                    when lettere is not null and strpos(lettere, left(f, 1)) = 0 then null
                    when substr(f, 2, 1) ~ '^[[:alpha:]]$' and (lettere is null or strpos(lettere, substr(f, 2, 1)) > 0) then left(f, 2)
                    else left(f, 1) || '-' end
          from a);

create function slug_di(p_lingua text, p_lemma text, p_translit text, p_omografo int, p_ricostruito boolean) returns text
language sql immutable parallel safe
return p_lingua || '/'
    || case when not p_ricostruito and length(p_lemma) > 1 and left(p_lemma, 1) = '-' then '-' else '' end
    || replace(norm(coalesce(p_translit, p_lemma)), ' ', '-')
    || case when not p_ricostruito and length(p_lemma) > 1 and right(p_lemma, 1) = '-' then '-' else '' end
    || case when p_omografo > 1 then '-' || p_omografo else '' end;

-- ---------------------------------------------------------------------
--  Strati di dati e licenze
-- ---------------------------------------------------------------------
create table strato (
  codice        text primary key,
  nome          text not null,
  licenza       text not null,
  share_alike   boolean not null default false,
  attribuzione  text,
  url           text
);
comment on table strato is
  'Origine dei dati e relativa licenza. Ogni record dichiara il suo strato in «provenienza», che non si può cambiare.';

-- ---------------------------------------------------------------------
--  Lingue e varietà (codici in stile Wiktionary, per facilitare l'import).
--  Nessuna lingua è privilegiata: l'italiano è una lingua come le altre.
-- ---------------------------------------------------------------------
create table lingua (
  codice       text primary key,
  nome         text not null,
  sigla        text not null,
  famiglia     text,
  ramo         text,
  iso639_3     text,
  antenato     text references lingua,
  varieta_di   text references lingua,
  ricostruita  boolean not null default false,
  anno_da      int,
  anno_a       int,
  lat          numeric(8,5),
  lon          numeric(8,5),
  check (antenato   is distinct from codice),
  check (varieta_di is distinct from codice)
);
comment on column lingua.sigla      is 'Abbreviazione per l''interfaccia: it., lat., gr. ant., PIE.';
comment on column lingua.famiglia   is 'Famiglia linguistica (indoeuropea, afroasiatica, uralica, sinotibetana…): vale per qualunque lingua.';
comment on column lingua.ramo       is 'Ramo della famiglia (italica, germanica, semitica…); nullo per la protolingua comune.';
comment on column lingua.antenato   is 'Lingua da cui questa discende geneticamente (it → la → itc-pro → ine-pro).';
comment on column lingua.varieta_di is 'Registro o varietà di un''altra lingua (la-vul, la-med → la).';
comment on column lingua.lat        is 'Centroide indicativo per le mappe del viaggio; nullo per le protolingue.';

-- ---------------------------------------------------------------------
--  Vocabolari controllati con descrizione (alimentano anche l'interfaccia)
-- ---------------------------------------------------------------------
create table tipo_relazione (
  codice       text primary key,
  etichetta    text not null,
  categoria    text not null check (categoria in ('trasmissione', 'formazione', 'indeterminata', 'influsso')),
  ereditario   boolean not null default false,
  descrizione  text not null,
  check (not ereditario or categoria = 'trasmissione')
);
comment on column tipo_relazione.categoria is
  'trasmissione: la stessa parola passa oltre (conta per cognati e allotropi); '
  'formazione: nasce una parola nuova; indeterminata: filiazione accertata ma di natura non specificata, '
  'entra negli alberi ma non nei cognati e negli allotropi; influsso: arco secondario, escluso dagli alberi.';
comment on column tipo_relazione.ereditario is
  'Vale per i cognati in senso stretto: solo trafila ereditaria, senza prestiti.';

create table processo_semantico (
  codice       text primary key,
  etichetta    text not null,
  descrizione  text not null
);

-- ---------------------------------------------------------------------
--  Lessemi: ogni forma, attestata o ricostruita, in una lingua
-- ---------------------------------------------------------------------
create table lessema (
  id                bigint generated always as identity primary key,
  lingua            text not null references lingua,
  lemma             text not null,
  omografo          smallint not null default 1 check (omografo > 0),
  ricostruito       boolean not null default false,
  translit          text,
  pos               text,
  glossa            text,
  glossa_lingua     text not null default 'it' references lingua,
  obsoleto          boolean not null default false,
  nota              text,
  provenienza       text not null default 'redazione' references strato,
  id_esterno        text,
  stato_editoriale  stato_editoriale not null default 'bozza',
  creato_il         timestamptz not null default now(),
  aggiornato_il     timestamptz not null default now(),
  lemma_norm        text generated always as (norm(lemma)) stored,
  translit_norm     text generated always as (norm(translit)) stored,
  slug              text generated always as (slug_di(lingua, lemma, translit, omografo, ricostruito)) stored,
  -- l'indice per lettere della lingua (parole_lingua): calcolato una volta, non a ogni pagina
  chiave_indice     text generated always as (indice_iniziali(lingua, coalesce(nullif(norm(lemma), ''), lemma))) stored,
  nome_proprio      boolean generated always as (coalesce(pos, '') = 'np' or (pos is null and lemma ~ '^-?[[:upper:]]')) stored,
  unique (lingua, lemma, omografo),
  unique (slug),
  check (lemma = btrim(lemma) and lemma <> ''),
  check (lemma !~ '^\*')
);
comment on column lessema.lemma       is 'Forma di citazione, senza asterisco: l''asterisco lo aggiunge l''interfaccia se ricostruito.';
comment on column lessema.omografo    is 'Distingue omografi: zefiro (vento) e zefiro² (antica forma di «zero»).';
comment on column lessema.glossa_lingua is 'Lingua della glossa di base. Le altre lingue stanno in «glossa»: nessuna lingua d''interfaccia è implicita.';
comment on column lessema.pos         is 'Parte del discorso: s.m., s.f., s.n., agg., v., avv., prep., np (nome proprio), rad. (radice).';
comment on column lessema.slug        is 'Indirizzo stabile della voce: it/fegato, grc/obelos, ine-pro/nokwts, it/zefiro-2, it/foto-, it/-grafia.';
comment on column lessema.id_esterno  is 'Riferimento allo strato d''origine (es. pagina e revisione Wiktionary) per i reimport.';

-- ---------------------------------------------------------------------
--  Accezioni: albero dei significati di un lessema, con il processo semantico
-- ---------------------------------------------------------------------
create table accezione (
  id                bigint generated always as identity primary key,
  lessema_id        bigint not null references lessema on delete cascade,
  n                 smallint not null,
  glossa            text not null,
  glossa_lingua     text not null default 'it' references lingua,
  ambito            text,
  deriva_da         bigint,
  processo          text references processo_semantico,
  anno_da           int,
  anno_a            int,
  precisione        precisione_data,
  nota              text,
  provenienza       text not null default 'redazione' references strato,
  stato_editoriale  stato_editoriale not null default 'bozza',
  creato_il         timestamptz not null default now(),
  aggiornato_il     timestamptz not null default now(),
  unique (lessema_id, n),
  unique (id, lessema_id),
  foreign key (deriva_da, lessema_id) references accezione (id, lessema_id),
  check (deriva_da is distinct from id),
  check (processo is null or deriva_da is not null)
);
comment on column accezione.deriva_da is 'Accezione madre dello stesso lessema (ὀβελός «spiedo» → «segno critico»).';

-- ---------------------------------------------------------------------
--  Ipotesi: una spiegazione dell'origine immediata di un lessema (l'esito).
--  Al più una «accolta»; nessuna accolta = etimologia dichiaratamente aperta.
-- ---------------------------------------------------------------------
create table ipotesi (
  id                bigint generated always as identity primary key,
  esito_id          bigint not null references lessema on delete cascade,
  etichetta         text not null,
  stato             stato_ipotesi not null default 'accolta',
  confidenza        smallint not null default 3 check (confidenza between 1 and 4),
  origine           origine_tipo not null default 'etimo',
  diffusa           boolean not null default false,
  nota              text,
  nota_lingua       text references lingua,
  provenienza       text not null default 'redazione' references strato,
  id_esterno        text,
  stato_editoriale  stato_editoriale not null default 'bozza',
  creato_il         timestamptz not null default now(),
  aggiornato_il     timestamptz not null default now(),
  unique (id, esito_id),
  unique (esito_id, etichetta)
);
create unique index ipotesi_una_accolta on ipotesi (esito_id) where stato = 'accolta';

comment on column ipotesi.stato      is 'Preferenza editoriale. È indipendente dalla confidenza: un''ipotesi può essere accolta e incerta.';
comment on column ipotesi.confidenza is '4 certa · 3 probabile · 2 possibile · 1 dubbia.';
comment on column ipotesi.origine    is 'etimo = spiegata da archi; onomatopea, espressiva, ignota, sostrato = nessun etimo.';
comment on column ipotesi.nota_lingua is 'Lingua della nota, se diversa dalla lingua di redazione (le note di Wiktionary sono in inglese).';
comment on column ipotesi.diffusa    is 'Spiegazione corrente fuori dalla letteratura: respinta + diffusa = falso mito.';

-- ---------------------------------------------------------------------
--  Relazioni: gli archi del grafo. Ogni arco appartiene a un'ipotesi sul suo esito.
-- ---------------------------------------------------------------------
create table relazione (
  id                  bigint generated always as identity primary key,
  ipotesi_id          bigint not null,
  esito_id            bigint not null,
  etimo_id            bigint not null references lessema on delete restrict,
  tipo                text not null references tipo_relazione,
  ordine              smallint not null default 1,
  forma_citata        text,
  affisso             text,
  etimo_accezione_id  bigint,
  esito_accezione_id  bigint,
  processo            text references processo_semantico,
  confidenza          smallint not null default 3 check (confidenza between 1 and 4),
  anno_da             int,
  anno_a              int,
  precisione          precisione_data,
  luogo               text,
  nota                text,
  provenienza         text not null default 'redazione' references strato,
  id_esterno          text,
  stato_editoriale    stato_editoriale not null default 'bozza',
  creato_il           timestamptz not null default now(),
  aggiornato_il       timestamptz not null default now(),
  foreign key (ipotesi_id, esito_id) references ipotesi (id, esito_id)
    on update cascade on delete cascade,
  foreign key (etimo_accezione_id, etimo_id) references accezione (id, lessema_id),
  foreign key (esito_accezione_id, esito_id) references accezione (id, lessema_id),
  check (etimo_id <> esito_id),
  check (anno_a is null or anno_a >= anno_da),
  unique (ipotesi_id, etimo_id, tipo)
);
comment on column relazione.ordine       is 'Per i composti: primo elemento, secondo elemento…';
comment on column relazione.forma_citata is 'Forma dell''etimo in questo passaggio (lat. noctem per notte).';
comment on column relazione.etimo_accezione_id is
  'Se il passaggio riguarda un''accezione precisa (lat. obelus ← ὀβελός nel senso di «segno critico»).';
comment on column relazione.luogo        is 'Via o luogo del passaggio (es. Sicilia, Venezia): alimenta le mappe del viaggio.';

-- ---------------------------------------------------------------------
--  Connessioni non genealogiche (culturali, omonimie, falsi amici…)
-- ---------------------------------------------------------------------
create table connessione (
  id                bigint generated always as identity primary key,
  da_id             bigint not null references lessema on delete cascade,
  a_id              bigint not null references lessema on delete cascade,
  tipo              text not null check (tipo in ('culturale', 'semantica', 'omonimia', 'paronimia', 'falso_amico', 'altro')),
  descrizione       text not null,
  provenienza       text not null default 'redazione' references strato,
  stato_editoriale  stato_editoriale not null default 'bozza',
  creato_il         timestamptz not null default now(),
  aggiornato_il     timestamptz not null default now(),
  check (da_id <> a_id),
  unique (da_id, a_id, tipo)
);

-- ---------------------------------------------------------------------
--  Attestazioni: le prove, con datazione a intervallo
-- ---------------------------------------------------------------------
create table attestazione (
  id                bigint generated always as identity primary key,
  lessema_id        bigint not null references lessema on delete cascade,
  accezione_id      bigint,
  forma_attestata   text,
  testo             text not null,
  rif               text,
  tipo              text not null check (tipo in ('letteraria', 'documentaria', 'epigrafica', 'grammaticale', 'lessicografica', 'altro')),
  banca_dati        text,
  id_esterno        text,
  url               text,
  anno_da           int not null,
  anno_a            int,
  precisione        precisione_data not null default 'esatta',
  periodo           int4range generated always as (int4range(anno_da, coalesce(anno_a, anno_da), '[]')) stored,
  citazione         text,
  nota              text,
  stima             boolean not null default false,
  confidenza        smallint check (confidenza between 1 and 4),
  provenienza       text not null default 'redazione' references strato,
  stato_editoriale  stato_editoriale not null default 'bozza',
  creato_il         timestamptz not null default now(),
  aggiornato_il     timestamptz not null default now(),
  foreign key (accezione_id, lessema_id) references accezione (id, lessema_id),
  check (anno_a is null or anno_a >= anno_da),
  check (stato_editoriale <> 'verificato' or rif is not null),
  constraint attestazione_stima_non_verificata check (not (stima and stato_editoriale = 'verificato'))
);
comment on column attestazione.anno_da   is 'Anni interi, negativi per l''età a.C.; «sec. XIII» = 1201–1300 con precisione «secolo».';
comment on column attestazione.citazione is 'Solo testi in pubblico dominio e solo brevi.';
comment on column attestazione.banca_dati is 'EDR, EDH, EDCS per l''epigrafia; OVI, TLIO per l''italiano antico.';
comment on column attestazione.stima is 'Terminus ante quem trovato in automatico (corpus, citazioni di un dizionario): la parola è attestata almeno da allora. Non è la prima attestazione finché la redazione non la verifica sulla fonte, e una stima non può essere «verificata».';
comment on column attestazione.confidenza is 'Per le stime: 4 sicura · 3 probabile · 2 possibile · 1 dubbia (per esempio un anno isolato in un corpus OCR).';

-- Gli autori citati dai dizionari (Lewis & Short, LSJ) con la loro datazione: dall'autore più antico citato in una voce
-- si ricava una stima della prima attestazione. La sigla è quella del dizionario, per lingua (Plaut., Hom.).
create table autore (
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

-- ---------------------------------------------------------------------
--  Bibliografia e rimandi, con la posizione della fonte
-- ---------------------------------------------------------------------
create table opera (
  id                bigint generated always as identity primary key,
  sigla             text not null unique,
  autore            text,
  titolo            text not null,
  edizione          text,
  anno              int,
  editore           text,
  url               text,
  pubblico_dominio  boolean not null default false,
  nota              text,
  -- v0.5: bibliografia e consultazione in rete
  ambito            text,
  lingue            text[] not null default '{}',
  modello_url       text,
  tipo              text not null default 'etimologico'
                    check (tipo in ('etimologico', 'storico', 'lessico', 'in_rete'))
);
comment on column opera.lingue      is 'Lingue (codici) per cui l''opera è un riferimento: decide quali opere suggerire in una voce.';
comment on column opera.modello_url is 'Indirizzo di consultazione per lemma, con {lemma} al posto della parola: genera i collegamenti «Da consultare».';

-- Frequenze d'uso: ordinano la ricerca e la coda di verifica (si parte dalle parole più usate)
create table frequenza (
  lingua      text not null references lingua,
  forma       text not null,
  rango       int not null,
  occorrenze  bigint,
  fonte       text not null references strato,
  primary key (lingua, forma)
);
create index frequenza_rango on frequenza (lingua, rango);

create table rimando (
  id               bigint generated always as identity primary key,
  opera_id         bigint not null references opera,
  sv               text,
  locus            text,
  posizione        posizione_fonte not null default 'accoglie',
  nota             text,
  ipotesi_id       bigint references ipotesi      on delete cascade,
  relazione_id     bigint references relazione    on delete cascade,
  attestazione_id  bigint references attestazione on delete cascade,
  accezione_id     bigint references accezione    on delete cascade,
  lessema_id       bigint references lessema      on delete cascade,
  connessione_id   bigint references connessione  on delete cascade,
  creato_il        timestamptz not null default now(),
  check (num_nonnulls(ipotesi_id, relazione_id, attestazione_id, accezione_id, lessema_id, connessione_id) = 1)
);
comment on column rimando.sv        is 'Lemma della voce citata (s.v.).';
comment on column rimando.locus     is 'Volume, pagina, colonna o numero di voce (REW n. …).';
comment on column rimando.posizione is 'propone, accoglie, discute, respinge (per le ipotesi); attesta (per le attestazioni).';

-- ---------------------------------------------------------------------
--  Storico delle modifiche: l'apparato
-- ---------------------------------------------------------------------
create table storico (
  id          bigint generated always as identity primary key,
  tabella     text not null,
  record_id   bigint not null,
  operazione  char(1) not null check (operazione in ('I', 'U', 'D')),
  prima       jsonb,
  dopo        jsonb,
  utente      text default current_setting('app.utente', true),
  momento     timestamptz not null default now()
);
comment on table storico is
  'Ogni inserimento, modifica e cancellazione, con la riga prima e dopo. L''app imposta «set local app.utente».';

-- ---------------------------------------------------------------------
--  Import da Wiktionary: corrispondenza tra template e tipi di relazione
-- ---------------------------------------------------------------------
create table mappa_wiktionary (
  template  text primary key,
  tipo      text references tipo_relazione,
  origine   origine_tipo,
  uso       text not null
);
comment on table mappa_wiktionary is
  'Come tradurre i template di etimologia di Wiktionary (via wiktextract) in archi. tipo nullo = nessun arco.';

-- ---------------------------------------------------------------------
--  Multilinguismo (v0.3): glosse tradotte, etichette dei vocabolari, impostazioni
-- ---------------------------------------------------------------------
create table glossa (
  id                bigint generated always as identity primary key,
  lessema_id        bigint not null references lessema on delete cascade,
  accezione_id      bigint,
  lingua            text not null references lingua,
  testo             text not null,
  provenienza       text not null default 'redazione' references strato,
  stato_editoriale  stato_editoriale not null default 'bozza',
  creato_il         timestamptz not null default now(),
  aggiornato_il     timestamptz not null default now(),
  foreign key (accezione_id, lessema_id) references accezione (id, lessema_id) on delete cascade,
  check (testo = btrim(testo) and testo <> '')
);
create unique index glossa_lessema_lingua   on glossa (lessema_id, lingua)   where accezione_id is null;
create unique index glossa_accezione_lingua on glossa (accezione_id, lingua) where accezione_id is not null;

-- La definizione della voce, più ampia della glossa: una per lingua. La scrive la redazione, oppure un modello
-- (provenienza «claude», con il nome del modello): finché nessuno la rivede è automatica, e la pagina la segna con ≈.
create table definizione (
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
comment on table glossa is
  'Glosse in lingue diverse da quella di base, ciascuna con provenienza e stato: le glosse inglesi di Wiktionary entrano qui come strato importato.';

create table etichetta_lingua (
  vocabolario  text not null,
  codice       text not null,
  lingua       text not null references lingua,
  etichetta    text not null,
  breve        text,
  descrizione  text,
  primary key (vocabolario, codice, lingua)
);
comment on table etichetta_lingua is
  'Traduzioni dei vocabolari controllati: lingua (nome e sigla), ramo, famiglia, tipo_relazione, processo, strato.';

create table impostazione (
  chiave  text primary key,
  valore  text not null
);
comment on table impostazione is 'Impostazioni del dizionario, ad esempio la lingua in cui sono scritte le note di redazione.';

-- ---------------------------------------------------------------------
--  Indici
-- ---------------------------------------------------------------------
create index lessema_lingua_idx      on lessema (lingua);
create index lessema_lemma_trgm      on lessema using gin (lemma_norm gin_trgm_ops);
create index lessema_translit_trgm   on lessema using gin (translit_norm gin_trgm_ops);
create index accezione_lessema_idx   on accezione (lessema_id);
create index relazione_etimo_idx     on relazione (etimo_id);
create index relazione_esito_idx     on relazione (esito_id);
create index relazione_ipotesi_idx   on relazione (ipotesi_id);
create index attestazione_lessema_idx on attestazione (lessema_id);
create index attestazione_periodo_idx on attestazione using gist (periodo);
create index connessione_da_idx      on connessione (da_id);
create index connessione_a_idx       on connessione (a_id);
create index rimando_opera_idx       on rimando (opera_id);
create index rimando_ipotesi_idx     on rimando (ipotesi_id)      where ipotesi_id      is not null;
create index rimando_relazione_idx   on rimando (relazione_id)    where relazione_id    is not null;
create index rimando_attest_idx      on rimando (attestazione_id) where attestazione_id is not null;
create index storico_record_idx      on storico (tabella, record_id);
create index glossa_lessema_idx      on glossa (lessema_id);
create unique index lessema_id_esterno on lessema (id_esterno) where id_esterno is not null;
create unique index ipotesi_id_esterno on ipotesi (id_esterno) where id_esterno is not null;
create index relazione_id_esterno_idx on relazione (id_esterno) where id_esterno is not null;

-- ---------------------------------------------------------------------
--  Dichiarazioni di Wiktionary usate per validare i calcoli (v0.4)
-- ---------------------------------------------------------------------
create table wiktionary_doppione (
  a_id  bigint not null references lessema on delete cascade,
  b_id  bigint not null references lessema on delete cascade,
  primary key (a_id, b_id),
  check (a_id < b_id)
);
comment on table wiktionary_doppione is 'Allotropi dichiarati da Wiktionary (template doublet): servono a misurare quelli calcolati.';
create table wiktionary_radice (
  lessema_id  bigint not null references lessema on delete cascade,
  radice_id   bigint not null references lessema on delete cascade,
  primary key (lessema_id, radice_id)
);
comment on table wiktionary_radice is 'Radici dichiarate da Wiktionary (template root): servono a misurare quanto le catene arrivano alla radice.';
create index glossa_testo_trgm       on glossa using gin (norm(testo) gin_trgm_ops);
create index lessema_glossa_trgm     on lessema using gin (norm(glossa) gin_trgm_ops);
create index lessema_indice          on lessema (lingua, nome_proprio, chiave_indice) include (stato_editoriale);

-- Informazioni sul database stesso: la versione del pacchetto dati importato (vedi scripts/inizializza-db.mjs)
create table if not exists meta (
  chiave        text primary key,
  valore        text not null,
  aggiornato_il timestamptz not null default now()
);
