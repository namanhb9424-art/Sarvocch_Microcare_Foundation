# SARVOOCCH — Deployment & Infrastructure Guide

**Document Classification:** Operations & Release Architecture  
**Date:** 3 November 2026  
**Application Name:** SARVOOCCH  

---

## 1. Local Bare-Metal Deployment
```bash
# 1. Activate Python virtual environment
cd /Users/vaidik/sarvocch_repo
python3 -m venv .venv
source .venv/bin/activate

# 2. Install dependencies
pip install -r requirements.txt

# 3. Start local development server
PORT=5001 FLASK_DEBUG=1 python app.py
```
Access the application at `http://127.0.0.1:5001`.

---

## 2. Docker Container Deployment
```bash
# Build and run using Docker Compose
docker-compose up --build -d

# Check service logs and health
docker-compose logs -f sarvoocch-web
docker-compose ps
```

---

## 3. Cloud Deployment Configurations

### 3.1 Render (`render.yaml`)
Pre-configured web service running Python with Gunicorn:
```yaml
services:
  - type: web
    name: sarvoocch-portal
    env: python
    buildCommand: pip install -r requirements.txt
    startCommand: gunicorn app:app
    disk:
      name: sarvoocch-data
      mountPath: /app/instance
      sizeGB: 1
```

### 3.2 Vercel Serverless (`vercel.json` & `api/index.py`)
Configured to route requests through ASGI/WSGI serverless functions. Suitable for rapid demonstration prototypes.
