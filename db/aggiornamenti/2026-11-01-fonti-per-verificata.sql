-- 1° novembre 2026: quante fonti per «verificata» (norme redazionali, questione decisa il 1° novembre).
-- Un'ipotesi verificata ha almeno un'opera della bibliografia che la propone o la accoglie, e due se la certezza è 4;
-- le opere in rete (Wiktionary, Wikizionario, Etymonline, Logeion) non contano. Prima bastava un rimando qualsiasi,
-- anche di un'opera che discute o respinge. Il controllo scatta anche quando cambiano la certezza di un'ipotesi
-- verificata o la posizione e l'opera di una sua fonte. Le ipotesi già verificate non si ricontrollano finché
-- nessuno le tocca. Stesso testo di db/02_logica.sql. Ripetibile senza danni.

create or replace function opere_a_sostegno(p_ipotesi bigint) returns int language sql stable as $$
  select count(distinct r.opera_id)::int
    from rimando r join opera o on o.id = r.opera_id
   where o.tipo <> 'in_rete' and r.posizione in ('propone', 'accoglie')
     and (r.ipotesi_id = p_ipotesi
          or r.relazione_id in (select x.id from relazione x where x.ipotesi_id = p_ipotesi))
$$;
comment on function opere_a_sostegno(bigint) is
  'Opere della bibliografia, non in rete, che propongono o accolgono l''ipotesi (anche su un suo passaggio).';

create or replace function controlla_ipotesi_verificata() returns trigger language plpgsql as $$
declare v_ip bigint; v_etichetta text; v_certezza smallint; v_opere int;
begin
  if tg_table_name = 'ipotesi' then
    v_ip := new.id;
  else
    v_ip := coalesce(old.ipotesi_id, (select ipotesi_id from relazione where id = old.relazione_id));
  end if;
  select h.etichetta, h.confidenza into v_etichetta, v_certezza
    from ipotesi h where h.id = v_ip and h.stato_editoriale = 'verificato';
  if not found then return null; end if;
  v_opere := opere_a_sostegno(v_ip);
  if v_opere = 0 then
    raise exception 'ipotesi % «%»: un''ipotesi verificata deve citare almeno un''opera che la proponga o la accolga',
      v_ip, v_etichetta using errcode = 'check_violation';
  elsif v_certezza = 4 and v_opere < 2 then
    raise exception 'ipotesi % «%»: la certezza 4 chiede due opere che propongano o accolgano l''ipotesi',
      v_ip, v_etichetta using errcode = 'check_violation';
  end if;
  return null;
end $$;

drop trigger if exists ipotesi_verificata_con_fonte on ipotesi;
create constraint trigger ipotesi_verificata_con_fonte
  after insert or update of stato_editoriale, confidenza on ipotesi
  deferrable initially deferred
  for each row when (new.stato_editoriale = 'verificato')
  execute function controlla_ipotesi_verificata();

drop trigger if exists rimando_ultima_fonte on rimando;
create constraint trigger rimando_ultima_fonte
  after delete or update of ipotesi_id, relazione_id, posizione, opera_id on rimando
  deferrable initially deferred
  for each row execute function controlla_ipotesi_verificata();
