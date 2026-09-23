#!/bin/bash
# Publishes public/ to rycollins.com on cedar.
#
#   ./deploy.sh            upload and install
#   ./deploy.sh --dry-run  show what would change on the server
#
# Uploads to a staging directory in the ubuntu user's home, then installs into the web root
# as www-data. Nothing is deleted from the web root: it also holds files this repo doesn't
# own (the edgehill mockup, wallpapers), so retire old files by hand.
set -euo pipefail
cd "$(dirname "$0")"

HOST=cedar
STAGE=deploy/rycollins.com
ROOT=/var/www/rycollins.com/

DRY=()
[ "${1:-}" = "--dry-run" ] && DRY=(--dry-run)

ssh "$HOST" "mkdir -p ~/$STAGE"
rsync -az --delete --exclude .DS_Store public/ "$HOST:$STAGE/"
ssh "$HOST" "sudo rsync -rlt --itemize-changes ${DRY[*]:-} --chown=www-data:www-data --chmod=D755,F644 ~/$STAGE/ $ROOT"
if [ ${#DRY[@]} -eq 0 ]; then echo "deployed to https://rycollins.com/"; fi
