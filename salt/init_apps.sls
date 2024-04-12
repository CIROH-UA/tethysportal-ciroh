{% set TETHYS_PERSIST = salt['environ.get']('TETHYS_PERSIST') %}
{% set TETHYS_HOME = salt['environ.get']('TETHYS_HOME') %}
{% set CONDA_HOME = salt['environ.get']('CONDA_HOME') %}
{% set CONDA_ENV_NAME = salt['environ.get']('CONDA_ENV_NAME') %}

{% set FILE_UPLOAD_MAX_MEMORY_SIZE = salt['environ.get']('FILE_UPLOAD_MAX_MEMORY_SIZE') %}
{% set CHANNEL_LAYERS_BACKEND = salt['environ.get']('CHANNEL_LAYERS_BACKEND') %}
{% set CHANNEL_LAYERS_CONFIG = salt['environ.get']('CHANNEL_LAYERS_CONFIG') %}
{% set PREFIX_URL = salt['environ.get']('PREFIX_URL') %}

{% set HYDROSHARE_CLIENT_ID = salt['environ.get']('HYDROSHARE_CLIENT_ID') %}
{% set HYDROSHARE_SECRET_ID = salt['environ.get']('HYDROSHARE_SECRET_ID') %}
{% set AUTHENTICATION_BACKENDS = salt['environ.get']('AUTHENTICATION_BACKENDS') %}
{% set SOCIAL_AUTH_LOGIN_REDIRECT_URL = salt['environ.get']('SOCIAL_AUTH_LOGIN_REDIRECT_URL') %}

Pre_Apps_Settings:
  cmd.run:
    - name: cat {{ TETHYS_HOME }}/portal_config.yml
    - shell: /bin/bash

# If we need to change more settings use this
Set_Tethys_Settings_For_Apps:
  cmd.run:
    - name: >
        tethys settings --set FILE_UPLOAD_MAX_MEMORY_SIZE {{ FILE_UPLOAD_MAX_MEMORY_SIZE }} &&
        tethys settings --set DATA_UPLOAD_MAX_MEMORY_SIZE {{ FILE_UPLOAD_MAX_MEMORY_SIZE }} &&
        tethys settings --set DATA_UPLOAD_MAX_NUMBER_FIELDS {{ FILE_UPLOAD_MAX_MEMORY_SIZE }}

Set_HydroShare_Login:
  cmd.run:
    - name: >
        tethys settings --set AUTHENTICATION_BACKENDS {{ AUTHENTICATION_BACKENDS }} &&
        tethys settings --set OAUTH_CONFIG.SOCIAL_AUTH_HYDROSHARE_KEY {{ HYDROSHARE_CLIENT_ID }} &&
        tethys settings --set OAUTH_CONFIG.SOCIAL_AUTH_HYDROSHARE_SECRET {{ HYDROSHARE_SECRET_ID }} &&
        tethys settings --set OAUTH_CONFIG.SOCIAL_AUTH_LOGIN_REDIRECT_URL {{ SOCIAL_AUTH_LOGIN_REDIRECT_URL }}


{% if PREFIX_URL %}
Set_Prefix_URL_Tethys_Settings:
  cmd.run:
    - name: >
        tethys settings --set PREFIX_URL {{ PREFIX_URL }}
{% endif %}


Sync_Apps:
  cmd.run:
    - name: tethys db sync
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/init_apps_setup_complete" ];"

Update_Tethys_Apps:
  file.managed:
    - name: {{ TETHYS_PERSIST }}/portal_changes.yml
    - source: {{ TETHYS_HOME }}/portal_changes.yml

run_on_apps_hanges:
  cmd.run:
    - name: {{ TETHYS_HOME }}/update_state.sh 
    - shell: /bin/bash
    - onchanges:
      - file: Update_Tethys_Apps

Manage_Proxy_Apps:
  file.managed:
    - name: {{ TETHYS_PERSIST }}/proxy_apps.yml
    - source: {{ TETHYS_HOME }}/proxy_apps.yml

run_on_proxy_apps_changes:
  cmd.run:
    - name: python {{ TETHYS_HOME }}/update_proxy_apps.py
    - shell: /bin/bash
    - onchanges:
      - file: Manage_Proxy_Apps
