"""Smoke-test the portal image: its CIROH modules import and Django's checks pass.

The portal is an OIDC hub with no apps installed (each app is its own image,
tested by build_push_app_images), so this checks what the portal itself ships:
the modules its settings name on PYTHONPATH=/opt/portal, the theme extension,
the HydroShare login backend, and `manage.py check`. Exits non-zero on failure.
"""
import importlib
import sys

import django

# Dotted paths the portal settings (charts/ciroh/values.yaml) and image rely on.
# Extend when the portal config names a new class or module.
REQUIRED = [
    "portal_oidc.CirohOIDCValidator",
    "portal_storage.PortalStaticS3Storage",
    "tethysext.ciroh_theme",
    "tethys_services.backends.hydroshare.HydroShareOAuth2",
    "oauth2_provider.oauth2_validators.OAuth2Validator",
    "storages.backends.s3.S3Storage",
    "channels_redis.core.RedisChannelLayer",
]


def load(path):
    try:
        return importlib.import_module(path)
    except ModuleNotFoundError:
        module, _, name = path.rpartition(".")
        return getattr(importlib.import_module(module), name)


django.setup()
broken = []
for path in REQUIRED:
    try:
        load(path)
        print(f"  PASS  {path}")
    except Exception as exc:  # noqa: BLE001
        broken.append(path)
        print(f"  FAIL  {path}: {type(exc).__name__}: {str(exc)[:160]}")

try:
    from django.core.management import call_command

    call_command("check")
    print("  PASS  manage.py check")
except Exception as exc:  # noqa: BLE001
    broken.append("manage.py check")
    print(f"  FAIL  manage.py check: {type(exc).__name__}: {str(exc)[:300]}")

print(f"\n{len(REQUIRED) + 1} checked, {len(broken)} broken"
      + ("" if not broken else ": " + ", ".join(broken)))
sys.exit(1 if broken else 0)
