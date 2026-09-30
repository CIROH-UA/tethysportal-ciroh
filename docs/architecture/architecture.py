"""CIROH Tethys Portal architecture diagrams.

Regenerate:  pip install diagrams  (needs the graphviz `dot` binary)
             python docs/architecture/architecture.py
Produces two PNGs in this directory:
  - ciroh_portal_infrastructure.png  (EKS / KEDA / Karpenter / AWS state)
  - ciroh_portal_dataflow.png        (sign on, app launch, per app data sources)
"""
from diagrams import Diagram, Cluster, Edge
from diagrams.aws.compute import EKS, EC2, AutoScaling
from diagrams.aws.database import RDS
from diagrams.aws.storage import S3
from diagrams.aws.network import ELB
from diagrams.aws.security import IAMRole
from diagrams.aws.integration import SQS
from diagrams.k8s.compute import Deployment, Pod, Job
from diagrams.k8s.clusterconfig import HPA
from diagrams.onprem.inmemory import Redis
from diagrams.onprem.client import Users
from diagrams.onprem.network import Internet
from diagrams.programming.framework import Django

GATTR = {"fontsize": "20", "labelloc": "t", "pad": "0.5", "nodesep": "0.55", "ranksep": "0.9"}


# ---------------------------------------------------------------- infrastructure
with Diagram(
    "CIROH Tethys Portal, Infrastructure (EKS ciroh-portal-prod, us-east-1)",
    filename="ciroh_portal_infrastructure",
    outformat="png",
    show=False,
    direction="TB",
    graph_attr=GATTR,
):
    users = Users("Users")
    hydroshare = Internet("HydroShare\n(identity via OAuth)")
    alb = ELB("Shared ALB\nciroh-apps")

    with Cluster("AWS data and identity"):
        rds = RDS("RDS Postgres\nciroh-portal-db\nhub DB + tethys_platform_<app> per app")
        s3 = S3("S3 ciroh-portal-assets\nstatic (gzip) + media/<app>/")
        irsa = IAMRole("IRSA ciroh-portal\n(keyless S3)")

    with Cluster("EKS: ciroh-portal-prod"):
        eks = EKS("Control plane")

        with Cluster("namespace: cirohportal"):
            with Cluster("Hub (OIDC provider + launcher)"):
                hpa = HPA("HPA + PDB")
                hub = Deployment("cirohportal-prod\n(lean, no apps)")
                valkey = Redis("valkey\ncache / channels")
                hpa >> hub

            with Cluster("Standalone apps (KEDA scale to zero)"):
                keda = Pod("KEDA HTTP\ninterceptor + scaler")
                apps = [
                    Deployment("<app>.tethys.ciroh.org\nown image + DB"),
                    Deployment("<app>.tethys.ciroh.org\nown image + DB"),
                    Deployment("<app>.tethys.ciroh.org\nown image + DB"),
                ]
                keda >> Edge(label="wake on request") >> apps

            with Cluster("Dask (fimeval, fimserve)"):
                dask_sched = Pod("Dask scheduler")
                dask_worker = Pod("Dask worker\n(autoscaled)")
                dask_sched >> dask_worker

            provision = Job("Provision hook Job\nmigrate + collectstatic->S3\n+ syncstores")

        with Cluster("Karpenter node autoscaling"):
            karpenter = AutoScaling("Karpenter")
            sqs = SQS("Spot interruption queue")
            mng = EC2("Baseline node\n1x c6i.large (on-demand)")
            spot = EC2("Spot nodes\n(elastic, consolidated)")
            sqs >> Edge(style="dashed", label="reclaim") >> karpenter
            karpenter >> Edge(style="dashed", label="provision") >> spot

    users >> Edge(label="https") >> alb
    alb >> Edge(label="tethys.ciroh.org") >> hub
    alb >> Edge(label="<app>.tethys.ciroh.org") >> keda
    users >> Edge(style="dashed", color="darkgreen", label="/static (S3 direct)") >> s3

    hub >> Edge(label="OIDC login") >> hydroshare
    hub >> Edge(label="hub DB") >> rds
    hub >> Edge(label="cache") >> valkey
    apps[1] >> Edge(style="dotted", color="purple", label="OIDC client") >> hub
    apps[0] >> Edge(label="per app DB") >> rds
    apps[2] >> Edge(label="static / media") >> s3
    apps[0] >> Edge(label="offload") >> dask_sched
    irsa >> Edge(style="dashed") >> apps[2]
    provision >> Edge(style="dotted") >> rds
    provision >> Edge(style="dotted") >> s3
    hub >> Edge(style="invis") >> mng


# ------------------------------------------------------------------- data flow
with Diagram(
    "CIROH Tethys Portal, Sign On and App Launch",
    filename="ciroh_portal_dataflow",
    outformat="png",
    show=False,
    direction="LR",
    graph_attr=GATTR,
):
    browser = Users("Browser")

    with Cluster("Single sign on"):
        hub = Django("Portal hub\nOIDC provider /o/\n+ app launcher")
        hydroshare = Internet("HydroShare\n(source of identity)")
        hub >> Edge(label="OAuth") >> hydroshare

    with Cluster("Standalone apps (own image + DB + subdomain)"):
        fim = Django("fimserve\nHAND flood (Dask)")
        mrms = Django("usgs-mrms\nflood alert")
        hydro = Django("hydro-correlation-tool\ngage crosswalk")
        ngiab = Django("ngiab\nmodel run viewer")
        nrds = Django("nrds\nNextGen deck.gl viz")

    with Cluster("Per app state (AWS)"):
        rds = RDS("RDS Postgres\ntethys_platform_<app>")
        s3 = S3("S3 ciroh-portal-assets\nstatic + media/<app>/")

    with Cluster("External data sources"):
        hand = S3("ciroh-owp-hand-fim\nHAND / hydrotable")
        nwm = Internet("NWM v3 retrospective\n(teehr)")
        chf = S3("communityhydrofabric /\nngen-datastream\npmtiles, Arrow")
        apis = Internet("USGS / GEOGLOWS /\nNWM API / MapBox")

    browser >> Edge(label="sign in once") >> hub
    for app in (fim, mrms, hydro, ngiab, nrds):
        browser >> Edge(style="dotted", color="purple", label="launch") >> app
        app >> Edge(style="dotted", color="purple", label="OIDC") >> hub
        app >> Edge(style="dotted", label="own DB") >> rds

    fim >> Edge(color="firebrick", label="HAND") >> hand
    fim >> Edge(color="firebrick", label="streamflow") >> nwm
    mrms >> Edge(color="teal", label="MRMS via IRSA") >> s3
    hydro >> Edge(color="purple", label="gage/reach APIs") >> apis
    ngiab >> Edge(color="navy", label="uploads + runs") >> s3
    nrds >> Edge(color="navy", label="pmtiles + Arrow") >> chf
