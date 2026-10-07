# Local Airflow environment

This repository runs Airflow 3.3.2 with LocalExecutor, PostgreSQL 16, and
MiniStack 1.5.21. The configuration is intended for development on this machine.

## Changes and reasons

| Change | Reason |
| --- | --- |
| Switch CeleryExecutor to LocalExecutor; remove Redis, the Celery worker, Flower, and their dependencies | Tasks run as processes on the scheduler. A single-machine development environment does not need the Celery queue and worker services. |
| Set total task parallelism to 4 and active tasks per DAG to 2 | Limit local resource usage and keep one DAG from taking every task slot. Increase these values in the shared environment block when needed. |
| Disable `AIRFLOW__CORE__LOAD_EXAMPLES` | The quick-start DAGs come bundled with Airflow, even when `dags/` is empty. Show project DAGs rather than loading demonstrations. Newly created DAGs remain paused until enabled. |
| Bind the UI to `127.0.0.1:8080` | Keep the development UI accessible from this machine instead of every host network interface. |
| Require `FERNET_KEY` in `.env` | The previous Compose file substituted an empty key. Persist a key shared by all Airflow services so new connection passwords and variables can be encrypted. |
| Add `Dockerfile` and pinned `requirements.txt` | Install dependencies at build time instead of during every container startup. Airflow stays at 3.3.2 and the Amazon provider stays at the existing image's 9.36.0. |
| Add MiniStack with a pinned image, health check, and persistent state volume | Provide an AWS endpoint for local integration testing; retain supported emulator state across graceful restarts. |
| Add the `aws_local` Airflow connection | Route AWS hooks and operators to MiniStack using dummy credentials, including STS connection checks and S3 path-style addressing. |
| Make the scheduler wait for the API server and MiniStack | LocalExecutor tasks need the execution API, and local AWS tasks need the emulator ready. |
| Add `.gitignore`, `.dockerignore`, and `.env.example` | Keep credentials, generated config, and logs out of Git and the image build context, and provide a safe environment template. |

The existing Fernet key in `config/airflow.cfg` was reused in this machine's
`.env`; its value is deliberately excluded from documentation and version control.
Keep this key if existing records are encrypted with it. Changing a key is a
separate migration, not part of restarting the environment. Records previously
stored without encryption are not automatically re-encrypted by this change.

## Services and configuration

| Service | Role |
| --- | --- |
| `postgres` | Airflow metadata, connections, variables, and run history |
| `airflow-apiserver` | UI, public API, and task execution API |
| `airflow-scheduler` | Schedules DAG runs and executes tasks through LocalExecutor |
| `airflow-dag-processor` | Parses DAG definitions |
| `airflow-triggerer` | Handles deferrable task waits |
| `airflow-init` | One-time database migration, initial user, and directory setup |
| `ministack` | Local AWS emulator |
| `airflow-cli` | Optional CLI helper under the `debug` profile |

Shared settings live under `x-airflow-common`. Environment variables override
`config/airflow.cfg`; change the Compose environment block for executor,
parallelism, example loading, and other values explicitly configured there.
The `dags/`, `logs/`, `config/`, and `plugins/` folders are bind-mounted into Airflow.
Put your DAG files in `dags/` and enable them in the UI when ready.

## Start and stop

The existing machine already has `.env` configured. On a fresh checkout, run
`bash scripts/setup-local.sh` to create directories and a private `.env` with
your user ID and a new Fernet key. The script preserves an existing `.env`.

For manual setup instead, copy `.env.example` to `.env`, set `AIRFLOW_UID` to the
output of `id -u` on Linux (use `50000` on other platforms), and generate a
Fernet key with:

```bash
docker run --rm --entrypoint python apache/airflow:3.3.2 -c 'from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())'
```

Paste the output after `FERNET_KEY=` in `.env`. Do not commit the key. Then run:

```bash
mkdir -p dags logs config plugins
docker compose config --quiet
docker compose build
docker compose up airflow-init
docker compose up -d --remove-orphans
docker compose ps --all
```

`--remove-orphans` removes the old Redis and Celery worker containers when
migrating from the original setup. The existing PostgreSQL named volume is kept.
The default initial UI credentials are `airflow` / `airflow`; initial-user
settings do not change an already-created user's password.

Open <http://localhost:8080>. Check MiniStack at
<http://localhost:4566/_ministack/health>.

```bash
docker compose stop
docker compose up -d
```

`docker compose down` also keeps named volumes. Do not add `--volumes` unless
you intend to erase the Airflow database and persisted MiniStack state.
After editing `requirements.txt`, run `docker compose build` and
`docker compose up -d` again. Runtime pip installation is disabled.

## Use mock AWS services

| Client location | Endpoint |
| --- | --- |
| Airflow container | `http://ministack:4566` |
| Host terminal | `http://localhost:4566` |

In an AWS operator or hook, set `aws_conn_id="aws_local"`. The connection is
supplied through `AIRFLOW_CONN_AWS_LOCAL`, so it does not require a database
connection record and may not appear in the UI's connection list.
It uses access key `test`, secret key `test`, and region `us-east-1`.
Use the same region when creating resources on the host.

For example, with the AWS CLI installed on the host:

```bash
AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 \
  aws --endpoint-url http://localhost:4566 s3 mb s3://airflow-local-demo
```

Create the buckets, queues, tables, and other resources your DAG needs before
running it. Raw boto3 code must explicitly configure its endpoint and dummy
credentials, or obtain a client through an Airflow AWS hook using `aws_local`.
This connection does not redirect unrelated AWS connections or raw SDK clients.

MiniStack compatibility depends on the service and operation. Container-backed
features such as RDS, ECS, and Docker Lambda execution require additional Docker
socket and network configuration. The current setup supports testing emulator
APIs without that access. Athena execution with DuckDB requires the full image.

## Example DAGs and existing metadata

Example loading is now disabled for every Airflow service. The DAG processor
needs time to refresh after the containers are recreated. Existing example DAG
metadata and history may still appear as stale entries; disabling examples does
not erase historical runs. Avoid resetting the database just to clean the UI.

## Verification

Useful checks after applying the configuration:

```bash
docker compose config --quiet
docker compose ps --all
docker compose exec -T airflow-scheduler airflow config get-value core executor
docker compose exec -T airflow-dag-processor airflow config get-value core load_examples
docker compose exec -T airflow-scheduler airflow connections test aws_local
```

The executor should be `LocalExecutor`, example loading should be `False`, and
the connection check should succeed against MiniStack's STS endpoint.
See `validation.md` for the checks performed during this change.

## References

- [Airflow Docker development setup](https://airflow.apache.org/docs/apache-airflow/3.3.2/howto/docker-compose/)
- [LocalExecutor](https://airflow.apache.org/docs/apache-airflow/3.3.2/core-concepts/executor/local.html)
- [Configuration precedence](https://airflow.apache.org/docs/apache-airflow/3.3.2/howto/set-config.html)
- [AWS connection and endpoint settings](https://airflow.apache.org/docs/apache-airflow-providers-amazon/9.36.0/connections/aws.html)
- [MiniStack setup and supported features](https://github.com/ministackorg/ministack)
- [MiniStack releases](https://github.com/ministackorg/ministack/releases)
