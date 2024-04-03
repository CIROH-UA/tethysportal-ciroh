## tethysportal-ciroh Helm repository

[Helm](https://helm.sh) must be installed to use the charts. Please refer to
Helm's [documentation](https://helm.sh/docs) to get started.

Once Helm has been set up correctly, add the repo as follows:

`helm repo add tethysportal-ciroh https://docs.ciroh.org/tethysportal-ciroh`

If you had already added this repo earlier, run `helm repo update` to retrieve the latest versions of the packages. You can then run `helm search repo tethysportal-ciroh` to see the charts.

To install the chart: `helm install cirohportal tethysportal-ciroh/ciroh`

To uninstall the chart: `helm delete cirohportal tethysportal-ciroh/ciroh`
