#
# Author:: Adam Jacob (<adam@opscode.com>)
# Copyright:: Copyright (c) 2012 Opscode, Inc.
#
# All Rights Reserved
#

drbd_dir = node['private_chef']['drbd']['dir']
drbd_etc_dir =  File.join(node['private_chef']['drbd']['dir'], "etc")
drbd_data_dir = node['private_chef']['drbd']['data_dir']

[ drbd_dir, drbd_etc_dir, drbd_data_dir ].each do |dir|
	directory dir do
		recursive true
		mode "0755"
	end
end

template File.join(drbd_etc_dir, "drbd.conf") do
  source "drbd.conf.erb"
  mode "0655"
  variables(node['private_chef']['drbd'].to_hash)
end

template File.join(drbd_etc_dir, "pc0.res") do
  source "pc0.res.erb"
  mode "0655"
  variables(node['private_chef']['drbd'].to_hash)
end

execute "mv /etc/drbd.conf /etc/drbd.conf.orig" do
	only_if { File.exists?("/etc/drbd.conf") && !File.symlink?("/etc/drbd.conf") }
end

link "/etc/drbd.conf" do
	to File.join(drbd_etc_dir, "drbd.conf")
end

ruby_block "check_for_drbd_mount" do
	block do
		while true
			case node["platform"]
			when "redhat","centos","scientific"
				Chef::Log.warn("To install DRBD on #{node['platform']} #{node['platform_version']}:")
				if node["platform_version"] =~ /^6/
					puts <<-EOH

rpm --import http://elrepo.org/RPM-GPG-KEY-elrepo.org
yum install -y http://elrepo.org/elrepo-release-6-4.el6.elrepo.noarch.rpm
yum install -y drbd84-utils kmod-drbd84
service drbd start

					EOH
				end
			when "ubuntu","debian"
				puts <<-EOH

apt-get install drbd8-utils
service drbd start

				EOH
			end
			Chef::Log.warn("Please defer to your Private Chef manual for instructions on initializing the device.")
			Chef::Log.warn("Cannot find #{File.join(drbd_dir, 'drbd_ready')} - please bootstrap DRBD and run 'touch #{File.join(drbd_dir, 'drbd_ready')}'.")
			Chef::Log.warn("Press CTRL-C to abort.")
			break if File.exists?(File.join(drbd_dir, "drbd_ready"))
			sleep 60 
		end
	end
	not_if { File.exists?(File.join(drbd_dir, "drbd_ready")) }
end