{% set CONDA_HOME = salt['environ.get']('CONDA_HOME') %}
{% set CONDA_ENV_NAME = salt['environ.get']('CONDA_ENV_NAME') %}
{% set TETHYS_PUBLIC_HOST = salt['environ.get']('TETHYS_PUBLIC_HOST') %}
{% set TETHYS_PERSIST = salt['environ.get']('TETHYS_PERSIST') %}

{% set ENABLE_OPEN_PORTAL = salt['environ.get']('ENABLE_OPEN_PORTAL') %}


{% set HERO_TEXT = salt['environ.get']('HERO_TEXT') %}
{% set BLURB_TEXT = salt['environ.get']('BLURB_TEXT') %}

{% set FEATURE_1_HEADING = salt['environ.get']('FEATURE_1_HEADING') %}
{% set FEATURE_1_BODY = salt['environ.get']('FEATURE_1_BODY') %}
{% set FEATURE_2_HEADING = salt['environ.get']('FEATURE_2_HEADING') %}
{% set FEATURE_2_BODY = salt['environ.get']('FEATURE_2_BODY') %}
{% set FEATURE_3_HEADING = salt['environ.get']('FEATURE_3_HEADING') %}
{% set FEATURE_3_BODY = salt['environ.get']('FEATURE_3_BODY') %}

Site_Settings_CIROH_Theme:
  cmd.run:
    - name: >
        tethys site --site-title "CIROH Portal"
        --apps-library-title "Tools"
        --primary-color "#255f9c"
        --secondary-color "#75acc4"
        --background-color "#ffffff"
        --brand-image "/ciroh_theme/images/CIROHLogo.png"
        --favicon "/ciroh_theme/images/favicon.ico"
        --hero-text "{{ HERO_TEXT }}"
        --blurb-text "{{ BLURB_TEXT }}"
        --feature-1-heading "{{ FEATURE_1_HEADING }}"
        --feature-1-body "{{ FEATURE_1_BODY }}"
        --feature-1-image "/ciroh_theme/images/feature_1.png"
        --feature-2-heading "{{ FEATURE_2_HEADING }}"
        --feature-2-body "{{ FEATURE_2_BODY }}"
        --feature-2-image "/ciroh_theme/images/feature_2.png"
        --feature-3-heading "{{ FEATURE_3_HEADING }}"
        --feature-3-body "{{ FEATURE_3_BODY }}"
        --feature-3-image "/ciroh_theme/images/feature_3.png"
        --copyright "Copyright © 2025 CIROH"
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/ciroh_theme_complete" ];"

Making_Portal_Home_Open:
  cmd.run:
    - name: tethys settings --set TETHYS_PORTAL_CONFIG.ENABLE_OPEN_PORTAL "{{ ENABLE_OPEN_PORTAL }}"
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/ciroh_theme_complete" ];"

Flag_Complete_Setup_CIROH_Theme:
  cmd.run:
    - name: touch {{ TETHYS_PERSIST }}/ciroh_theme_complete
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/ciroh_theme_complete" ];"