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

PortalLogoutMiddleware (add it to the app's MIDDLEWARE) makes the app's logout
also end the portal session, so signing out of one app signs out of the portal.
"""
import os
from urllib.parse import urlencode

from django.conf import settings
from django.contrib.auth import logout
from django.shortcuts import redirect
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


class PortalLogoutMiddleware:
    """RP-initiated logout: after the app logs the user out, send them to the
    portal's end_session endpoint so the portal session (the SSO hub) ends too.
    The portal then redirects back to this app's root.

    Users who didn't sign in through the portal (break-glass ModelBackend
    admins) get the stock Tethys logout.
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        return self.get_response(request)

    def process_view(self, request, view_func, view_args, view_kwargs):
        if not (
            getattr(view_func, "__module__", "") == "tethys_portal.views.accounts"
            and view_func.__name__ == "logout_view"
            and request.user.is_authenticated
        ):
            return None
        social = request.user.social_auth.filter(
            provider=TethysPortalOpenIdConnect.name
        ).first()
        id_token = (social.extra_data or {}).get("id_token") if social else None
        if not id_token:
            return None
        logout(request)
        # Same https rule social-auth applies to the login redirect_uri, so the
        # URI matches what is registered on the portal behind the ALB.
        app_root = request.build_absolute_uri("/")
        if getattr(settings, "SOCIAL_AUTH_REDIRECT_IS_HTTPS", False):
            app_root = app_root.replace("http://", "https://", 1)
        params = {
            "id_token_hint": id_token,
            "client_id": os.environ.get("TETHYS_PORTAL_OIDC_KEY", ""),
            "post_logout_redirect_uri": app_root,
        }
        endpoint = TethysPortalOpenIdConnect.OIDC_ENDPOINT.rstrip("/")
        return redirect(f"{endpoint}/logout/?{urlencode(params)}")
