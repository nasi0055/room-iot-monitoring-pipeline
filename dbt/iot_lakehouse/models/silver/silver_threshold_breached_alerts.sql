{{ config(
    materialized='incremental',
    table_type='iceberg',
    incremental_strategy='merge',
    unique_key='pk_alert_event_id',
    pre_hook=["MSCK REPAIR TABLE {{ source('bronze', 'bronze_threshold_breached_alerts').render_hive() }}"])
}}


WITH base AS (
  SELECT
    from_iso8601_timestamp(alert_time) AS alert_ts,
    user_id,
    device_id,
    rule,
    severity,
    metric,
    observed_value,
    threshold_value,
    window_start_ms,
    window_end_ms
  FROM {{ source('bronze', 'bronze_threshold_breached_alerts') }}
  WHERE alert_time IS NOT NULL
    AND device_id IS NOT NULL
  {% if is_incremental() %}
  AND from_iso8601_timestamp(alert_time) >= date_trunc('hour', date_add('hour', -2, current_timestamp))
  {% endif %}

),

final AS (
  SELECT
    {{ dbt_utils.generate_surrogate_key(['user_id',
    'device_id',
    'rule',
    'severity',
    'alert_ts']) }} AS pk_alert_event_id,
    alert_ts,
    date(alert_ts) AS alert_date,
    hour(alert_ts) AS alert_hour,
    user_id,
    device_id,
    rule,
    severity,
    metric,
    CAST(observed_value AS double) AS observed_value,
    CAST(threshold_value AS double) AS threshold_value,
    window_start_ms,
    window_end_ms,
    ROW_NUMBER() OVER (PARTITION BY user_id, device_id, rule, severity, alert_ts ORDER BY alert_ts DESC) as rnk
  FROM base
)

SELECT *
FROM final
where rnk = 1