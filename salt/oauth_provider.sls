{% set PKCE_REQUIRED = salt['environ.get']('PKCE_REQUIRED') %}
{% set OIDC_ENABLED = salt['environ.get']('OIDC_ENABLED') %}
{% set OPENID_SCOPE = salt['environ.get']('OPENID_SCOPE') %}
{% set OIDC_RSA_PRIVATE_KEY = salt['environ.get']('OIDC_RSA_PRIVATE_KEY') %}


Set_Tethys_As_Oauth_Provider:
  cmd.run:
    - name: >
        tethys settings --set OAUTH_CONFIG.OAUTH2_PROVIDER.PKCE_REQUIRED {{ PKCE_REQUIRED }} &&
        tethys settings --set OAUTH_CONFIG.OAUTH2_PROVIDER.OIDC_ENABLED {{ OIDC_ENABLED }} &&
        tethys settings --set OAUTH_CONFIG.OAUTH2_PROVIDER.OPENID_SCOPE {{ OPENID_SCOPE }} &&
        tethys settings --set OAUTH_CONFIG.OAUTH2_PROVIDER.OIDC_RSA_PRIVATE_KEY {{ OIDC_RSA_PRIVATE_KEY }}