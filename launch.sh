#!/bin/bash

# This script launches a Laravel development server and a frontend development server.
# It also ensures that all processes are stopped when the script is interrupted (e.g., with Ctrl+C).
cleanup() {
    echo "Stopping all processes..."
    kill $(jobs -p)
    exit 0
}

trap cleanup SIGINT

php artisan serve &
npm run dev &
wait

echo "Both Laravel and frontend servers are running. Press Ctrl+C to stop."
