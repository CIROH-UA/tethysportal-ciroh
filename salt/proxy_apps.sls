{% set TETHYS_PERSIST = salt['environ.get']('TETHYS_PERSIST') %}
{% set TETHYS_HOME = salt['environ.get']('TETHYS_HOME') %}
{% set CONDA_HOME = salt['environ.get']('CONDA_HOME') %}
{% set CONDA_ENV_NAME = salt['environ.get']('CONDA_ENV_NAME') %}


Adding_Proxy_Apps:
  cmd.run:
    - name: >
        tethys proxyapp add "OWP NWM Map Viewer" "https://water.noaa.gov/map" "Proxy app for Office in Water Prediction" "/static/ciroh_theme/images/owp.png" "NOAA" True True "https://portal.ciroh.org/t" True True &&
        tethys proxyapp add "CIROH JupyterHub" "https://jupyterhub.cuahsi.org/hub/login" "Proxy app for the CIROH JupyterHub" "/static/ciroh_theme/images/jupyterhub.png" "CUAHSI" True True "https://portal.ciroh.org/t" True True &&
        tethys proxyapp add "HydroShare" "https://water.noaa.gov/map" "Proxy app for the Hydroshare app" "/static/ciroh_theme/images/HydroShare.png" "CUAHSI" True True "https://portal.ciroh.org/t" True True
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/init_apps_setup_complete" ];"

Flag_Proxy_Apps_Complete_Setup:
  cmd.run:
    - name: touch ${TETHYS_PERSIST}/init_proxy_apps_setup_complete
    - shell: /bin/bash
