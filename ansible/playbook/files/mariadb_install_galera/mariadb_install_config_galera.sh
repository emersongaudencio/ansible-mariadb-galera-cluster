#!/bin/bash
### give it random number to serverid on MariaDB
# To generate a random number in a UNIX or Linux shell, the shell maintains a shell variable named RANDOM. Each time this variable is read, a random number between 0 and 32767 is generated.
SERVERID=$(($RANDOM))
GTID=$(cat /tmp/GTID)
##### Checking MariaDB Version #####
MARIADB_VERSION=`mysql --version |awk -F "-" {'print $1'}|awk -F "." {'print $1$2$3'} | awk {'print $5'}`

### get amount of memory who will be reserved to InnoDB Buffer Pool
INNODB_MEM=$(expr $(($(cat /proc/meminfo | grep MemTotal | awk '{print $2}') / 10)) \* 7 / 1024)

lg=$(expr $(echo $INNODB_MEM | wc -m) - 3)
var_innodb_suffix="${INNODB_MEM:$lg:2}"

if [ "$var_innodb_suffix" -gt 1 -a "$var_innodb_suffix" -lt 99 ]; then
  var_innodb_suffix="00"
fi

var_innodb_preffix="${INNODB_MEM:0:$lg}"
INNODB_MEM=${var_innodb_preffix}${var_innodb_suffix}M
echo "InnoDB BF Pool: "$INNODB_MEM

### get the number of cpu's to estimate how many innodb instances will be enough for it. ###
NR_CPUS=$(cat /proc/cpuinfo | awk '/^processor/{print $3}' | wc -l)

if [[ $NR_CPUS -gt 8 ]]
then
 INNODB_INSTANCES=$NR_CPUS
 WSREP_THREADS=16
 INNODB_WRITES=16
 INNODB_READS=16
 INNODB_MIN_IO=200
 INNODB_MAX_IO=800
 TEMP_TABLE_SIZE='16M'
 NR_CONNECTIONS=1000
 NR_CONNECTIONS_USER=950
 SORT_MEM='256M'
 SORT_BLOCK="read_rnd_buffer_size                    = 1M
read_buffer_size                        = 1M
max_sort_length                         = 1M
max_length_for_sort_data                = 1M
mrr_buffer_size                         = 1M
group_concat_max_len                    = 4096"
else
 INNODB_INSTANCES=8
 WSREP_THREADS=8
 INNODB_WRITES=8
 INNODB_READS=8
 INNODB_MIN_IO=200
 INNODB_MAX_IO=300
 TEMP_TABLE_SIZE='16M'
 NR_CONNECTIONS=500
 NR_CONNECTIONS_USER=450
 SORT_MEM='128M'
 SORT_BLOCK="read_rnd_buffer_size                    = 131072
read_buffer_size                        = 131072
max_sort_length                         = 262144
max_length_for_sort_data                = 262144
mrr_buffer_size                         = 131072
group_concat_max_len                    = 2048"
fi

### galera parms ###
GALERA_CLUSTER_NAME=$(cat /tmp/GALERA_CLUSTER_NAME)
GALERA_CLUSTER_ADDRESS=$(cat /tmp/GALERA_CLUSTER_ADDRESS)
PRIMARY_SERVER=$(cat /tmp/PRIMARY_SERVER)
LOCAL_SERVER_IP=" "

