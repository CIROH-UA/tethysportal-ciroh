"""CIROH Tethys Portal architecture diagrams.

Regenerate:  pip install diagrams  (needs the graphviz `dot` binary)
             python docs/architecture/architecture.py
Produces two PNGs in this directory:
  - ciroh_portal_infrastructure.png  (EKS / Karpenter / AWS state)
  - ciroh_portal_dataflow.png        (apps and the data sources they read)
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
    "CIROH Tethys Portal — Infrastructure (EKS ciroh-portal-prod, us-east-1)",
    filename="ciroh_portal_infrastructure",
    outformat="png",
    show=False,
    direction="TB",
    graph_attr=GATTR,
):
    users = Users("Users\ntethys.ciroh.org")
    alb = ELB("ALB Ingress\n(external)")

    with Cluster("AWS data & identity"):
        rds = RDS("RDS PostGIS\nciroh-portal-db\nplatform DB + jobs_db + primary_db")
        s3 = S3("S3 ciroh-portal-assets\nstatic (S3-direct + gzip)\n+ usgs-mrms data")
        irsa = IAMRole("IRSA ciroh-portal-irsa\n(keyless S3)")

    with Cluster("EKS: ciroh-portal-prod (v1.33)"):
        eks = EKS("Control plane")

        with Cluster("namespace: cirohportal"):
            with Cluster("Portal workload (Tethys / uvicorn)"):
                hpa = HPA("HPA min2/max3 + PDB")
                portal = Deployment("cirohportal-prod\n(mem 12Gi)")
                pods = [Pod("pod"), Pod("pod")]
                hpa >> portal >> pods
            valkey = Redis("valkey\ncache / channels")
            provision = Job("Provision hook Job\nmigrate + collectstatic->S3\n+ syncstores")

        with Cluster("Karpenter node autoscaling"):
            karpenter = AutoScaling("Karpenter (1 replica)")
            sqs = SQS("Spot interruption queue")
            mng = EC2("Core node group\n1x c6i.large (on-demand)")
            spot = EC2("Spot nodes\n(elastic, c-family)")
            sqs >> Edge(style="dashed", label="reclaim") >> karpenter
            karpenter >> Edge(style="dashed", label="provision") >> spot

    users >> Edge(label="https") >> alb >> Edge(label="/apps/*") >> portal
    users >> Edge(style="dashed", color="darkgreen", label="/static (301 -> S3)") >> s3
    portal >> Edge(label="DB + app stores") >> rds
    portal >> Edge(label="cache") >> valkey
    portal >> Edge(label="results / static") >> s3
    irsa >> Edge(style="dashed") >> portal
    provision >> Edge(style="dotted") >> rds
    provision >> Edge(style="dotted") >> s3
    portal >> Edge(style="invis") >> mng  # keep the node group near the workload


# ------------------------------------------------------------------- data flow
with Diagram(
    "CIROH Tethys Portal — Apps & Data Flow",
    filename="ciroh_portal_dataflow",
    outformat="png",
    show=False,
    direction="LR",
    graph_attr=GATTR,
):
    browser = Users("Browser")

    with Cluster("Portal (Tethys) apps — in-process"):
        fim = Django("fimserve_viewer\nHAND flood (JobManager)")
        mrms = Django("usgs_mrms\nflood-alert (JobManager)")
        hydro = Django("hydro_correlation_tool\ngage crosswalk")
        nrds = Django("nrds\nNextGen deck.gl viz")

    with Cluster("Portal state (AWS)"):
        rds = RDS("RDS PostGIS\njobs_db + primary_db")
        s3 = S3("S3 ciroh-portal-assets\nstatic (gzip) + results\n+ nrds slim index")

    with Cluster("External data sources"):
        hand = S3("ciroh-owp-hand-fim\nHAND / hydrotable")
        nwm = Internet("NWM v3 retrospective\n(teehr zarr)")
        chf = S3("communityhydrofabric /\nngen-datastream\npmtiles, Arrow")
        apis = Internet("USGS / GEOGLOWS /\nNWM API / MapBox")

    browser >> Edge(style="dashed", color="darkgreen", label="static + slim index (range reads)") >> s3

    fim >> Edge(color="firebrick", label="HAND") >> hand
    fim >> Edge(color="firebrick", label="streamflow") >> nwm
    fim >> Edge(style="dotted") >> rds
    fim >> Edge(style="dotted") >> s3

    mrms >> Edge(color="teal", label="MRMS/ref via IRSA") >> s3
    mrms >> Edge(style="dotted") >> rds

    hydro >> Edge(color="purple", label="gage/reach APIs") >> apis
    hydro >> Edge(style="dotted", label="cache + crosswalk") >> rds

    nrds >> Edge(color="navy", label="pmtiles + per-VPU Arrow") >> chf
