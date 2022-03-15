serviceAccount:
  create: false
  name: ${s3_logs_sa_name}
worker:  
  extraEnvVars:
    - name: GIT_DISCOVERY_ACROSS_FILESYSTEM
      value: 'True'
    - name: AIRFLOW__LOGGING__REMOTE_LOGGING
      value: 'True'
    - name: AIRFLOW__LOGGING__REMOTE_BASE_LOG_FOLDER
      value: '${remote_base_log_folder}'
    - name: AIRFLOW__LOGGING__REMOTE_LOG_CONN_ID
      value: '${remote_log_conn_id}'
    - name: AIRFLOW__LOGGING__ENCRYPT_S3_LOGS
      value: '${encrypt_s3_logs}'
    - name: AIRFLOW__LOGGING__LOGGING_LEVEL
      value: '${logging_level}'
scheduler:
  extraEnvVars:
    - name: GIT_DISCOVERY_ACROSS_FILESYSTEM
      value: 'True'
    - name: AIRFLOW__LOGGING__REMOTE_LOGGING
      value: 'True'
    - name: AIRFLOW__LOGGING__REMOTE_BASE_LOG_FOLDER
      value: '${remote_base_log_folder}'
    - name: AIRFLOW__LOGGING__REMOTE_LOG_CONN_ID
      value: '${remote_log_conn_id}'
    - name: AIRFLOW__LOGGING__ENCRYPT_S3_LOGS
      value: '${encrypt_s3_logs}'
    - name: AIRFLOW__LOGGING__LOGGING_LEVEL
      value: '${logging_level}'
web:
  extraEnvVars:
    - name: GIT_DISCOVERY_ACROSS_FILESYSTEM
      value: 'True'
    - name: AIRFLOW__LOGGING__REMOTE_LOGGING
      value: 'True'
    - name: AIRFLOW__LOGGING__REMOTE_BASE_LOG_FOLDER
      value: '${remote_base_log_folder}'
    - name: AIRFLOW__LOGGING__REMOTE_LOG_CONN_ID
      value: '${remote_log_conn_id}'
    - name: AIRFLOW__LOGGING__ENCRYPT_S3_LOGS
      value: '${encrypt_s3_logs}'
    - name: AIRFLOW__LOGGING__LOGGING_LEVEL
      value: '${logging_level}'
     