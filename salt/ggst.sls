{% set TETHYS_PERSIST = salt['environ.get']('TETHYS_PERSIST') %}

{% set GGST_CS_THREDDS_DIRECTORY = salt['environ.get']('GGST_CS_THREDDS_DIRECTORY') %}
{% set GGST_CS_THREDDS_CATALOG = salt['environ.get']('GGST_CS_THREDDS_CATALOG') %}
{% set GGST_CS_GLOBAL_OUTPUT_DIRECTORY = salt['environ.get']('GGST_CS_GLOBAL_OUTPUT_DIRECTORY') %}
{% set GGST_CS_EARTHDATA_USERNAME = salt['environ.get']('GGST_CS_EARTHDATA_USERNAME') %}
{% set GGST_CS_EARTHDATA_PASS = salt['environ.get']('GGST_CS_EARTHDATA_PASS') %}
{% set GGST_CS_CONDA_PYTHON_PATH = salt['environ.get']('GGST_CS_CONDA_PYTHON_PATH') %}

Set_GGST_Settings:
  cmd.run:
    - name: > 
        tethys app_settings set ggst grace_thredds_directory {{ GGST_CS_THREDDS_DIRECTORY }} &&
        tethys app_settings set ggst grace_thredds_catalog {{ GGST_CS_THREDDS_CATALOG }} &&
        tethys app_settings set ggst global_output_directory {{ GGST_CS_GLOBAL_OUTPUT_DIRECTORY }} &&
        tethys app_settings set ggst earthdata_username {{ GGST_CS_EARTHDATA_USERNAME }} &&
        tethys app_settings set ggst earthdata_pass {{ GGST_CS_EARTHDATA_PASS }} &&
        tethys app_settings set ggst conda_python_path {{ GGST_CS_CONDA_PYTHON_PATH }}

    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "${TETHYS_PERSIST}/ggst_complete" ];"

Flag_Tethys_GGST_Setup_Complete:
  cmd.run:
    - name: touch {{ TETHYS_PERSIST }}/ggst_complete
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/ggst_complete" ];"