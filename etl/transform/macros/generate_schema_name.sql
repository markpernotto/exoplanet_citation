{# Use the model's +schema value as-is, instead of dbt's default
   "<target_schema>_<custom_schema>" prefixing. This gives us clean
   `staging` and `marts` schemas instead of `public_staging` etc. #}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
