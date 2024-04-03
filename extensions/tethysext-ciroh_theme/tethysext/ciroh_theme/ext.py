from tethys_sdk.base import TethysExtensionBase


class CirohTheme(TethysExtensionBase):
    """
    Tethys extension class for Ciroh Theme.
    """

    name = 'Ciroh Theme'
    package = 'ciroh_theme'
    root_url = 'ciroh-theme'
    description = 'Extension for the style and theming of the CIROH Tethys portal'