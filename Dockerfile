FROM quay.io/astronomer/astro-runtime:9.19.5-python-3.11-base 

# Added to force bash execution of scripts rather than use sh 
SHELL ["/bin/bash","-c"] 

# Loading airflow variables 
ENV AIRFLOW__CELERY CELERYD_CONCURRENCY=16 
ENV AIRFLOW__CORE PARALLELISM=64 
ENV AIRFLOW__CORE__NON_POOLED_TASK_SLOT_COUNT=256 
ENV AIRFLOW_ETL_STEST_P0OL_SIZE=30 
ENV AIRFLOW__WEBSERVER__UPDATE_FAB_PERMS=True 
ENV AIRFLOW_VAR_DAG_CATCHUP_DEFAULT "True" 
ENV AIRFLOW_VAR_DEFAULT_MAX_ACTIVE_RUNS 2 
ENV AIRFLOW_VAR_DEFAULT_CONCURRENCY 4 
ENV AIRFLOW_VAR_SENSOR_RETRY_COUNT 288 
ENV AIRFLOW_VAR_SENSOR_RETRY_PERIOD_MINUTES 15 
ENV AIRFLOW_VAR_SENSOR_TIMEOUT_HOURS 24 

# Loading dbt variables 
# This is the equivalent of setprofile in the devops container: allows 'dbt debug' 
ENV DBT_PROFILES_DIR=/usr/Local/airflow/dbt_as_databases/ 

# Private PyPi server 
ARG ARTIFACTORY_PYPI_SERVER 
ENV ARTIFACTORY_PYPI_SERVER ${ARTIFACTORY_PYPI_SERVER} 

# Install debian packages
#root user is necessary for installation - switch back to astro after this section
USER root
RUN apt-get update --allow-releaseinfo-change \
    && apt-get install -y build-essential \
    && apt-get clean \
    && rm -rf /var/Lib/apt/Lists/*


# Install packages
COPY packages.txt.
RUN apt-get update \
    && cat packages.txt | xargs apt-get ins tall -y--no-install-recommends \
    && apt-get clean \
    && rm -rf /var/lib/apt/Lists/*

#Install python packages
#Locking pip version since new version br eaks on NTL Index support
ENV PIP_EXTRA_INDEX_URL="${ARTIFACTORY_PYPI_SERVER}/simple"
RUN curl https://bootstrap.pypa.io/get-pip .py-o get-pip.py \
    && python get-pip.py pip==21.3.1

# Install requirements
#Uninstall pyyaml so that it can be re-in atalled an top of Libyaml package
COPY requirements.txt.
RUN if [[ -s requirements,txt ]]; then \
        pip3 uninstall pyyaml-y \
        && pip3 install --no-cache-dir-q- r requirements.txt \
    ;fi

# Copy GAIT customizations
COPY include//etc/setup/
RUN chmod +x -R/etc/setup/

# Install the Root CA for EA as well
COPY include/root.cer  /usr/Local/share/ca-certificates/root.crt
RUN update-ca-certificates 2> /dev/null

COPY certs/ /usr/Local/share/certs/

# Remove all existing Airflow connections and recreate them based on the given json file
ENV OVERWRITE_AIRFLOW_CONNECTIONS=true

# switch back to astro user
#USER astro

# Run airflow with minimal init
ENTRYPOINT ["/etc/setup/setup-entrypoint"]