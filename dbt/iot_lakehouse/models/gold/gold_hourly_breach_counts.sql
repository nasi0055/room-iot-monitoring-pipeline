{{ config(
    materialized='incremental',
    table_type='iceberg',
    incremental_strategy='append',
    pre_hook=[
      "DELETE FROM {{ this }} WHERE hour_ts >= date_trunc('hour', date_add('hour', -2, current_timestamp))"
    ]
) }}


WITH base AS (
  SELECT *
  FROM {{ ref('silver_threshold_breached_alerts') }}
  {% if is_incremental() %}
    WHERE alert_ts >= date_trunc('hour', date_add('hour', -2, current_timestamp))
  {% endif %}
),

aggregated AS (

  SELECT
    device_id,
    date_trunc('hour', alert_ts) AS hour_ts,
    severity,
    rule,
    count(*) AS breach_count
  FROM base
  {{ dbt_utils.group_by(4)}}

)

SELECT 
  {{ dbt_utils.generate_surrogate_key(['device_id',
  'hour_ts',
  'severity',
  'rule']) }} AS pk_alert_hour_id,
  *
from aggregated
