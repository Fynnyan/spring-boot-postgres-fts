-- We don't specify a schema, the extension will be installed on public and available globally
create extension if not exists ltree;

create type language as enum ('de', 'fr', 'it', 'en');

-- Create custom id types for the cpv code, format of a code: 8 numbers then a hyphen and a check number at the end e.g. 42954000-8
-- In the wild the check number is usually omitted
create domain original_cpv_code as text check ( value ~ '^[0-9]{8}-[0-9]$');
create domain cpv_code as text check ( value ~ '^[0-9]{8}$');

create table cpv_codes
(
    code        cpv_code primary key,
    original    original_cpv_code unique check ( original like code || '%' ),
    name        jsonb not null check ( name ?| array ['de', 'fr', 'it', 'en'] ),
    parent_code cpv_code references cpv_codes,
    path        ltree
);


--
-- INDEXES
--


-- crete gist index on the path to make the ltree searchable
create index cpv_codes_node_gist_idx on cpv_codes using GIST (path);

-- add a index for parent lookup
create index cpv_codes_parent_code_idx on cpv_codes using btree (parent_code);


--
-- HELPER FUNCTIONS TO EASIER INTERACT WITH THE FTS METHODS
--


-- function to provide the to_tsvector() with the ts_config 'simple' for a lookup over all languages in a jsonb.
-- can be used in queries and also is used for creating the GIN index over all languages for the 'name' field
create function jsonb_to_tsvector(json jsonb)
    returns tsvector
    language plpgsql
    immutable
    parallel safe
as
$$
begin
    return to_tsvector('simple', json);
end;
$$;

-- function to provide the to_tsvector() with the ts_config of the different languages for a lookup of a given language.
-- can be used in queries and also is used for creating the GIN index for each language in the jsonb for the 'name' field
create or replace function text_to_tsvector(text text, language language)
    returns tsvector
    language plpgsql
    immutable
    strict
    parallel safe
as
$$
begin
    return
        (case
             when language = 'de' then to_tsvector('german', text)
             when language = 'fr' then to_tsvector('french', text)
             when language = 'it' then to_tsvector('italian', text)
             when language = 'en' then to_tsvector('english', text)
            end);
end;
$$;

-- function to provide the websearch_to_tsquery() with the ts_config of the different languages or for a lookup ofer all languages in a jsonb.
-- can be used in statements to have a convenient way to get the tsquery for a language with the right config, that is important for the usage with the indices
create or replace function localized_websearch_to_tsquery(query text, language language default null)
    returns tsquery
    language plpgsql
    immutable
    parallel safe
as
$$
begin
    return
        case language
            when 'de' then websearch_to_tsquery('german', query)
            when 'fr' then websearch_to_tsquery('french', query)
            when 'it' then websearch_to_tsquery('italian', query)
            when 'en' then websearch_to_tsquery('english', query)
            else websearch_to_tsquery('simple', query)
            end;
end;
$$;

-- function to provide the to_tsquery() method with the configurations for the different languages
create or replace function localized_to_tsquery(query text, language language default null)
    returns tsquery
    language plpgsql
    immutable
    parallel safe
as
$$
begin
    return
        (case
             when language = 'de' then to_tsquery('german', query)
             when language = 'fr' then to_tsquery('french', query)
             when language = 'it' then to_tsquery('italian', query)
             when language = 'en' then to_tsquery('english', query)
             else to_tsquery('simple', query)
            end);
end;
$$;


--
-- TEXT SEARCH INDEXES
--


create index cpv_codes_name_idx on cpv_codes using GIN (jsonb_to_tsvector(name));
create index cpv_codes_name_de_idx on cpv_codes using GIN (text_to_tsvector(name ->> 'de', 'de'));
create index cpv_codes_name_fr_idx on cpv_codes using GIN (text_to_tsvector(name ->> 'fr', 'fr'));
create index cpv_codes_name_it_idx on cpv_codes using GIN (text_to_tsvector(name ->> 'it', 'it'));
create index cpv_codes_name_en_idx on cpv_codes using GIN (text_to_tsvector(name ->> 'en', 'en'));


--
-- LTREE FUNCTIONS
--


-- create function to calculate the path for a given code entry
create or replace function cpv_codes_calculate_path(parameter_code cpv_code)
    returns ltree
    language plpgsql
    strict stable
as
$$
begin
    return (
        select case
                   when parent_code is null then code::ltree
                   else cpv_codes_calculate_path(parent_code) || code::ltree
                   end
        from cpv_codes
        where code = parameter_code
    );
end
$$;

-- trigger function to calculate the ltree path for the cpv_codes on insert and update
create or replace function cpv_codes_update_path()
    returns trigger
    language plpgsql
    volatile
as
$$
begin
    if tg_op = 'UPDATE' then
        if old.parent_code != new.parent_code
            or old.parent_code is null and new.parent_code is not null
            or old.parent_code is not null and new.parent_code is null
        then
            -- when the parent changes update the path of all children and the updated entry
            update cpv_codes
            set path = cpv_codes_calculate_path(code)
            where path <@ old.path;
        end if;
    elsif tg_op = 'INSERT' then
        update cpv_codes set path = cpv_codes_calculate_path(new.code) where code = new.code;
    end if;
    return new;
end;
$$;

-- trigger the calculation of the path after an insert or update
create trigger trigger_cpv_codes_update_path
    after insert or update
    on cpv_codes
    for each row
execute procedure cpv_codes_update_path();

