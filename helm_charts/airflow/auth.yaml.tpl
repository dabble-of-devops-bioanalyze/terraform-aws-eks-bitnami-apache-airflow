## @section Airflow common parameters

## Authentication
## @param auth.existingSecret Name of an existing secret containing password and fernet key ('airflow-password and 'airflow-fernetKey' keys)
## @param auth.fernetKey Fernet key to secure connections
## @param auth.forcePassword Force users to specify a password
## @param auth.password Password to access web UI
## @param auth.username Username to access web UI
##

auth:
  existingSecret: ""
  ## More info about the fernet key at:
  ## - https://airflow.readthedocs.io/en/stable/howto/secure-connections.html
  ## - https://bcb.github.io/airflow/fernet-key
  ##
  fernetKey: ${fernet}
  ## This is required for 'helm upgrade' to work properly.
  ## If it is not forced, a random password will be generated.
  ##
  forcePassword: false
  password: ${password}
  username: ${user}

## Airflow service parameters. For minikube, set this to NodePort, elsewhere use LoadBalancer
## @param service.type Airflow service type
## @param service.port Airflow service HTTP port
## @param service.nodePort Airflow service NodePort
## @param service.loadBalancerIP loadBalancerIP if service type is `LoadBalancer` (optional, cloud specific)
## @param service.annotations Additional custom annotations for Airflow service
##
service:
  type: ${helm_release_values_service_type}
  port: ${helm_release_values_service_port}