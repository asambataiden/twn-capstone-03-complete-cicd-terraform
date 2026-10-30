FROM python:3.13-slim

WORKDIR /app

RUN groupadd --system appuser \
    && useradd --system --gid appuser --no-create-home appuser

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .

USER appuser

EXPOSE 8080

CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "main:app"]
