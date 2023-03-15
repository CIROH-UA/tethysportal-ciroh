{% set TETHYS_PERSIST = salt['environ.get']('TETHYS_PERSIST') %}
{% set NGINX_READ_TIME_OUT = salt['environ.get']('NGINX_READ_TIME_OUT') %}

Patch_NGINX_TimeOut:
  cmd.run:
    - name: >
        sed -i 'N;/location \@proxy_to_app.*$/a \        proxy_read_timeout {{ NGINX_READ_TIME_OUT }};\n        proxy_connect_timeout {{ NGINX_READ_TIME_OUT }};\n        proxy_send_timeout {{ NGINX_READ_TIME_OUT }};\n' /etc/nginx/sites-enabled/tethys_nginx.conf &&
        cat /etc/nginx/sites-enabled/tethys_nginx.conf
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/apply_nginx_patches_complete" ];"

Apply_NGINX_Patches_Complete_Setup:
  cmd.run:
    - name: touch {{ TETHYS_PERSIST }}/apply_nginx_patches_complete
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/apply_nginx_patches_complete" ];"

# if the config needs to be after
# sed -i '/proxy_pass http:\/\/channels-backend;/a         proxy_read_timeout 300;\n         proxy_connect_timeout 300;\n         proxy_send_timeout 300;\n' tethys_nginx.conf
#https://serverfault.com/questions/1103442/sed-add-a-line-after-match-that-contains-a-new-line