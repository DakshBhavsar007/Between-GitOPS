# AWS GitOps Readiness Audit: Between (Vishleshan)

**Project Name:** Between (Vishleshan AI Resume Intelligence Platform)  
**Audit Date:** September 23, 2026  
**Auditor:** Antigravity AI Engineering  
**Target Infrastructure:** AWS EC2 (k3s) + ArgoCD + GHCR + AWS RDS PostgreSQL + Redis + Celery  

---

## 1. Complete Repository Audit (25-Point Deep-Dive)

### 1. Project Structure
The repository is organized as a decoupled monorepo:
```
Between-GitOps/
├── backend/                  # Django 5 backend API & Celery worker
│   ├── vishleshan_backend/   # Django project configuration (settings, urls, wsgi, asgi, celery)
│   ├── api/                  # Core application (models, views, serializers, middleware, auth)
│   ├── agents/               # AI & ML parsing agents, LLM client rotation, PDF renderers
│   ├── workers/              # Celery worker definitions (celery_worker.py)
│   ├── tests/                # Automated test suites
│   ├── datasets/ & scripts/  # ML training scripts and skill taxonomies
│   └── manage.py             # Django management entrypoint
├── frontend/                 # React 18 + Vite 5 SPA
│   ├── src/                  # React components, pages, hooks, state stores (Zustand)
│   ├── public/               # Static assets & favicons
│   ├── package.json          # Node dependencies & build scripts
│   └── vite.config.js        # Vite bundling and API proxy rules
├── .github/                  # GitHub workflows & templates
└── docs/                     # Documentation & operational runbooks
```

### 2. Django Version
- Installed/Target Version: **Django 5.1.15** (`Django>=5.0.0` in `requirements.txt`).
- Modern features used: Async DB configurations, `dj_database_url`, updated security middleware.

### 3. Python Version
- Runtime environment: **Python 3.11 / 3.12 / 3.13** (Local runtime tested on Python 3.13.5).
- CI workflow targets **Python 3.11** for stable C-extension wheels (`psycopg2-binary`, `fitz`/PyMuPDF, `scikit-learn`).

### 4. Entry Point
- **Web Backend (WSGI)**: `vishleshan_backend.wsgi:application` served via Gunicorn in production (`gunicorn vishleshan_backend.wsgi:application --bind 0.0.0.0:8000`).
- **Web Backend (ASGI)**: `vishleshan_backend.asgi:application` (available for async web protocols).
- **Background Worker**: Celery entrypoint `workers.celery_worker:celery_app` started via:
  `celery -A workers.celery_worker worker --loglevel=info -c 2` or `python start_celery.py`.
- **Frontend SPA**: `frontend/dist/index.html` served by NGINX.

### 5. Django Settings Structure
- Monolithic settings module: `backend/vishleshan_backend/settings.py`.
- Configured dynamically via `os.getenv` using `python-dotenv` loading `BASE_DIR / ".env"`.
- Features strict startup validation: raises `ValueError` if `DATABASE_URL`, `JWT_SECRET`, or LLM API keys are unconfigured.

### 6. Installed Dependencies
Key dependencies in `backend/requirements.txt`:
- **Web & Framework**: `Django>=5.0.0`, `django-cors-headers>=4.3.1`, `gunicorn>=21.2.0`, `whitenoise>=6.5.0`, `fastapi==0.111.0`, `uvicorn[standard]==0.29.0`
- **Database & Cache**: `psycopg2-binary>=2.9.9`, `asyncpg>=0.29.0`, `dj-database-url>=2.1.0`, `alembic==1.13.1`, `redis==5.0.4`, `aioredis==2.0.1`
- **Asynchronous Processing**: `celery==5.4.0`
- **Document & PDF Processing**: `PyMuPDF>=1.24.3`, `pdfplumber==0.11.0`, `python-docx==1.1.2`, `reportlab>=4.1.0`, `pypdf>=4.0.0`
- **AI & ML**: `google-generativeai==0.8.3`, `openai==1.30.1`, `scikit-learn>=1.4.0`, `spacy>=3.7.0`, `sentence-transformers==2.7.0`
- **Email & Payments**: `django-anymail[brevo]>=11.0`, `razorpay==1.4.1`

