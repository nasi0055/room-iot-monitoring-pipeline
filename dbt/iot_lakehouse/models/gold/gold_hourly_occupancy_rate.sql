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
  FROM {{ ref('silver_iot_sensor_readings') }}
  {% if is_incremental() %}
    WHERE event_ts >= date_trunc('hour', date_add('hour', -2, current_timestamp))
  {% endif %}
),

aggregated AS (
  SELECT
    device_id,
    date_trunc('hour', event_ts) AS hour_ts,
    avg(CAST(occupancy AS double)) AS occupancy_rate
  FROM base
  {{ dbt_utils.group_by(2)}}
)

SELECT 
  {{ dbt_utils.generate_surrogate_key(['device_id',
  'hour_ts']) }} AS pk_sensor_device_hour_id,
  *
from aggregated
