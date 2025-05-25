"""
CIROH Portal – Kubernetes architecture on AWS EKS
Requires:  `pip install diagrams`
"""

from diagrams import Diagram, Cluster, Edge
from diagrams.onprem.client import Users
from diagrams.aws.network import ALB                         # AWS Application Load Balancer
from diagrams.k8s.compute import Deployment, StatefulSet, Pod
from diagrams.k8s.network import Service
from diagrams.onprem.database import PostgreSQL
from diagrams.onprem.inmemory import Redis

# Diagram appearance
graph_attr = {
    "size": "18,14!",
    "dpi": "300",
    "fontsize": "12",
    "splines": "ortho",
    "rankdir": "TB",
    "nodesep": "1",
    "ranksep": "1",
}

with Diagram(
    "CIROH Portal – Kubernetes Architecture",
    show=False,
    outformat="png",
    graph_attr=graph_attr,
):

    # ──────────────────────────────────────────────────────────
    # External entry‐point
    # ──────────────────────────────────────────────────────────
    user = Users("End-users\n(web browser)")
    alb  = ALB("AWS Application\nLoad Balancer")

    user >> alb

    # ──────────────────────────────────────────────────────────
    # EKS cluster / namespace
    # ──────────────────────────────────────────────────────────
    with Cluster("EKS Cluster – namespace *cirohportal*"):

        # ░░ Ingress controller (AWS LB Controller) ░░
        with Cluster("Ingress controller"):
            alb_controller_dep = Deployment("aws-lb-controller")
            alb_controller_pod = Pod("controller-xxx")
            alb_controller_svc = Service("webhook")
            alb_controller_dep >> alb_controller_pod >> alb_controller_svc

        # ░░ CIROH Portal web app ░░
        with Cluster("cirohportal-prod"):
            portal_dep = Deployment("portal")
            portal_pod = Pod("portal-xxx")
            portal_svc = Service("portal")
            portal_dep >> portal_pod >> portal_svc

        # ░░ THREDDS Data Server ░░
        with Cluster("ciroh-tds"):
            tds_dep = Deployment("tds")
            tds_pod = Pod("tds-xxx")
            tds_svc = Service("tds")
            tds_dep >> tds_pod >> tds_svc

        # ░░ PostgreSQL database ░░
        with Cluster("PostgreSQL"):
            db_dep = Deployment("ciroh-db")
            db_pod = Pod("db-xxx")
            db_svc = Service("db")
            postgres = PostgreSQL("PostgreSQL")
            db_dep >> db_pod >> db_svc >> postgres

        # ░░ Redis ░░
        with Cluster("Redis"):
            redis_sts = StatefulSet("redis-master")
            redis_pod = Pod("redis-0")
            redis_svc = Service("redis")
            redis   = Redis("Redis")
            redis_sts >> redis_pod >> redis_svc >> redis

        # ─── traffic & dependencies ─────────────────────────

        # Public traffic routed by ALB Ingress
        alb >> Edge(label="HTTP / 8080") >> portal_svc
        alb >> Edge(label="HTTP / 8080") >> tds_svc

        # App-internal dependencies
        portal_pod >> Edge(label="5432/TCP") >> db_svc
        portal_pod >> Edge(label="6379/TCP") >> redis_svc