### 7. requirements.txt / pyproject.toml
- Standard `backend/requirements.txt` with 47 pinned/versioned packages.
- No `pyproject.toml` or Poetry setup exists; pip-based installation is standard.

### 8. Existing .env Usage
- Backend `.env` is loaded automatically at startup via `dotenv.load_dotenv(BASE_DIR / ".env")`.
- `CRITICAL_VARS = ["DATABASE_URL", "JWT_SECRET"]` and LLM API keys (`GEMINI_API_KEY`, `GEMINI_API_KEYS`, or `OPENAI_API_KEY`) are enforced.
- `.env.example` provides comprehensive reference documentation of all 40+ configuration options.

### 9. Database Configuration
- Managed via `dj-database-url` in `backend/vishleshan_backend/settings.py`.
- Supports Postgres connection string parsing, connection pooling (`conn_max_age`), health checks (`conn_health_checks=True`), and cursor optimization (`DISABLE_SERVER_SIDE_CURSORS = True`).
- Fallback: SQLite (`db.sqlite3`) if `DATABASE_URL` is empty.

### 10. PostgreSQL Configuration
- Engine: `django.db.backends.postgresql`.
- Connects using either `postgresql://` or `postgresql+asyncpg://` (automatically sanitized to `postgresql://`).
- SSL Mode: Automatically configured to `require` when `DEBUG=False` unless overridden via `DB_SSLMODE`.

### 11. Redis Usage
- Role 1: Celery message broker and task result backend (`REDIS_URL`, default `redis://127.0.0.1:6379/1`).
- Role 2: In-memory token cache and rate-limiting.
- Supports secure TLS Redis URLs (`rediss://`) with `ssl_cert_reqs=none`.

### 12. Celery Configuration
- Project Celery configuration defined in `backend/vishleshan_backend/celery.py` and worker app in `backend/workers/celery_worker.py`.
- Serialization: JSON (`task_serializer="json"`, `result_serializer="json"`).
- Timezone: `Asia/Kolkata`.
- Tasks:
  - `process_resume_batch`: Multi-threaded resume document parsing, skill normalization, criteria matching.
  - `enrich_candidates_llm`: Background LLM evaluation for candidates parsed with regex fallback.
  - `sync_gmail_resumes`: Gmail inbox candidate ingestion.

### 13. Static Files Configuration
- `STATIC_URL = '/static/'`
- `STATIC_ROOT = BASE_DIR / 'staticfiles'`
- Storage: `whitenoise.storage.CompressedStaticFilesStorage` via `whitenoise.middleware.WhiteNoiseMiddleware`.
- Self-contained static asset delivery enabled without requiring separate S3 bucket for CSS/JS.

### 14. Media Files Configuration
- `UPLOAD_DIR`: Configurable via environment variable (default `uploads`).
- `PHOTO_DIR`: Configurable via environment variable (default `photos`).
- Served via `custom_serve_uploads` view in `vishleshan_backend/urls.py`.
- Resilient architecture: Includes dynamic reconstruction of missing PDFs, candidate exports, and DB base64 avatar images if disk files are missing.

### 15. Existing API Endpoints
- Over 100+ endpoints organized in `backend/api/urls.py`:
  - Authentication: Recruiter, Job Seeker, Developer, Google/GitHub OAuth, Email/Phone OTP verification.
  - Core Domain: Sessions, Criteria, Candidates, Ingestion (File/Zip/Gmail/Drive/ATS), Chat/RAG.
  - Developer Platform: API Key issuance, Usage metrics, Webhooks, Embeddable SDK.
  - Assessments: MCQ tests, Online code runner, Live proctoring flags, Audio transcription.
  - Machine Learning: Salary prediction, Job recommendation, Skills clustering.

