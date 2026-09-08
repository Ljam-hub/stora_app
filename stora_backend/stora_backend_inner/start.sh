#!/usr/bin/env bash
set -o errexit

gunicorn stora_backend.wsgi:application