#!/bin/bash
set -e

# If POSTGRES_HOST and POSTGRES_PORT are provided, wait until PostgreSQL is accessible
if [ -n "$POSTGRES_HOST" ] && [ -n "$POSTGRES_PORT" ]; then
    echo "Waiting for PostgreSQL at $POSTGRES_HOST:$POSTGRES_PORT..."
    while ! nc -z "$POSTGRES_HOST" "$POSTGRES_PORT"; do
        sleep 0.5
    done
    echo "PostgreSQL is reachable."
fi

# Run DB migration and collectstatic only when starting the web server
if [ "$1" = "gunicorn" ] || [ "$1" = "python" -a "$2" = "manage.py" -a "$3" = "runserver" ]; then
    if [ "$SKIP_MIGRATIONS" != "1" ]; then
        echo "Applying database migrations..."
        python manage.py migrate --noinput || echo "Warning: Migration check completed with warnings."
    fi

    if [ "$SKIP_COLLECTSTATIC" != "1" ]; then
        echo "Collecting static files for Whitenoise..."
        python manage.py collectstatic --noinput || echo "Warning: Static file collection completed with warnings."
    fi
fi

exec "$@"
