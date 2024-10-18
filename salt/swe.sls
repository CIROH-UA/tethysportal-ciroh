{% set TETHYS_PERSIST = salt['environ.get']('TETHYS_PERSIST') %}

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

{% set THREDDS_SERVICE_NAME = 'swe_tethys_thredds' %}


Create_THREDDS_SWE_Spatial_Dataset_Service:
  cmd.run:
    - name: "tethys services create spatial -t THREDDS -n {{ THREDDS_SERVICE_NAME }} -c {{ THREDDS_SERVICE_PRIVATE_URL }} -p {{ THREDDS_SERVICE_PUBLIC_URL }}"
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/swe_complete" ];"


Link_Spatial_SWE_Thredds_Dataset_Service:
  cmd.run:
    - name: "tethys link spatial:{{ THREDDS_SERVICE_NAME }} swe:ds_spatial:thredds_service"
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "${TETHYS_PERSIST}/swe_complete" ];"

Flag_Tethys_SWE_Setup_Complete:
  cmd.run:
    - name: touch {{ TETHYS_PERSIST }}/swe_complete
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/swe_complete" ];"