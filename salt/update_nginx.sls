{% set TETHYS_PERSIST = salt['environ.get']('TETHYS_PERSIST') %}
{% set NGINX_PORT = salt['environ.get']('NGINX_PORT') %}
{% set CLIENT_MAX_BODY_SIZE = salt['environ.get']('CLIENT_MAX_BODY_SIZE') %}
{% set TETHYS_PORT = salt['environ.get']('TETHYS_PORT') %}

Update_NGINX_Patch:
  cmd.run:
    - name: >
        tethys gen nginx
        --tethys-port {{ TETHYS_PORT }}
        --web-server-port {{ NGINX_PORT }}
        --client-max-body-size {{ CLIENT_MAX_BODY_SIZE }}
        --overwrite
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/update_nginx_patch_complete" ];"


Flag_Update_NGINX_Patch_Setup_Complete:
  cmd.run:
    - name: touch {{ TETHYS_PERSIST }}/update_nginx_patch_complete
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/update_nginx_patch_complete" ];"