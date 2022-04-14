-- see the available default language configs
select * from pg_ts_config;
-- another example to get the one part of the available config, the defining text search dictionaries.
select * from pg_ts_dict;


-- what does to_tsvector do and why the language config is important
select 'system_default' as config, to_tsvector('Sphinx of black quartz judge my vow')
union
select 'simple' as config, to_tsvector('simple', 'Sphinx of black quartz judge my vow')
union
select 'english' as config, to_tsvector('english', 'Sphinx of black quartz judge my vow')
union
select 'german' as config, to_tsvector('german', 'Sphinx of black quartz judge my vow')
order by config desc;

-- same as previous with german text to display the behaviour of the config i.e. looks for other stop words
select 'system_default' as config, to_tsvector('Falsches Üben von Xylophonmusik quält jeden größeren Zwerg')
union
select 'simple' as config, to_tsvector('simple', 'Falsches Üben von Xylophonmusik quält jeden größeren Zwerg')
union
select 'english' as config, to_tsvector('english', 'Falsches Üben von Xylophonmusik quält jeden größeren Zwerg')
union
select 'german' as config, to_tsvector('german', 'Falsches Üben von Xylophonmusik quält jeden größeren Zwerg')
order by config desc;

-- what does to_tsquery do and why the language config is important
select 'system_default' as config, to_tsquery('black & quartz | of')
union
select 'simple' as config, to_tsquery('simple', 'black & quartz | of')
union
select 'english' as config, to_tsquery('english', 'black & quartz | of')
union
select 'german' as config, to_tsquery('german', 'black & quartz | of')
order by config desc;

-- postgres got some convenient functions to turn input into a query string (also sanitizes the string)
select 'system_default' as config, websearch_to_tsquery('judge my vow')
union
select 'simple' as config, websearch_to_tsquery('simple', 'judge my vow')
union
select 'english' as config, websearch_to_tsquery('english', 'judge my vow')
union
select 'german' as config, websearch_to_tsquery('german', 'judge my vow')
union
select '' as config, websearch_to_tsquery('german', 'judge, jury & executioner (my words are final!)')
order by config desc;

-- both combined to do a search
select '1 query' as setup, to_tsquery('black & quartz')::text
union
select '2 vector' as setup, to_tsvector('Sphinx of black quartz judge my vow')::text
union
select '3 result' as setup, (to_tsvector('Sphinx of black quartz judge my vow') @@ to_tsquery('black & quartz'))::text
order by setup;

select '1 query' as setup, to_tsquery('sphinx <-> quartz')::text
union
select '2 vector' as setup, to_tsvector('Sphinx of black quartz judge my vow')::text
union
select '3 result' as setup, (to_tsvector('Sphinx of black quartz judge my vow') @@ to_tsquery('sphinx <-> quartz'))::text
order by setup;
