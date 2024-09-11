# SLS job for HydroShare login and also make the portal an oauth provider

{% set TETHYS_PERSIST = salt['environ.get']('TETHYS_PERSIST') %}


{% set PKCE_REQUIRED = salt['environ.get']('PKCE_REQUIRED') %}
{% set OIDC_ENABLED = salt['environ.get']('OIDC_ENABLED') %}
{% set SCOPES_OPENID = salt['environ.get']('SCOPES_OPENID') %}
{% set OIDC_RSA_PRIVATE_KEY = salt['environ.get']('OIDC_RSA_PRIVATE_KEY') %}

{% set HYDROSHARE_CLIENT_ID = salt['environ.get']('HYDROSHARE_CLIENT_ID') %}
{% set HYDROSHARE_SECRET_ID = salt['environ.get']('HYDROSHARE_SECRET_ID') %}
{% set AUTHENTICATION_BACKENDS = salt['environ.get']('AUTHENTICATION_BACKENDS') %}
{% set SOCIAL_AUTH_LOGIN_REDIRECT_URL = salt['environ.get']('SOCIAL_AUTH_LOGIN_REDIRECT_URL') %}


Set_HydroShare_Login:
  cmd.run:
    - name: >
        tethys settings --set AUTHENTICATION_BACKENDS {{ AUTHENTICATION_BACKENDS }} &&
        tethys settings --set OAUTH_CONFIG.SOCIAL_AUTH_HYDROSHARE_KEY {{ HYDROSHARE_CLIENT_ID }} &&
        tethys settings --set OAUTH_CONFIG.SOCIAL_AUTH_HYDROSHARE_SECRET {{ HYDROSHARE_SECRET_ID }} &&
        tethys settings --set OAUTH_CONFIG.SOCIAL_AUTH_LOGIN_REDIRECT_URL {{ SOCIAL_AUTH_LOGIN_REDIRECT_URL }}

    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/oauth_setup_complete" ];"

Set_Oauth_settings:
  cmd.run:
    - name: >
        tethys settings --set OAUTH_CONFIG.OAUTH2_PROVIDER.PKCE_REQUIRED {{ PKCE_REQUIRED }} &&
        tethys settings --set OAUTH_CONFIG.OAUTH2_PROVIDER.OIDC_ENABLED {{ OIDC_ENABLED }} &&
        tethys settings --set OAUTH_CONFIG.OAUTH2_PROVIDER.SCOPES.openid {{ SCOPES_OPENID }} &&
        tethys settings --set OAUTH_CONFIG.OAUTH2_PROVIDER.OIDC_RSA_PRIVATE_KEY {{ OIDC_RSA_PRIVATE_KEY }}
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/oauth_setup_complete" ];"

Flag_Oauth_Complete:
  cmd.run:
    - name: touch {{ TETHYS_PERSIST }}/oauth_setup_complete
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/oauth_setup_complete" ];"