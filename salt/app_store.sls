{% set TETHYS_PERSIST = salt['environ.get']('TETHYS_PERSIST') %}
{% set POSTGIS_SERVICE_NAME = 'tethys_postgis' %}


{% set APP_STORE_CS_STORES_SETTINGS = salt['environ.get']('APP_STORE_CS_STORES_SETTINGS') %}
{% set APP_STORE_CS_ENCRYPTION_KEY = salt['environ.get']('APP_STORE_CS_ENCRYPTION_KEY') %}

Set_App_Store_Settings:
  cmd.run:
    - name: > 
        tethys app_settings set app_store stores_settings '{{ APP_STORE_CS_STORES_SETTINGS }}' &&
        tethys app_settings set app_store encryption_key {{ APP_STORE_CS_ENCRYPTION_KEY }}
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "${TETHYS_PERSIST}/app_store_complete" ];"

Flag_Tethys_App_Store_Setup_Complete:
  cmd.run:
    - name: touch {{ TETHYS_PERSIST }}/app_store_complete
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/app_store_complete" ];"