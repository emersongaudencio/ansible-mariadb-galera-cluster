#!/bin/bash

export SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export PYTHON_BIN=/usr/bin/python
export ANSIBLE_CONFIG=$SCRIPT_PATH/ansible.cfg

cd $SCRIPT_PATH

VAR_HOST="$1"
VAR_MARIADB_VERSION="$2"
VAR_GTID="$3"
VAR_PRIMARY_SERVER="$4"
VAR_GALERA_CLUSTER_NAME="$5"
VAR_GALERA_CLUSTER_ADDRESS="$6"

### Ping host ####
ansible -i $SCRIPT_PATH/hosts -m ping $VAR_HOST -v

### MariaDB install ####
ansible-playbook -v -i $SCRIPT_PATH/hosts -e "{mariadb_version: '$VAR_MARIADB_VERSION', gtid: '$VAR_GTID', primary_server: '$VAR_PRIMARY_SERVER', galera_cluster_name: '$VAR_GALERA_CLUSTER_NAME', galera_cluster_address: '$VAR_GALERA_CLUSTER_ADDRESS'}" $SCRIPT_PATH/playbook/mariadb_install_galera.yml -l $VAR_HOST
