#!/bin/bash
echo "HOSTNAME: " `hostname`
echo "BEGIN - [`date +%d/%m/%Y" "%H:%M:%S`]"
echo "##############"
echo "$1" > /tmp/MARIADB_VERSION
echo "$2" > /tmp/GTID
echo "$3" > /tmp/PRIMARY_SERVER
echo "$4" > /tmp/GALERA_CLUSTER_NAME
echo "$5" > /tmp/GALERA_CLUSTER_ADDRESS
MARIADB_VERSION=$(cat /tmp/MARIADB_VERSION)

##### FIREWALLD DISABLE ########################
systemctl disable firewalld
systemctl stop firewalld
######### SELINUX ###############################
sed -ie 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
# disable selinux on the fly
/usr/sbin/setenforce 0

### clean yum cache ###
rm -rf /etc/yum.repos.d/MariaDB.repo
rm -rf /etc/yum.repos.d/mariadb.repo
rm -rf /etc/yum.repos.d/mysql-community.repo
rm -rf /etc/yum.repos.d/mysql-community-source.repo
rm -rf /etc/yum.repos.d/percona-original-release.repo
yum clean headers
yum clean packages
yum clean metadata

####### PACKAGES ###########################
# -------------- For RHEL/CentOS 7 --------------
yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
# yum -y install epel-release

### remove old packages ####
yum -y remove mariadb-libs
yum -y remove 'maria*'
yum -y remove mysql mysql-server mysql-libs mysql-common mysql-community-common mysql-community-libs
yum -y remove 'mysql*'
yum -y remove MariaDB-common MariaDB-compat
yum -y remove MariaDB-server MariaDB-client
yum -y remove percona-release
yum -y remove galera

### install pre-packages ####
yum -y install screen yum-utils expect nload bmon iptraf glances perl perl-DBI openssl pigz zlib file sudo  libaio rsync snappy net-tools wget nmap htop dstat sysstat perl-IO-Socket-SSL perl-Digest-MD5 perl-TermReadKey socat libev gcc zlib zlib-devel openssl openssl-devel python-pip python-devel

if [ "$MARIADB_VERSION" == "101" ]; then
   VERSION="10.1"
elif [[ "$MARIADB_VERSION" == "102" ]]; then
   VERSION="10.2"
elif [[ "$MARIADB_VERSION" == "103" ]]; then
   VERSION="10.3"
elif [[ "$MARIADB_VERSION" == "104" ]]; then
   VERSION="10.4"
elif [[ "$MARIADB_VERSION" == "105" ]]; then
   VERSION="10.5"
fi

#### REPO MARIADB ######
# -------------- For RHEL/CentOS 7 --------------
echo "# MariaDB $VERSION CentOS repository list
# http://downloads.mariadb.org/mariadb/repositories/
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/$VERSION/centos7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1" > /etc/yum.repos.d/mariadb.repo

### clean yum cache ###
yum clean headers
yum clean packages
yum clean metadata

### Installation MARIADB via yum ####
yum -y install MariaDB-client
yum -y install MariaDB-server
yum -y install MariaDB-compat
yum -y install perl-DBD-MySQL
yum -y install MySQL-python
yum -y install MariaDB-backup

#### mydumper ######
#yum -y install https://github.com/maxbube/mydumper/releases/download/v0.9.5/mydumper-0.9.5-2.el7.x86_64.rpm
yum -y install https://github.com/emersongaudencio/linux_packages/raw/master/RPM/mydumper-0.9.5-2.el7.x86_64.rpm

#### qpress #####
yum -y install https://github.com/emersongaudencio/linux_packages/raw/master/RPM/qpress-11-1.el7.x86_64.rpm

### Percona #####
### https://www.percona.com/doc/percona-server/LATEST/installation/yum_repo.html
yum install https://repo.percona.com/yum/percona-release-latest.noarch.rpm -y
yum -y install percona-toolkit sysbench

