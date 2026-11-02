-- 2 novembre 2026: lo stemma più pulito. nodo_json() dice se una voce è un nome proprio, così lo stemma può
-- nasconderli finché il lettore non chiede di vederli. Funzione copiata da db/02_logica.sql. Ripetibile senza danni.

create or replace function nodo_json(p_id bigint, p_lingua text default 'it', p_anteprima boolean default false) returns jsonb
language sql stable as $$
  select jsonb_build_object('id', x.id, 'slug', x.slug, 'lingua', x.lingua,
           'lingua_nome', coalesce(etichetta_in('lingua', x.lingua, p_lingua), g.nome),
           'lingua_sigla', coalesce(etichetta_in('lingua', x.lingua, p_lingua, 'breve'), g.sigla),
           'ramo', g.ramo, 'lemma', x.lemma, 'ricostruito', x.ricostruito, 'translit', x.translit,
           'nome_proprio', x.nome_proprio,      -- lo stemma nasconde i nomi propri, se non si chiede di vederli
           'glossa', coalesce(t.testo, x.glossa),
           'glossa_lingua', case when t.testo is not null then t.lingua else x.glossa_lingua end,
           'glossa_automatica', coalesce(t.provenienza in ('traduzione-automatica', 'claude') and t.stato_editoriale = 'importato', false))
  from lessema x
  join lingua g on g.codice = x.lingua
  left join glossa t on t.lessema_id = x.id and t.accezione_id is null and t.lingua = p_lingua
                    and visibile(t.stato_editoriale, p_anteprima)
  where x.id = p_id
$$;
