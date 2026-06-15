FROM python:3.12-slim

ENV POETRY_VIRTUALENVS_CREATE=false \
    POETRY_CACHE_DIR=/tmp/poetry_cache

RUN pip install poetry

WORKDIR /app

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libglib2.0-0 \
        libgl1 \
        libsm6 \
        libxrender1 && \
    rm -rf /var/lib/apt/lists/*

COPY poetry.lock pyproject.toml ./
RUN poetry install --no-interaction --no-ansi --no-root

COPY ./app /app 

CMD ["python", "-m", "app.app"]