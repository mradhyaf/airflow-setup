# Local Airflow with mock AWS

A Docker Compose development setup with Airflow 3.3.2, LocalExecutor,
PostgreSQL 16, and MiniStack 1.5.21. Airflow's Amazon provider is pinned to 9.36.0.

## Quick start from a fresh checkout

Install Docker with Docker Compose v2 and Bash. Start the Docker daemon, clone
this repository, and run these commands from its root:

```bash
bash scripts/setup-local.sh
docker compose build
docker compose up airflow-init
docker compose up -d --wait
```

The setup script creates local directories and a private `.env` containing your
container user ID and a generated Fernet key. It preserves an existing `.env`.
No host Python installation or AWS account is required.

Open [Airflow](http://localhost:8080) and log in with `airflow` / `airflow`.
The [MiniStack health endpoint](http://localhost:4566/_ministack/health) is also
available on the host. Both exposed ports bind to localhost.

Put DAGs in `dags/`, plugins in `plugins/`, and custom configuration code in
`config/`. Example DAGs are disabled; newly created DAGs start paused.
Use `aws_conn_id="aws_local"` in AWS hooks and operators to reach MiniStack.

## Daily use

```bash
docker compose ps --all
docker compose stop
docker compose up -d --wait
```

After editing `requirements.txt`, rebuild the image and recreate the services:

```bash
docker compose build
docker compose up -d --wait
```

PostgreSQL and MiniStack keep their data in named Docker volumes. Avoid
`docker compose down --volumes` unless you intend to delete that data.
Keep your Fernet key when restoring an existing Airflow database.

## What belongs in Git

Commit Compose configuration, the Dockerfile, dependency pins, the setup script,
`.env.example`, documentation, and DAG/plugin/configuration source files.
`.gitignore` excludes actual credentials, generated `airflow.cfg`, logs, local
SQLite databases, process files, and Python caches. Empty directory placeholders
preserve the source layout in a fresh checkout.

Application configuration and dependency versions are reproducible from the
repository. Image tags are versioned but are not digest-locked; PostgreSQL's
`16` tag follows patch releases. Local secrets and runtime data are generated
or restored separately, rather than copied from the repository.

## Documentation

- [Configuration changes, reasons, and AWS usage](docs/local-environment.md)
- [Runtime validation results and limits](docs/validation.md)
