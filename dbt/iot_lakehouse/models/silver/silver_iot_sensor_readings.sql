{{ config(
    materialized='incremental',
    table_type='iceberg',
    incremental_strategy='merge',
    unique_key='pk_sensor_event_id',
    pre_hook=["MSCK REPAIR TABLE {{ source('bronze', 'bronze_iot_sensor_readings').render_hive() }}"])
}}

WITH base AS (
  SELECT
    from_iso8601_timestamp(event_time) AS event_ts,
    device_id,
    temperature,
    humidity,
    light,
    co2,
    humidity_ratio,
    occupancy
  FROM {{ source('bronze', 'bronze_iot_sensor_readings') }}
  WHERE device_id IS NOT NULL
    AND event_time IS NOT NULL
  {% if is_incremental() %}
  AND from_iso8601_timestamp(event_time) >= date_trunc('hour', date_add('hour', -2, current_timestamp))
  {% endif %}

),

final as (
  SELECT
    {{ dbt_utils.generate_surrogate_key(['device_id',
    'event_ts']) }} AS pk_sensor_event_id,
    event_ts,
    date(event_ts) AS event_date,
    hour(event_ts) AS event_hour,
    device_id,
    CAST(temperature AS double) AS temperature,
    CAST(humidity AS double) AS humidity,
    CAST(light AS double) AS light,
    CAST(co2 AS double) AS co2,
    CAST(humidity_ratio AS double) AS humidity_ratio,
    CAST(occupancy AS integer) AS occupancy,
    ROW_NUMBER() OVER (PARTITION BY device_id, event_ts  ORDER BY event_ts DESC) as rnk
  FROM base
)

SELECT *
FROM final
WHERE rnk = 1