### 16. Health-Check Endpoint
- Multiple endpoints exist:
  - Root: `/health` and `/healthz` in `vishleshan_backend/urls.py` returning JSON:
    `{"status": "healthy", "service": "Between AI Engine API", "timestamp": "..."}` with HTTP 200.
  - API router: `/api/v1/health` and `/health` in `api/urls.py`.
- Perfectly suited for Kubernetes Liveness and Readiness probes.

### 17. Existing Frontend/Backend Architecture
- **Frontend**: Single-Page Application (SPA) built with React 18, Vite 5, Tailwind CSS, Zustand, and React Router.
- **Backend**: Stateless Django REST API + Celery asynchronous workers.
- **Communication**: JSON REST APIs. Reverse-proxied via NGINX in production to prevent Cross-Origin Resource Sharing (CORS) complications.

### 18. Existing Tests
Test suites located in `backend/tests/`:
- `test_admin.py`: Tests for administrative views and privileges.
- `test_dynamic_configs.py`: Tests dynamic setting overrides and runtime configs.
- `test_ml_accuracy.py`: Tests skill extraction and ML scoring algorithms.
- `test_twofactor.py`: Tests OTP verification and two-factor auth mechanisms.

### 19. Existing Deployment Files
- Legacy deployment setup: `run.bat` for Windows local development, `start_celery.py` with dummy HTTP server for Render port scanning, and `frontend/vercel.json`.
- Zero existing Kubernetes manifests or AWS GitOps automation existed prior to this project initiative.

### 20. Existing Docker Files
- Originally, no Dockerfiles existed in the repository.

### 21. Existing GitHub Actions Workflows
- `.github/workflows/ci.yml` originally performed basic Node 22 build checks and Python syntax compile checks on pushes to `main`.

### 22. Existing Production Settings
- Toggled via environment variables (`DEBUG=False`, `DATABASE_URL` with SSL, `ALLOWED_HOSTS`, `CORS_ALLOWED_ORIGINS`).
- No hardcoded environment-specific configurations.

### 23. Existing Logging Configuration
- Standard Python `logging` module utilized throughout `api/` and `agents/`.
- Middleware `api.middleware.UsageLoggerMiddleware` logs HTTP method, path, response status, and execution duration.

### 24. Existing CORS Configuration
- Handled by `corsheaders.middleware.CorsMiddleware`.
- `CORS_ALLOWED_ORIGINS` parsed from comma-separated `ALLOWED_ORIGINS` environment variable.
- Configured with `CORS_ALLOW_CREDENTIALS = True` and support for custom headers (`x-api-key`, `x-developer-token`, `x-seeker-token`, `x-recruiter-token`).

### 25. Existing Allowed Hosts Configuration
- Configured in `settings.py` as `ALLOWED_HOSTS = ["*"]` (suitable for container ingress routing behind Traefik/NGINX reverse proxies).

---

## 2. Current Architecture Summary

```
[ Client Browser ]
        |
        v
[ Ingress Controller (Traefik/NGINX on EC2) ]
        |
        +---> /api/*, /static/*, /uploads/* ----> [ Django Gunicorn (Port 8000) ]
        |                                                    |
        |                                                    +---> [ PostgreSQL (RDS) ]
        |                                                    +---> [ Redis (Broker) ]
        |                                                                 ^
        |                                                                 |
        |                                                    [ Celery Worker Pod ]
        |
        +---> /* (All other web routes) --------> [ React NGINX SPA (Port 80) ]
```

---

## 3. Current Deployment Blockers

1. **Strict Startup Env Check in `settings.py`**:
   `settings.py` raises a fatal `ValueError` if `DATABASE_URL`, `JWT_SECRET`, or LLM API keys are unset. If `collectstatic` runs during `docker build`, it will fail unless build-time dummy variables are supplied or static collection is deferred to the container startup entrypoint.
