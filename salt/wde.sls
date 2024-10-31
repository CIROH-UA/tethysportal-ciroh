{% set TETHYS_PERSIST = salt['environ.get']('TETHYS_PERSIST') %}
{% set POSTGIS_SERVICE_NAME = 'tethys_postgis' %}


Link_Persistent_Stores_Database_WDE:
  cmd.run:
    - name: "tethys link persistent:{{ POSTGIS_SERVICE_NAME }} water_data_explorer:ps_database:catalog_db"
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "${TETHYS_PERSIST}/wde_complete" ];"

Flag_Tethys_WDE_Setup_Complete:
  cmd.run:
    - name: touch {{ TETHYS_PERSIST }}/wde_complete
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/wde_complete" ];"