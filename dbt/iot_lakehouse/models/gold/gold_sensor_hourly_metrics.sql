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

    avg(temperature) AS avg_temperature,
    min(temperature) AS min_temperature,
    max(temperature) AS max_temperature,

    avg(humidity) AS avg_humidity,
    min(humidity) AS min_humidity,
    max(humidity) AS max_humidity,

    avg(light) AS avg_light,
    min(light) AS min_light,
    max(light) AS max_light,

    avg(co2) AS avg_co2,
    min(co2) AS min_co2,
    max(co2) AS max_co2,

    avg(humidity_ratio) AS avg_humidity_ratio
  FROM base
  {{ dbt_utils.group_by(2)}}

)

SELECT
  {{ dbt_utils.generate_surrogate_key(['device_id',
  'hour_ts']) }} AS pk_sensor_device_hour_id,
  *
from aggregated
