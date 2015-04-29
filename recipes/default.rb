#
# Cookbook Name:: spark
# Recipe:: default
#
# Copyright (C) 2014 Antonin Amand
#
# MIT License
#

require 'etc'

include_recipe "scala"

archive = "#{Chef::Config[:file_cache_path]}/spark.tar.gz"
extract_path = "/tmp/spark/archive"
spark_path = node['spark']['install_dir']
bin_path = File.join(spark_path, 'sbin')
spark_user = node["spark"]["user"]

remote_file archive do
  source node['spark']['bin_url']
  checksum node['spark']['bin_checksum']
end

directory File.dirname(spark_path) do
  mode "0755"
  recursive true
end

spark_group = node['spark']['group']

group spark_group do
  system true
end

user spark_user do
  gid spark_group
  system true
  shell "/bin/bash"
  home spark_path
end

bash 'install_spark' do
  cwd ::File.dirname(archive)
  code <<-EOH
    rm -rf '#{extract_path}'
    mkdir -p '#{extract_path}'
    tar xzf '#{archive}' -C '#{extract_path}'
    mv #{extract_path}/spark* '#{spark_path}'
    chown -R '#{spark_user}:#{spark_group}' '#{spark_path}'
  EOH
  not_if { ::File.exists?(spark_path) }
end


cassandra_connector_path = File.join(spark_path, 'lib', 'cassandra')
directory cassandra_connector_path do
  mode "0755"
  owner spark_user
  group spark_group
  recursive true
end

scratch_path = '/mnt/scratch'
directory scratch_path do
  mode "0755"
  owner spark_user
  group spark_group
  recursive true
end

job_deploy_path = File.join(spark_path, 'jobs')
directory job_deploy_path do
  mode "0755"
  owner "ubuntu"
  group "ubuntu"
  recursive true
end

bash 'install_cassandra_connector' do
  cwd cassandra_connector_path
  code <<-EOH
    rm *.jar

    curl -L -o ivy-2.4.0.jar \
    'http://search.maven.org/remotecontent?filepath=org/apache/ivy/ivy/2.4.0/ivy-2.4.0.jar'

    curl -L -o spark-cassandra-connector_2.10-1.2.0-rc3.jar \
    'http://search.maven.org/remotecontent?filepath=com/datastax/spark/spark-cassandra-connector_2.10/1.2.0-rc3/spark-cassandra-connector_2.10-1.2.0-rc3.jar'

    ivy () { java -jar ivy-2.4.0.jar -dependency $1 $2 $3 -retrieve "[artifact]-[revision](-[classifier]).[ext]"; }

    ivy org.apache.cassandra cassandra-thrift 2.0.12
    ivy com.datastax.cassandra cassandra-driver-core 2.1.5
    ivy joda-time joda-time 2.7
    ivy org.joda joda-convert 1.7

    rm -rf *-{sources,javadoc}.jar
  EOH
end

template "spark-env.sh" do
  mode "0644"
  owner "root"
  path File.join(spark_path, "conf", "spark-env.sh")
  variables :spark_env => node["spark"]["env"]
end

template "spark-defaults.conf" do
  mode "0644"
  owner spark_user
  group spark_group
  path File.join(spark_path, "conf", "spark-defaults.conf")
  variables :connector_path => cassandra_connector_path
end

directory "#{spark_path}/.ssh" do
  mode "0700"
  owner spark_user
end
