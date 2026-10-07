# Validation results

Validated on 2026-10-07 against the running local Docker environment.

| Check | Result |
| --- | --- |
| `docker compose config --quiet` | Passed; no missing Fernet variable warning |
| `git diff --check` | Passed |
| `docker compose build` | Passed; Airflow 3.3.2 and Amazon provider 9.36.0 installed |
| `docker compose up -d --remove-orphans --wait --wait-timeout 180` | Passed; runtime services healthy and initialization exited successfully |
| Effective Airflow executor | `LocalExecutor` |
| Effective total parallelism / active tasks per DAG | `4` / `2` |
| Effective example loading | Disabled |
| Fernet configuration | Nonempty key accepted by `cryptography.fernet.Fernet`; no key printed |
| `aws_local` connection | STS connection check succeeded against MiniStack |
| S3 integration through Airflow's `S3Hook` | Created a unique temporary bucket, wrote an object, read and verified the payload, then deleted the object and bucket |
| Secret and generated-file exclusions | `.env`, `config/airflow.cfg`, and `logs/` are ignored by Git |

The Airflow API server, scheduler, DAG processor, triggerer, PostgreSQL, and
MiniStack all reported healthy. Redis and the Celery worker were removed during
the migration. PostgreSQL's existing named volume was retained.

The integration smoke check ran inside an Airflow container, using the same
connection and provider available to DAGs. No project DAG was added, and no
scheduled DAG execution was tested because the project `dags/` folder is empty.
Persistence is configured for MiniStack, but a restart round-trip of emulator
state was not part of this check. AWS services beyond STS and S3 were not tested.
