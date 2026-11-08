-- 31 ottobre 2026: la lista di lavoro «catene-da-sistemare». Raccoglie le parole italiane la cui catena accolta va
-- subito a una radice ricostruita, senza tappe: segno che l'etimologia di Wiktionary è stata letta solo in parte.
-- Si ricalcola dai dati a ogni deploy, quindi una catena sistemata esce dalla lista da sola. Ripetibile senza danni.
create table if not exists lista_lavoro (
  lista text not null, posizione int not null, lessema_id bigint not null references lessema on delete cascade,
  gruppo text not null, suggerimento text, primary key (lista, lessema_id), unique (lista, posizione)
);
delete from lista_lavoro where lista = 'catene-da-sistemare';
insert into lista_lavoro (lista, posizione, lessema_id, gruppo, suggerimento)
select 'catene-da-sistemare', row_number() over (order by y.rango nulls last, y.lemma), y.id,
       case when y.dichiarata then 'Solo la radice dichiarata' else 'Salta alla radice' end,
       'La catena va dalla parola a una radice ricostruita, senza tappe: ricostruirle dalle fonti (latino, greco, germanico…).'
  from (
    select l.id, l.lemma, bool_or(h.etichetta like '%radice%') as dichiarata,
           (select min(f.rango) from frequenza f where f.lingua = 'it' and f.forma = l.lemma) as rango
      from lessema l
      join ipotesi h on h.esito_id = l.id and h.stato = 'accolta' and h.stato_editoriale = 'importato'
      join relazione x on x.ipotesi_id = h.id
      join lessema e on e.id = x.etimo_id
     where l.lingua = 'it'
     group by l.id, l.lemma
    having bool_and(x.tipo = 'generico' and e.ricostruito and e.lemma like '%-')   -- una radice (*sek-), non una forma (*wardōn)
  ) y;

-- 7 novembre 2026: secondo gruppo, «Passaggio sospetto». Le parole italiane d'uso comune (le prime 30.000 per frequenza)
-- la cui catena accolta passa per un legame indeterminato tra due parole della stessa lingua che non hanno nemmeno un
-- trigramma in comune, fuori dai composti: τύρρις «torre» < φιλία «amicizia» portava torre nella famiglia di φίλος.
-- Quasi sempre è un confronto letto come origine. Una parola già nel primo gruppo non si ripete.
insert into lista_lavoro (lista, posizione, lessema_id, gruppo, suggerimento)
with recursive
comuni as (
  select l.id, min(f.rango) as rango, l.lemma
    from lessema l join frequenza f on f.lingua = 'it' and f.forma = l.lemma
   where l.lingua = 'it' and f.rango <= 30000
   group by l.id, l.lemma),
su (parola, id, prof) as (
  select c.id, c.id, 0 from comuni c
  union
  select s.parola, x.etimo_id, s.prof + 1
    from su s join ipotesi h on h.esito_id = s.id and h.stato = 'accolta'
    join relazione x on x.ipotesi_id = h.id
   where s.prof < 12),
sospetti as (
  select distinct s.parola, e.lemma as etimo, l.lemma as esito
    from su s
    join ipotesi h on h.esito_id = s.id and h.stato = 'accolta' and h.stato_editoriale = 'importato'
    join relazione x on x.ipotesi_id = h.id and x.tipo = 'generico'   -- non le derivazioni: occupo < capio, θέμα < τίθημι sono giuste
    join lessema l on l.id = x.esito_id
    join lessema e on e.id = x.etimo_id and e.lingua = l.lingua and not e.ricostruito and not l.ricostruito
   where (select count(*) from relazione y where y.ipotesi_id = h.id) = 1
     and similarity(l.lemma_norm, e.lemma_norm) = 0
     -- non le parole corte (invio < via), i nomi (Lola < Dolores), le radici semitiche scritte a lettere (أمير < ء م ر)
     and length(l.lemma_norm) >= 4 and length(e.lemma_norm) >= 4
     and not l.nome_proprio and not e.nome_proprio and e.lemma !~ '[ ־]')
select 'catene-da-sistemare', coalesce((select max(posizione) from lista_lavoro where lista = 'catene-da-sistemare'), 0)
         + row_number() over (order by c.rango, c.lemma), c.id, 'Passaggio sospetto',
       'Nella catena ' || min(z.esito) || ' < ' || min(z.etimo) || ' non hanno niente in comune: controllare sulle fonti se è un etimo o un confronto.'
  from sospetti z join comuni c on c.id = z.parola
 group by c.id, c.rango, c.lemma
on conflict do nothing;

