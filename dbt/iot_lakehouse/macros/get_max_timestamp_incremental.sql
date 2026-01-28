{% macro get_max_timestamp_incremental(TIMESTAMP_COLUMN, REFRESH_INTERVAL='0 DAYS', FULL_REFRESH_TIMESTAMP='2010-01-01', DATE_CASTING='DATE', WHERE_CLAUSE='1=1') %}

{%- set max_date = DEFAULT_MAX_DATE -%}

{%- if not is_incremental() -%}
    {{ return(max_date) }}
{%- endif -%}

{%- if not execute -%}
    {{ return(max_date) }}
{%- endif -%}

{%- set query -%}
    SELECT COALESCE(MAX({{ TIMESTAMP_COLUMN }}), '{{ DEFAULT_MAX_DATE }}')::{{ DATE_CASTING }} - INTERVAL '{{ DATE_INTERVAL }}' 
    FROM {{ this }} WHERE {{ WHERE_CLAUSE }};
{%- endset -%}

{%- set max_date = run_query(query).columns[0].values()[0] -%}
{{ return(max_date) }}

{% endmacro %}