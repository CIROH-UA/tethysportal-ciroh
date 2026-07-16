# Dependency management

Everything installs with pip (uv) inside the tethys-uvx builder stage; conda is not used.

- **`piprequirements.txt`** - portal-level dependencies, in three groups:
  1. Tethys framework extras (optional features the base image does not carry:
     axes, MFA, captcha, oauth provider, gizmo plotting, jobs/dask, dataset services).
  2. The shared scientific stack plus packages imported by apps that declare no
     dependencies of their own (sweml, hydrocompute, snow-inspector, CSES, fimbench).
  3. Version guards: `numpy==1.26.4` and the matching `pynhd`/`pygeo*` pins. Newer
     releases of those packages require numpy >= 2, which breaks the portal.
- **`overrides.txt`** - uv `--overrides` file used when installing apps whose
  metadata conflicts with the pins above (fimserve_viewer's FIMserv requires
  numpy >= 2; the override keeps 1.26.4).

Apps with proper dependency metadata (tethys_dash, fimserve_viewer, the tethysdash
plugins) bring their own requirements when pip-installed; do not duplicate them here.
