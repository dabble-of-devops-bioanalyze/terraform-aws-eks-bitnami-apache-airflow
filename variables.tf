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

variable "helm_release_namespace" {
  type        = string
  description = "helm release namespace"
  default     = "default"
}

variable "helm_release_version" {
  type        = string
  description = "helm release version"
  default     = "11.0.8"
}

variable "helm_release_wait" {
  type    = bool
  default = true
}

variable "helm_release_create_namespace" {
  type    = bool
  default = true
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

variable "helm_release_merged_values_file" {
  type        = string
  description = "Path to merged helm files. This path must exist before the module is invoked."
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

# these variables are only needed if enable_ssl == true

variable "letsencrypt_email" {
  type        = string
  description = "Email to use for https setup. Not needed unless enable_ssl"
  default     = "hello@gmail.com"
}

variable "aws_route53_zone_name" {
  type        = string
  description = "Name of the zone to add records. Do not forget the trailing '.' - 'test.com.'"
  default     = "test.com."
}

variable "aws_route53_record_name" {
  type        = string
  description = "Record name to add to aws_route_53. Must be a valid subdomain - www,app,etc"
  default     = "www"
}

##################################################
# Module Versions
##################################################

variable "module_helm_merge_values_version" {
  type    = string
  default = "0.2.0"
}

variable "module_aws_eks_bitnami_nginx_ingress_version" {
  type    = string
  default = "0.1.0"
}

variable "external_db_name" {
  default = "airflow"
}

variable "external_db_secret" {
  
}
variable "external_db_user" {
  
}

variable "external_db_type" {
  default = "postgres"
}
variable "external_db_host" {  
}

variable "use_external_db" {
}

variable "external_db_port" {
  default = 5432
}