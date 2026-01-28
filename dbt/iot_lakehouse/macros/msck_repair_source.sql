{% macro msck_repair_source(source_name, table_name) %}
  
  {# Resolve the source into a Relation so we get database/schema/table reliably #}
  {% set src = source(source_name, table_name) %}

  {# src is a Relation; in Athena adapter schema maps to Glue database #}
  {% set fqtn = src.database ~ "." ~ src.identifier %}

  {% do log("Running: MSCK REPAIR TABLE " ~ fqtn, info=True) %}
  {% do run_query("MSCK REPAIR TABLE " ~ fqtn) %}

{% endmacro %}