2. **Local Resume/Photo Storage**:
   Uploads are saved to local filesystem paths (`uploads/`, `photos/`). In Kubernetes, multiple pod replicas cannot share local container storage without a `PersistentVolumeClaim` (PVC) or an object store (e.g., AWS S3).
3. **No Container Registries Configured**:
   Images were not versioned or published to GitHub Container Registry (GHCR).
4. **No GitOps Reconciliation Loop**:
   No declarative Kubernetes repository or ArgoCD controller was linked to the repository.

---

## 4. Required Files

To make this repository 100% production-ready for AWS k3s + ArgoCD:
1. `backend/Dockerfile`: Multi-stage Python 3.11 container running as unprivileged `appuser`.
2. `backend/entrypoint.sh`: Container entrypoint to run migrations and `collectstatic` safely.
3. `backend/.dockerignore`: Prevents local virtual environments, `.env` secrets, and media files from leaking into Docker images.
4. `frontend/Dockerfile`: Multi-stage Node builder + Alpine NGINX runner.
5. `frontend/nginx.conf`: NGINX configuration handling SPA routing and reverse-proxying `/api/` to backend.
6. `frontend/.dockerignore`: Excludes `node_modules` and local build artifacts.
7. `docker-compose.yml`: Full-stack local validation stack (PostgreSQL + Redis + Django + Celery + React).
8. `.github/workflows/ci.yml`: Pure GitOps CI pipeline (Tests -> Multi-stage Docker build -> GHCR push -> Update manifests repo commit).
9. `gitops-manifests/`: Standalone repository containing declarative Kustomize manifests (Base + Prod Overlays).
10. `argocd/application.yaml`: ArgoCD Application Custom Resource with automated self-healing.
11. `scripts/aws/01_create_k3s_ec2.ps1` / `.sh`: AWS EC2 + k3s automation script.
12. `scripts/aws/02_create_rds_postgres.ps1` / `.sh`: AWS RDS PostgreSQL automation script.

---

## 5. Required Environment Variables

| Variable | Required For | Example / Target Value |
| :--- | :--- | :--- |
| `DATABASE_URL` | Django & Celery | `postgresql://postgres:<pass>@<rds-endpoint>:5432/vishleshan` |
| `REDIS_URL` | Celery Broker | `redis://redis-service:6379/1` |
| `JWT_SECRET` | Authentication | Cryptographically random 64-char string |
| `DEBUG` | Django Settings | `False` |
| `ALLOWED_ORIGINS` | CORS Configuration | `https://yourdomain.com,http://<EC2-IP>` |
| `GEMINI_API_KEY` | AI Resume Parsing | Valid Google Gemini API Key |
| `UPLOAD_DIR` | Media Storage | `/app/uploads` (Mounted to PVC) |
| `PHOTO_DIR` | Media Storage | `/app/photos` (Mounted to PVC) |

---

## 6. Required Changes (Zero Feature Regression)

- **Dockerfile Creation**: Containerize both backend and frontend without altering any business logic.
- **Entrypoint Logic**: Ensure database migration and static file collection execute conditionally on web server startup, while worker containers immediately boot Celery.
- **K8s Persistent Storage**: Mount a `local-path` PersistentVolumeClaim at `/app/uploads` and `/app/photos` so resume files persist across pod restarts and can be read by Celery workers.
- **Manifest Repository Isolation**: Maintain Kubernetes manifests in a separate Git repository (`Between-GitOps-Manifests`) so CI image updates do not trigger infinite CI build loops.

---

## 7. Potential Risks & Mitigations

| Risk | Impact | Mitigation Strategy |
| :--- | :--- | :--- |
| **OOM (Out of Memory) on EC2** | k3s/Pods Crash | Use `t3.medium` (4GB RAM) minimum. Set explicit pod resource requests and limits. |
| **Secrets Exposure in Git** | Security Vulnerability | Keep `secrets.yaml` in `.gitignore` or use templates. Inject production credentials via AWS Secrets Manager or initial cluster bootstrap. |
| **CI Runner Compromise** | Unauthorized Cluster Access | Enforce strict pull-based GitOps: GitHub Actions has **zero** cluster access keys and **never** runs `kubectl apply`. |
| **Database Migration Race Condition** | DB Schema Locks | Restrict migration execution to backend web entrypoint or dedicated pre-sync Kubernetes Job. Celery worker skips migration. |