### check the ips address of the machines used on the cluster env ###
hostname=${PRIMARY_SERVER}
if [[ $hostname =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    PRIMARY_SERVER=$hostname
    echo "IP: $PRIMARY_SERVER"
else
    PRIMARY_SERVER=`resolveip -s $hostname`
    if [ -n "$PRIMARY_SERVER" ]; then
        echo "IP: $PRIMARY_SERVER"
    else
        echo "Could not resolve hostname."
    fi
fi

### check the ips address of the machines used on the cluster env ###
ips=($(hostname -I))
for ip in "${ips[@]}"
do
 if [ "$PRIMARY_SERVER" == "$ip" ];
 then
    LOCAL_SERVER_IP=$ip
    PRIMARY="OK"
    echo $LOCAL_SERVER_IP
    echo "$PRIMARY is a Primary!"
 else
    if [ "$LOCAL_SERVER_IP" == " " ];
    then
    LOCAL_SERVER_IP=$ip
    PRIMARY="NO"
    echo $LOCAL_SERVER_IP
    echo "$PRIMARY is not a Primary!"
    fi
 fi
done

### datadir and logdir ####
DATA_DIR="/var/lib/mysql/datadir"
DATA_LOG="/var/lib/mysql-logs"
TMP_DIR="/var/lib/mysql-tmp"

if [ "$MARIADB_VERSION" == "101" ]; then
  ### collation and character set ###
  COLLATION="utf8_general_ci"
  CHARACTERSET="utf8"
  MARIADB_BLOCK='innodb_large_prefix                     = 1'
  WS_PROV="/usr/lib64/galera/libgalera_smm.so"
elif [[ "$MARIADB_VERSION" == "102" ]]; then
  ### collation and character set ###
  COLLATION="utf8_general_ci"
  CHARACTERSET="utf8"
  MARIADB_BLOCK='innodb_large_prefix                     = 1'
  WS_PROV="/usr/lib64/galera/libgalera_smm.so"
elif [[ "$MARIADB_VERSION" == "103" ]]; then
  ### collation and character set ###
  COLLATION="utf8mb4_general_ci"
  CHARACTERSET="utf8mb4"
  MARIADB_BLOCK='######'
  WS_PROV="/usr/lib64/galera/libgalera_smm.so"
elif [[ "$MARIADB_VERSION" == "104" ]]; then
  ### collation and character set ###
  COLLATION="utf8mb4_general_ci"
  CHARACTERSET="utf8mb4"
  MARIADB_BLOCK='innodb_large_prefix                     = 1'
  WS_PROV="/usr/lib64/galera-4/libgalera_smm.so"
elif [[ "$MARIADB_VERSION" == "105" ]]; then
  ### collation and character set ###
  COLLATION="utf8mb4_general_ci"
  CHARACTERSET="utf8mb4"
  MARIADB_BLOCK='innodb_large_prefix                     = 1'
  WS_PROV="/usr/lib64/galera-4/libgalera_smm.so"
fi

### galera standard users ##
GALERA_USER_NAME="wsrepsst"
REPLICATION_USER_NAME="replication_user"
MYSQLCHK_USER_NAME="mysqlchk"

### generate galera passwd #####
RD_GALERA_USER_PWD="wsrepsst-$GTID"
touch /tmp/$RD_GALERA_USER_PWD
echo $RD_GALERA_USER_PWD > /tmp/$RD_GALERA_USER_PWD
HASH_GALERA_USER_PWD=`md5sum  /tmp/$RD_GALERA_USER_PWD | awk '{print $1}' | sed -e 's/^[[:space:]]*//' | tr -d '/"/'`

### generate replication passwd #####
RD_REPLICATION_USER_PWD="replication-$GTID"
touch /tmp/$RD_REPLICATION_USER_PWD
echo $RD_REPLICATION_USER_PWD > /tmp/$RD_REPLICATION_USER_PWD
HASH_REPLICATION_USER_PWD=`md5sum  /tmp/$RD_REPLICATION_USER_PWD | awk '{print $1}' | sed -e 's/^[[:space:]]*//' | tr -d '/"/'`

### generate mysqlchk passwd #####
RD_MYSQLCHK_USER_PWD="mysqlchk-$GTID"
touch /tmp/$RD_MYSQLCHK_USER_PWD
echo $RD_MYSQLCHK_USER_PWD > /tmp/$RD_MYSQLCHK_USER_PWD
HASH_MYSQLCHK_USER_PWD=`md5sum  /tmp/$RD_MYSQLCHK_USER_PWD | awk '{print $1}' | sed -e 's/^[[:space:]]*//' | tr -d '/"/'`

### galera pwd users ##
REPLICATION_USER_PWD=$HASH_REPLICATION_USER_PWD
GALERA_USER_PWD=$HASH_GALERA_USER_PWD
MYSQLCHK_USER_PWD=$HASH_MYSQLCHK_USER_PWD

### generate root passwd #####
passwd="root-$GTID"
touch /tmp/$passwd
echo $passwd > /tmp/$passwd
hash=`md5sum  /tmp/$passwd | awk '{print $1}' | sed -e 's/^[[:space:]]*//' | tr -d '/"/'`

echo "[client]
port                                    = 3306
socket                                  = /var/lib/mysql/mysql.sock

[mysqld]
server-id                               = $SERVERID
gtid_domain_id                          = $GTID
sql_mode                                = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION'
port                                    = 3306
pid-file                                = /var/lib/mysql/mysql.pid
socket                                  = /var/lib/mysql/mysql.sock
basedir                                 = /usr
local_infile                            = 1

# general configs
datadir                                 = $DATA_DIR
collation-server                        = $COLLATION
character_set_server                    = $CHARACTERSET
init-connect                            = SET NAMES $CHARACTERSET
lower_case_table_names                  = 1
default-storage-engine                  = InnoDB
optimizer_switch                        = 'index_merge_intersection=off'
bulk_insert_buffer_size                 = 128M

# files limits
open_files_limit                        = 102400
innodb_open_files                       = 65536

query_cache_size                        = 0
query_cache_type                        = 0

thread_handling                         = pool-of-threads
thread_cache_size                       = 300

# logbin configs
log-bin                                 = $DATA_LOG/mysql-bin
binlog_format                           = ROW
binlog_checksum                         = CRC32
expire_logs_days                        = 5
log_bin_trust_function_creators         = 1
sync_binlog                             = 1
log_slave_updates                       = 1

relay_log                               = $DATA_LOG/mysql-relay-bin
relay_log_purge                         = 1

# slave configs
slave_compressed_protocol               = 1
slave_ddl_exec_mode                     = IDEMPOTENT
slave_net_timeout                       = 60
slave_parallel_threads                  = 0
slave_sql_verify_checksum               = ON

# innodb vars
innodb_buffer_pool_size                 = $INNODB_MEM
innodb_buffer_pool_instances            = $INNODB_INSTANCES
innodb_flush_log_at_trx_commit          = 1
innodb_file_per_table                   = 1
innodb_flush_method                     = O_DIRECT
innodb_flush_neighbors                  = 0
innodb_log_buffer_size                  = 16M
innodb_lru_scan_depth                   = 4096
innodb_purge_threads                    = 4
innodb_sync_array_size                  = 4
innodb_autoinc_lock_mode                = 2
innodb_print_all_deadlocks              = 1
innodb_io_capacity                      = $INNODB_MIN_IO
innodb_io_capacity_max                  = $INNODB_MAX_IO
innodb_read_io_threads                  = $INNODB_READS
innodb_write_io_threads                 = $INNODB_WRITES
innodb_max_dirty_pages_pct              = 90
innodb_max_dirty_pages_pct_lwm          = 10
innodb_doublewrite                      = 1
innodb_thread_concurrency               = 0
$MARIADB_BLOCK

# innodb redologs
innodb_log_file_size                    = 1G
innodb_log_files_in_group               = 4

# table configs
table_open_cache                        = 16384
table_definition_cache                  = 52428
max_heap_table_size                     = $TEMP_TABLE_SIZE
tmp_table_size                          = $TEMP_TABLE_SIZE
tmpdir                                  = $TMP_DIR

# connection configs
max_allowed_packet                      = 1G
net_buffer_length                       = 999424
max_connections                         = $NR_CONNECTIONS
max_user_connections                    = $NR_CONNECTIONS_USER
max_connect_errors                      = 100
wait_timeout                            = 28800
connect_timeout                         = 60
skip-name-resolve                       = 1

# sort and group configs
key_buffer_size                         = 32M
sort_buffer_size                        = $SORT_MEM
innodb_sort_buffer_size                 = 67108864
myisam_sort_buffer_size                 = $SORT_MEM
join_buffer_size                        = $SORT_MEM
$SORT_BLOCK

# log configs
slow_query_log                          = 1
slow_query_log_file                     = $DATA_LOG/mysql-slow.log
long_query_time                         = 3
log_slow_verbosity                      = query_plan,explain
log_slow_admin_statements               = ON
log_slow_slave_statements               = ON
log_queries_not_using_indexes           = ON

log-error                               = $DATA_LOG/mysql-error.log

general_log_file                        = $DATA_LOG/mysql-general.log
general_log                             = 0

# enable scheduler on MariaDB
event_scheduler                         = 1

# Performance monitoring (with low overhead)
innodb_monitor_enable                   = all
performance_schema                      = ON
performance-schema-instrument           ='%=ON'
performance-schema-consumer-events-stages-current=ON
performance-schema-consumer-events-stages-history=ON
performance-schema-consumer-events-stages-history-long=ON
" > /etc/my.cnf.d/server.cnf

### restart mysql service to apply new config file generate it at this stage ###
pid_mysql=$(pidof mysqld)
if [[ $pid_mysql -gt 1 ]]
then
kill -15 $pid_mysql
fi
sleep 10

# clean standard mysql dir
rm -rf /var/lib/mysql/*
chown -R mysql:mysql /var/lib/mysql
### remove old config file ####
rm -rf /root/.my.cnf

# create directories for mysql datadir and datalog
if [ ! -d ${DATA_DIR} ]
then
    mkdir -p ${DATA_DIR}
    chmod 755 ${DATA_DIR}
    chown -Rf mysql.mysql ${DATA_DIR}
else
    chown -Rf mysql.mysql ${DATA_DIR}
fi

if [ ! -d ${DATA_LOG} ]
then
    mkdir -p ${DATA_LOG}
    chmod 755 ${DATA_LOG}
    chown -Rf mysql.mysql ${DATA_LOG}
else
    chown -Rf mysql.mysql ${DATA_LOG}
fi

if [ ! -d ${TMP_DIR} ]
then
    mkdir -p ${TMP_DIR}
    chmod 755 ${TMP_DIR}
    chown -Rf mysql.mysql ${TMP_DIR}
else
    chown -Rf mysql.mysql ${TMP_DIR}
fi

if [[ $PRIMARY == "OK" ]]
then

### mysql_install_db for deploy a new db fresh and clean ###
mysql_install_db --user=mysql --skip-name-resolve --force --defaults-file=/etc/my.cnf.d/server.cnf
sleep 3

### start mysql service ###
systemctl enable mariadb.service
sleep 1
systemctl start mariadb.service
sleep 1

### generate root passwd #####
echo The server_id is $SERVERID and the gt_domain_id is $GTID!
echo The root password is $hash
echo The $GALERA_USER_NAME password is $GALERA_USER_PWD
echo The $REPLICATION_USER_NAME password is $REPLICATION_USER_PWD
echo The $MYSQLCHK_USER_NAME password is $MYSQLCHK_USER_PWD

### update root password #####
mysqladmin -u root password $hash

### generate user file on root account linux #####
echo "[client]
user            = root
password        = $hash

[mysql]
user            = root
password        = $hash
prompt          = '(\u@\h) MariaDB [\d]>\_'

[mysqladmin]
user            = root
password        = $hash

[mysqldump]
user            = root
password        = $hash

###### Automated users generated by the installation process ####
#The root password is $hash
#The $GALERA_USER_NAME password is $GALERA_USER_PWD
#The $REPLICATION_USER_NAME password is $REPLICATION_USER_PWD
#The $MYSQLCHK_USER_NAME password is $MYSQLCHK_USER_PWD
#################################################################
" > /root/.my.cnf

### restart mysql service to apply new config file generate it at this stage ###
pid_mysql=$(pidof mysqld)
if [[ $pid_mysql -gt 1 ]]
then
kill -15 $pid_mysql
fi
sleep 10

### generate galera.cnf file #####
echo "#
# MariaDB Galera configuration
#

[mariadb]
wsrep_on                                = ON
wsrep_provider                          = $WS_PROV
wsrep_provider_options                  = 'gcache.size=2G; gmcast.segment=1; gcache.dir=${DATA_DIR}; gcache.recover=yes; cert.log_conflicts=yes; socket.checksum=1; gcs.fc_limit=256; gcs.fc_factor=0.99; gcs.fc_master_slave=yes; evs.version=1; evs.delay_margin=PT1S; evs.delayed_keep_period=PT1M; evs.auto_evict=5;'
wsrep_log_conflicts                     = ON
wsrep_retry_autocommit                  = 2

wsrep_node_name                         = $LOCAL_SERVER_IP
wsrep_node_address                      = $LOCAL_SERVER_IP
wsrep_cluster_name                      = $GALERA_CLUSTER_NAME

wsrep_cluster_address                   = gcomm://$GALERA_CLUSTER_ADDRESS
wsrep_sst_method                        = mariabackup
# This user is only used for mariadb-backup SST method
wsrep_sst_auth                          = $GALERA_USER_NAME:$GALERA_USER_PWD
wsrep_sst_donor                         =
wsrep_slave_threads                     = $WSREP_THREADS

# Enable of consistent GTID even across cluster nodes
wsrep_gtid_domain_id                    = $GTID
wsrep_gtid_mode                         = ON

[sst]
inno-apply-opts='--use-memory=4G'
inno-apply-opts='--datadir=${DATA_DIR}'
inno-move-opts='--datadir=${DATA_DIR}'" > /etc/my.cnf.d/galera.cnf

### start mysql with galera_new_cluster to inicialize the cluster on the primary server ###
galera_new_cluster
sleep 3

### setup the users for galera cluster/replication streaming ###
mysql -e "GRANT REPLICATION SLAVE ON *.* TO '$REPLICATION_USER_NAME'@'%' IDENTIFIED BY '$REPLICATION_USER_PWD';";
mysql -e "GRANT SELECT, INSERT, CREATE, RELOAD, PROCESS, SUPER, LOCK TABLES, REPLICATION CLIENT ON *.* TO '$GALERA_USER_NAME'@'localhost' IDENTIFIED BY '$GALERA_USER_PWD';"
mysql -e "GRANT PROCESS ON *.* TO '$MYSQLCHK_USER_NAME'@'localhost' IDENTIFIED BY '$MYSQLCHK_USER_PWD';";
mysql -e "flush privileges;"

else

### generate user file on root account linux #####
echo "[client]
user            = root
password        = $hash

[mysql]
user            = root
password        = $hash
prompt          = '(\u@\h) MariaDB [\d]>\_'

[mysqladmin]
user            = root
password        = $hash

[mysqldump]
user            = root
password        = $hash

###### Automated users generated by the installation process ####
#The root password is $hash
#The $GALERA_USER_NAME password is $GALERA_USER_PWD
#The $REPLICATION_USER_NAME password is $REPLICATION_USER_PWD
#The $MYSQLCHK_USER_NAME password is $MYSQLCHK_USER_PWD
#################################################################
" > /root/.my.cnf

### generate galera.cnf file #####
echo "#
# MariaDB Galera configuration
#

[mariadb]
wsrep_on                                = ON
wsrep_provider                          = $WS_PROV
wsrep_provider_options                  = 'gcache.size=2G; gmcast.segment=1; gcache.dir=${DATA_DIR}; gcache.recover=yes; cert.log_conflicts=yes; socket.checksum=1; gcs.fc_limit=256; gcs.fc_factor=0.99; gcs.fc_master_slave=yes; evs.version=1; evs.delay_margin=PT1S; evs.delayed_keep_period=PT1M; evs.auto_evict=5;'
wsrep_log_conflicts                     = ON
wsrep_retry_autocommit                  = 2

wsrep_node_name                         = $LOCAL_SERVER_IP
wsrep_node_address                      = $LOCAL_SERVER_IP
wsrep_cluster_name                      = $GALERA_CLUSTER_NAME

wsrep_cluster_address                   = gcomm://$GALERA_CLUSTER_ADDRESS
wsrep_sst_method                        = mariabackup
# This user is only used for mariadb-backup SST method
wsrep_sst_auth                          = $GALERA_USER_NAME:$GALERA_USER_PWD
wsrep_sst_donor                         =
wsrep_slave_threads                     = $WSREP_THREADS

# Enable of consistent GTID even across cluster nodes
wsrep_gtid_domain_id                    = $GTID
wsrep_gtid_mode                         = ON

[sst]
inno-apply-opts='--use-memory=4G'
inno-apply-opts='--datadir=${DATA_DIR}'
inno-move-opts='--datadir=${DATA_DIR}'" > /etc/my.cnf.d/galera.cnf

### start mysql service ###
systemctl enable mariadb.service
sleep 1
systemctl start mariadb.service
sleep 1

fi
