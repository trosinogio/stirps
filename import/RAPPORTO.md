# Rapporto sull’import da Wiktionary e dal Wikizionario: italiano, con chiusura su latino e francese antico (ottobre 2026)

## In sintesi

| | |
|---|---|
| voci del dump italiano di Kaikki | 624.122 |
| lemmi italiani con un’etimologia strutturata | 71.385 |
| voci latine e del francese antico usate per chiudere le catene | 4.116 |
| lessemi nel dizionario dopo l’import | 101.455, in 268 lingue |
| archi importati | 74.032 |
| ipotesi importate | 73.579: 71.718 accolte, 1.861 alternative |
| famiglie | 24.457: 1.863 radici, 22.594 capostipiti provvisori |
| allotropi calcolati | 822 |
| glosse italiane dal Wikizionario | 39.417: 34.566 parole italiane, 4.851 etimi |
| prime attestazioni | 231, secondo Wiktionary |
| tempo complessivo | circa quattro minuti, download compreso |
| dimensione del database | 173 MB |

## Che cosa è entrato

| tipo di arco | archi |
|---|---|
| derivazione e composizione | 44.400 |
| legami indeterminati | 14.427 |
| prestiti | 6.892 |
| eredità | 5.402 |
| prestiti dotti | 2.392 |
| calchi, accorciamenti, semidotti, retroformazioni, deonimici | 519 |

Due terzi dell’etimologia italiana di Wiktionary sono formazioni interne (*carnivoro* < *carne*, *centavo* < *cento*). Per un dizionario per radici è una ricchezza: le famiglie crescono da sole sotto le loro radici.

Le famiglie più ampie sono radici indoeuropee:
- \*dʰeh₁- (289 parole): \*dʰh₁-m-eló-m > \*fameliā > *familia* > *famiglia* > *capofamiglia*;
- \*h₂yew- (196);
- \*ǵenh₁- (189);
- \*bʰeydʰ- (141);
- \*h₃reǵ- (127): *rex*, *rectus*, *rogus*, *rettangolo*.

## La chiusura delle catene

Una voce italiana spiega bene da dove viene la parola italiana. Il legame tra un antenato e l’altro, però, lo descrive davvero solo la voce dell’antenato. La seconda fase legge quindi anche le voci latine, del latino volgare ricostruito e del francese antico, per i lessemi già presenti nel dizionario.

| a parità di parser | solo italiano | con chiusura |
|---|---|---|
| parole italiane che risalgono a una radice indoeuropea | 5.674 | 10.150 |
| di cui senza legami indeterminati | 1.935 | 3.603 |
| capostipiti provvisori | 24.415 | 22.594 |
| allotropi calcolati | 748 | 822 |

**Una correzione.** Avevo previsto che le voci latine avrebbero fatto incontrare *burro* e *butirro*: era sbagliato. Il tratto mancante era *bure* < *butyrum*, scritto con un `der` nella voce italiana. L’eredità la dichiara solo la voce del francese antico *bure*. Per questo la chiusura comprende anche il francese antico, 362 lessemi; con quello *burro* e *butirro* risultano allotropi.

Il latino di Wiktionary è più povero del previsto: solo 10.068 dei suoi 54.627 lemmi hanno un’etimologia con template. Le voci chiuse sono state 4.116, circa il 30% dei lessemi intermedi. Il resto è prosa, o etimologia assente.

## Glosse italiane e prime attestazioni

Le glosse di Wiktionary sono inglesi, e per un dizionario italiano erano il difetto più visibile. Il Wikizionario, estratto anch’esso da Kaikki, dà definizioni scritte in italiano. Le glosse entrano come traduzioni, con la loro provenienza, e la voce cita il Wikizionario tra le fonti.

| | con glossa italiana |
|---|---|
| parole italiane | 34.600 su 73.069 (47%) |
| parole ereditate dal latino | 2.998 su 4.133 (73%) |
| prestiti, anche dotti | 5.093 su 8.836 (58%) |
| etimi in altre lingue | 4.975 su 28.386, tra cui 2.833 latini e 953 greci |

Il limite è la fonte, non le regole. Il 49% delle parole italiane manca nel Wikizionario: per lo più derivati rari (*carnesecca*, *sottofamiglia*) e nomi propri. Assegnazioni ambigue e parti del discorso diverse valgono insieme circa 2.400 casi, lasciati senza glossa piuttosto che con una glossa indovinata. Due omografi con la stessa parte del discorso, come *torta* e *torta*², restano senza. La ricerca per significato ora funziona anche in italiano: «ghiandola» trova *acne*, *adenite*, *amigdala*.

Le date sono la parte povera: Wiktionary ne fornisce 231 per tutto l’italiano, 181 con il template `etydate` e 50 nella prosa («First attested in 1590»). Entrano come attestazioni lessicografiche, con la precisione dichiarata, e la voce le presenta «secondo Wiktionary». Le datazioni sistematiche stanno nei dizionari storici come il DELI e il TLIO, che non hanno licenza libera: la linea del tempo è lavoro di redazione.

## Quanto ci si può fidare

