-- 6 novembre 2026: la riga delle forme e le accezioni di ogni voce, da Wiktionary, per la scheda della voce. La tabella,
-- quella d'appoggio e la funzione dell'import: stesso testo di db/01_schema.sql e db/05_import_wiktionary.sql.
-- Ripetibile senza danni.

-- La riga delle forme e le accezioni della voce, da Wiktionary: l'espansione del modello di intestazione («carō f
-- (genitive carnis); third declension») e fino a otto accezioni con le etichette d'uso e l'ambito. Una riga per voce.
create table if not exists sensi (
  lessema_id        bigint primary key references lessema on delete cascade,
  testa             text,                                  -- carō f (genitive carnis); third declension
  sensi             jsonb not null default '[]',           -- [["flesh, meat", ""], ["the body", "figuratively"], …]
  provenienza       text not null default 'wiktionary'
);
comment on table sensi is 'Riga delle forme e accezioni della voce da Wiktionary (CC BY-SA), con le etichette d''uso.';

create unlogged table if not exists stg_sensi (chiave text, dati text);   -- sensi.tsv: chiave, JSON

-- La riga delle forme e le accezioni, per differenza, come le pronunce: quelle della redazione non si toccano.
create or replace function importa_sensi() returns jsonb
language plpgsql as $$
declare
  nuove int;
  cambiate int;
  tolte int;
begin
  perform set_config('app.import', 'on', true);
  create temp table cand_se on commit drop as
    select distinct on (l.id) l.id, s.dati::jsonb ->> 't' as testa, coalesce(s.dati::jsonb -> 's', '[]'::jsonb) as sensi
      from stg_sensi s join lessema l on l.id_esterno = s.chiave
     where s.dati is not null and s.dati <> ''
     order by l.id;
  create index on cand_se (id);
  analyze cand_se;
  delete from sensi x
   where x.provenienza = 'wiktionary' and not exists (select 1 from cand_se c where c.id = x.lessema_id);
  get diagnostics tolte = row_count;
  update sensi x set testa = c.testa, sensi = c.sensi
    from cand_se c
   where c.id = x.lessema_id and x.provenienza = 'wiktionary' and (x.testa, x.sensi) is distinct from (c.testa, c.sensi);
  get diagnostics cambiate = row_count;
  insert into sensi (lessema_id, testa, sensi)
  select id, testa, sensi from cand_se
  on conflict (lessema_id) do nothing;
  get diagnostics nuove = row_count;
  return jsonb_build_object('nuove', nuove, 'cambiate', cambiate, 'tolte', tolte);
end $$;
comment on function importa_sensi() is 'Riga delle forme e accezioni di Wiktionary per differenza; quelle della redazione non si toccano.';
