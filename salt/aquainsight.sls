{% set TETHYS_PERSIST = salt['environ.get']('TETHYS_PERSIST') %}
{% set POSTGIS_SERVICE_NAME = 'tethys_postgis' %}


Link_Persistent_Stores_Database_Aquainsight:
  cmd.run:
    - name: "tethys link persistent:{{ POSTGIS_SERVICE_NAME }} aquainsight:ps_database:primary_db"
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "${TETHYS_PERSIST}/aquainsight_complete" ];"

Flag_Tethys_AquaInsight_Setup_Complete:
  cmd.run:
    - name: touch {{ TETHYS_PERSIST }}/aquainsight_complete
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/aquainsight_complete" ];"