locals {
  helm_release_values_files = tolist(distinct(
    compact(flatten([
      [
        [
          try(abspath(local_file.rendered_airflow_db[0].filename), ""),
          try(abspath(local_file.rendered_airflow_remote_logs[0].filename), ""),
          abspath(local_file.rendered_auth.filename)
        ],
        [for s in var.helm_release_values_files : abspath(s)],
      ]
    ]))
  ))
  aws_account_id =  data.aws_caller_identity.current.account_id
  urls = [
    for url in distinct(var.provider_urls):
    replace(url, "https://", "")
  ]
  bucket_name = format("%s-arflow-logs", var.name) 
  helm_release_namespace = var.helm_release_namespace
}

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

resource "local_file" "rendered_airflow_db" {
  count = var.use_external_db ? 1 : 0
  depends_on = [
    data.template_file.airflow_external_db
  ]
  content  = data.template_file.airflow_external_db[0].rendered
  filename = "${var.helm_release_values_dir}/airflow_db_values.yaml"
}

#########################################################################
# var.remote_logging == true
#########################################################################

data "template_file" "airflow_remote_logging" {
  count = var.remote_logging ? 1 : 0
  template = file("${path.module}/helm_charts/airflow/airflow_remote_logs.yaml.tpl")
  vars = {
      remote_base_log_folder = format("s3://%s", local.bucket_name),
      remote_log_conn_id     = var.remote_log_conn_id,
      encrypt_s3_logs        = var.encrypt_s3_logs,
      logging_level          = var.logging_level,
      s3_logs_sa_name        = kubernetes_service_account.eks_s3.metadata[0].name 
  }
}


resource "local_file" "rendered_airflow_remote_logs" {
  count = var.remote_logging ? 1 : 0
  depends_on = [
    data.template_file.airflow_remote_logging
  ]
  content  = data.template_file.airflow_remote_logging[0].rendered
  filename = "${var.helm_release_values_dir}/airflow_remote_logs.yaml"
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

module "s3_bucket" {
  name = local.bucket_name  
  source = "cloudposse/s3-bucket/aws"
  versioning_enabled       = false
  acl                      = "private"
  user_enabled             = false
  allowed_bucket_actions   = ["s3:GetObject", "s3:ListBucket", "s3:GetBucketLocation"]
}

data "aws_iam_policy_document" "s3-logs-eks" {
  depends_on = [module.s3_bucket]
  statement {
    actions   = ["s3:*Object"]
    resources = [format("arn:aws:s3:::%s/*", local.bucket_name)]
    effect    = "Allow"
  }
  statement {
    actions   = ["sts:*"]
    resources = ["*"]
    effect    = "Allow"
  }
  statement {
    actions   = ["s3:ListBucket"]
    resources = [format("arn:aws:s3:::%s", local.bucket_name)]
    effect    = "Allow"
  }
}


resource "aws_iam_policy" "s3-logs-eks" {
  name   = format("%s-s3-logs-eks", var.name)
  path   = "/"
  policy = data.aws_iam_policy_document.s3-logs-eks.json
}

data "aws_iam_policy_document" "assume_role_with_oidc" {
  count = 1

  dynamic "statement" {
    for_each = local.urls

    content {
      effect = "Allow"

      actions = ["sts:AssumeRoleWithWebIdentity"]

      principals {
        type = "Federated"

        identifiers = ["arn:${data.aws_partition.current.partition}:iam::${local.aws_account_id}:oidc-provider/${statement.value}"]
      }

      dynamic "condition" {
        for_each = local.urls 

        content {
          test     = "StringEquals"
          variable = "${statement.value}:aud"
          values   = var.oidc_fully_qualified_subjects
        }
      }

    }
  }
}


resource "aws_iam_role" "logs" {
  assume_role_policy = join("", data.aws_iam_policy_document.assume_role_with_oidc.*.json)
  description =  ""
  managed_policy_arns =  [resource.aws_iam_policy.s3-logs-eks.arn]
  max_session_duration=  3600
  name =  format("%s-airflow-logs-role", var.name)
  path =  "/"
  permissions_boundary =  null
  tags =  {}
}


resource "kubernetes_namespace" "airflow_ns" {
  metadata {
    annotations = {
      name = var.helm_release_namespace 
    }
    name = var.helm_release_namespace
  }
}

resource "kubernetes_service_account" "eks_s3" {
  depends_on = [kubernetes_namespace.airflow_ns]
  metadata {
    name = "clienta-org-s3-aitflow-logs"
    namespace = var.helm_release_namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = format("arn:aws:iam::018835827632:role/%s", aws_iam_role.logs.name) 
    }
  }  
}


module "airflow" {
  depends_on = [
     local_file.rendered_airflow_db,
     local_file.rendered_auth,
     local_file.rendered_airflow_remote_logs
   ]
  source  = "git::https://github.com/dabble-of-devops-bioanalyze/terraform-aws-eks-helm.git"
  # DNS
  aws_route53_record_name    = var.aws_route53_record_name
  aws_elb_zone_id            = var.aws_elb_zone_id
  aws_elb_dns_name           = var.aws_elb_dns_name
  helm_release_name          = var.helm_release_name
  helm_release_repository    = var.helm_release_repository
  helm_release_chart         = var.helm_release_chart
  helm_release_version       = var.helm_release_version
  helm_release_wait          = var.helm_release_wait
  helm_release_values_files  = local.helm_release_values_files //["helm_charts/airflow_values.yaml", "helm_charts/airflow_remote_logs.yaml", "helm_charts/auth.yaml"] 
  helm_release_values_dir    = var.helm_release_values_dir
  enable_ssl                 =  var.enable_ssl
  render_cluster_issuer      =  var.render_cluster_issuer
  use_existing_ingress       =  var.use_existing_ingress
  render_ingress             =  var.render_ingress
  letsencrypt_email          =  var.letsencrypt_email
  aws_route53_zone_name      =  var.aws_route53_zone_name
  aws_route53_zone_id        =  var.aws_route53_zone_id
  helm_release_namespace     =  var.helm_release_namespace
  context                    =  module.this.context

}



resource "null_resource" "sleep_airflow_update" {
  depends_on = [
    module.airflow
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
    module.airflow,
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
    module.airflow,
    data.kubernetes_service.airflow,
  ]
  name = split("-", data.kubernetes_service.airflow[0].status.0.load_balancer.0.ingress.0.hostname)[0]
}

output "aws_elb_airflow" {
  value = data.aws_elb.airflow
}

