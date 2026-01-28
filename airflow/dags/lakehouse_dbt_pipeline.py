import os
import subprocess
import zipfile

from datetime import datetime

from airflow import DAG
from airflow.operators.python import PythonOperator

import boto3


def _download_and_unpack_dbt_project(**context):
    """
    Downloads dbt project zip from the MWAA S3 bucket and unpacks to /tmp/dbt_project
    """
    airflow_bucket = os.environ["AIRFLOW_S3_BUCKET"]  # set in MWAA env vars
    key = os.environ.get("DBT_PROJECT_ZIP_KEY", "dbt/iot_lakehouse.zip")

    target_dir = "/tmp/dbt_project"
    zip_path = "/tmp/iot_lakehouse.zip"

    # Clean
    subprocess.run(["rm", "-rf", target_dir], check=False)
    subprocess.run(["mkdir", "-p", target_dir], check=True)

    s3 = boto3.client("s3", region_name=os.environ.get("AWS_REGION", "eu-west-1"))
    s3.download_file(airflow_bucket, key, zip_path)

    with zipfile.ZipFile(zip_path, "r") as z:
        z.extractall(target_dir)

    # The project folder will be /tmp/dbt_project/iot_lakehouse
    project_path = os.path.join(target_dir, "iot_lakehouse")
    if not os.path.isdir(project_path):
        raise RuntimeError(f"dbt project folder not found at {project_path}")

    context["ti"].xcom_push(key="dbt_project_path", value=project_path)


def _run_cmd(cmd, cwd=None, env=None):
    print("Running:", " ".join(cmd))
    p = subprocess.run(cmd, cwd=cwd, env=env, text=True, capture_output=True)
    print(p.stdout)
    if p.returncode != 0:
        print(p.stderr)
        raise RuntimeError(f"Command failed: {' '.join(cmd)}")


def _run_dbt_operation(**context):
    project_path = context["ti"].xcom_pull(key="dbt_project_path", task_ids="download_dbt_project")

    # MWAA should have dbt installed via requirements.txt
    # Use a profile dir packaged with the project OR set DBT_PROFILES_DIR env var.
    profiles_dir = os.path.join(project_path, "/")

    env = os.environ.copy()
    env["DBT_PROFILES_DIR"] = profiles_dir

    # (Optional) sanity
    _run_cmd(["dbt", "--version"], cwd=project_path, env=env)

    # Run silver + gold
    _run_cmd(["dbt", "run", "--select", "silver+ gold+"], cwd=project_path, env=env)

    # Optional tests
    if os.environ.get("DBT_RUN_TESTS", "true").lower() == "true":
        _run_cmd(["dbt", "test"], cwd=project_path, env=env)


with DAG(
    dag_id="lakehouse_dbt_pipeline",
    start_date=datetime(2025, 1, 1),
    schedule="0 * * * *",  # hourly
    catchup=False,
    max_active_runs=1,
    default_args={"owner": "data-eng"},
    tags=["dbt", "athena", "iceberg", "medallion"],
) as dag:

    download_dbt_project = PythonOperator(
        task_id="download_dbt_project",
        python_callable=_download_and_unpack_dbt_project,
        provide_context=True,
    )

    run_dbt = PythonOperator(
        task_id="run_dbt",
        python_callable=_run_dbt_operation,
        provide_context=True,
    )

    download_dbt_project >> run_dbt

