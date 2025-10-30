# Dockerfile
FROM python:3.11-slim

# create non-root user
RUN useradd --create-home --shell /bin/bash appuser
WORKDIR /home/appuser

# install system deps for psutil build
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential curl ca-certificates git \
    && rm -rf /var/lib/apt/lists/*  

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# copy app code
COPY . .

ENV FLASK_APP=app.py
ENV PYTHONUNBUFFERED=1
EXPOSE 5000

USER appuser

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app:app", "--workers", "2", "--threads", "2"]


RUN apk add --no-cache ca-certificates curl
RUN update-ca-certificates
