# Ansible MariaDB Galera Cluster install
### Ansible routines to deploy MariaDB Galera Cluster installation on CentOS / Red Hat Linux distros.

# Translation in English en-us

 In this file, I will present and demonstrate how to install MariaDB Galera Cluster in an automated and easy way.

 For this, I will be using the scenario described down below:
 ```
 1 Linux server for Ansible
 3 Linux servers for MariaDB (the one that we will install MariaDB using Ansible)
 ```

 First of all, we have to prepare our Linux environment to use Ansible

 Please have a look below how to install Ansible on CentOS/Red Hat:
 ```
 yum install ansible -y
 ```
 Well now that we have Ansible installed already, we need to install git to clone our git repository on the Linux server, see below how to install it on CentOS/Red Hat:
 ```
 yum install git -y
 ```

 Copying the script packages using git:
 ```
 cd /root
 git clone https://github.com/emersongaudencio/ansible-mariadb-galera-cluster.git
 ```
 Alright then after we have installed Ansible and git and clone the git repository. We have to generate ssh heys to share between the Ansible control machine and the database machines. Let see how to do that down below.

 To generate the keys, keep in mind that is mandatory to generate the keys inside of the directory who was copied from the git repository, see instructions below:
 ```
 cd /root/ansible-mariadb-galera-cluster/ansible
 ssh-keygen -f ansible
 ```
 After that you have had generated the keys to copy the keys to the database machines, see instructions below:
 ```
 ssh-copy-id -i ansible.pub 172.16.122.128
 ```

 Please edit the file called hosts inside of the ansible git directory :
 ```
 vi hosts
 ```
 Please add the hosts that you want to install your database and save the hosts file, see an example below:

 ```
 # This is the default ansible 'hosts' file.
 #

 ## [dbservers]
 ##
 ## db01.intranet.mydomain.net
 ## db02.intranet.mydomain.net
 ## 10.25.1.56
 ## 10.25.1.57

 [galeracluster]
 dbtest01 ansible_ssh_host=172.16.122.128
 dbtest02 ansible_ssh_host=172.16.122.136
 dbtest03 ansible_ssh_host=172.16.122.137
 ```

 For testing if it is all working properly, run the command below :
 ```
 ansible -m ping dbtest01 -v
 ansible -m ping dbtest02 -v
 ansible -m ping dbtest03 -v
 ```

 Alright finally we can install our MariaDB 10.3 using Ansible as we planned to, run the command below:
 ```
 sh run_mariadb_galera_install.sh dbtest01 103 777 "172.16.122.128" "prd01" "172.16.122.128,172.16.122.136,172.16.122.137"  
 sh run_mariadb_galera_install.sh dbtest02 103 777 "172.16.122.128" "prd01" "172.16.122.128,172.16.122.136,172.16.122.137"
 sh run_mariadb_galera_install.sh dbtest03 103 777 "172.16.122.128" "prd01" "172.16.122.128,172.16.122.136,172.16.122.137"
 ```

### Parameters specification:
#### run_mariadb_galera_install.sh
Parameter    | Value           | Mandatory   | Order        | Accepted values
------------ | ------------- | ------------- | ------------- | -------------
hostname or group-name listed on hosts files | dbtest01 | Yes | 1 | hosts who are placed inside of the hosts  file
db mariadb version | 103 | Yes | 2 | 101, 102, 103, 104, 105
mariadb galera cluster gtid | 777 | Yes | 3 | integer unique number between 1 to 1024 to identify gtid mariadb galera cluster
db mariadb galera primary server address | 172.16.122.128 | Yes | 4 | primary server ip address or dns name respective for
mariadb galera cluster name | prd01 | Yes | 5 | unique name to identify mariadb galera cluster
mariadb galera cluster members | 172.16.122.128,172.16.122.136,172.16.122.137 | Yes | 6 | list of ip addresses for the machines who will belongs to the cluster

 PS: Just remember that you can do a single installation at the time or a group installation you inform the name of the group in the hosts' files instead of the host itself.

 The mariadb versions supported for this script are these between the round brackets (101, 102, 103, 104, 105).

