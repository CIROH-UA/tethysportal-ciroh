#!/bin/bash

# TETHYS_HOME=$TETHYS_HOME
# TETHYS_PERSIST=$TETHYS_PERSIST

#path to the install files -> we might need to create files <app_name>.yaml in the site_packages folder of the env in which tethys is installed
PATH_INSTALL_FILES=$(${CONDA_HOME}/envs/${CONDA_ENV_NAME}/bin/python -m site | grep -a -m 1 "site-packages" | head -1 | sed 's/.$//' | sed -e 's/^\s*//' -e '/^$/d'| sed 's![^/]*$!!' | cut -c2-)
# TETHYS_PERSIST_HOME="$1"
# PATH_INSTALL_FILES="$2"

#create list of Intalled apps
tethys_list_output=$(tethys list)
apps_strings=$(echo "$tethys_list_output" | awk '/Apps:/{flag=1; next} /Extensions:/{flag=0} flag')
extensions_strings=$(echo "$tethys_list_output" | awk '/Extensions:/{flag=1; next} flag')
apps_arr=("$apps_strings")

# Parse the portal_changes.yaml
# Get the current directory
current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
yaml_file="$current_dir/portal_changes.yml"
# load the YAML file
data=$(cat "$yaml_file")

# Extract the keys from the "apps" level using awk and save them in an array
# apps_to_update=($(echo "$data" | awk '/^apps:/{flag=1; next} /^  [^ ]/{flag=0} flag'))
apps_to_update=($(awk '/^apps:/ {p=1} p && /^  [^ ]+/ {sub(/:/, "", $1); print $1}' "$yaml_file"))

# do not need to have this anymore because of the new setting
# proxy_apps_to_update=($(awk '/^proxy_apps:/ {p=1} p && /^  [^ ]+/ {sub(/:/, "", $1); print $1}' "$yaml_file"))

# iterate over all the installed appps, and udpate the current values of the portal config and then the values of the portal change file
for app_installed in ${apps_arr[@]}; do
    # Check if the app_installed is in the apps_to_update array
    if [[ " ${apps_to_update[@]} " =~ "${app_installed}" ]]; then
        echo "updating ${app_installed}"
        # Execute the command and store the output in a variable
        output=$(tethys app_settings list "$app_installed")
        # Extract unlinked settings
        unlinked_settings=$(echo "$output" | awk '/Unlinked Settings:/{flag=1; next} /Linked Settings:/{flag=0} flag')
        # Extract linked settings
        linked_settings=$(echo "$output" | awk '/Linked With/{flag=1; next} flag')
        # Parse unlinked settings

        IFS=$'\n'
        unlinked_array=()
        for line in $(echo "$unlinked_settings" | awk 'NR>1{print $0}'); do
            id=$(echo "$line" | awk '{print $1}')
            name=$(echo "$line" | awk '{print $2}')
            type=$(echo "$line" | awk '{print $3}')
            unlinked_array+=("{\"ID\": \"$id\", \"Name\": \"$name\", \"Type\": \"$type\"}")
        done

        # Parse linked settings
        IFS=$'\n'
        linked_array=()
        for line in $(echo "$linked_settings" | awk 'NF>1{print $0}'); do
            id=$(echo "$line" | awk '{print $1}')
            name=$(echo "$line" | awk '{print $2}')
            type=$(echo "$line" | awk '{print $3}')
            linked_with=$(echo "$line" | awk '{$1=$2=$3=""; print substr($0,4)}')
            linked_array+=("{\"ID\": \"$id\", \"Name\": \"$name\", \"Type\": \"$type\", \"Linked With\": \"$linked_with\"}")
        done

        #removing single quotes and double quotes if there is json string nested for linked and unlinked serttings
        for ((i=0; i<${#linked_array[@]}; i++)); do
            linked_array[$i]=$(echo "${linked_array[$i]}" | sed 's/"{\(.*\)}"/{\1}/')
            linked_array[$i]="${linked_array[$i]//\'/\"}"
        done

        for ((i=0; i<${#unlinked_array[@]}; i++)); do
            ulinked_array[$i]="${ulinked_array[$i]//\'/\"}"
            ulinked_array[$i]="${ulinked_array[$i]//\'/\"}"
        done

        #update the settings in the apps portion of the portal_config.yaml
        if (( ${#linked_array[@]} )) && (( ${#unlinked_array[@]} )); then
            update_settings="$(python3 "${TETHYS_HOME}/update_tethys_apps.py" --app_name "$app_installed" --linked_settings "${linked_array[@]}" --unlinked_settings "${unlinked_array[@]}")"
        elif (( ${#linked_array[@]} ))
        then
            update_settings="$(python3 "${TETHYS_HOME}/update_tethys_apps.py" --app_name "$app_installed" --linked_settings "${linked_array[@]}")"
        elif (( ${#unlinked_array[@]} ))
        then
            update_settings="$(python3 "${TETHYS_HOME}/update_tethys_apps.py" --app_name "$app_installed" --unlinked_settings "${unlinked_array[@]}")"
        fi

        #install the app again, but this time do it from file
        tethys install -w -q -f "${PATH_INSTALL_FILES}/site-packages/${app_installed}.yml"

    fi

done

#Update the proxy apps only if ther is something in the proxy_apps section of the portal_changes.yaml
# do not need to have this anymore because of the new setting
# if (( ${#proxy_apps_to_update[@]} )); then
#     update_proxy_apps="$(python3 "${TETHYS_HOME}/update_proxy_apps.py")"

# fi