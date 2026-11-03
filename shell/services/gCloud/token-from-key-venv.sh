#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source $(eval echo $TAMS_DOTS_VENV)/bin/activate
"$SCRIPT_DIR/token_from_key.py" "$@"
deactivate
