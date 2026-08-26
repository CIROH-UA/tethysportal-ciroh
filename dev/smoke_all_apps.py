"""Import-smoke every installed portal app; exit non-zero if any is broken."""
import importlib
import pkgutil
import sys

import django

django.setup()

# Deep runtime deps a shared pin (numpy/zarr/gdal/...) can silently break and a
# home-page 200 would miss. Extend when an app leans on a fragile native dep.
DEEP_DEPS = {
    "fimserve_viewer": ["fimserve.runFIM", "fimserve.datadownload"],
    "usgs_mrms": ["osgeo.gdal", "mrms_usgs_events.ews.state_rain",
                  "mrms_usgs_events.ews.current_alerts"],
    "community_streamflow_evaluation_system": ["geopandas", "sklearn.metrics"],
    "sweml": ["geopandas"],
    "fimbench_gui": ["osgeo.gdal"],
    "hydro_correlation_tool": ["geoglows", "dataretrieval", "geoalchemy2",
                               "hydroeval", "geopandas"],
}
EXTRA = ["ciroh_plugins"]


def app_packages():
    import tethysapp
    return sorted(m.name for m in pkgutil.iter_modules(tethysapp.__path__))


def check_app(pkg):
    importlib.import_module(f"tethysapp.{pkg}.app")
    try:
        controllers = importlib.import_module(f"tethysapp.{pkg}.controllers")
    except ModuleNotFoundError:
        controllers = None
    if controllers is not None and hasattr(controllers, "__path__"):
        for m in pkgutil.iter_modules(controllers.__path__):
            importlib.import_module(f"tethysapp.{pkg}.controllers.{m.name}")
    for dep in DEEP_DEPS.get(pkg, []):
        importlib.import_module(dep)


import numpy
import zarr

print(f"python {sys.version.split()[0]} | numpy {numpy.__version__} | zarr {zarr.__version__}")

targets = [(f"tethysapp.{p}", p) for p in app_packages()] + [(e, None) for e in EXTRA]
broken = []
for label, pkg in targets:
    try:
        importlib.import_module(label) if pkg is None else check_app(pkg)
        print(f"  PASS  {label}")
    except Exception as exc:  # noqa: BLE001
        broken.append(label)
        print(f"  FAIL  {label}: {type(exc).__name__}: {str(exc)[:160]}")

print(f"\n{len(targets)} checked, {len(broken)} broken"
      + ("" if not broken else ": " + ", ".join(broken)))
raise SystemExit(1 if broken else 0)