#####  MYSQL LIMITS ###########################
check_limits=$(cat /etc/security/limits.conf | grep '# mysql-pre-reqs' | wc -l)
if [ "$check_limits" == "0" ]; then
echo ' ' >> /etc/security/limits.conf
echo '# mysql-pre-reqs' >> /etc/security/limits.conf
echo 'mysql              soft    nproc   102400' >> /etc/security/limits.conf
echo 'mysql              hard    nproc   102400' >> /etc/security/limits.conf
echo 'mysql              soft    nofile  102400' >> /etc/security/limits.conf
echo 'mysql              hard    nofile  102400' >> /etc/security/limits.conf
echo 'mysql              soft    stack   102400' >> /etc/security/limits.conf
echo 'mysql              soft    core unlimited' >> /etc/security/limits.conf
echo 'mysql              hard    core unlimited' >> /etc/security/limits.conf
echo '# all_users' >> /etc/security/limits.conf
echo '* soft nofile 102400' >> /etc/security/limits.conf
echo '* hard nofile 102400' >> /etc/security/limits.conf
else
echo "MySQL Pre-reqs for /etc/security/limits.conf is already in place!"
fi

##### CONFIG PROFILE #############
check_profile=$(cat /etc/profile | grep '# mysql-pre-reqs' | wc -l)
if [ "$check_profile" == "0" ]; then
echo ' ' >> /etc/profile
echo '# mysql-pre-reqs' >> /etc/profile
echo 'if [ $USER = "mysql" ]; then' >> /etc/profile
echo '  if [ $SHELL = "/bin/bash" ]; then' >> /etc/profile
echo '    ulimit -u 65536 -n 65536' >> /etc/profile
echo '  else' >> /etc/profile
echo '    ulimit -u 65536 -n 65536' >> /etc/profile
echo '  fi' >> /etc/profile
echo 'fi' >> /etc/profile
else
echo "MySQL Pre-reqs for /etc/profile is already in place!"
fi

##### SYSCTL MARIADB/MYSQL ###########################
check_sysctl=$(cat /etc/sysctl.conf | grep '# mysql-pre-reqs' | wc -l)
if [ "$check_sysctl" == "0" ]; then
# insert parameters into /etc/sysctl.conf for incresing MariaDB limits
echo "# mysql-pre-reqs
# virtual memory limits
vm.swappiness = 1
vm.dirty_background_ratio = 3
vm.dirty_ratio = 40
vm.dirty_expire_centisecs = 500
vm.dirty_writeback_centisecs = 100
fs.suid_dumpable = 1
vm.nr_hugepages = 0
# file system limits
fs.aio-max-nr = 1048576
fs.file-max = 6815744
# kernel limits
kernel.panic_on_oops = 1
kernel.shmall = 1073741824
kernel.shmmax = 4398046511104
kernel.shmmni = 4096
# kernel semaphores: semmsl, semmns, semopm, semmni
kernel.sem = 250 32000 100 128
# networking limits
net.ipv4.ip_local_port_range = 9000 65499
net.core.rmem_default=4194304
net.core.rmem_max=4194304
net.core.wmem_default=262144
net.core.wmem_max=1048586" >> /etc/sysctl.conf
else
echo "MySQL Pre-reqs for /etc/sysctl.conf is already in place!"
fi
# reload confs of /etc/sysctl.confs
sysctl -p

#####  MARIADB/MYSQL LIMITS ###########################
mkdir -p /etc/systemd/system/mariadb.service.d/
echo '[Service]' > /etc/systemd/system/mariadb.service.d/limits.conf
echo 'LimitNOFILE=102400' >> /etc/systemd/system/mariadb.service.d/limits.conf
echo '[Service]' > /etc/systemd/system/mariadb.service.d/timeout.conf
echo 'TimeoutSec=28800' >> /etc/systemd/system/mariadb.service.d/timeout.conf
mkdir -p /etc/systemd/system/mysqld.service.d/
echo '[Service]' > /etc/systemd/system/mysqld.service.d/limits.conf
echo 'LimitNOFILE=102400' >> /etc/systemd/system/mysqld.service.d/limits.conf
echo '[Service]' > /etc/systemd/system/mysqld.service.d/timeout.conf
echo 'TimeoutSec=28800' >> /etc/systemd/system/mysqld.service.d/timeout.conf
systemctl daemon-reload

### REMOVE MARIADB VERSION FILE #####
rm -rf /tmp/MARIADB_VERSION

echo "##############"
echo "END - [`date +%d/%m/%Y" "%H:%M:%S`]"
