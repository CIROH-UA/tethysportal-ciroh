{% set TETHYS_PERSIST = salt['environ.get']('TETHYS_PERSIST') %}
{% set TETHYS_HOME = salt['environ.get']('TETHYS_HOME') %}
{% set CONDA_HOME = salt['environ.get']('CONDA_HOME') %}
{% set CONDA_ENV_NAME = salt['environ.get']('CONDA_ENV_NAME') %}

{% set FILE_UPLOAD_MAX_MEMORY_SIZE = salt['environ.get']('FILE_UPLOAD_MAX_MEMORY_SIZE') %}
{% set CHANNEL_LAYERS_BACKEND = salt['environ.get']('CHANNEL_LAYERS_BACKEND') %}
{% set CHANNEL_LAYERS_CONFIG = salt['environ.get']('CHANNEL_LAYERS_CONFIG') %}
{% set PREFIX_URL = salt['environ.get']('PREFIX_URL') %}


{% set ALLOWED_HOSTS = salt['environ.get']('ALLOWED_HOSTS') %}


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


Set_White_Listed_Origins:
  cmd.run:
    - name: >
        tethys settings --set CSRF_TRUSTED_ORIGINS {{ ALLOWED_HOSTS }}

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
