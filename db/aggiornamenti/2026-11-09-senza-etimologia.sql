-- 9 novembre 2026: la lista di lavoro «senza-etimologia». Le parole italiane d'uso comune (le prime 30.000 del lessico
-- di frequenza) che non hanno nessuna ipotesi: né Wiktionary né il Wikizionario ne danno un'etimologia che il dizionario
-- sappia leggere (referto). L'analisi di un testo le riconosce ma le mette «senza origine». Restano fuori le forme di un
-- altro lemma (sono, ha, dalla) e gli omografi di una parola che l'etimologia ce l'ha già (mi, la nota). Una voce per parola (chiamata ne ha due), e le interiezioni (oh, beh) in un gruppo a parte, in fondo:
-- la loro origine è di solito espressiva. Si ricalcola a ogni deploy: una parola che riceve un'etimologia esce dalla lista
-- da sola. Ripetibile senza danni.
delete from lista_lavoro where lista = 'senza-etimologia';
insert into lista_lavoro (lista, posizione, lessema_id, gruppo, suggerimento)
select 'senza-etimologia', row_number() over (order by y.interiezione, y.rango, y.lemma), y.id,
       case when y.interiezione then 'Interiezione senza etimologia' else 'Parola comune senza etimologia' end,
       case when y.interiezione
            then 'Di solito un''origine espressiva o onomatopeica: registrarla come ipotesi, con la fonte che la dà.'
            else 'Wiktionary e il Wikizionario non ne danno un''etimologia leggibile: cercarla nelle fonti (DELI, Nocentini, Vocabolario Treccani) e scriverla con la sua fonte.' end
  from (select distinct on (l.lemma) l.id, l.lemma, coalesce(l.pos, '') like 'inter%' as interiezione,
               (select min(f.rango) from frequenza f where f.lingua = 'it' and f.forma = l.lemma) as rango
          from lessema l
         where l.lingua = 'it' and not l.ricostruito and l.lemma = lower(l.lemma)
           and exists (select 1 from frequenza f where f.lingua = 'it' and f.forma = l.lemma and f.rango <= 30000)
           and not exists (select 1 from ipotesi h where h.esito_id = l.id)
           and not exists (select 1 from forma_lemma fl where fl.lingua = 'it' and fl.forma = l.lemma)
           and not exists (select 1 from lessema o join ipotesi h on h.esito_id = o.id and h.stato = 'accolta'
                            where o.lingua = 'it' and o.lemma = l.lemma and o.id <> l.id)
         order by l.lemma, (l.pos is null), l.id) y;
