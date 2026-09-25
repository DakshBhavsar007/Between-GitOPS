# Security Policy — Vishleshan

**Vishleshan** is a Multi-Agent Recruitment Intelligence Platform that processes sensitive personal data (resumes, contact details, employment history) and provides fraud detection services. We take security seriously and appreciate responsible disclosure from the community.

---

## Supported Versions

The following versions of Vishleshan are actively maintained and receive security updates:

| Version | Supported          | Notes                              |
| ------- | ------------------ | ---------------------------------- |
| `1.x`   | :white_check_mark: | Current stable — actively patched  |
| `< 1.0` | :x:                | Pre-release builds — not supported |

We strongly recommend always running the latest `1.x` release.

---

## Scope

The following components are in scope for security reports:

| Component | Description |
|-----------|-------------|
| **Django REST Backend** | All API endpoints under `/api/v1/` |
| **Authentication** | JWT token flow (recruiter/seeker/admin), API Key auth (`X-API-Key`), Google OAuth, GitHub OAuth |
| **Admin Dashboard** | Dedicated admin login, ban/unban moderation, support ticket management |
| **Multi-Agent Pipeline** | Resume parsing, matching, fraud detection, interview, and chatbot agents |
| **Developer Portal APIs** | Key management, subscription billing, rate limiting, webhooks |
| **Fraud Detection Engine** | Resume and job posting scanning endpoints |
| **OTP & Verification** | SMS OTP (2Factor), Email verification (Brevo) |
| **LLM Router** | Gemini API key rotation and failover logic |
| **File Upload Handling** | PDF/DOCX/TXT resume ingestion via Celery workers |
| **Redis Layer** | Rate limiting, JWT blacklisting, ban status caching |

The following are **out of scope**:

- Third-party services (Neon, Razorpay, Google Gemini API, 2Factor, Brevo)
- Social engineering attacks against team members
- Denial-of-service attacks on the dev server
- Issues found only in unsupported / pre-release versions

---

## Sensitive Data Handled

Vishleshan processes and stores the following sensitive information. Any vulnerability affecting these assets is considered **high priority**:

- **PII** — Candidate names, email addresses, phone numbers, LinkedIn/GitHub profiles
- **Resume Contents** — Employment history, education records, project details
- **API Keys** — Developer-issued `vish_live_*` and `vish_test_*` keys
- **JWT Tokens** — Recruiter, seeker, and admin session tokens
- **Admin Credentials** — Admin email and password stored exclusively in environment variables
- **Fraud Analysis Audits** — Detailed scan logs, website validation outcomes, recruiter email verification metadata
- **Payment Data** — Razorpay subscription metadata (no raw card data stored)
- **LLM API Keys & OAuth Credentials** — Gemini API keys, Google/GitHub client IDs and secrets stored in `.env`
- **OTP Codes** — Time-limited verification codes for SMS and email

---

## Reporting a Vulnerability

If you discover a security vulnerability in Vishleshan, **please do not open a public GitHub Issue**. Instead, report it privately using one of the following channels:

### Option 1 — GitHub Private Security Advisory (Preferred)
Use GitHub's built-in [Private Vulnerability Reporting](https://github.com/DakshBhavsar007/Multi-Agent-Resume-Project/security/advisories/new) to submit a confidential advisory directly to the maintainers.

### Option 2 — Email
Send a detailed report to the project maintainers. Include the following information:

```
Subject: [SECURITY] Vishleshan — <brief description>

- Component affected (e.g., "Admin login endpoint", "API Key auth")
- Steps to reproduce the vulnerability
- Potential impact (data exposure, privilege escalation, etc.)
- Proof of concept (code, curl commands, screenshots — if available)
- Suggested fix (optional)
```

---

## What to Expect After Reporting

| Timeline | Action |
|----------|--------|
| **Within 48 hours** | Acknowledgement of your report |
| **Within 7 days** | Initial triage — confirmed or declined with reasoning |
| **Within 30 days** | Patch released for confirmed vulnerabilities (critical issues prioritised) |
| **After patch release** | Public disclosure coordinated with the reporter |

We follow a **coordinated disclosure** policy. We ask that you give us reasonable time to patch before publicly disclosing the issue.

---

## Vulnerability Severity Classification

We use the following severity levels to prioritise reported issues:

| Severity | Examples |
|----------|---------|
| **Critical** | Unauthenticated access to candidate PII, API key leakage, RCE via file upload, admin credential exposure |
| **High** | Broken authentication, IDOR exposing other recruiters' data, JWT forgery, ban bypass |
| **Medium** | Rate limit bypass, excessive data exposure in API responses, SSRF, stale cache exploitation |
| **Low** | Missing security headers, verbose error messages, minor info disclosure |

---

## Security Best Practices for Self-Hosting

If you are running Vishleshan locally or in your own infrastructure, follow these guidelines:

### Environment & Secrets
- **Never commit `.env` or `.env.local` to version control** — they contain Gemini API keys, DB credentials, JWT secrets, OAuth credentials, and admin passwords.
- Use `.env.example` and `.env.local.example` as templates and populate secrets securely.
- Rotate `GEMINI_API_KEYS`, `GOOGLE_OAUTH_CLIENT_SECRET`, and `ADMIN_PASSWORD` regularly.
- Wrap `.env` values containing `#` in double quotes (e.g., `ADMIN_PASSWORD="Pass#word"`) to prevent comment truncation.

