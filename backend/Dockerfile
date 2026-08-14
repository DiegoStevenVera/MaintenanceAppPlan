FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libcairo2 \
        libffi8 \
        libgdk-pixbuf-2.0-0 \
        libpango-1.0-0 \
        libpangoft2-1.0-0 \
        libpangocairo-1.0-0 \
        shared-mime-info \
        fonts-dejavu \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app/backend

COPY pyproject.toml /app/backend/pyproject.toml
COPY src /app/backend/src
COPY migrations /app/backend/migrations
COPY alembic.ini /app/backend/alembic.ini
COPY assets /app/backend/assets

RUN pip install .

RUN mkdir -p /app/backend/storage/attachments /app/backend/storage/reports

WORKDIR /app/backend
EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--app-dir", "src", "--host", "0.0.0.0", "--port", "8000"]
