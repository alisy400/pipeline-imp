# Dockerfile
FROM python:3.11-slim

# create non-root user
RUN useradd --create-home --shell /bin/bash appuser
WORKDIR /home/appuser

# install system deps for building some Python packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential curl ca-certificates git \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# copy application
COPY . .

# expose the app port (Flask/uvicorn etc. -- adjust if different)
EXPOSE 5000

# run as non-root user
USER appuser

# default command - adjust if your app uses e.g. gunicorn or uvicorn
CMD ["python", "app.py"]
