import yaml
import logging
import os
import subprocess

logging.basicConfig(format="%(asctime)s - %(message)s", level=logging.INFO)

script_dir = os.environ["TETHYS_HOME"]
proxy_apps_path = os.path.join(script_dir, "proxy_apps.yml")


def add_proxy_app(proxy_app, name_app):
    name = proxy_app.get("name")
    endpoint = proxy_app.get("endpoint")
    logo_url = proxy_app.get("logo_url", "")
    description = proxy_app.get("description", "")
    tags = proxy_app.get("tags", "")
    enabled = proxy_app.get("enabled", True)
    show_in_apps_library = proxy_app.get("show_in_apps_library", True)
    back_url = proxy_app.get("back_url", "")
    open_in_new_tab = proxy_app.get("open_in_new_tab", True)
    display_external_icon = proxy_app.get("display_external_icon", False)
    order = proxy_app.get("order", 0)
    try:
        add_result = subprocess.run(
            [
                "tethys",
                "proxyapp",
                "add",
                f"{name_app}",
                f"{endpoint}",
                f"{description}",
                f"{logo_url}",
                f"{tags}",
                f"{enabled}",
                f"{show_in_apps_library}",
                f"{back_url}",
                f"{open_in_new_tab}",
                f"{display_external_icon}",
                f"{order}",
            ]
        )
        if add_result.returncode == 1:
            logging.error(f"proxy app {name_app} not added")
            return False
        logging.info(f"proxy app {name_app} added successfully")
    except Exception as e:
        logging.error(f"proxy app {name_app} not added: {e}")
        return False


def add_proxy_apps():
    try:
        with open(proxy_apps_path) as portal_changes:
            ymlportal_changes = yaml.safe_load(portal_changes)
            proxy_apps = ymlportal_changes.get("proxy_apps", {})
            for proxy_app in proxy_apps:
                add_proxy_app(proxy_apps[proxy_app], proxy_app)

    except Exception as e:
        logging.error(f"It was not possible to add all the proxy apps: {e}")


# This an temporary patch until the bug in the tethys platform for proxy apps gets sorted
def update_proxy_app_tmp_patch(proxy_app, name_app):
    name = proxy_app.get("name")
    endpoint = proxy_app.get("endpoint")
    logo_url = proxy_app.get("logo_url", "")
    description = proxy_app.get("description", "")
    tags = proxy_app.get("tags", "")
    enabled = proxy_app.get("enabled", True)
    show_in_apps_library = proxy_app.get("show_in_apps_library", True)
    back_url = proxy_app.get("back_url", "")
    open_in_new_tab = proxy_app.get("open_in_new_tab", True)
    display_external_icon = proxy_app.get("display_external_icon", False)
    order = proxy_app.get("order", 0)
    try:
        subprocess.run(
            [
                "tethys",
                "proxyapp",
                "update",
                f"{name_app}",
                "--set",
                "name",
                f"{name}",
            ],
            capture_output=True,
        )
        update_result = subprocess.run(
            [
                "tethys",
                "proxyapp",
                "update",
                f"{name}",
                "--set",
                "name",
                f"{name}",
                "--set",
                "endpoint",
                f"{endpoint}",
                "--set",
                "description",
                f'"{description}"',
                "--set",
                "logo_url",
                f"{logo_url}",
                "--set",
                "back_url",
                f"{back_url}",
                "--set",
                "tags",
                f'"{tags}"',
                "--set",
                "enabled",
                f"{enabled}",
                "--set",
                "show_in_apps_library",
                f"{show_in_apps_library}",
                "--set",
                "open_in_new_tab",
                f"{open_in_new_tab}",
                "--set",
                "display_external_icon",
                f"{display_external_icon}",
                "--set",
                "order",
                f"{order}",
            ],
            capture_output=True,
        )
        if update_result.stderr.decode("utf-8") != "":
            logging.error(
                f"proxy app {name_app} not added: {update_result.stderr.decode('utf-8')}"
            )
        if (
            f"Proxy app '{name_app}' was updated successfully"
            in update_result.stdout.decode("utf-8")
        ):
            logging.info(f"proxy app {name_app} was updated successfully")

        if (
            f"Proxy app named '{name_app}' does not exist"
            in update_result.stdout.decode("utf-8")
        ):
            add_proxy_app(proxy_app, name_app)

    except Exception as e:
        logging.error(f"proxy app {name_app} not updated: {e}")
        return False


