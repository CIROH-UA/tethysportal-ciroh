<p align="center">
<img align= "center" src="https://ciroh.ua.edu/wp-content/uploads/2022/08/CIROHLogo_200x200.png" width="20%" height="20%"/>
</p>

<h1 align="center"> CIROH Tethys Portal</h1>

## Description

The Ciroh Tethys Portal is composed of the following micro-services:

1. Django CMS
2. Tethys Platform
3. Geoserver Cloud (Geoserver Cloud Native)
4. Thredds Server

The portal contains native Tethys Platform and Proxy applications:

1. [Water Data Explorer](https://github.com/BYU-Hydroinformatics/Water-Data-Explorer.git)
2. [Met Data Explorer](https://github.com/BYU-Hydroinformatics/tethysapp-metdataexplorer.git)
3. [HydroCompute &amp;&amp; HydroLang Tethys Application Demo](https://github.com/tethysplatform/tethysapp-hydrocompute.git)
4. [SWE](https://github.com/Aquaveo/tethysapp-swe.git)
5. [Ground Water Mapper Application](https://github.com/Aquaveo/gwdm.git) (GWDM)
6. [Ground Subsseting Tool](https://github.com/Aquaveo/ggst.git) (GGST)
7. [Snow Inspector](https://github.com/BYU-Hydroinformatics/snow-inspector)
8. [OWP Tethys App](https://github.com/Aquaveo/OWP)
9. [Community Streamflow Evaluation System (CSES) - Tethys Web Application](https://github.com/whitelightning450/Tethys-CSES)
10. [OWP NWM Map Viewer](https://water.noaa.gov/map) (Proxy App)
11. [CIROH JupyterHub](https://jupyterhub.cuahsi.org/hub/login) (Proxy App)
12. [HydroShare](https://www.hydroshare.org/home/) (Proxy App)

## Installation with Cloud Providers

### 1. AWS

The installation through Amazon Web Services (AWS) is done using Terraform

### 1.1 Prerequisites

- AWS Client (https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- AWS access to specific account/profile (https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html)
- Terraform (https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)

### 1.2 Structure of the terraform directory

The terraform directory has three different directories: prod, dev, and modules. The prod and dev directory are for the differetn environment that the user wants to set up.
The modules directory contains the infraestracture to build the ciroh portal, but it comes with two modules: ciroh_portal, and ciroh_portal_dev.
Both modules (ciroh_portal and ciroh_portal_dev) have variables that can be changed such as (name of the cluster, etc)

For example:

```yaml
region = "aws_region"
profile = "aws_profile"
cluster_name = "tethysportal-ciroh"
app_name = "tethysportal"
helm_chart = "./helm_package.tgz"  # add helm package to working directory
helm_values_file = "./values.yaml"  # add custom values.yaml to working directory
```

or

```yaml
region = "aws_region"
profile = "aws_profile"
cluster_name = "tethysportal-ciroh"
app_name = "tethysportal"
helm_chart = "chart_name"
helm_repo = "url_to_helm_repo"
helm_values_file = "./values.yaml" # add custom values.yaml to working directory
```

### 1.3 Deployment

In order to deploy the following commands can needs to be run:

**Configure kubectl**

```bash
#Configure kubectl
aws eks update-kubeconfig --name <cluster_name> --region <region> --profile <profile>
# Initialize the terraform state

terraform init
# Plan the infrastructure
terrafrom plan

# Apply the planned infrastructure
terraform apply
```

If the environment is a development one: the following code needs to be run after the dev env has been tested: `terraform destroy`

**Notes**

When terrafrom is deployed. It deploys the tethys portal using the helm provider. You need to be careful to check the the paths `charts/ciroh/ci/prod_aws_values.yaml` and `charts/ciroh/ci/dev_aws_values.yaml` depending on the environment that you are deploying to. You might need to check that you are using the correct configuration (docker image, etc)

### 1.4 Deployment

Once the deployment is completed, it is not necessary to deploy the whole infrastructure every time there is a change. If there is an update in the image that the portal is using the following command can be used:

```bash
# add the helm repo
helm repo add tethysportal-ciroh https://alabamawaterinstitute.github.io/tethysportal-ciroh

# upgrade the helm chart
helm upgrade <name_deployment> <helm_repo>/<chart> --install --wait --timeout <any_timeout_value> -f <path_to_values>  --set storageClass.parameters.fileSystemId=<storage efs id> --namespace <namespace>

# for example
helm upgrade cirohportal-prod tethysportal-ciroh/ciroh --install --wait --timeout 3600 -f charts/ciroh/ci/prod_aws_values.yaml  --set storageClass.parameters.fileSystemId=MyFileSystemID --set image.tag=crazyTag --namespace cirohportal
```

**Notes**

You need to use the `--set storageClass.parameters.fileSystemId` to upgrade because it was not referenced when the chart was deployed with the terraform scripts. Therefore, you need to do it manually also for the upgrade. Similarly, in the values.yaml that you use you need to have `enabled: true` in the **StorageClass** section or it will produce an error.

If you upgrade fails with the following error:

```bash
Error: UPGRADE FAILED: another operation (install/upgrade/rollback) is in progress

```

you can rollback to a previous revision with:

```bash
helm history <release> --namespace <namespace>
helm rollback <release> <number_release> --namespace <namespace>
```

More on this in the following [medium article](https://medium.com/nerd-for-tech/kubernetes-helm-error-upgrade-failed-another-operation-install-upgrade-rollback-is-in-progress-52ea2c6fcda9)

### 1.5 Troubleshooting

- When the `terraform destroy` command does not work in one run, it can be du to a couple of reasons:
  - The ALB ingress gets destroy before, so the ingresses of the Tethys portal do nto get deleted. You might need to delete them in the AWS dashboard --> EC2--> Load Balancers
  - The VPC cannot be deleted, This is also realted to the ALB ingress being deleted before (leaving the ingresses of the Tethys Portal hanging around after the creation) As a result, the VPC is still being used by these Load Balancers. Delete the Load Balancers, and then the VPC in the AWS dashboard
- Deleting manually can sometimes cause the following error:
  - `Kubernetes cluster unreachable: invalid configuration: no configuration has been provided, try setting KUBERNETES_MASTER environment variable`
  - The following [Github Issue Comment](https://github.com/terraform-aws-modules/terraform-aws-eks/issues/1234#issuecomment-894998800) is helpful
  - The following [Medium Article](https://itnext.io/terraform-dont-use-kubernetes-provider-with-your-cluster-resource-d8ec5319d14a) is helpful as well

### 1.6 Useful Tool

Monitoring cluster and deployments: [k9s](https://k9scli.io/)
Visualizing dynamic node usage within a cluster: [eks-node-viewer](https://github.com/awslabs/eks-node-viewer)

### 1.7 Development

when updating git submodules the following can be useful: https://stackoverflow.com/questions/29882960/changing-an-existing-submodules-branch
