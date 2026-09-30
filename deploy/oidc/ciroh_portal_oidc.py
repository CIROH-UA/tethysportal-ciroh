"""CIROH portal OpenID Connect login backend for standalone Tethys apps.

This module lives in the tethysportal-ciroh deploy overlay, not in any app
repository, and is baked into the app image by the deploy wrapper
(deploy/<app>/Dockerfile). It lets a standalone app authenticate its users
against the CIROH portal's OIDC provider so the portal is the single sign-on hub.
The portal in turn logs users in via HydroShare, so HydroShare remains the source
of identity.

Endpoint and client credentials come from the environment so the same module
serves every app and every tier (prod, staging) without edits:

  TETHYS_PORTAL_OIDC_ENDPOINT  discovery base, e.g. https://tethys.ciroh.org/o
  TETHYS_PORTAL_OIDC_KEY       client_id from the portal's /o/applications/
  TETHYS_PORTAL_OIDC_SECRET    client_secret (inject from a Kubernetes secret)
"""
import os

from social_core.backends.open_id_connect import OpenIdConnectAuth


class TethysPortalOpenIdConnect(OpenIdConnectAuth):
    name = "tethys_portal"
    OIDC_ENDPOINT = os.environ.get(
        "TETHYS_PORTAL_OIDC_ENDPOINT", "https://tethys.ciroh.org/o"
    )
    DEFAULT_SCOPE = ["openid"]
    DEFAULT_USE_PKCE = True

    def get_key_and_secret(self):
        return (
            os.environ.get("TETHYS_PORTAL_OIDC_KEY", ""),
            os.environ.get("TETHYS_PORTAL_OIDC_SECRET", ""),
        )
