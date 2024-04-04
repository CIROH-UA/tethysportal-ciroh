# Dependency Management for Dockerized Python Applications

This project utilizes Docker to containerize a Python application, leveraging both Conda (via Micromamba) and Pip for dependency management. The dependencies are split across two different files to accommodate the availability, compatibility, and installation preferences of each package.

## Dependency Files

- **`requirements.txt`**: Lists the dependencies that are available through Conda. These are installed using Micromamba, benefiting from Conda's environment management and compatibility assurances.
- **`piprequirements.txt`**: Contains dependencies that are not available on Conda or are preferred to be installed via Pip. This allows us to cover packages that are only available in the Python Package Index (PyPI) or have specific version requirements not met by Conda.

## Dockerfile Overview

The Dockerfile follows a multi-stage build process to ensure a lightweight production image. It outlines several key steps:

1. **Dependency Installation**:
   - Conda dependencies (`requirements.txt`) are installed first to leverage Conda's package management.
   - Pip dependencies (`piprequirements.txt`) are installed subsequently to address packages not available through Conda.

## Managing Dependencies

When adding or updating project dependencies, consider the following:

- **Conda First**: Prefer adding dependencies to `requirements.txt` if they are available on Conda, to benefit from Conda's environment and dependency management.
- **Pip as a Fallback**: Use `piprequirements.txt` for packages not found on Conda, or when a specific version is required that's only available via Pip.
