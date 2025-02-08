#!/usr/bin/env python3
from __future__ import print_function
import json
import os
import sys

from airflow import settings
from airflow.models import Connection

from sqlalchemy.orm import exc

class InitializeConnections(object):

    def __init__(self):
        self.session = settings.Session()

def has_connection(self,conn_id):
    try:
       (
           self.session.query(Connection)
           .filter(Connection.conn_id==conn_id)
           .one()
       )
    except exc.NoResultFound:
        return False
    except exc.MultipleResultsFound:
        print("[WARN] There is a duplicated connection:" + conn_id)
        return True
    return True

def delete_connection(self,conn_id):
    try:
        (
             self.session.query(Connection)
            .filter(Connection.conn_id== conn_id)
            .delete()
        )
    except exc.DBAPIError:
        return False
    return True

def delete_default_connections(self):
    print("Deleting default connections...")
    default_connections=[
        "cassandra_default","azure_cosmos_default", "azure_data_lake_default", "segment_default"
        "qubole_default", "databricks_default", "ear_default", "sqoop_default", "redis_default",
        "druid_ingest_default", "druid_broker_default", "spark_default", "aws_default", "fs_default",
        "sftp_default", "ssh_default", "webhdfs_default", "wasb_default", "vertica_default",
        "mssql_default", "http_default", "sqlite default", "postgres_default","mysql_default",
        "mongo_default", "metastore_default", "hiveserver2_default", "hive_cli_default",
        "google_cloud_default", "presto_default", "bigquery_default", "beeline_default",
        "qubole_default", "segment default", "Local_mysql", "airflow_db","airflow_ci",
        "azure_container_instances_default", "dingding_default", "opsgenie_default", "pig_cli_ default"]

    for conn_id in default_connections:
        self.delete_connection(connid)
        self.session.commit()

def add_connection(self, overwrite, **args):
    """Create a new connection.
    
    conn_id, conn_type, extra, host, Login,
    password, port,schema,uri
    """
    conn=Connection(**args)
    if overwrite:
        self.delete_connection(conn.conn_id)
    self.session.add(conn)
    self.session.commit()


if __name__=="main ":
    if len(sys.argv) < 2:
      print(f'Usage:\n\t {sys.argv[0]} <path to airflow connections json file> [remave all existing(truelfalse)]')

    json_file_path = sys.argv[1]
    overwrite_flag = (sys.argv[2].lower() == 'true') if (len(sys.argv) == 3) else False

    ic = InitializeConnections()

    #delete all the default connections
    ic.delete_default_connections()

    #add connections
    with open(json_file_path) as json_file:
        json_str = json_file.read()

        #Evaluate embedded env vars
        json_str = os.path.expanvars(json_str)

        data = json.loads(json_str)
        for conn in data:
            conn_id = conn['conn_id']

            #skip initialization if connection exists
            conn_exists = ic.has_connection(conn_id)
            if conn_exists and not overwrite_flag:
                print("Connection '{}' present. Skipping it.".format(conn_id))
                continue

            overwrite = conn_exists and overwrite_flag
            print("{} connection: {}".format(
                "Overwriting" if overwrite else "Adding",
                conn_id))

            #convert extra to string
            if conn.get('extra') is not None:
                conn['extra'] = json.dumps(conn.get('extra'))
            ic.add_connection(overwrite, **conn)