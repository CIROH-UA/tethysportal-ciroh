#!/usr/bin/env bash
set -euo pipefail

# CIROH: make the standalone apps' OIDC clients single sign-on friendly. Runs via the base
# provision.sh (init.d loop), after migrate. For every OAuth client registered with a
# `/oauth2/complete/tethys_portal/` redirect (the apps using deploy/oidc), it
#   - skips the "Authorize <app>?" consent screen (first-party apps), and
#   - allows the app's root as post_logout_redirect_uri, so app logout can end the
#     portal session and return to the app.
# Idempotent: only clients that need a change are saved.
PY="$(dirname "$(command -v tethys)")/python"

"$PY" - <<'EOF'
import os
from urllib.parse import urlsplit

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "tethys_portal.settings")
import django

django.setup()
from oauth2_provider.models import get_application_model

CALLBACK = "/oauth2/complete/tethys_portal/"
for app in get_application_model().objects.all():
    roots = sorted({
        "{0.scheme}://{0.netloc}/".format(urlsplit(uri))
        for uri in app.redirect_uris.split()
        if uri.endswith(CALLBACK)
    })
    if not roots:
        continue
    logout_uris = sorted(set(app.post_logout_redirect_uris.split()) | set(roots))
    if app.skip_authorization and app.post_logout_redirect_uris.split() == logout_uris:
        continue
    app.skip_authorization = True
    app.post_logout_redirect_uris = " ".join(logout_uris)
    app.save(update_fields=["skip_authorization", "post_logout_redirect_uris"])
    print(f"  OIDC client {app.name!r}: skip consent, logout returns to {' '.join(roots)}")
EOF