Il confronto con quello che Wiktionary dichiara esplicitamente:

- **radici:** 1.246 delle 1.453 dichiarate sono raggiunte dalle catene, cioè l’86%. Il dato è sceso rispetto a una versione intermedia (91%) per due correzioni volute. Non si attacca più una radice sotto un’altra, e i 76 casi in conflitto non vengono forzati. Le radici omografe sono distinte, quindi una catena che arriva al nodo generico di \*(s)ker- non conta come arrivata a \*(s)ker- «tagliare».
- **allotropi:** 279 dei 971 dichiarati sono trovati anche dal calcolo. Gli altri si fermano prima dell’antenato comune perché la catena è troppo corta.

Su un campione di allotropi calcolati ma non dichiarati più di quattro su cinque sono veri, e molti sono classici: *retto*/*ritto*, *lasciare*/*lassare*, *libagione*/*libazione*, *ghiaia*/*ghiara*, *gruppo*/*groppo*, *cresima*/*crisma*, *albicocca*/*bricoccola*. Gli errori residui sono omografi latini citati senza indicazioni e catene imprecise di Wiktionary.

Le anomalie restano a disposizione della redazione in `v_anomalie`:
- **1.261 formazioni tra lingue:** radici indoeuropee collegate direttamente a parole latine;
- **477 indirizzi con caratteri non latini:** mancano le traslitterazioni;
- **191 ipotesi incoerenti:** origine «onomatopea» ma con archi.

## Le decisioni di metodo, e da dove vengono

Ogni regola dell’importatore nasce da un errore trovato nei dati.

**Prima fase, italiano**
- **Un `der` è un legame indeterminato.** Trattato come trasmissione, raddoppiava gli allotropi calcolati, ma metà dei nuovi erano falsi (*luminescenza*/*luminista*).
- **I periodi del latino sono la stessa voce:** così compare *posare*/*pausare*.
- **Una forma senza pagina è comunque un termine.** In `{{inh|it|la-vul||*terraceus}}` saltarla dava *terrazzo* < *terra* per eredità.
- **Un affisso non è un etimo:** 348 casi.
- **Tra due spiegazioni vince la più vicina:** *rēx* < \*rēks, non direttamente \*h₃rḗǵs.
- **Un difetto dello schema emerso solo a scala.** Senza parte del discorso `pos = 'rad.'` vale NULL, e 23 mila capostipiti restavano senza classe.

**Seconda fase, chiusura**
- **Solo le forme di citazione sono la parola.** Ricondurre ogni forma flessa al suo lemma faceva di *aprire*/*aperto* e *forte*/*fortissimo* due allotropi. Ora participi e superlativi derivano dalla base (519 casi) e le altre forme si legano al lemma con un legame indeterminato (187).
- **L’indice dei lemmi deve essere completo.** Contenendo solo i lemmi con etimologia, *pugnō* risultava «dativo di *pugnus*» e *pugnare* finiva sotto il nome.
- **Gli omografi si distinguono con l’infinito.** I due *fundō* hanno la stessa prima persona; le citazioni (*fundere*, *fundāre*) li separano. Distinti: 638.
- **La catena si ferma agli elementi.** La voce *consuetus* spiega gli elementi del composto uno per uno; letta come una catena unica, ne usciva \*ḱóm «con» come derivato di \*swe-dʰh₁-sk-. Fermate: 48.
- **Una radice non discende da un’altra radice.** Le radici dichiarate in conflitto con la cima della catena non si applicano: 76.
- **Radici omografe distinte.** \*(s)ker-, \*men-, \*bʰel- e altre 20 radici hanno più identificativi; ne nascono 69 nodi distinti.
- **Più forme in un template.** «ἀββα,ἀββᾶς» non è una parola sola: 40 casi.

## Che cosa cambia nell’app

- **Prestazioni:** l’indice della pagina iniziale era salito a 44 secondi. Con le famiglie precalcolate (`mv_famiglia`) torna a 0,4 secondi; una voce si compone in 20–40 ms, la ricerca in 6 ms.
- **Nuove pagine:** l’elenco completo delle radici, a pagine, e le parole di una lingua per iniziale.
- **Stemma:** le colonne sono larghe quanto serve alla loro generazione e la radice sta in testa. La famiglia più grande si disegna senza errori.
- **Fonte delle ipotesi importate:** «Fonte: Wiktionary (CC BY-SA 4.0)», con la nota originale marcata «in inglese».

## Prossimi passi

1. **Estendere la chiusura.** Greco antico (3.189 lessemi presenti) e lingue romanze: lo strumento è pronto, basta aggiungerle a `CHIUSURA`.
2. **Le glosse che mancano.** Circa 38 mila parole italiane hanno ancora la sola glossa inglese. Si può procedere per priorità, con una traduzione assistita dichiarata come tale, oppure attendere che il Wikizionario cresca: l’import si rilancia.
3. **Coda della redazione.** Le 1.861 ipotesi alternative, le 195 citazioni di radici omografe da smistare, le traslitterazioni mancanti, le datazioni: un’interfaccia che le presenti in ordine di importanza.
