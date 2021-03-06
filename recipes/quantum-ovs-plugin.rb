# Cookbook Name:: nova-network
# Recipe:: quantum-ovs-plugin
#
# Copyright 2012, Rackspace US, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

include_recipe "osops-utils"
include_recipe "nova-network::quantum-common"

platform_options = node["quantum"]["platform"]
plugin = node["quantum"]["plugin"]


node["quantum"][plugin]["packages"].each do |pkg|
  package pkg do
    action node["osops"]["do_package_upgrades"] == true ? :upgrade : :install
    options platform_options["package_overrides"]
  end
end

service "quantum-plugin-openvswitch-agent" do
  service_name node["quantum"]["ovs"]["service_name"]
  supports :status => true, :restart => true
  action :enable
  subscribes :restart, "template[/etc/quantum/quantum.conf]", :delayed
  subscribes :restart, "template[/etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini]", :delayed
end

service "openvswitch-switch" do
  service_name "openvswitch-switch"
  supports :status => true, :restart => true
  action [:enable, :start]
end

execute "create integration bridge" do
  command "ovs-vsctl add-br #{node["quantum"]["ovs"]["integration_bridge"]}"
  action :run
  not_if "ovs-vsctl show | grep 'Bridge br-int'" ## FIXME
end

node["quantum"]["ovs"]["provider_networks"].each do |k,v|
    execute "create provider bridge #{v['bridge']}" do
        command "ovs-vsctl add-br #{v['bridge']}"
        action :run
        notifies :restart, "service[quantum-plugin-openvswitch-agent]", :delayed
        not_if "ovs-vsctl list-br | grep #{v['bridge']}" ## FIXME
    end
end