---

## 8. Recommended Implementation Order

1. **PHASE 1**: Create Backend & Frontend Dockerfiles, NGINX config, and Entrypoint script.
2. **PHASE 2**: Validate full stack locally using `docker-compose.yml`.
3. **PHASE 3**: Configure GitHub Container Registry (GHCR) and authentication.
4. **PHASE 4**: Provision AWS EC2 instance and install k3s (`ap-south-1`).
5. **PHASE 5**: Structure separate GitOps Manifests repository with Kustomize.
6. **PHASE 6**: Deploy Redis and Celery worker workloads in k3s.
7. **PHASE 7**: Provision AWS RDS PostgreSQL and bind `DATABASE_URL` secret.
8. **PHASE 8**: Deploy ArgoCD inside k3s and register `Application` CRD.
9. **PHASE 9**: Configure GitHub Actions CI for lint, test, and GHCR build/push.
10. **PHASE 10**: Wire CI GitOps step to update `Between-GitOps-Manifests` image tag via Kustomize commit.
11. **PHASE 11**: Validate ArgoCD automated deployment and zero-downtime rolling update.
12. **PHASE 12**: Configure Ingress routes, DNS, and TLS certificates.
13. **PHASE 13**: Conduct GitOps self-healing drift recovery test.
14. **PHASE 14**: Finalize architectural documentation and diagrams.
15. **PHASE 15**: Prepare resume bullet points and technical interview mastery guide.

---

## Summary Classification

### A. What is Already Production-Ready
- **Django Core**: Django 5.1 with modern middleware, async DB support, and Whitenoise static storage.
- **Health Checks**: Root `/health` and `/healthz` endpoints are already implemented and ready for Kubernetes probes.
- **Celery Architecture**: Worker code (`celery_worker.py`) is decoupled and supports Redis connection strings.
- **Frontend SPA**: Vite build generates an optimized static bundle ready for NGINX.
- **AWS CLI**: Region `ap-south-1` is configured with active credentials and existing keypairs.

### B. What Needs Modification
- **Containerization**: Need standard Dockerfiles and entrypoints for Backend and Frontend.
- **Secrets Injection**: Decouple secrets from `.env` files into Kubernetes Secret objects.
- **Media Storage**: Mount Kubernetes PersistentVolumeClaims to preserve uploads across container lifecycles.
- **CI/CD Pipeline**: Update `.github/workflows/ci.yml` to build multi-stage images, push to GHCR, and commit new image tags to the manifests repo.

### C. What Must Be Done Manually in AWS
- Launch EC2 instance (`t3.medium`) or run the provided automated PowerShell/Bash script (`01_create_k3s_ec2.ps1`).
- Create AWS RDS PostgreSQL instance (`db.t4g.micro`) or run `02_create_rds_postgres.ps1`.
- Configure EC2 Security Group inbound rules (Ports 22, 80, 443, 6443, 8080).
- Allocate and associate an Elastic IP (EIP).

### D. What Can Be Automated with GitHub Actions
- Code linting and Python syntax validation.
- Frontend test and production build compilation.
- Multi-stage Docker image builds with layer caching.
- Pushing tagged container images (`sha-<commit>` and `latest`) to GHCR.
- Cloning `Between-GitOps-Manifests`, updating the production image tag with Kustomize, and pushing the commit.

### E. What Should Be Handled by ArgoCD
- Continuously monitoring `Between-GitOps-Manifests` for desired-state changes.
- Automatically pulling new manifests and triggering zero-downtime rolling updates in k3s.
- Detecting unauthorized cluster drift (e.g. manual `kubectl` scale or edit) and enforcing self-healing back to Git state.
- Automated resource pruning when manifests are removed from Git.
