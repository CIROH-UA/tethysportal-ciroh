{% set TETHYS_PERSIST = salt['environ.get']('TETHYS_PERSIST') %}
{% set NGINX_READ_TIME_OUT = salt['environ.get']('NGINX_READ_TIME_OUT') %}
{% set PREFIX_URL = salt['environ.get']('PREFIX_URL') %}
{% set TETHYS_PUBLIC_HOST = salt['environ.get']('TETHYS_PUBLIC_HOST') %}

Patch_NGINX_TimeOut:
  cmd.run:
    - name: >
        sed -i 'N;/location \@proxy_to_app.*$/a \        proxy_read_timeout {{ NGINX_READ_TIME_OUT }};\n        proxy_connect_timeout {{ NGINX_READ_TIME_OUT }};\n        proxy_send_timeout {{ NGINX_READ_TIME_OUT }};\n' /etc/nginx/sites-enabled/tethys_nginx.conf &&
        cat /etc/nginx/sites-enabled/tethys_nginx.conf
    - shell: /bin/bash

# necesary for the hydrocompute app
Add_Wasm_MIME_Type:
  cmd.run:
    - name: >
        sed -i '1s/^/#include mime.types;\n\n/' /etc/nginx/sites-enabled/tethys_nginx.conf && sed -i '2s/^/types {\n    application\/wasm wasm;\n}\n\n/' /etc/nginx/sites-enabled/tethys_nginx.conf &&
        cat /etc/nginx/sites-enabled/tethys_nginx.conf
    - shell: /bin/bash

{% if PREFIX_URL %}
# necesary for prefix path:
Add_Prefix_to_static:
  cmd.run:
    - name: >
          sed -i 's/location \/static/location \/{{ PREFIX_URL }}\/static/g' /etc/nginx/sites-enabled/tethys_nginx.conf &&
          cat /etc/nginx/sites-enabled/tethys_nginx.conf
    - shell: /bin/bash
{% endif %}

#necessary to handle the Invalid HTTP_HOST header error due to dynamic ip addresses
Add_Error_Handler:
  cmd.run:
    - name: > 
          sed -i -e '/location \/workspaces/ { i\    if ( $host !~* ^({{ TETHYS_PUBLIC_HOST }}|www.{{ TETHYS_PUBLIC_HOST }})$ ) {\n        return 444;\n    }\n' -e '}' /etc/nginx/sites-enabled/tethys_nginx.conf &&
          cat /etc/nginx/sites-enabled/tethys_nginx.conf
    - shell: /bin/bash





