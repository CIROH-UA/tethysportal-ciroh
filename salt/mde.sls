{% set TETHYS_PERSIST = salt['environ.get']('TETHYS_PERSIST') %}
{% set POSTGIS_SERVICE_NAME = 'tethys_postgis' %}


{% set MDE_CS_DISCLAIMER_HEADER = salt['environ.get']('MDE_CS_DISCLAIMER_HEADER') %}
{% set MDE_CS_DISCLAIMER_MESSAGE = salt['environ.get']('MDE_CS_DISCLAIMER_MESSAGE') %}
{% set MDE_CS_SERVER_HOME_DIRECTORY = salt['environ.get']('MDE_CS_SERVER_HOME_DIRECTORY') %}


Link_Persistent_Stores_Database_MDE:
  cmd.run:
    - name: "tethys link persistent:{{ POSTGIS_SERVICE_NAME }} metdataexplorer:ps_database:thredds_db"
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "${TETHYS_PERSIST}/mde_complete" ];"

Set_Settings:
  cmd.run:
    - name: > 
        tethys app_settings set metdataexplorer disclaimer_header {{ MDE_CS_DISCLAIMER_HEADER }} &&
        tethys app_settings set metdataexplorer disclaimer_message {{ MDE_CS_DISCLAIMER_MESSAGE }} &&
        tethys app_settings set metdataexplorer server_home_directory {{ MDE_CS_SERVER_HOME_DIRECTORY }}

    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "${TETHYS_PERSIST}/mde_complete" ];"

Flag_Tethys_MDE_Setup_Complete:
  cmd.run:
    - name: touch {{ TETHYS_PERSIST }}/mde_complete
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/mde_complete" ];"