def update_proxy_app(proxy_app, name_app):
    name = proxy_app.get("name")
    endpoint = proxy_app.get("endpoint")
    logo_url = proxy_app.get("logo_url", "")
    description = proxy_app.get("description", "")
    tags = proxy_app.get("tags", "")
    enabled = proxy_app.get("enabled", True)
    show_in_apps_library = proxy_app.get("show_in_apps_library", True)
    back_url = proxy_app.get("back_url", "")
    open_in_new_tab = proxy_app.get("open_in_new_tab", True)
    display_external_icon = proxy_app.get("display_external_icon", False)
    order = proxy_app.get("order", 0)
    try:
        update_result = subprocess.run(
            [
                "tethys",
                "proxyapp",
                "update",
                f"{name_app}",
                "--set",
                "name",
                f"{name}",
                "--set",
                "endpoint",
                f"{endpoint}",
                "--set",
                "description",
                f'"{description}"',
                "--set",
                "logo_url",
                f"{logo_url}",
                "--set",
                "back_url",
                f"{back_url}",
                "--set",
                "tags",
                f'"{tags}"',
                "--set",
                "enabled",
                f"{enabled}",
                "--set",
                "show_in_apps_library",
                f"{show_in_apps_library}",
                "--set",
                "open_in_new_tab",
                f"{open_in_new_tab}",
                "--set",
                "display_external_icon",
                f"{display_external_icon}",
                "--set",
                "order",
                f"{order}",
            ],
            capture_output=True,
        )
        logging.info(f"{update_result}")
        if update_result.stderr.decode("utf-8") != "":
            logging.error(
                f"proxy app {name_app} not added: {update_result.stderr.decode('utf-8')}"
            )
        if (
            f"Proxy app '{name_app}' was updated successfully"
            in update_result.stdout.decode("utf-8")
        ):
            logging.info(f"proxy app {name_app} was updated successfully")

        if (
            f"Proxy app named '{name_app}' does not exist"
            in update_result.stdout.decode("utf-8")
        ):
            add_proxy_app(proxy_app, name_app)

    except Exception as e:
        logging.error(f"proxy app {name_app} not updated: {e}")
        return False


def update_proxy_apps():
    try:
        with open(proxy_apps_path) as proxy_apps_yaml:
            yml_proxy_apps = yaml.safe_load(proxy_apps_yaml)
            proxy_apps = yml_proxy_apps.get("proxy_apps", {})
            for proxy_app in list(proxy_apps):
                if proxy_app != proxy_apps[proxy_app].get("name", "") and proxy_apps[
                    proxy_app
                ].get("name", ""):
                    # erase once the bug has been fixed
                    update_proxy_app_tmp_patch(proxy_apps[proxy_app], proxy_app)
                    proxy_apps[proxy_apps[proxy_app]["name"]] = proxy_apps[proxy_app]
                    del proxy_apps[proxy_app]
                else:
                    update_proxy_app(proxy_apps[proxy_app], proxy_app)

        with open(proxy_apps_path, "w") as proxy_apps_yaml:
            yaml.dump(yml_proxy_apps, proxy_apps_yaml)
    except Exception as e:
        logging.error(f"It was not possible to update all the proxy apps: {e}")


def manage_proxy_apps():
    list_pa = subprocess.run(["tethys", "proxyapp", "list"], capture_output=True)
    if "Proxy Apps:" in list_pa.stdout.decode("utf-8").split("\n")[-2]:
        add_proxy_apps()
    else:
        update_proxy_apps()


def main():
    manage_proxy_apps()


if __name__ == "__main__":
    main()