### API Keys
- Generate separate `vish_test_*` keys for development — never use production keys in testing.
- Revoke unused developer API keys from the Developer Portal dashboard.
- Set appropriate monthly quotas on all API keys to limit blast radius.

### Authentication & Admin
- Set a strong, unique `JWT_SECRET` (minimum 50 random characters).
- Ensure JWT tokens have short expiry — admin tokens are set to 20 minutes.
- Use a strong `ADMIN_PASSWORD` — avoid defaults; change immediately after first deployment.
- Admin login is rate-limited (5 attempts/min per IP+email combination) with structured `[SECURITY_ALERT]` logs on failures.
- Enable HTTPS in production — do not run with `DEBUG=True`.

### File Uploads
- Only `.pdf`, `.docx`, and `.txt` files are accepted by the resume parser — validate MIME types server-side.
- Uploaded files are processed by Celery workers in isolated threads; do not expose the `uploads/` directory publicly.

### Database & Redis
- Restrict PostgreSQL and Redis access to internal network only — do not expose ports publicly.
- Use strong credentials for both services and rotate them periodically.
- Redis ban status cache has a 300s TTL; if Redis goes down, the system falls back to DB checks (fail-closed, not fail-open).

---

## Known Security Features

Vishleshan includes the following built-in security controls:

| Feature | Description |
|---------|-------------|
| **IDOR Protection** | Enforces company/seeker ownership checks on all candidate management, results, and chat views |
| **JWT Blacklisting** | Revokes tokens instantly on logout via Redis-based blacklist (`blacklist:{token}`) with auto-expiration |
| **Redis Ban Cache** | Caches ban status per user type with 300s TTL; graceful DB fallback when Redis is unavailable |
| **Atomic Cache Invalidation** | Ban/unban clears Redis via `transaction.on_commit()` to prevent stale windows; logged if Redis delete fails |
| **Combined Rate Limiting** | IP + Email rate limiting on admin login and support ticket creation; returns masked identifiers in 429 responses |
| **Admin Self-Ban Prevention** | Case-insensitive email comparison (`.strip().lower()`) against `ADMIN_EMAIL` blocks self-banning |
| **Audit Logging** | `AdminBanLog` records every moderation action with admin email, target type/ID, action, and timestamp |
| **XSS Protection** | HTML template variables escaped at render-time (email templates) using `django.utils.html.escape` |
| **Content Injection Protection** | ReportLab PDF text inputs recursively HTML-escaped to prevent XML parser crashes |
| **API Key Authentication** | All developer endpoints require valid `X-API-Key` header |
| **Short Admin Token Expiry** | Admin JWT tokens expire in 20 minutes |
| **Fraud Detection Agent** | Scans resumes for AI-generated content, plagiarism, and ATS keyword stuffing |
| **Job Legitimacy Scanner** | 6-point AI verification (website, email domain, salary, LinkedIn, copy detection, duplicates) |
| **LLM Key Rotation** | `RotateLLMClient` distributes across multiple Gemini API keys to prevent single-key exposure |
| **CORS Configuration** | Restricted allowed origins to frontend domain in production |
| **Error Sanitization** | Production responses suppress internal traces, hostnames, and DB details; return generic correlation IDs |
| **Cross-Portal Session Sync** | Logging out from one portal invalidates sessions across all active portal tabs |

---

## Infrastructure & GitOps Security Controls

| Domain | Control Description |
| :--- | :--- |
| **Git Repository Secret Hygiene** | Zero production secrets, private keys, `.env` files, or kubeconfig files exist in Git. Secret templates in Git contain only dummy placeholder strings. |
| **Cluster Secret Isolation** | Production secrets are injected cluster-side directly as Kubernetes Opaque Secrets (`between-secrets`). ArgoCD is configured with `ignoreDifferences` to prevent overwriting. |
| **CI Runner Credential Isolation** | GitHub Actions workflows contain no AWS credentials, SSH private keys, or kubeconfig tokens. CI solely builds images and publishes to GHCR. |
| **AWS Security Group Ingress** | RDS PostgreSQL port 5432 ingress is restricted exclusively to the k3s EC2 Security Group. No external `0.0.0.0/0` access is permitted. |
| **Administrative Access Restriction** | EC2 SSH port 22 and Kubernetes API port 6443 ingress are restricted to authorized operator subnets (`152.58.0.0/16`). |
| **Container Privilege Minimization** | Backend and Celery workloads execute with `runAsNonRoot: true`, unprivileged UID 1000, `allowPrivilegeEscalation: false`, and all Linux capabilities dropped (`drop: [ALL]`). |
| **Database Encryption & Isolation** | AWS RDS PostgreSQL runs in private subnets across multiple AZs with TLS/SSL database connections enforced. |
| **TLS/HTTPS Edge Termination** | Automated Let's Encrypt TLS certificates issued via Traefik ACME HTTP-01 challenge for `between.dakshaws.sryze.cc`; permanent 301 HTTP-to-HTTPS redirect enforced. |

---

## Acknowledgements

We are grateful to security researchers who help make Vishleshan safer. Responsible disclosures will be credited in release notes (with your permission).

---

*Built as a Sem-IV Project at DAIICT — Multi-Agent Recruitment Intelligence Platform*
