output "helm_release" {
  value = module.airflow
}

output "helm_notes" {
  value = <<EOT
  # When service type is LoadBalancer
  %{if var.helm_release_values_service_type == "LoadBalancer"}
  export AIRFLOW_HOST=$(kubectl get svc --namespace ${var.helm_release_namespace} ${var.helm_release_name} --template "{{ range (index .status.loadBalancer.ingress 0) }}{{ . }}{{ end }}")
  export AIRFLOW_PORT=$(kubectl get svc --namespace ${var.helm_release_namespace} ${var.helm_release_name} -o jsonpath="{ .spec.ports[0].port }")
  %{endif}

  export AIRFLOW_PASSWORD=$(kubectl get secret --namespace "${var.helm_release_namespace}" ${var.helm_release_name} -o jsonpath="{.data.airflow-password}" | base64 --decode)
  export AIRFLOW_FERNETKEY=$(kubectl get secret --namespace "${var.helm_release_namespace}" ${var.helm_release_name} -o jsonpath="{.data.airflow-fernetKey}" | base64 --decode)
  export AIRFLOW_SECRETKEY=$(kubectl get secret --namespace "${var.helm_release_namespace}" ${var.helm_release_name} -o jsonpath="{.data.airflow-secretKey}" | base64 --decode)
  export POSTGRESQL_PASSWORD=$(kubectl get secret --namespace "${var.helm_release_namespace}" ${var.helm_release_name}-postgresql -o jsonpath="{.data.postgresql-password}" | base64 --decode)
  export REDIS_PASSWORD=$(kubectl get secret --namespace "${var.helm_release_namespace}" ${var.helm_release_name}-redis -o jsonpath="{.data.redis-password}" | base64 --decode)

# 2. Complete your Airflow deployment by running:

  helm upgrade --namespace ${var.helm_release_namespace} ${var.helm_release_name} bitnami/airflow \
    --set service.type=${var.helm_release_values_service_type} \
    --set service.port=${var.helm_release_values_service_port} \
  %{if var.helm_release_values_service_type == "LoadBalancer"~}
    --set web.baseUrl=https://$AIRFLOW_HOST:$AIRFLOW_PORT \
  %{endif~}
    --set auth.password=$AIRFLOW_PASSWORD \
    --set auth.fernetKey=$AIRFLOW_FERNETKEY \
    --set auth.secretKey=$AIRFLOW_SECRETKEY \
    --set postgresql.postgresqlPassword=$POSTGRESQL_PASSWORD \
    --set redis.auth.password=$REDIS_PASSWORD \
  EOT
}

