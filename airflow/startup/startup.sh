#!/bin/bash
set -euo pipefail

# Export env vars for all MWAA processes (scheduler/webserver/workers)
cat <<'EOF' > /etc/profile.d/mwaa_env.sh
export AWS_REGION="eu-west-1"
export DBT_PROJECT_ZIP_KEY="dbt/iot_lakehouse.zip"
export DBT_RUN_TESTS="true"
EOF

chmod +x /etc/profile.d/mwaa_env.sh
