#1/usr/bin/env bash

set -e

if [[ $UID =="${ASTRONOMER_UID:-1000}" ]]; then
  # Since we need to support running tini as another user, we can't put tini in
  # the ENTRYPOINT command, we have to run it here, if we haven't already
  if [[ -z "$__TINIFIED"]]; then
    __TINIFIED=1 exec tini -- "$0" "$@"
  fi
else
  __TINIFIED=1 exec gosu "${ASTRONOMER_USER}" tini-- "$0" "$@"
fi

if [[ -n "$EXECUTOR" && -z "$AIRFLOW_CORE__EXECUTOR" 1];then
  # Support for puckle style of defining configs
  export AIRFLOW__CORE__EXECUTOR"${EXECUTOR}Executor"
fi

# Handle 2.3.0 DeprecationWarnings- can be removed once platform is setting these themselves
# Add SQL_ALCHEMY_CONN to new section if it only exists in the old section
if [[ -n "$AIRFLOW_CORE_SQL_ALCHENY_CONN" &&-z "$AIRFLOW__DATABASE__SQL_ALCHEMY_CONN" ]]; then
  export AIRFLOW_DATABASE_SQL_ALCHEMY_CONN=$AIRFLOW_CORE_SQL_ALCHEMY_CONN
fi
#add new session backend to AUTH_BACKENDS if no env vars are set and old key/value is present in cfg
if [[ -z "$AIRFLOW_API_AUTH_BACKEND" &&-z "$AIRFLOW_API__AUTH_BACKENDS" &&-r "$AIRFLOW_HOME/airflow.cfg"]] \
  && grep -q "auth_backend = astronomer.flask_appbuilder.current_user_backend$" "$AIRFLOW_HOME/airflow.cfg" \
  && ! grep -q "auth_backends=" "$AIRFLOW_HOME/airflow.cfg"; then
  export AIRFLOW_API_AUTH_BACKENDS="astronomer.flask_appbuilder,current_user_backend,airflow.api.auth.backend.session"
fi

#Airflow subcommand
CMD=$2
# Custom gait variable to get the local call
LOCAL_CMD=$3

url_parse_regex="[^:]+://([^@/]*@)?([^/:]*):?([0-9]*)/?"

# Wait for postgres then init the db
if [[ -n $AIRFLOW__DATABASE__SQL_ALCHEMY_CONN ]];then
  # Wait for database port to open up
  [[ ${AIRFLOW__DATABASE__SQL_ALCHEMY_CONN} =~ $url_parse_regex ]]
  HOST=${BASH_REMATCH[2]}
  PORT=${BASH_REMATCH[3]}
  echo "Waiting for host: ${HOST} ${PORT}"
  while ! nc -w 1 -z "${HOST}" "${PORT}"; do
    sleep 0.001
  done
fi

# Entrypoint code starts here
# Only executed on the webserver.First condition handles cluster startup,second condition handles local startup
if [[ -n $AIRFLOW__DATABASE_SQL_ALCHEMY_CONN ]] && [[ $CMD =~ ^(.*webserver)$ || $LOCAL_CMD =~ ^(.webserver)$ J]; then
  echo "Update Airflow Variables..."
  /etc/setup/setup_variables.py /etc/setup/airflow-variables.json
  echo "Variables Update Complete"

  echo "Update Airflow Pools..."
  airflow pools import /etc/setup/airflow-pools.json
  echo "Pools Update Complete"
 
  echo "Setup Airflow Connections..."
  OVERWRITE_AIRFLOW_CONNECTIONS="${OVERWRITE_AIRFLOW_CONNECTIONS:-false}"
  /etc/setup/setup_connections.py /etc/gait/airflow-connectionss.json $OVERWRITE_AIRFLOW_CONNECTIONS
  echo "Connections Setup Complete"
  
  # If it's a development build,add env_postfix variable and reload connections
  if [[ ! -z "$ENV_POSTFIX"]]; then
    echo "environment post_fix found.Updating connections and variables accordingly
    /etc/setup/setup_variables.py/etc/setup/airflow-vars-dev.json
    /etc/setup/setup_connections.py /etc/setup/airflom-conns-dev.json true
    echo "Connection and Variables Update Complete"
  fi
fi
#Entrypoint code stops here

if [[ -n $AIRFLOW_CELERY_BROKER_URL ]] && [[ $CMD =~ ^(schedulerlworkerlflower)$ ]]; then
  # Wait for database port to open up
  [[ ${AIRFLOW__CELERY_BROKER_URL} =~ urLparse_regex ]]
  HOST=${BASH_REMATCH[2]}
  PORT=${BASH_REMATCH[3]}
  echo "Waiting for host: ${HOST} ${PORT}"
  while l nc -w 1 -z "${HOST}" "${PORT}"; do
    sleep 0.001
  done
f1

if [[ $CMD== "webserver" ]]; then
  airflow sync-perm
f1

# Run the original command
exec "$@"
