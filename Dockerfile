
FROM apache/superset:latest

USER root

RUN . /app/.venv/bin/activate && \
    uv pip install psycopg2-binary && \
    /app/.venv/bin/python -c "import psycopg2; print('psycopg2 installed successfully')"

USER superset