-- 7 novembre 2026: terzo gruppo, «Radice diversa da quella dichiarata». Le parole italiane che dichiarano la loro radice in
-- Wiktionary (wiktionary_radice) e la cui catena, per i primi etimi, arriva a un'altra radice: otre arrivava a *kʷ- invece
-- di *wed-, fusse a *h₁es- invece di *bʰuH-. Tra queste ci sono anche varianti di notazione della stessa radice (*h₂eh₁s- e
-- *h₂eHs-) e composti con due radici: il suggerimento mostra le due radici, e chi controlla decide.
insert into lista_lavoro (lista, posizione, lessema_id, gruppo, suggerimento)
with recursive
dich as (
  select w.lessema_id, r.id as rid, r.lemma as rlemma
    from wiktionary_radice w join lessema r on r.id = w.radice_id join lessema l on l.id = w.lessema_id
   where l.lingua = 'it'),
su (parola, id, prof) as (
  select distinct lessema_id, lessema_id, 0 from dich
  union
  select s.parola, x.etimo_id, s.prof + 1
    from su s join ipotesi h on h.esito_id = s.id and h.stato = 'accolta'
    join relazione x on x.ipotesi_id = h.id and x.ordine = 1
   where s.prof < 15),
cima as (select distinct on (parola) parola, id from su order by parola, prof desc)
select 'catene-da-sistemare', coalesce((select max(posizione) from lista_lavoro where lista = 'catene-da-sistemare'), 0)
         + row_number() over (order by min(l.lemma)), k.parola, 'Radice diversa da quella dichiarata',
       'La catena arriva a *' || min(c.lemma) || ', Wiktionary dichiara *' || string_agg(distinct d.rlemma, ', *')
         || ': un errore, una variante di notazione o un composto con due radici.'
  from cima k join lessema l on l.id = k.parola join lessema c on c.id = k.id
  join dich d on d.lessema_id = k.parola
 where c.ricostruito and c.lemma like '%-'
   and not exists (select 1 from dich d2 where d2.lessema_id = k.parola and (d2.rid = k.id or d2.rlemma = c.lemma))
   and not exists (select 1 from su s2 join dich d3 on d3.lessema_id = s2.parola and d3.rid = s2.id where s2.parola = k.parola)
 group by k.parola
on conflict do nothing;

-- 7 novembre 2026: quarto gruppo, «Wiktionary e Wikizionario discordano» (la regola dei due Wiktionary). Le parole italiane
-- la cui etimologia di Wiktionary inglese, accolta e intatta, ha accanto un'alternativa del Wikizionario che dà un'altra
-- origine (import/confronta_wikizionario.py): destinatario dal latino destinatarius o dal francese destinataire.
-- 9 novembre: lo stesso per le parole francesi e il Wiktionnaire, gruppo «Wiktionary e Wiktionnaire discordano».
insert into lista_lavoro (lista, posizione, lessema_id, gruppo, suggerimento)
select 'catene-da-sistemare', coalesce((select max(posizione) from lista_lavoro where lista = 'catene-da-sistemare'), 0)
         + row_number() over (order by y.lingua desc, y.rango nulls last, y.lemma), y.id,
       'Wiktionary e ' || y.fonte || ' discordano',
       'Wiktionary: ' || coalesce(y.wikt, '?') || '; ' || y.fonte || ': ' || coalesce(y.wiz, '?')
         || '. Controllare sulle fonti quale origine accogliere.'
  from (
    select distinct on (l.id) l.id, l.lemma, l.lingua,
           case w.provenienza when 'wiktionnaire' then 'Wiktionnaire' else 'Wikizionario' end as fonte,
           (select min(f.rango) from frequenza f where f.lingua = l.lingua and f.forma = l.lemma) as rango,
           (select string_agg(g.nome || ' ' || e.lemma, ' + ' order by x.ordine)
              from relazione x join lessema e on e.id = x.etimo_id join lingua g on g.codice = e.lingua
             where x.ipotesi_id = a.id) as wikt,
           (select string_agg(g.nome || ' ' || e.lemma, ' + ' order by x.ordine)
              from relazione x join lessema e on e.id = x.etimo_id join lingua g on g.codice = e.lingua
             where x.ipotesi_id = w.id) as wiz
      from lessema l
      join ipotesi a on a.esito_id = l.id and a.stato = 'accolta' and a.provenienza = 'wiktionary'
                    and a.stato_editoriale = 'importato'
      join ipotesi w on w.esito_id = l.id and w.stato = 'alternativa' and w.provenienza in ('wikizionario', 'wiktionnaire')
                    and w.stato_editoriale = 'importato'
     where (l.lingua = 'it' and w.provenienza = 'wikizionario') or (l.lingua = 'fr' and w.provenienza = 'wiktionnaire')
     order by l.id, w.id
  ) y
on conflict do nothing;
