{% set TETHYS_PERSIST = salt['environ.get']('TETHYS_PERSIST') %}
{% set NGINX_PORT = salt['environ.get']('NGINX_PORT') %}
{% set CLIENT_MAX_BODY_SIZE = salt['environ.get']('CLIENT_MAX_BODY_SIZE') %}
{% set TETHYS_PORT = salt['environ.get']('TETHYS_PORT') %}
{% set CONDA_ENV_NAME = salt['environ.get']('CONDA_ENV_NAME') %}
{% set CONDA_HOME = salt['environ.get']('CONDA_HOME') %}
{% set ASGI_PROCESSES = salt['environ.get']('ASGI_PROCESSES') %}


Update_ASGI_Patch:
  cmd.run:
    - name: >
        tethys gen asgi_service
        --tethys-port {{ TETHYS_PORT }}
        --asgi-processes {{ ASGI_PROCESSES }}
        --conda-prefix {{ CONDA_HOME }}/envs/{{ CONDA_ENV_NAME }}
        --micromamba
        --overwrite
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/update_asgi_patch_setup_complete" ];"

Flag_Update_ASGI_Patch_Setup_Complete:
  cmd.run:
    - name: touch {{ TETHYS_PERSIST }}/update_asgi_patch_setup_complete
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/update_asgi_patch_setup_complete" ];"