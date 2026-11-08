-- 8 novembre 2026: la linea del senso tra una parola e il suo etimo (parole_glossa(), legame_di_senso()). Stesso testo di
-- db/02_logica.sql. Ripetibile senza danni.

-- La linea del senso tra una parola e il suo etimo (regola di Giovanni, 8 novembre 2026: «la lezione del tre e del
-- dente»). Due glosse inglesi hanno un legame di senso evidente se condividono una parola piena, o una contiene l'altra
-- (seventh e seven), dopo la stessa riduzione grezza delle desinenze di import/controlla_sensi.py. Misura sul pacchetto
-- dell'8 novembre: 51% degli archi accolti, 0,6% delle coppie a caso. L'assenza di un legame evidente non prova un
-- errore (*h₂ōwyóm «egg» < *h₂éwis «bird» è giusto): serve a far guardare l'arco, mai a toglierlo.
create or replace function parole_glossa(p_glossa text) returns text[]
language sql immutable as $$
  select coalesce(array_agg(distinct regexp_replace(w, '^(.{3,}?)(ingly|edly|ings|ing|ness|ment|ers|ied|ies|est|ed|er|es|ly|s)$', '\1')), '{}')
    from regexp_split_to_table(lower(regexp_replace(coalesce(p_glossa, ''), '\([^)]*\)', ' ', 'g')), '[^a-z]+') w
   where length(w) >= 3 and w <> all ('{a,ablative,about,accusative,act,action,adjective,adverb,all,also,alternative,an,and,another,any,archaic,are,as,at,be,being,belonging,between,by,certain,characteristic,condition,dative,do,does,done,down,e.g,esp,especially,etc,feminine,first,for,form,from,generally,genitive,get,go,got,having,he,her,him,his,i.e,imperative,in,indicative,infinitive,instrumental,into,is,it,its,just,kind,less,like,locative,made,make,manner,masculine,me,more,most,much,my,name,neuter,no,nominative,not,noun,obsolete,of,often,on,oneself,only,or,other,our,out,over,participle,particle,particular,past,people,person,pertaining,place,plural,prefix,present,quality,related,relating,same,second,she,singular,some,somebody,someone,something,sort,specific,state,subjunctive,such,suffix,term,that,the,their,them,these,they,thing,things,third,this,those,through,to,type,under,up,upon,us,use,used,usually,variant,verb,very,via,vocative,was,way,we,were,what,where,which,who,whom,whose,with,within,without,word,you,your}'::text[])
$$;

create or replace function legame_di_senso(p_glossa_a text, p_glossa_b text) returns boolean
language sql immutable as $$
  select exists (select 1 from unnest(parole_glossa(p_glossa_a)) x, unnest(parole_glossa(p_glossa_b)) y
                  where x = y or (length(x) >= 3 and strpos(y, x) > 0) or (length(y) >= 3 and strpos(x, y) > 0))
$$;
comment on function legame_di_senso(text, text) is
  'Le due glosse condividono una parola piena, o una contiene l’altra: la linea del senso tra una parola e il suo etimo è evidente.';
