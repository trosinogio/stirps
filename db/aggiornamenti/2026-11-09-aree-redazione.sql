-- 9 novembre 2026: la redazione rivede le aree di significato delle radici. imposta_area_radice() (stesso testo di
-- db/02_logica.sql) e la lista di lavoro «aree-da-rivedere»: un campione fisso di cinque radici per area, scelte a
-- caso ma sempre le stesse (in ordine di md5 dell'indirizzo), per misurare quante aree di Claude la redazione conferma.
-- Si ricalcola a ogni deploy; le radici già riviste restano nel campione, con il loro stato. Ripetibile senza danni.

-- L'area di significato di una radice scelta dalla redazione (editor, sezione «Area di significato»): confermare l'area
-- di Claude o sceglierne un'altra la rende della redazione, e l'import non la tocca più. area_radice non ha un id: la
-- modifica entra nello storico con l'id della voce. Si tolgono solo con la voce: senza area, l'import rimetterebbe
-- quella di Claude.
create or replace function imposta_area_radice(p_lessema bigint, p_area text) returns boolean
language plpgsql as $$
declare
  v_prima jsonb;
  v_dopo jsonb;
begin
  if not exists (select 1 from lessema where id = p_lessema and ricostruito) then
    raise exception 'un''area di significato ce l''hanno solo le forme ricostruite' using errcode = 'P0001';
  end if;
  select to_jsonb(a) into v_prima from area_radice a where a.lessema_id = p_lessema;
  insert into area_radice (lessema_id, area, provenienza, modello) values (p_lessema, p_area, 'redazione', null)
  on conflict (lessema_id) do update set area = excluded.area, provenienza = 'redazione', modello = null;
  select to_jsonb(a) into v_dopo from area_radice a where a.lessema_id = p_lessema;
  if v_prima is distinct from v_dopo then
    insert into storico (tabella, record_id, operazione, prima, dopo)
    values ('area_radice', p_lessema, case when v_prima is null then 'I' else 'U' end, v_prima, v_dopo);
    return true;
  end if;
  return false;
end $$;
comment on function imposta_area_radice(bigint, text) is
  'L’area di una radice scelta o confermata dalla redazione: provenienza redazione, con la riga prima e dopo nello storico.';

delete from lista_lavoro where lista = 'aree-da-rivedere';
insert into lista_lavoro (lista, posizione, lessema_id, gruppo, suggerimento)
select 'aree-da-rivedere', row_number() over (order by s.ordine, s.n), s.lessema_id, s.nome,
       case when s.provenienza = 'redazione' then 'Area già rivista dalla redazione.'
            else 'Area proposta da Claude: ' || s.nome || '. Confermala o scegline un''altra nella sezione «Area di significato».' end
  from (select a.lessema_id, a.provenienza, g.ordine, g.it as nome,
               row_number() over (partition by a.area order by md5(l.slug)) as n
          from area_radice a join lessema l on l.id = a.lessema_id join area_semantica g on g.codice = a.area) s
 where s.n <= 5;
