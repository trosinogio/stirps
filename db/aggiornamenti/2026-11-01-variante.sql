-- 1° novembre 2026: la variante (norme redazionali, questione decisa il 1° novembre). Resta un tipo di passaggio
-- a sé, ma solo per un'altra forma della stessa parola nella stessa lingua: grafica, sincopata, ridotta. Una forma
-- dialettale è una voce del suo dialetto, collegata con eredità o prestito. Cambiano le descrizioni che l'editor
-- mostra, come in db/03_seed_pilota.sql. Ripetibile senza danni.

update tipo_relazione
   set descrizione = 'Forma alternativa della stessa parola nella stessa lingua: grafica, sincopata, ridotta. Una forma dialettale si collega con eredità o prestito.'
 where codice = 'variante';

update etichetta_lingua
   set descrizione = 'Alternative form of the same word in the same language: spelling, syncopated, reduced. A dialect form is linked by inheritance or borrowing.'
 where vocabolario = 'tipo_relazione' and codice = 'variante' and lingua = 'en';
