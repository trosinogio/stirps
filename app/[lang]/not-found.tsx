import Link from 'next/link';

export default function NonTrovato() {
  return (
    <section>
      <h2>Voce non trovata / Entry not found</h2>
      <p className="nota-sez">La parola non è nel dizionario, o non è ancora pubblicata. The word is not in the dictionary, or not yet published.</p>
      <p><Link className="btn" href="/it">Radici</Link> <Link className="btn" href="/en">Roots</Link></p>
    </section>
  );
}
