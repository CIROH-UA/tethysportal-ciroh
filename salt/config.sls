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
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/init_apps_setup_complete" ];"

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

Sync_App_Persistent_Stores:
  cmd.run:
    - name: tethys syncstores all
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "${TETHYS_PERSIST}/init_apps_setup_complete" ];"

Flag_Complete_Setup:
  cmd.run:
    - name: touch ${TETHYS_PERSIST}/init_apps_setup_complete
    - shell: /bin/bash
