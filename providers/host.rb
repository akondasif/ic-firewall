action :create do
  zabbix_host.save
end

action :destroy do
  zabbix_host.destroy
end

attr_accessor :zabbix_host, :chef_node

def virtual?
  new_resource.virtual
end

def load_current_resource
  self.zabbix_host = (Rubix::Host.find(:name => new_resource.name) || Rubix::Host.new(:name => new_resource.name))

  load_host_groups
  load_templates
  load_user_macros

  return if virtual?
  
  self.chef_node = search(:node, "name:#{zabbix_host.name}").first
  if self.chef_node
    self.zabbix_host.profile = chef_node_profile
    self.zabbix_host.ip      = self.chef_node[:ipaddress]
    self.zabbix_host.port    = 10050
  else
    Chef::Log.error("Cannot find a Chef node named '#{zabbix_host.name}' to register in Zabbix.")
  end
end

def load_host_groups
  # Remember - we are *adding* the host groups to the host's current
  # groups, not replacing...
  current_host_groups      = self.zabbix_host.host_groups || []
  current_host_group_names = current_host_groups.map(&:name).to_set
  (new_resource.host_groups || []).flatten.compact.uniq.each do |host_group_name|
    next if current_host_group_names.include?(host_group_name)
    current_host_groups      << Rubix::HostGroup.find_or_create(:name => host_group_name)
    current_host_group_names << host_group_name
  end
  self.zabbix_host.host_groups = current_host_groups
end

def load_templates
  # Remember - we are *adding* the templates to the host's current
  # templates, not replacing...
  current_templates      = self.zabbix_host.templates || []
  current_template_names = current_templates.map(&:name).to_set
  (new_resource.templates || []).flatten.compact.uniq.each do |template_name|
    next if current_template_names.include?(template_name)
    t = Rubix::Template.find(:name => template_name)
    if t
      current_templates      << t
      current_template_names << template_name
    else
      Chef::Log.error("Cannot find a Zabbix template named '#{template_name}' for host '#{new_resource.name}', skipping....")
    end
  end
  self.zabbix_host.templates = current_templates
end

def load_user_macros
  # Remember - we are *adding* the user macros to the host's current
  # user macros, not replacing...
  current_user_macros = {}.tap do |macros|
    (self.zabbix_host.user_macros || []).each do |macro|
      macros[macro.name] = macro
    end
  end
  (new_resource.user_macros || {}).each_pair do |macro_name, macro_value|
    if current_user_macros[macro_name]
      current_user_macros[macro_name].value = macro_value
    else
      current_user_macros[macro_name] = Rubix::UserMacro.new(:name => macro_name, :value => macro_value)
    end
  end
  
  self.zabbix_host.user_macros = current_user_macros.values
end
  
def chef_node_profile
  case
  when (!virtual? && chef_node)
    {
      'devicetype' => chef_node[:ec2][:instance_type],
      'name'       => zabbix_host.name,
      'os'         => [chef_node[:platform], chef_node[:platform_version]].join(' '),
      'serialno'   => chef_node[:ec2][:instance_id],
      'tag'        => tag,
      'macaddress' => chef_node[:macaddress],
      'hardware'   => hardware,
      'software'   => software,
      'contact'    => contact,
      'location'   => location,
      'notes'      => notes
    }
  else
    {}
  end
end

def tag
  ''
end

def hardware
  num_cpus   = chef_node[:cpu][:total].to_i
  cpu_models = (0...num_cpus).map { |index| chef_node[:cpu][index.to_s][:model_name] rescue '' }.compact.to_set.to_a.join(', ')
  ram        = chef_node[:cpu][:memory][:total] rescue 0
  swap       = chef_node[:cpu][:memory][:swap][:total] rescue 0
  ["CPU: #{num_cpus} (#{cpu_models})", "RAM: #{ram}, SWAP: #{swap}"].join("\n")
end

def software
  node_roles    = (chef_node[:roles] || []).join(', ')
  node_provides = (chef_node[:provides_service] || {}).keys.join(', ')
  ["Roles: #{node_roles}", "Provides: #{node_provides}"].join("\n")
end

def contact
  ["Public: #{chef_node[:ec2][:public_hostname]}", "Private: #{chef_node[:ipaddress]}", "FQDN: #{chef_node[:fqdn]}"].join("\n")
end

def location
  node_security_groups = (chef_node[:ec2][:security_groups] || []).join(', ')
  ["Availability Zone: #{chef_node[:ec2][:placement_availability_zone]}", "Security Groups: #{node_security_groups}"].join("\n")
end

def notes
  [].tap do |lines|
    (chef_node[:filesystem] || {}).each_pair do |dev, dev_data|
      next unless dev =~ /dev/
      lines << "#{dev}: #{dev_data[:mount]} (#{dev_data[:kb_size]})"
    end
  end.join("\n")
end
