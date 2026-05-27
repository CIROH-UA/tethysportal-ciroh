{% set TETHYS_PERSIST = salt['environ.get']('TETHYS_PERSIST') %}
{% set TETHYS_HOME = salt['environ.get']('TETHYS_HOME') %}
{% set POSTGIS_SERVICE_NAME = 'tethys_postgis' %}


Link_Persistent_Stores_Database_Tethysdash:
  cmd.run:
    - name: "tethys link persistent:{{ POSTGIS_SERVICE_NAME }} tethysdash:ps_database:primary_db"
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "${TETHYS_PERSIST}/tethysdash_complete" ];"

Sync_Dash_App_Persistent_Stores:
  cmd.run:
    - name: tethys syncstores tethysdash
    - shell: /bin/bash

Collect_Plugin_Metadata:
  cmd.run:
  - name: python {{ TETHYS_HOME }}/apps/tethysapp-tethys_dash/tethysapp/tethysdash/collect_plugin_static.py
  - shell: /bin/bash
  - cwd: {{ TETHYS_HOME }}/apps/tethysapp-tethys_dash/tethysapp/tethysdash


Flag_Tethys_Tethysdash_Setup_Complete:
  cmd.run:
    - name: touch {{ TETHYS_PERSIST }}/tethysdash_complete
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/tethysdash_complete" ];"

