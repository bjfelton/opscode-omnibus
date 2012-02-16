#
# Author:: Adam Jacob (<adam@opscode.com>)
# Copyright:: Copyright (c) 2011 Opscode, Inc.
#
# All Rights Reserved
#

opscode_authz_dir = node['private_chef']['opscode-authz']['dir']
opscode_authz_etc_dir = File.join(opscode_authz_dir, "etc")
opscode_authz_log_dir = node['private_chef']['opscode-authz']['log_directory']
[ 
  opscode_authz_dir,
  opscode_authz_etc_dir,
  opscode_authz_log_dir,
].each do |dir_name|
  directory dir_name do
    owner node['private_chef']['user']['username']
    mode '0700'
    recursive true
  end
end

link "/opt/opscode/embedded/service/opscode-authz/priv/log" do
  to opscode_authz_log_dir 
end

authz_config = File.join(opscode_authz_etc_dir, "authz.config") 

template authz_config do
  source "authz.config.erb"
  mode "644"
  variables(node['private_chef']['opscode-authz'].to_hash)
  notifies :restart, 'service[opscode-authz]' if OmnibusHelper.should_notify?("opscode-authz")
end

link "/opt/opscode/embedded/service/opscode-authz/authz.config" do
  to authz_config 
end

runit_service "opscode-authz" do
  down node['private_chef']['opscode-authz']['ha']
  options({
    :log_directory => opscode_authz_log_dir
  }.merge(params))
end

if node['private_chef']['bootstrap']['enable']
	execute "/opt/opscode/bin/private-chef-ctl opscode-authz start" do
		retries 20 
	end

  execute "/opt/opscode/embedded/bin/rake design:load" do
    cwd "/opt/opscode/embedded/service/opscode-authz"
    not_if "curl http://#{node['private_chef']['couchdb']['vip']}:#{node['private_chef']['couchdb']['port']}/_all_dbs | grep authorization_design_documents"
  end
end

add_nagios_hostgroup("opscode-authz")