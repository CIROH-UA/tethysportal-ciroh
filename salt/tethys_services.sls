{% set TETHYS_PERSIST = salt['environ.get']('TETHYS_PERSIST') %}
{% set TETHYS_DB_HOST = salt['environ.get']('TETHYS_DB_HOST') %}
{% set TETHYS_DB_PORT = salt['environ.get']('TETHYS_DB_PORT') %}
{% set TETHYS_DB_SUPERUSER = salt['environ.get']('TETHYS_DB_SUPERUSER') %}
{% set TETHYS_DB_SUPERUSER_PASS = salt['environ.get']('TETHYS_DB_SUPERUSER_PASS') %}

{% set THREDDS_TDS_USERNAME = salt['environ.get']('THREDDS_TDS_USERNAME') %}
{% set THREDDS_TDS_PASSWORD = salt['environ.get']('THREDDS_TDS_PASSWORD') %}
{% set THREDDS_TDS_CATALOG = salt['environ.get']('THREDDS_TDS_CATALOG') %}
{% set THREDDS_TDS_PRIVATE_PROTOCOL = salt['environ.get']('THREDDS_TDS_PRIVATE_PROTOCOL') %}
{% set THREDDS_TDS_PRIVATE_HOST = salt['environ.get']('THREDDS_TDS_PRIVATE_HOST') %}
{% set THREDDS_TDS_PRIVATE_PORT = salt['environ.get']('THREDDS_TDS_PRIVATE_PORT') %}
{% set THREDDS_TDS_PUBLIC_PROTOCOL = salt['environ.get']('THREDDS_TDS_PUBLIC_PROTOCOL') %}
{% set THREDDS_TDS_PUBLIC_HOST = salt['environ.get']('THREDDS_TDS_PUBLIC_HOST') %}
{% set THREDDS_TDS_PUBLIC_PORT = salt['environ.get']('THREDDS_TDS_PUBLIC_PORT') %}
{% set THREDDS_SERVICE_NAME = 'tethys_thredds' %}
{% set THREDDS_SERVICE_PRIVATE_URL = THREDDS_TDS_USERNAME + ':' + THREDDS_TDS_PASSWORD + '@' + THREDDS_TDS_PRIVATE_PROTOCOL +'://' + THREDDS_TDS_PRIVATE_HOST + ':' + THREDDS_TDS_PRIVATE_PORT + THREDDS_TDS_CATALOG %}
{% set THREDDS_SERVICE_PUBLIC_URL = THREDDS_TDS_PUBLIC_PROTOCOL +'://' + THREDDS_TDS_PUBLIC_HOST + ':' + THREDDS_TDS_PUBLIC_PORT + THREDDS_TDS_CATALOG %}

{% set TETHYS_GS_HOST = salt['environ.get']('TETHYS_GS_HOST') %}
{% set TETHYS_GS_PASSWORD = salt['environ.get']('TETHYS_GS_PASSWORD') %}
{% set TETHYS_GS_PORT = salt['environ.get']('TETHYS_GS_PORT') %}
{% set TETHYS_GS_USERNAME = salt['environ.get']('TETHYS_GS_USERNAME') %}
{% set TETHYS_GS_PROTOCOL = salt['environ.get']('TETHYS_GS_PROTOCOL') %}
{% set TETHYS_GS_HOST_PUB = salt['environ.get']('TETHYS_GS_HOST_PUB') %}
{% set TETHYS_GS_PORT_PUB = salt['environ.get']('TETHYS_GS_PORT_PUB') %}
{% set TETHYS_GS_PROTOCOL_PUB = salt['environ.get']('TETHYS_GS_PROTOCOL_PUB') %}
{% set TETHYS_GS_URL = TETHYS_GS_PROTOCOL +'://' + TETHYS_GS_USERNAME + ':' + TETHYS_GS_PASSWORD + '@' + TETHYS_GS_HOST + ':' + TETHYS_GS_PORT %}
{% set TETHYS_GS_URL_PUB = TETHYS_GS_PROTOCOL_PUB +'://' + TETHYS_GS_USERNAME + ':' + TETHYS_GS_PASSWORD + '@' + TETHYS_GS_HOST_PUB + ':' + TETHYS_GS_PORT_PUB %}
{% set GS_SERVICE_NAME = 'tethys_geoserver' %}

{% set POSTGIS_SERVICE_NAME = 'tethys_postgis' %}
{% set POSTGIS_SERVICE_URL = TETHYS_DB_SUPERUSER + ':' + TETHYS_DB_SUPERUSER_PASS + '@' + TETHYS_DB_HOST + ':' + TETHYS_DB_PORT %}

{% set TETHYS_CLUSTER_PKEY_PASSWORD = salt['environ.get']('TETHYS_CLUSTER_PKEY_PASSWORD') %}


Create_PostGIS_Database_Service:
  cmd.run:
    - name: "tethys services create persistent -n {{ POSTGIS_SERVICE_NAME }} -c {{ POSTGIS_SERVICE_URL }}"
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/tethys_services_complete" ];"

Create_THREDDS_Spatial_Dataset_Service:
  cmd.run:
    - name: "tethys services create spatial -t THREDDS -n {{ THREDDS_SERVICE_NAME }} -c {{ THREDDS_SERVICE_PRIVATE_URL }} -p {{ THREDDS_SERVICE_PUBLIC_URL }}"
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/tethys_services_complete" ];"

## this needs to be checked, the tethys command uses
##check#1
Create_GeoServer_Spatial_Dataset_Service:
  cmd.run:
    - name: "tethys services create spatial -t GeoServer -n {{ GS_SERVICE_NAME }} -c {{ TETHYS_GS_USERNAME }}:{{ TETHYS_GS_PASSWORD }}@{{ TETHYS_GS_PROTOCOL }}://{{ TETHYS_GS_HOST }}:{{ TETHYS_GS_PORT }} -p {{ TETHYS_GS_PROTOCOL_PUB }}://{{ TETHYS_GS_HOST_PUB }}:{{ TETHYS_GS_PORT_PUB }}"
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/tethys_services_complete" ];"

Flag_Tethys_Services_Setup_Complete:
  cmd.run:
    - name: touch {{ TETHYS_PERSIST }}/tethys_services_complete
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/tethys_services_complete" ];"