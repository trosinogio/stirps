// Il logotipo: il segno di radice con la barra (vinculum) stesa sopra il nome, √‾stirps.
// Il segno è un tracciato SVG alto quanto il nome: la sua punta tocca la linea superiore a ogni dimensione.
export default function Marchio({ grande = false, nome }: { grande?: boolean; nome: string }) {
  return (
    <span className={grande ? 'logotipo logotipo-grande' : 'logotipo'} role="img" aria-label={nome}>
      <svg className="logotipo-radice" viewBox="0 0 40 100" preserveAspectRatio="none" aria-hidden="true">
        <path d="M1 60 L10 53 L22 96 L39 1" />
      </svg>
      <span className="logotipo-nome" aria-hidden="true">{nome.toLowerCase()}</span>
    </span>
  );
}
