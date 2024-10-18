{% set TETHYS_PERSIST = salt['environ.get']('TETHYS_PERSIST') %}
{% set THREDDS_SERVICE_NAME = 'tethys_thredds' %}
{% set GS_SERVICE_NAME = 'tethys_geoserver' %}
{% set POSTGIS_SERVICE_NAME = 'tethys_postgis' %}


{% set TETHYS_HOME = salt['environ.get']('TETHYS_HOME') %}
{% set TETHYS_DB_HOST = salt['environ.get']('TETHYS_DB_HOST') %}
{% set TETHYS_DB_PORT = salt['environ.get']('TETHYS_DB_PORT') %}
{% set POSTGRES_PASSWORD = salt['environ.get']('POSTGRES_PASSWORD') %}
{% set POSTGRES_USER = salt['environ.get']('POSTGRES_USER') %}

{% set TETHYS_GS_HOST = salt['environ.get']('TETHYS_GS_HOST') %}
{% set TETHYS_GS_PASSWORD = salt['environ.get']('TETHYS_GS_PASSWORD') %}
{% set TETHYS_GS_PORT = salt['environ.get']('TETHYS_GS_PORT') %}
{% set TETHYS_GS_USERNAME = salt['environ.get']('TETHYS_GS_USERNAME') %}
{% set TETHYS_GS_PROTOCOL = salt['environ.get']('TETHYS_GS_PROTOCOL') %}

{% set GWDM_CS_DATA_DIRECTORY = salt['environ.get']('GWDM_CS_DATA_DIRECTORY') %}
{% set GWDM_CS_THREDDS_DIRECTORY = salt['environ.get']('GWDM_CS_THREDDS_DIRECTORY') %}
{% set GWDM_CS_THREDDS_CATALOG = salt['environ.get']('GWDM_CS_THREDDS_CATALOG') %}

{% set GWDM_WORKSPACE_NAME = salt['environ.get']('GWDM_WORKSPACE_NAME') %}
{% set GWDM_STORE_NAME = salt['environ.get']('GWDM_STORE_NAME') %}
{% set GWDM_TABLE_NAME = salt['environ.get']('GWDM_TABLE_NAME') %}
{% set GWDM_REGION_LAYER_NAME = salt['environ.get']('GWDM_REGION_LAYER_NAME') %}
{% set GWDM_AQUIFER_LAYER_NAME = salt['environ.get']('GWDM_AQUIFER_LAYER_NAME') %}
{% set GWDM_WELL_LAYER_NAME = salt['environ.get']('GWDM_WELL_LAYER_NAME') %}



Post_Setup_GWDM:
  cmd.run:
    - name: "python {{ TETHYS_HOME }}/post_setup_gwdm.py -gh {{ TETHYS_GS_PROTOCOL }}://{{ TETHYS_GS_HOST }} -p {{ TETHYS_GS_PORT }} -u {{ TETHYS_GS_USERNAME }} -pw {{ TETHYS_GS_PASSWORD }} -s {{ GWDM_STORE_NAME }} -w {{ GWDM_WORKSPACE_NAME }} -db {{ GWDM_TABLE_NAME }} -dbp {{ TETHYS_DB_PORT }} -dbh {{ TETHYS_DB_HOST }} -dbu {{ POSTGRES_USER }} -dbpw {{ POSTGRES_PASSWORD }} -rt {{ GWDM_REGION_LAYER_NAME }} -at {{ GWDM_AQUIFER_LAYER_NAME }} -wt {{ GWDM_WELL_LAYER_NAME }}"
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/post_set_up_gwdm_complete" ];"

Link_Persistent_Stores_Database_GWDM:
  cmd.run:
    - name: "tethys link persistent:{{ POSTGIS_SERVICE_NAME }} gwdm:ps_database:gwdb"
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "${TETHYS_PERSIST}/gwdm_complete" ];"

Link_Spatial_Geoserver_Dataset_Service:
  cmd.run:
    - name: "tethys link spatial:{{ GS_SERVICE_NAME }} gwdm:ds_spatial:primary_geoserver"
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "${TETHYS_PERSIST}/gwdm_complete" ];"

Link_Spatial_Thredds_Dataset_Service:
  cmd.run:
    - name: "tethys link spatial:{{ THREDDS_SERVICE_NAME }} gwdm:ds_spatial:primary_thredds"
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "${TETHYS_PERSIST}/gwdm_complete" ];"

Sync_GWDM_Stores_Persistent_Stores:
  cmd.run:
    - name: tethys syncstores gwdm
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "${TETHYS_PERSIST}/gwdm_complete" ];"

Set_Settings:
  cmd.run:
    - name: > 
        tethys app_settings set gwdm gw_data_directory {{ GWDM_CS_DATA_DIRECTORY }} && 
        tethys app_settings set gwdm gw_thredds_directory {{ GWDM_CS_THREDDS_DIRECTORY }} &&
        tethys app_settings set gwdm gw_thredds_catalog {{ GWDM_CS_THREDDS_CATALOG }}
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "${TETHYS_PERSIST}/gwdm_complete" ];"

Post_Setup_GWDM:
  cmd.run:
    - name: "python {{ TETHYS_HOME }}/post_setup_gwdm.py -gh {{ TETHYS_GS_PROTOCOL }}://{{ TETHYS_GS_HOST }} -p {{ TETHYS_GS_PORT }} -u {{ TETHYS_GS_USERNAME }} -pw {{ TETHYS_GS_PASSWORD }} -s {{ GWDM_STORE_NAME }} -w {{ GWDM_WORKSPACE_NAME }} -db {{ GWDM_TABLE_NAME }} -dbp {{ TETHYS_DB_PORT }} -dbh {{ TETHYS_DB_HOST }} -dbu {{ POSTGRES_USER }} -dbpw {{ POSTGRES_PASSWORD }} -rt {{ GWDM_REGION_LAYER_NAME }} -at {{ GWDM_AQUIFER_LAYER_NAME }} -wt {{ GWDM_WELL_LAYER_NAME }}"
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/gwdm_complete" ];"

Flag_Tethys_GWDM_Setup_Complete:
  cmd.run:
    - name: touch {{ TETHYS_PERSIST }}/gwdm_complete
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/gwdm_complete" ];"



# Some notes on the post_setup_gwdm.py script

  #for debugging the following can be used inside the container.
  #python $TETHYS_HOME/post_setup_gwdm.py -gh $TETHYS_GS_PROTOCOL://$TETHYS_GS_HOST -p $TETHYS_GS_PORT -u $TETHYS_GS_USERNAME -pw $TETHYS_GS_PASSWORD -s $GWDM_STORE_NAME -w $GWDM_WORKSPACE_NAME -db $GWDM_TABLE_NAME -dbp $TETHYS_DB_PORT -dbh $TETHYS_DB_HOST -dbu $POSTGRES_USER -dbpw $POSTGRES_PASSWORD -rt $GWDM_REGION_LAYER_NAME -at $GWDM_AQUIFER_LAYER_NAME -wt $GWDM_WELL_LAYER_NAME

  # the geoservercloud service uses the gateway to proxy the different services (e.g. rest, wms, wfs, etc)
  #http://gateway:8080/rest/workspaces    