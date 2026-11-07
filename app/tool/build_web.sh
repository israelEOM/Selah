#!/usr/bin/env bash
# Builds the Flutter app and the landing site into build/web, ready for tool/serve.py or a Cloudflare Pages deploy.
# Run from app/.
set -euo pipefail
cd "$(dirname "$0")/.."

flutter build web --release --dart-define-from-file=config/beta.json
# The landing page takes /index.html; the app answers its own addresses from app.html (see tool/routes.py).
mv build/web/index.html build/web/app.html
python3 ../site/build.py --out build/web
python3 -c 'import sys; sys.path.insert(0, "tool"); from routes import redirects_file; print(redirects_file(), end="")' > build/web/_redirects
echo "Built build/web"
