# CIROH Portal Deployment on AWS

## Prerequisites

- AWS Client (https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- AWS access to specific account/profile (https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html)
- OpenTofu >= 1.9 (https://opentofu.org/docs/intro/install/). The code is plain HCL and
  also validates with Terraform, but the state has been written by OpenTofu since
  2026-10, so use `tofu`.
- A GitLab token (api scope) on git.aquaveo.com with access to
  `tethys/ciroh/cirohportal-terraform-backend`, where the state lives.

## Features

* Karpenter has been added to the cluster in order to save cost per EC2 instaces
  * EKS managed nodes
* EFS instead of the EBS in order to share filesystems between deployments

## Variables (terraform.tfvars) Template

```yaml
region = "aws_region"
profile = "aws_profile"
cluster_name = "tethysportal-ciroh"
kubernetes_version = "1.36"
app_name = "tethysportal"
environment = "prod"
single_nat_gate_way = false
```

Terraform builds the infrastructure only. The portal release is deployed by CI
(`.github/workflows/helm_deploy.yml`), not by Terraform.

## How to Run

The state is GitLab-managed (`prod/backend.tf`). Give the backend your GitLab
credentials through the environment, then work from `prod/`:

```bash
cd terraform/prod
export TF_HTTP_USERNAME=<gitlab user>
export TF_HTTP_PASSWORD=<gitlab token>   # or: $(glab config get token --host git.aquaveo.com)
tofu init
tofu plan     # always read the plan before applying
tofu apply
```

GitLab keeps every state version (project > Operate > Terraform states), so an
earlier one can be restored.

Read the plan before every apply. Things it can show that aren't obvious:

- The EKS add-ons use `most_recent = true`, so a plan upgrades any add-on AWS has
  released a newer build of since the last apply, and the core node group rolls to
  the newest AMI. Apply those in a maintenance window.
- The cluster role (`module.ciroh_portal.module.eks.aws_iam_role.this[0]`) carries a
  hand-added trust statement for an admin user that the EKS module can't express.
  A full apply would remove it; skip it with
  `tofu apply -exclude='module.ciroh_portal.module.eks.aws_iam_role.this[0]'`.
- The EKS module makes the user who applies the cluster KMS key's administrator.

In order to destroy de infrastructure run the following:

```bash
tofu destroy
```

After the first run, you will se the following errors:

```bash
 Error: deleting EC2 Subnet (subnet-0c265a6bb8baa67cb): DependencyViolation: The subnet 'subnet-0c265a6bb8baa67cb' has dependencies and cannot be deleted.
│ 	status code: 400, request id: d71817ae-7a12-481d-a2e3-b28183417894
│
│
╵
╷
│ Error: context deadline exceeded
│
│
╵
╷
│ Error: deleting EC2 Subnet (subnet-09e13f87f1aab0446): DependencyViolation: The subnet 'subnet-09e13f87f1aab0446' has dependencies and cannot be deleted.
│ 	status code: 400, request id: 7a964213-67cd-4152-b229-15eb92763f2e
│
│
╵
╷
│ Error: uninstallation completed with 1 error(s): context deadline exceeded
│
│
╵
╷
│ Error: error detaching EC2 Internet Gateway (igw-0d82c59f9e9149bf1) from VPC (vpc-0799c7288fb67d02c): DependencyViolation: Network vpc-0799c7288fb67d02c has some mapped public address(es). Please unmap those public address(es) before detaching the gateway.
│ 	status code: 400, request id: e77b40e3-a166-47bd-b273-31770990ae05

```

The contexty deadline is only a timeout error while the second indicated is related to two load balancers(internal and internet-facing) that were not deleted with the destruction of the tethys portal. You might need to go to the AWS dashboard and delete them manually.

Run `tofu destroy` again, if the problem ios still the same delete the vpc manually and run again `tofu destroy`

## Configure kubectl

`aws eks update-kubeconfig --name <cluster_name> --region <region> --profile <profile>`

## Specify kubeconfig for OpenTofu

- Unix: KUBE_CONFIG_PATH=/path/to/kubeconfig
- Powershell: $Env:KUBE_CONFIG_PATH=/path/to/kubeconfig

## TroubleShooting

- When the `tofu destroy` command does not work in one run, it can be du to a couple of reasons:
  - The ALB ingress gets destroy before, so the ingresses of the Tethys portal do nto get deleted. You might need to delete them in the AWS dashboard --> EC2--> Load Balancers
  - The VPC cannot be deleted, This is also realted to the ALB ingress being deleted before (leaving the ingresses of the Tethys Portal hanging around after the creation) As a result, the VPC is still being used by these Load Balancers. Delete the Load Balancers, and then the VPC in the AWS dashboard
- Deleting manually can sometimes cause the following error:
  - `Kubernetes cluster unreachable: invalid configuration: no configuration has been provided, try setting KUBERNETES_MASTER environment variable`
  - The following [Github Issue Comment](https://github.com/terraform-aws-modules/terraform-aws-eks/issues/1234#issuecomment-894998800) is helpful
  - The following [Medium Article](https://itnext.io/terraform-dont-use-kubernetes-provider-with-your-cluster-resource-d8ec5319d14a) is helpful as well
- https://github.com/terraform-aws-modules/terraform-aws-eks/issues/2864
