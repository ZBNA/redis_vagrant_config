#!/bin/sh


#@Author Andre Conde
#03/02/2015
#A simple Vagrant Provisioning Shell script to create a development environment for redis cluster 


set -o pipefail

##### PARAMETERS
server=$1
port=$2
cluster_config_file="nodes-"$port.conf
cluster_enabled="yes"


redis_conf_file="redis.conf"
##### CONFIG
cluster_node_timeout=5000
appendonly="yes"


##### VARIABLES
redis_tar_gz_dir="/opt/"
redis_file="redis-3.0.6.tar.gz"
path_redis_tar_gz_file=$redis_tar_gz_dir$redis_file

redis_dir="/opt/redis-3.0.6/"
redis_sym_dir="/opt/redis/"
redis_dir_src=$redis_dir/src
redis_dir_deps="/opt/redis-3.0.6/deps"
redis_download_url="http://download.redis.io/releases/"

log_file="/vagrant/redis_install_log_$server"

redis_init_status_file="/vagrant/redis_init_status"

##### FUNCTIONS

reset_redis_init_status_file() {
	if [ "$server" == "redis1" ]
	then
		echo "" > $redis_init_status_file
	
	fi	
}

install_dependencies() {
	sudo yum install -y vim
	sudo yum install -y tcl
	sudo yum install -y gcc
	sudo yum install -y rubygems
}

install_redis_ruby_gem_package() {
	sudo gem install redis
}

download_redis() {
	sudo wget -O $redis_tar_gz_dir$redis_file $redis_download_url$redis_file
}

unpack_redis() {
	sudo tar -zxvf $path_redis_tar_gz_file -C $redis_tar_gz_dir
}

build_redis() {
	sudo make -C $redis_dir_deps hiredis lua jemalloc linenoise
	sudo make -C $redis_dir_src
	#sudo make -C $redis_dir_src test #msg=All tests passed without errors
	#sudo make -C $redis_dir_src  clean
	sudo make -C $redis_dir_src install
}

create_sym_link() {
	sudo ln -s /opt/redis-3.0.6/ ${redis_sym_dir::-1}
}

configure_port_property() {
	content=$(sed -e "s/^port\s\+[0-9]\+$/port $port/" $redis_sym_dir$redis_conf_file)
	echo "$content" > $redis_sym_dir$redis_conf_file	
}


configure_cluster_redis_config_file_property() {
	content=$(sed -e "s/^#\scluster-config-file\s\+nodes-[0-9]\+\.conf$/cluster-config-file $cluster_config_file/" $redis_sym_dir$redis_conf_file)
	echo "$content" > $redis_sym_dir$redis_conf_file
}

configure_node_timeout_property() {
	content=$(sed -e "s/^#\scluster-node-timeout\s\+[0-9]\+$/cluster-node-timeout $cluster_node_timeout/" $redis_sym_dir$redis_conf_file)
	echo "$content" > $redis_sym_dir$redis_conf_file	

}

configure_appendonly_property() {
	content=$(sed -e "s/^appendonly\sno$/appendonly yes/" $redis_sym_dir$redis_conf_file)
	echo "$content" > $redis_sym_dir$redis_conf_file	
}

configure_redis_cluster_enabled_property() {
	content=$(sed -e "s/^#\scluster-enabled\syes$/cluster-enabled yes/" $redis_sym_dir$redis_conf_file)
	echo "$content" > $redis_sym_dir$redis_conf_file	
}


set_redis_properties() {
	configure_port_property
	configure_cluster_redis_config_file_property
	configure_node_timeout_property
	configure_appendonly_property
	configure_redis_cluster_enabled_property
}

start_redis() {
	/usr/local/bin/redis-server $redis_sym_dir$redis_conf_file &
	sleep 15
	echo "$server" >> $redis_init_status_file
	echo "$server started" >> $log_file	
	
}

create_cluster() {
	echo "create cluster" >> $log_file
	redis1=$(grep "redis1" "$redis_init_status_file") 
	redis2=$(grep "redis2" "$redis_init_status_file")
	redis3=$(grep "redis3" "$redis_init_status_file")
	redis4=$(grep "redis4" "$redis_init_status_file")
	redis5=$(grep "redis5" "$redis_init_status_file")
	redis6=$(grep "redis6" "$redis_init_status_file")
	
	echo "depois da criacao do cluster" >> $log_file	
	
	echo "========== REDIS SERVERS ARE UP ? =========" >> $log_file
	echo "$redis1" >> $log_file
	echo "$redis2" >> $log_file
	echo "$redis3" >> $log_file
	echo "$redis4" >> $log_file
	echo "$redis5" >> $log_file
	echo "$redis6" >> $log_file
	echo "===========================================" >> $log_file



	if [[ "$redis1" == "redis1" && "$redis2" == "redis2" && "$redis3" == "redis3" && "$redis4" == "redis4" && "$redis5" == "redis5" && $redis6 == "redis6" ]] 
	then
	{	
		if [ "$server" == "redis1" ]
		then
		{
			
			yes "yes" | /opt/redis/src/redis-trib.rb create --replicas 1 192.168.1.5:7000 192.168.1.6:7001 192.168.1.7:7002 192.168.1.8:7003 192.168.1.9:7004 192.168.1.10:7005 >> $log_file
			echo "Cluster criado" >> $log_file
			exit 0			

		}	
		fi	
	
	}
	fi	
		
}


wait_all_nodes_up() {
	while true
	do

		if [ "$server" != "redis1" ]
		then
		{
			echo "$server is not responsible to start the cluster command" >> $log_file
			break;
			
		}
		fi


		echo "Waiting all nodes" >> $log_file
		sleep 5
		create_cluster 
	done
}

main() {
	echo "The selected portr for this redis instance is: " $port > $log_file 
	echo "cluster is Enabled ? " $cluster_enabled >> $log_file
	echo "cluster config file ( Don't ever touch this file ): " $cluster_config_file >> $log_file 
	echo "cluster node timeout: " $cluster_node_timeout >> $log_file
	echo "appendonly:" $appendonly >> $log_file 

	echo "Starting Redis installation and configuration" >> $log_file 
	
	reset_redis_init_status_file

	install_dependencies
	echo "Dependencies has been installed"  >> $log_file

	install_redis_ruby_gem_package
	
	download_redis
	echo "Redis" $redis_file "has been downloaded from" $redis_download_url >> $log_file

	unpack_redis
	echo "Redis unpacked" >> $log_file 
	build_redis
	echo "Redis built" >> $log_file 
	create_sym_link
	echo "Redis binaries compiled" >> $log_file 
	set_redis_properties
	echo "starting redis" >> $log_file 
	start_redis &
	wait_all_nodes_up &
}

main
