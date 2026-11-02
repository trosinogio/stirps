# Prime attestazioni: fonti e strumento di datazione

Progetto del 2 novembre 2026. Fatti la fase 0 e il passo 1 (`datatore_dizionari.py`, `importa_stime()`). La fase 0: la tabella `attestazione` distingue le **stime** (`stima`, `confidenza`) dalle attestazioni verificate, e c'è la tabella `autore` per datare le citazioni dei dizionari. Il resto è da fare.

## Il principio

Una data trovata in automatico non è la prima attestazione. È un **terminus ante quem**: la parola è attestata almeno da quella data, secondo una fonte dichiarata. Nel database è un'attestazione con `stima = true`, la fonte in `banca_dati` e una `confidenza` da 1 a 4. La voce la mostra come «almeno dal 1525». Diventa prima attestazione solo quando la redazione la verifica sulla fonte: una stima non può essere «verificata» (vincolo `attestazione_stima_non_verificata`).

Cosa si data, per lingua:
- **italiano:** l'anno, o il secolo, e il testo;
- **latino e greco:** l'autore e l'opera, con la loro datazione;
- **forme ricostruite:** niente, per definizione.

## Le fonti italiane: che cosa si può estrarre

| fonte | contenuto | accesso | estrazione in massa |
|---|---|---|---|
| DELI, GDLI, Treccani | prime attestazioni datate, le più affidabili | in commercio o in rete gratis (GDLI) | **no**: diritto d'autore e diritto sui database; si consultano e si citano voce per voce |
| TLIO e Corpus OVI dell'italiano antico (CNR) | ~3.500 testi fino al 1400, ~30 milioni di occorrenze, lemmatizzati | consultazione gratuita in rete; nessuna API né scarico in massa | **solo con un accordo** con l'OVI: è la via migliore per le parole antiche |
| Vocabolario della Crusca 1612–1923, Tommaseo-Bellini | citazioni d'autore per voce | consultazione gratuita in rete; nessuna licenza dichiarata | **no**, salvo accordo con l'Accademia della Crusca |
| Google Books Ngram, italiano (versione 2020) | per ogni forma, gli anni in cui compare nei libri, dal Cinquecento | scarico pubblico, CC BY 3.0 | **sì** |
| Wikisource italiano + Wikidata | testi in pubblico dominio, datati attraverso l'opera o l'autore | dump pubblici, CC BY-SA / CC0 | **sì** |
| Wiktionary | `etydate` e citazioni datate | già nel pacchetto | **sì**: poche voci (209 datate oggi) |

Nessuna fonte affidabile per l'italiano si estrae in massa senza un accordo. Per questo serve uno strumento che stimi il terminus ante quem dalle fonti storiche aperte. In parallelo si può proporre all'OVI e alla Crusca di condividere le datazioni.

## Lo strumento: il datatore

Un programma in `import/` che produce un file del pacchetto (`dati/stime.tsv.gz`: voce, anno, precisione, fonte, opera, confidenza). La build lo carica come attestazioni con `stima = true` e uno strato per ogni fonte. Per ogni voce prende la data più antica tra le sue fonti, con la confidenza della fonte che la dà.

**1. Wikisource (prima del 1500 e oltre).**
- Testi del dump italiano.
- Datazione: la data dell'opera da Wikidata (P571, P577); in mancanza, l'autore (morte, o floruit).
- Lemmi: le forme flesse si riconducono al lemma con la mappa forme → lemma di Wiktionary, la stessa del parser.
- Uscita: l'opera più antica che contiene il lemma, per esempio «almeno dal 1321, Dante, *Commedia*».
- Confidenza: 3 con almeno due opere entro cinquant'anni, 2 con una sola, 1 per le forme ambigue.

**2. Google Books Ngram (dal Cinquecento).**
- Si scaricano gli 1-grammi italiani e si tengono solo le forme del dizionario.
- Data: il primo anno *robusto* della forma, cioè con almeno due volumi in quell'anno e presenze in almeno altri due anni entro i 25 anni successivi. Così si scartano gli errori di OCR (la *ſ* letta come *f*) e le date sbagliate dei metadati.
- Precisione: «circa».
- Confidenza: 3 con dieci o più volumi nella finestra, 2 da tre a nove, 1 sotto. Prima del 1600 resta al più 1, salvo un sostegno forte.

**3. Le citazioni dei dizionari (latino e greco), fatto.** `datatore_dizionari.py autori` interroga Wikidata (le proprietà «PHI Latin Texts author ID» e «TLG author ID», cercate per etichetta) e data ogni autore con la morte, o la fine dell'attività, o il floruit, o la nascita più sessant'anni, con la precisione di Wikidata; scarta le date fuori dal 1500 a.C.–1500 d.C. e si ferma se trova meno di cento autori per lingua. `datatore_dizionari.py stime` dà a ogni voce l'autore datato più antico tra le citazioni con l'identificativo dell'opera. `importa_stime()` le assegna solo dove la voce è certa: la voce del dizionario stessa, o un lemma con una sola voce nel dizionario e una sola nella lingua (*caro*, con tre voci nel Lewis & Short, resta senza). La voce mostra «almeno dal 184 a.C. — Plauto, secondo il Lewis & Short», con il link all'opera su Scaife.

In origine:
- Fonti: le voci del Lewis & Short e dell'LSJ nei file TEI del Perseus citano gli autori, spesso con l'identificativo dell'opera (`urn:cts:latinLit:phi0119…`, `Perseus:abo:tlg,0012,001`).
- Datazione degli autori: si passa dagli identificativi PHI e TLG a Wikidata, e il risultato va nella tabella `autore`.
- Data: l'autore più antico citato nella voce, per esempio «almeno da Plauto (III–II sec. a.C.)».
- Confidenza: 3 per gli autori datati con sicurezza, 2 per le datazioni per secolo.
- Per il greco si aggiunge il corpus Diorisis (10 milioni di parole lemmatizzate, da Omero al V secolo d.C., CC BY-SA 4.0).

**Taratura.** Prima di pubblicare, le stime si confrontano con le 209 date di Wiktionary e con un campione di 200 date del DELI controllate dalla redazione (4–6 ore). Si misurano lo scarto mediano e la quota entro ±50 anni. Le soglie si fissano su quei numeri, che vanno nel rapporto del pacchetto e nel Metodo del sito.

**Limiti dichiarati.**
- Un corpus dà la prima occorrenza *nel corpus*, non nella lingua.
- I dizionari citano passi rappresentativi, non sempre il primo.
- Le forme ambigue (*era*, *fine*) vanno escluse o abbassate di confidenza.
- La lemmatizzazione automatica sbaglia nel 5–10% dei casi.

## Il lavoro, in ordine

| passo | che cosa | lavoro (sessioni) | altro |
|---|---|---|---|
| fase 0 | colonne `stima` e `confidenza`, tabella `autore`, la voce mostra «almeno dal …» | fatto | – |
| 1 | citazioni del Lewis & Short e dell'LSJ, autori datati con Wikidata (`datatore_dizionari.py`, `importa_stime()`) | fatto | revisione dei ~300 autori più citati (10–15 h di redazione) |
| 2 | Wikisource: italiano antico e moderno | 2 | ~1 h di workflow |
| 3 | Google Books Ngram: italiano dal Cinquecento | 2 | ~1–2 h di workflow per lo scarico |
| 4 | taratura e pubblicazione | 1 | 4–6 h di redazione |
| parallelo | proposta di accordo all'OVI-CNR e all'Accademia della Crusca | 1 (il testo) | tempi e esito incerti |

Spazio su Neon: circa 50 MB in più per 250 mila stime.
