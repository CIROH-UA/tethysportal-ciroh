{% set TETHYS_PERSIST = salt['environ.get']('TETHYS_PERSIST') %}
{% set POSTGIS_SERVICE_NAME = 'tethys_postgis' %}


Link_Persistent_Stores_Database_Tethysdash:
  cmd.run:
    - name: "tethys link persistent:{{ POSTGIS_SERVICE_NAME }} tethysdash:ps_database:primary_db"
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "${TETHYS_PERSIST}/tethysdash_complete" ];"

Run_Alembic_Migrations:
  cmd.run:
    - name: "alembic alembic upgrade head"
    - shell: /bin/bash

Flag_Tethys_Tethysdash_Setup_Complete:
  cmd.run:
    - name: touch {{ TETHYS_PERSIST }}/tethysdash_complete
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/tethysdash_complete" ];"

