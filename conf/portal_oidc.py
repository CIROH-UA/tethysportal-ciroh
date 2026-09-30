"""OIDC identity claims for the CIROH portal as an OpenID Connect provider.

Django OAuth Toolkit's default userinfo returns only `sub` (the user UUID), so
standalone apps end up labelling users by that UUID. This validator adds
`preferred_username`, `name`, and `email` (gated by the `profile` and `email`
scopes) so an app shows the real HydroShare username and name instead.
"""
from oauth2_provider.oauth2_validators import OAuth2Validator


class CirohOIDCValidator(OAuth2Validator):
    oidc_claim_scope = {
        **(OAuth2Validator.oidc_claim_scope or {}),
        "preferred_username": "profile",
    }

    def get_additional_claims(self, request):
        user = request.user
        full_name = (user.get_full_name() or "").strip()
        return {
            "preferred_username": user.get_username(),
            "name": full_name or user.get_username(),
            "given_name": user.first_name or "",
            "family_name": user.last_name or "",
            "email": user.email or "",
        }