# Translation in Portuguese pt-br

Neste arquivo, venho apresentar e demonstrar como fazer a instalacao do MariaDB de forma automatizada e simples.

Para este post estarei utilizando o seguinte cenario:
```
1 servidor para o ansible
3 servidores que sera o nosso banco de dados MariaDB
```

Primeiramente temos que preparar nosso ambiente para utilizar o Ansible.

Veja abaixo com fazer a instalacao do Ansible no CentOS/Red Hat ou derivados:
```
yum install ansible -y
```

Bom agora que ja temos o Ansible instalado, vamos fazer o download do pacote de scripts no GitHub abaixo:
```
yum install git -y
```

Copiando o pacote de scripts com git:
```
cd /root
git clone https://github.com/emersongaudencio/ansible-mariadb-galera-cluster.git
```

Bom depois de instalar o ansible, git e clonar o repositorio no servidor do ansible, vamos precisar gerar chaves ssh e compartilhar entre o servidor do ansible e o servidor de banco de dados para que possamos executar os scripts do pacote do ansible.

Para gerar as chaves dentro do diretorio que copiou o repositorio de scripts do git:
```
cd /root/ansible-mariadb-galera-cluster/ansible
ssh-keygen -f ansible
```
Depois copie a
```
ssh-copy-id -i ansible.pub 172.16.122.135
```

Edite o arquivo hosts do pacote de diretorio do ansible:
```
vi hosts
```
Adicione os hosts que vai fazer a instalacao e salve o arquivo, veja o exemplo abaixo:

```
# This is the default ansible 'hosts' file.
#

## [dbservers]
##
## db01.intranet.mydomain.net
## db02.intranet.mydomain.net
## 10.25.1.56
## 10.25.1.57

[galeracluster]
dbtest01 ansible_ssh_host=172.16.122.128
dbtest02 ansible_ssh_host=172.16.122.136
dbtest03 ansible_ssh_host=172.16.122.137
```

Depois disso faca um teste para verificar se o ansible esta realmente conectando e funcionando corretamente com o script abaixo:
```
ansible -m ping dbtest01 -v
ansible -m ping dbtest02 -v
ansible -m ping dbtest03 -v
```

Agora finalmente execute o script para fazer a instalacao remota do MariaDB 10.4 no seu servidor de banco de dados:
```
sh run_mariadb_galera_install.sh dbtest01 103 777 "172.16.122.128" "prd01" "172.16.122.128,172.16.122.136,172.16.122.137"  
sh run_mariadb_galera_install.sh dbtest02 103 777 "172.16.122.128" "prd01" "172.16.122.128,172.16.122.136,172.16.122.137"
sh run_mariadb_galera_install.sh dbtest03 103 777 "172.16.122.128" "prd01" "172.16.122.128,172.16.122.136,172.16.122.137"
```

Explicacao dos parametros:

```
O script run_mariadb_galera_install.sh possui 6 parametros e nisso vou explicar a funcao de cada um na sua ordem:
Primeiro parametro: nome do servidor ou grupo de servidores listado no arquivo hosts do diretorio do ansible

Segundo parametro: versao do mariadb que deseja instalar.

Terceiro parametro: numero para representar o id do cluster, escolha entre 1 a 1024.

Quarto parametro: ip do servidor primario do galera cluster, que no caso sera o que ira fazer o bootstrap do cluster.

Quinto parametro: nome do cluster , que no caso precisa ser uma string

Sexto parametro: lista dos ips do servidor que irao fazer para do cluster, se quiser utilizar o dns ao inves do ip o script ira funcionar da mesma maneira.
```
Obs: Lembrando que tambem eh possivel fazer a instalacao para todo um grupo de servidor de uma soh vez, substituindo o nome do servidor pelo nome do grupo, que no nosso exemplo eh dbservers.

Outra observacao sobre o script eh que as versoes que voce pode instalar sao essas aqui (101, 102, 103, 104, 105).
