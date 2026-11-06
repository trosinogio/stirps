-- 6 novembre 2026: la pronuncia di ogni voce, da Wiktionary (IPA con la varietà, sillabazione, audio di Wikimedia
-- Commons). La tabella, quella d'appoggio e la funzione dell'import: stesso testo di db/01_schema.sql e
-- db/05_import_wiktionary.sql. Ripetibile senza danni.

-- La pronuncia della voce, da Wiktionary: le trascrizioni IPA con la loro varietà (latino classico ed ecclesiastico,
-- inglese britannico e americano…), la sillabazione, un file audio di Wikimedia Commons. Una riga per voce.
create table if not exists pronuncia (
  lessema_id        bigint primary key references lessema on delete cascade,
  ipa               jsonb not null default '[]',           -- [["/ˈka.roː/", "Classical-Latin"], …]
  sillabazione      text,                                  -- ca‧ro
  audio             text,                                  -- nome del file su Wikimedia Commons
  provenienza       text not null default 'wiktionary'
);
comment on table pronuncia is 'Pronuncia della voce da Wiktionary (CC BY-SA): IPA con la varietà, sillabazione, audio di Wikimedia Commons.';

create unlogged table if not exists stg_pronuncia (chiave text, dati text);   -- pronunce.tsv: chiave, JSON

-- La pronuncia, per differenza: si scrive solo ciò che cambia, e si tolgono le pronunce di Wiktionary di voci che non
-- ne hanno più. Una pronuncia della redazione (provenienza diversa) non si tocca.
create or replace function importa_pronunce() returns jsonb
language plpgsql as $$
declare
  nuove int;
  cambiate int;
  tolte int;
begin
  perform set_config('app.import', 'on', true);
  create temp table cand_pr on commit drop as
    select distinct on (l.id) l.id, coalesce(s.dati::jsonb -> 'i', '[]'::jsonb) as ipa, s.dati::jsonb ->> 's' as sill,
           s.dati::jsonb ->> 'a' as audio
      from stg_pronuncia s join lessema l on l.id_esterno = s.chiave
     where s.dati is not null and s.dati <> ''
     order by l.id;
  create index on cand_pr (id);
  analyze cand_pr;
  delete from pronuncia p
   where p.provenienza = 'wiktionary' and not exists (select 1 from cand_pr c where c.id = p.lessema_id);
  get diagnostics tolte = row_count;
  update pronuncia p set ipa = c.ipa, sillabazione = c.sill, audio = c.audio
    from cand_pr c
   where c.id = p.lessema_id and p.provenienza = 'wiktionary'
     and (p.ipa, p.sillabazione, p.audio) is distinct from (c.ipa, c.sill, c.audio);
  get diagnostics cambiate = row_count;
  insert into pronuncia (lessema_id, ipa, sillabazione, audio)
  select id, ipa, sill, audio from cand_pr
  on conflict (lessema_id) do nothing;
  get diagnostics nuove = row_count;
  return jsonb_build_object('nuove', nuove, 'cambiate', cambiate, 'tolte', tolte);
end $$;
comment on function importa_pronunce() is 'Pronunce di Wiktionary per differenza (IPA, sillabazione, audio); quelle della redazione non si toccano.';
