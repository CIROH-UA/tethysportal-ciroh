{% set TETHYS_PERSIST = salt['environ.get']('TETHYS_PERSIST') %}

{% set FIMBENCH_S3_ALLOWED_HOST = salt['environ.get']('FIMBENCH_S3_ALLOWED_HOST') %}
{% set FIMBENCH_S3_BUCKET_URL   = salt['environ.get']('FIMBENCH_S3_BUCKET_URL') %}
{% set FIMBENCH_S3_CATALOG_KEY  = salt['environ.get']('FIMBENCH_S3_CATALOG_KEY') %}
{% set FIMBENCH_S3_VIZ_TILES    = salt['environ.get']('FIMBENCH_S3_VIZ_TILES') %}

Set_FIMbench_Settings:
  cmd.run:
    - name: >
        tethys app_settings set fimbench-gui s3_allowed_host {{ FIMBENCH_S3_ALLOWED_HOST }} &&
        tethys app_settings set fimbench-gui s3_bucket_url   {{ FIMBENCH_S3_BUCKET_URL }}   &&
        tethys app_settings set fimbench-gui s3_catalog_key  {{ FIMBENCH_S3_CATALOG_KEY }}  &&
        tethys app_settings set fimbench-gui s3_viz_tiles    {{ FIMBENCH_S3_VIZ_TILES }}
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "${TETHYS_PERSIST}/fimbench_complete" ];"

Flag_Tethys_FIMbench_Setup_Complete:
  cmd.run:
    - name: touch {{ TETHYS_PERSIST }}/fimbench_complete
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/fimbench_complete" ];"
