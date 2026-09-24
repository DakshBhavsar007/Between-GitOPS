# Production Containerization Guide: Between (Vishleshan)

This document provides complete instructions for building, running, validating, and troubleshooting the Docker containers for the **Between** (Vishleshan AI Resume Intelligence) platform.

---

## 1. Backend Image (`between-backend`)

The backend container encapsulates the Django 5 REST API, document ingestion engines, and ML models.

- **Base Image**: `python:3.11-slim-bullseye`
- **Architecture**: Multi-stage build
  - *Builder stage*: Installs GCC, G++, `libpq-dev`, and builds Python dependencies into an isolated virtual environment (`/opt/venv`).
  - *Runner stage*: Copies `/opt/venv`, installs only runtime shared libraries (`libpq5`, `curl`, `netcat-traditional`), creates an unprivileged user (`appuser`, UID 1000), and copies application code.
- **WSGI Entrypoint**: `vishleshan_backend.wsgi:application`
- **Application Server**: Gunicorn (`gunicorn vishleshan_backend.wsgi:application --bind 0.0.0.0:8000 --workers 3 --timeout 120`)
- **Port Exposed**: `8000`
- **User**: `appuser` (non-root)

---

## 2. Frontend Image (`between-frontend`)

The frontend container compiles the React 18 / Vite 5 SPA and serves optimized static assets via NGINX.

- **Stage 1 (Builder)**: `node:22-alpine` runs `npm ci` and compiles client assets with `npm run build` into `dist/`.
- **Stage 2 (Runner)**: `nginx:1.27-alpine` copies `dist/` into `/usr/share/nginx/html`.
- **SPA Routing**: Configured via `try_files $uri $uri/ /index.html;` to ensure client-side routing (React Router) functions seamlessly without 404 errors on browser refresh.
- **Reverse Proxy**: NGINX proxies all requests matching `/api/` directly to the backend service (`http://backend:8000`), completely eliminating Cross-Origin Resource Sharing (CORS) issues in production.
- **Port Exposed**: `80` (mapped to `3000` in Docker Compose)

---

## 3. Celery Worker (`between-celery`)

The Celery worker executes asynchronous, CPU-intensive tasks such as bulk resume parsing with PyMuPDF, criteria matching, and background LLM enrichment.

- **Image Reusability**: The Celery worker uses the **exact same container image** as the backend (`between-backend`).
- **Worker Command**:
  ```bash
  celery -A workers.celery_worker worker --loglevel=info -c 2
  ```
- **Entrypoint Behavior**: When invoked with `celery`, the container entrypoint (`backend/entrypoint.sh`) bypasses web migrations and static file collection, immediately launching the worker processes.

---

## 4. Redis

Redis 7 serves as the task broker and result backend for Celery.
- **Image**: `redis:7-alpine`
- **Port**: `6379`
- **Default Connection URL**: `redis://redis:6379/1`
- **Persistence**: Backed by a dedicated Docker volume (`redis_data`) in local development.

---

## 5. PostgreSQL Requirements

The application uses PostgreSQL as its primary relational database via `dj-database-url` and `psycopg2-binary`.
- **Image for Local Dev**: `postgres:15-alpine`
- **Default Database**: `vishleshan`
- **Default Port**: `5432`
- **Connection URL Format**:
  `postgresql://<user>:<password>@<host>:5432/<database_name>`
- **Production Target**: AWS RDS PostgreSQL (Engine version 15 or 16).

---

## 6. Environment Variables

Runtime configuration must be supplied through environment variables. **No secrets or credentials are hardcoded into the Docker images.**

| Variable | Required In | Purpose | Example / Default |
| :--- | :--- | :--- | :--- |
| `DATABASE_URL` | Backend, Celery | PostgreSQL connection string | `postgresql://postgres:password@postgres:5432/vishleshan` |
| `REDIS_URL` | Backend, Celery | Redis broker URL | `redis://redis:6379/1` |
| `JWT_SECRET` | Backend, Celery | Secret key for JWT signing | 64-char random hex string |
| `DEBUG` | Backend, Celery | Enable/disable debug mode | `False` (production) / `True` (local) |
| `ALLOWED_ORIGINS` | Backend | Permitted CORS origins | `http://localhost:3000,http://localhost` |
| `GEMINI_API_KEY` | Backend, Celery | Google Gemini LLM API Key | `AIzaSy...` |
| `UPLOAD_DIR` | Backend, Celery | Path to resume uploads | `/app/uploads` |
| `PHOTO_DIR` | Backend, Celery | Path to candidate photos | `/app/photos` |
| `VITE_API_URL` | Frontend Build | Base API prefix | `/api/v1` |

---

## 7. Local Build Commands

Run the following commands from the project root directory:

### Build Backend Image
```bash
docker build -t between-backend ./backend
```
*Build Context*: `./backend`  
*Dockerfile*: `./backend/Dockerfile`

### Build Frontend Image
```bash
docker build -t between-frontend ./frontend
```
*Build Context*: `./frontend`  
*Dockerfile*: `./frontend/Dockerfile`

