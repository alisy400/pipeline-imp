#!/bin/bash
set -e

# Use Minikube's Docker daemon
eval $(minikube docker-env)

# Build locally
docker build -t python-webapp:latest .

echo "Local Docker image built successfully for Minikube."
