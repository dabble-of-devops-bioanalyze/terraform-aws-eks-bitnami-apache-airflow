##################################################
# Variables
# This file has various groupings of variables
##################################################

##################################################
# AWS
##################################################

variable "region" {
  type        = string
  default     = "us-east-1"
  description = "AWS Region"
}

##################################################
# AWS EKS
##################################################

##################################################
# Helm Release Variables
# corresponds to input to resource "helm_release"
##################################################

# name             = var.airflow_release_name
# repository       = "https://charts.bitnami.com/bitnami"
# chart            = "airflow"
# version          = "11.0.8"
# namespace        = var.airflow_namespace
# create_namespace = true
# wait             = false
# values = [file("helm_charts/airflow/values.yaml")]

variable "helm_release_name" {
  type        = string
  description = "helm release name"
  default     = "airflow"
}

variable "helm_release_repository" {
  type        = string
  description = "helm release chart repository"
  default     = "https://charts.bitnami.com/bitnami"
}

variable "helm_release_chart" {
  type        = string
  description = "helm release chart"
  default     = "airflow"
}


variable "helm_release_version" {
  type        = string
  description = "helm release version"
  default     = "12.0.10"
}

variable "helm_release_wait" {
  type    = bool
  default = false
}

variable "helm_release_values_dir" {
  type        = string
  description = "Directory to put rendered values template files or additional keys. Should be helm_charts/{helm_release_name}"
  default     = "helm_charts"
}

variable "helm_release_values_files" {
  type        = list(string)
  description = "helm release values files - paths values files to add to helm install --values {}"
  default     = []
}


##################################################
# Airflow Specific Variables
##################################################

variable "airflow_user" {
  type        = string
  description = "Initial airflow user"
  default     = "user"
}

variable "airflow_password" {
  type        = string
  description = "Initial airflow password"
  default     = "Password#123"
}

variable "helm_release_values_service_type" {
  type        = string
  description = "Service type to set for exposing the airflow service. The default is to use the ClusterIP and an ingress. Alternative is to use a LoadBalancer, but this only recommended for testing."
  default     = "ClusterIP"
}

variable "helm_release_values_service_port" {
  type        = string
  description = "Service port to set for exposing the airflow service"
  default     = "80"
}

##################################################
# Helm Release Variables - Enable SSL
# corresponds to input to resource "helm_release"
##################################################

variable "enable_ssl" {
  description = "Enable SSL Support?"
  type        = bool
  default     = true
}

variable "render_ingress" {
  type    = bool
  default = true
}

variable "use_existing_ingress" {
  type    = bool
  default = true
}

variable "render_cluster_issuer" {
  type    = bool
  default = false
}

variable "letsencrypt_email" {
  type        = string
  description = "Email to use for https setup. Not needed unless enable_ssl"
  default     = "hello@gmail.com"
}

variable "aws_route53_zone_name" {
  type        = string
  description = "Name of the zone to add records. Do not forget the trailing '.' - 'test.com.'"
  default     = "bioanalyzedev.com."
}

variable "aws_route53_record_name" {
  type        = string
  description = "Record name to add to aws_route_53. Must be a valid subdomain - www,app,etc"
  default     = "www"
}

variable "aws_route53_zone_id" {
  type        = string
  description = "AWS route_53 zone ID for airflow"
  default     = ""

}

##################################################
# External database
##################################################


variable "external_db_name" {
  default = "airflow"
}

variable "external_db_secret" {
  default = ""

}
variable "external_db_user" {
  default = ""

}

variable "external_db_type" {
  default = "postgres"
}

variable "external_db_host" {
  default = ""
}

variable "use_external_db" {
  default = false
}

variable "external_db_port" {
  default = 5432
}

#########################################################################
# Remote logging settings
#########################################################################

variable "remote_logging" {
  default = false
}

variable "remote_base_log_folder" {
  default = ""
}

variable "remote_log_conn_id" {
  default = "aws_default"
}

variable "encrypt_s3_logs" {
  default = "False"
}

variable "logging_level" {
  default = "DEBUG"
}

variable "provider_urls" {
  description = "List of URLs of the OIDC Providers"
  default     = []
}

variable "oidc_fully_qualified_subjects" {
  description = "The fully qualified OIDC subjects to be added to the role policy"
  type        = set(string)
  default     = ["sts.amazonaws.com"]
}


variable "aws_elb_dns_name" {
  type        = string
  description = "DNS of AWS ELB for ingress controller"
}

variable "aws_elb_zone_id" {
  type        = string
  description = "AWS ELB zone id for ingress controller"
}

variable "helm_release_namespace" {
  type        = string
  description = "helm release namespace for BioAnalyze deployment"
}