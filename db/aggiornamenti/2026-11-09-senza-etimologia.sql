-- 9 novembre 2026: la lista di lavoro «senza-etimologia». Le parole italiane d'uso comune (le prime 30.000 del lessico
-- di frequenza) che non hanno nessuna ipotesi: né Wiktionary né il Wikizionario ne danno un'etimologia che il dizionario
-- sappia leggere (referto). L'analisi di un testo le riconosce ma le mette «senza origine». Restano fuori le forme di un
-- altro lemma (sono, ha, dalla) e gli omografi di una parola che l'etimologia ce l'ha già (mi, la nota). Si ricalcola a ogni deploy: una parola che riceve un'etimologia esce dalla lista
-- da sola. Ripetibile senza danni.
delete from lista_lavoro where lista = 'senza-etimologia';
insert into lista_lavoro (lista, posizione, lessema_id, gruppo, suggerimento)
select 'senza-etimologia', row_number() over (order by y.rango, y.lemma), y.id, 'Parola comune senza etimologia',
       'Wiktionary e il Wikizionario non ne danno un''etimologia leggibile: cercarla nelle fonti (DELI, Nocentini, Vocabolario Treccani) e scriverla con la sua fonte.'
  from (select l.id, l.lemma, min(f.rango) as rango
          from lessema l join frequenza f on f.lingua = 'it' and f.forma = l.lemma
         where l.lingua = 'it' and not l.ricostruito and l.lemma = lower(l.lemma) and f.rango <= 30000
           and not exists (select 1 from ipotesi h where h.esito_id = l.id)
           -- non le forme di un altro lemma (sono: essere; ha: avere; dalla: da + la), e non gli omografi di una parola che
           -- l'etimologia ce l'ha già (mi, la nota, accanto al pronome mi)
           and not exists (select 1 from forma_lemma fl where fl.lingua = 'it' and fl.forma = l.lemma)
           and not exists (select 1 from lessema o join ipotesi h on h.esito_id = o.id and h.stato = 'accolta'
                            where o.lingua = 'it' and o.lemma = l.lemma and o.id <> l.id)
         group by l.id, l.lemma) y;
