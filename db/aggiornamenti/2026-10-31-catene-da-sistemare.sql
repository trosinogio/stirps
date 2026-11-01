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
