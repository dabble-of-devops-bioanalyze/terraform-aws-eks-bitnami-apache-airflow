resource "null_resource" "helm_dirs" {
  provisioner "local-exec" {
    command = "mkdir -p ${var.helm_release_values_dir}"
  }
}

resource "null_resource" "fernet" {
  depends_on = [
    null_resource.helm_dirs
  ]
  provisioner "local-exec" {
    command     = <<EOT
from cryptography.fernet import Fernet
fernet_key= Fernet.generate_key()
print(fernet_key.decode()) # your fernet_key, keep it in secured place!
with open("${var.helm_release_values_dir}/FERNET_SECRET", "w") as f:
  f.write(fernet_key.decode())
    EOT
    interpreter = ["python", "-c"]
  }
}

data "local_file" "fernet" {
  depends_on = [
    null_resource.fernet
  ]
  filename = "${var.helm_release_values_dir}/FERNET_SECRET"
}

data "template_file" "auth" {
  template = file("${path.module}/helm_charts/airflow/auth.yaml.tpl")
  vars = {
    user                             = var.airflow_user
    password                         = var.airflow_password
    fernet                           = data.local_file.fernet.content
    helm_release_values_service_type = var.helm_release_values_service_type
    helm_release_values_service_port = var.helm_release_values_service_port
  }
}

resource "local_file" "rendered_auth" {
  depends_on = [
    data.template_file.auth
  ]
  content  = data.template_file.auth.rendered
  filename = "${var.helm_release_values_dir}/auth.yaml"
}

module "airflow_ingress" {
  count                   = var.enable_ssl == true ? 1 : 0
  source                  = "dabble-of-devops-bioanalyze/eks-bitnami-nginx-ingress/aws"
  version                 = ">= 0.1.0"
  letsencrypt_email       = var.letsencrypt_email
  helm_release_values_dir = var.helm_release_values_dir
  helm_release_name       = var.helm_release_name
}

data "kubernetes_service" "airflow_ingress" {
  count = var.enable_ssl == true ? 1 : 0
  depends_on = [
    module.airflow_ingress
  ]
  metadata {
    name = "${var.helm_release_name}-ingress-nginx-ingress-controller"
  }
}

data "aws_elb" "airflow_ingress" {
  count = var.enable_ssl == true ? 1 : 0
  depends_on = [
    data.kubernetes_service.airflow_ingress
  ]
  name = split("-", data.kubernetes_service.airflow_ingress[0].status.0.load_balancer.0.ingress.0.hostname)[0]
}

data "template_file" "ingress" {
  count    = var.enable_ssl == true ? 1 : 0
  template = file("${path.module}/helm_charts/airflow/ingress.yaml.tpl")
  vars = {
    helm_release_name       = var.helm_release_name
    aws_route53_record_name = var.aws_route53_record_name
    aws_route53_domain_name = trimsuffix(var.aws_route53_zone_name, ".")
    ingress_dns             = data.aws_elb.airflow_ingress[0].dns_name
  }
}

resource "local_file" "rendered_ingress" {
  count = var.enable_ssl == true ? 1 : 0
  depends_on = [
    data.template_file.ingress
  ]
  content  = data.template_file.ingress[0].rendered
  filename = "${var.helm_release_values_dir}/ingress.yaml"
}

locals {
  helm_release_values_files = tolist(distinct(
    compact(flatten([
      [
        [
          try(abspath(local_file.rendered_ingress[0].filename), ""),
          try(abspath(local_file.rendered_aitflow_db[0].filename), ""),
          abspath(local_file.rendered_auth.filename)
        ],
        [for s in var.helm_release_values_files : abspath(s)],
      ]
    ]))
  ))
}
###############External_dabase############
data "template_file" "airflow_external_db" {
  count    = var.use_external_db ? 1 : 0
  template = file("${path.module}/helm_charts/airflow/external_db.yaml.tpl")
  vars = {
    external_db_host   = var.external_db_host,
    external_db_user   = var.external_db_user,
    external_db_secret = var.external_db_secret,
    external_db_name   = var.external_db_name,
    external_db_type   = var.external_db_type,
    external_db_port   = var.external_db_port
  }
}

resource "local_file" "rendered_aitflow_db" {
  count = var.use_external_db ? 1 : 0
  depends_on = [
    data.template_file.airflow_external_db
  ]
  content  = data.template_file.airflow_external_db[0].rendered
  filename = "${var.helm_release_values_dir}/airflow_db_values.yaml"
}


module "merge_values" {
  depends_on = [
    local_file.rendered_aitflow_db,
    local_file.rendered_auth
  ]
  source                          = "dabble-of-devops-biodeploy/merge-values/helm"
  version                         = ">= 0.2.0"
  context                         = module.this.context
  helm_values_dir                 = var.helm_release_values_dir
  helm_values_files               = local.helm_release_values_files
  helm_release_merged_values_file = var.helm_release_merged_values_file
}

resource "helm_release" "airflow" {
  depends_on = [
    module.airflow_ingress,
    module.merge_values,
  ]
  name             = var.helm_release_name
  repository       = var.helm_release_repository
  chart            = var.helm_release_chart
  version          = var.helm_release_version
  namespace        = var.helm_release_namespace
  create_namespace = var.helm_release_create_namespace
  wait             = var.helm_release_wait

  values = [file(var.helm_release_merged_values_file)]
}

resource "null_resource" "sleep_airflow_update" {
  depends_on = [
    helm_release.airflow
  ]
  triggers = {
    always_run = timestamp()
  }
  provisioner "local-exec" {
    command = <<EOT
    echo "Waiting for the airflow service to come up"
    sleep 60
    EOT
  }
}

#########################################################################
# Airflow Service Type == LoadBalancer
#########################################################################
data "kubernetes_service" "airflow" {
  count = var.helm_release_values_service_type == "LoadBalancer" ? 1 : 0
  depends_on = [
    helm_release.airflow,
    null_resource.sleep_airflow_update
  ]
  metadata {
    name      = var.helm_release_name
    namespace = var.helm_release_namespace
  }
}

data "aws_elb" "airflow" {
  count = var.helm_release_values_service_type == "LoadBalancer" ? 1 : 0
  depends_on = [
    helm_release.airflow,
    data.kubernetes_service.airflow,
  ]
  name = split("-", data.kubernetes_service.airflow[0].status.0.load_balancer.0.ingress.0.hostname)[0]
}

output "aws_elb_airflow" {
  value = data.aws_elb.airflow
}

#########################################################################
# helm_release_values_service_type == ClusterIP and var.enable_ssl = true
#########################################################################


data "aws_route53_zone" "airflow" {
  count = var.enable_ssl == true ? 1 : 0
  name  = var.aws_route53_zone_name
}

resource "aws_route53_record" "airflow" {
  count = var.enable_ssl ? 1 : 0
  depends_on = [
    module.airflow_ingress,
    helm_release.airflow,
  ]
  zone_id = data.aws_route53_zone.airflow[0].zone_id
  name    = var.aws_route53_record_name
  type    = "A"
  alias {
    name                   = data.aws_elb.airflow_ingress[0].dns_name
    zone_id                = data.aws_elb.airflow_ingress[0].zone_id
    evaluate_target_health = true
  }
}