---

## 8. Local Run Commands (Standalone Containers)

If running containers individually without Docker Compose:

```bash
# 1. Create a bridge network
docker network create between-net

# 2. Run Redis
docker run -d --name between-redis --network between-net redis:7-alpine

# 3. Run PostgreSQL
docker run -d --name between-postgres --network between-net \
  -e POSTGRES_DB=vishleshan \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgrespassword \
  postgres:15-alpine

# 4. Run Django Backend
docker run -d --name between-backend --network between-net -p 8000:8000 \
  -e DATABASE_URL=postgresql://postgres:postgrespassword@between-postgres:5432/vishleshan \
  -e REDIS_URL=redis://between-redis:6379/1 \
  -e JWT_SECRET=local-development-jwt-secret-string \
  -e DEBUG=True \
  -e GEMINI_API_KEY=dummy_or_real_key \
  between-backend

# 5. Run Celery Worker
docker run -d --name between-celery --network between-net \
  -e DATABASE_URL=postgresql://postgres:postgrespassword@between-postgres:5432/vishleshan \
  -e REDIS_URL=redis://between-redis:6379/1 \
  -e JWT_SECRET=local-development-jwt-secret-string \
  -e DEBUG=True \
  -e GEMINI_API_KEY=dummy_or_real_key \
  between-backend celery -A workers.celery_worker worker --loglevel=info -c 2

# 6. Run Frontend
docker run -d --name between-frontend --network between-net -p 3000:80 between-frontend
```

---

## 9. Docker Compose (Recommended for Local Dev)

A complete, self-contained development stack is defined in [docker-compose.yml](file:///c:/Users/parul/Desktop/Resume%20Project/Between-GitOps/docker-compose.yml).

### Starting the Stack
```bash
docker compose up -d --build
```

### Checking Container Status
```bash
docker compose ps
```

### Viewing Logs
```bash
# All logs
docker compose logs -f

# Backend only
docker compose logs -f backend

# Celery only
docker compose logs -f celery
```

### Stopping the Stack
```bash
docker compose down
```

---

## 10. Health Checks

The backend provides two built-in health check endpoints defined in `vishleshan_backend/urls.py`:
- `/health`
- `/healthz`

Both endpoints return HTTP 200 with JSON:
```json
{
  "status": "healthy",
  "service": "Between AI Engine API",
  "timestamp": "2026-09-23T10:00:00.000000+05:30"
}
```

### Probe Recommendations
- **Docker Healthcheck**: Uses `curl -f http://localhost:8000/healthz || exit 1`.
- **Kubernetes Liveness Probe**: Use `/healthz` on port 8000. It tests whether Gunicorn process is responsive without querying the database, ensuring temporary DB connection spikes do not trigger cascading pod restarts.
- **Kubernetes Readiness Probe**: Use `/healthz` on port 8000. Ensures traffic is only directed to pods that have completed startup and static asset initialization.

---

## 11. Persistent Media Storage

### Architecture & Requirements
The Between platform stores uploaded candidate resumes (PDF, DOCX) and extracted candidate photos on disk:
- Resumes: Saved under `UPLOAD_DIR` (default: `/app/uploads`)
- Photos: Saved under `PHOTO_DIR` (default: `/app/photos`)

### Celery Access Requirement
When a recruiter or candidate uploads a resume file through the Django web API, Django saves the file to `UPLOAD_DIR` and dispatches a task to Celery containing the file path.
- **Crucial Requirement**: The Celery worker container **must** have read/write access to the exact same filesystem storage as the Django web container.
- **Docker Compose Solution**: Managed via shared named volumes `uploads_data:/app/uploads` and `photos_data:/app/photos` mounted on both `backend` and `celery` containers.
- **Kubernetes Solution (Future Phase)**: A shared `PersistentVolumeClaim` (PVC) with `ReadWriteMany` (NFS / EFS) or `local-path` volume mount will be bound to both Deployment pods.

---

## 12. Troubleshooting

### Issue 1: `ValueError: Critical Error: Missing required LLM API keys`
- **Cause**: Django `settings.py` enforces that at least one of `GEMINI_API_KEY`, `GEMINI_API_KEYS`, or `OPENAI_API_KEY` is set.
- **Solution**: Pass `-e GEMINI_API_KEY=your_key` or set it in your local environment file. For testing without LLM calls, any non-empty string satisfies the startup validator.

### Issue 2: Gunicorn fails with `bad interpreter: No such file or directory`
- **Cause**: Windows line endings (`CRLF` instead of `LF`) in `entrypoint.sh`.
- **Solution**: The Dockerfile automatically runs `sed -i 's/\r$//' /app/entrypoint.sh` to sanitize line endings during container build.

### Issue 3: Celery cannot connect to Redis
- **Cause**: `REDIS_URL` pointing to `localhost` inside the container instead of the service name `redis`.
- **Solution**: Set `REDIS_URL=redis://redis:6379/1` in Docker Compose or container network.
