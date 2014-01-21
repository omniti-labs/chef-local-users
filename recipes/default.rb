#
# Cookbook Name:: users
# Recipe:: default
#
# Copyright 2011, OmniTI
#

unless node[:local_users][:enabled] then return end

# Make sure we have auto_home working for us!
if node[:platform] == 'omnios' then
  include_recipe('auto_home')
end

data_bag('users').each do |data_bag_item_id|
  u = data_bag_item('users', data_bag_item_id)
  user_name = u['username'] || u['id']

  # Try to determine if this user exists in LDAP (assuming we even have an LDAP config)
  # If the user does exist in LDAP, we'll bomb if we try to manage them 
  # locally (though we can do most of our auxilary tasks, like 
  # placing LDAP users in local groups)
  local_user_exists = !(`egrep '^#{user_name}' /etc/passwd`.chomp().empty?)
  if local_user_exists then 
    ldap_user_exists = false; # We assume
  else
    ldap_user_exists = !(`getent passwd #{user_name}`.chomp().empty?)
  end

  # Delete users who aren't in any groups that are supposed to be on this
  # machine
  if (u['groups'] & node[:local_users][:groups]).empty? then
    # User shouldn't be on this machine
    user user_name do
      action :remove
      not_if { ldap_user_exists } # userdel on an LDAP user will fail
    end
    next
  end

  # Delete users with a "remove" attribute. For removing anybody as
  # needed
  if u.has_key?("remove")
    user user_name do
      action :remove
      not_if { ldap_user_exists } # userdel on an LDAP user will fail
    end
    next
  end
  
  # Note that even under omnios (and other automounting homedir systems)
  # we want to specify the logical location here - so don't use the auto_home value 
  homebase = '/home/'
  homedir = homebase + user_name
  if node.has_key?("auto_home") then
    real_homebase = node[:auto_home][:base] + '/' # This is the physical location, the mount target
    real_homedir = real_homebase + user_name
  else
    real_homedir = homedir
  end

  # Make sure primary group exists
  primary_group_name = u['group'] || user_name
  group "#{primary_group_name}_as_primary_group" do
    group_name primary_group_name
  end

  # Split this into two pieces - one to create user (conditional on LDAP)
  # and one to handle homedir (needed whether LDAP or not)
  user "create #{user_name}" do
    username user_name
    uid u['uid']
    gid primary_group_name
    shell u['shell']
    comment u['comment']
    not_if { ldap_user_exists }
  end
  user "homedir for #{user_name}" do
    username user_name
    action :modify
    supports :manage_home => true
    home homedir      
  end

  # Ensure the user's home directory exists. This is a no-op if it
  # already does.
  directory real_homedir do
    owner user_name
    group primary_group_name
    action :create
  end

  directory "#{homedir}/.ssh" do
    owner user_name
    group primary_group_name
    mode "0700"
  end

  if u.has_key?('overwrite_ssh_key') and u['overwrite_ssh_key'] then
    ssh_key_action = :create
  else
    ssh_key_action = :create_if_missing
  end

  template "#{homedir}/.ssh/authorized_keys" do
    action ssh_key_action
    source "authorized_keys.erb"
    owner user_name
    group primary_group_name
    mode "0600"
    variables :u => u
  end

  # Add the user to any groups
  u['groups'].each do |g|
    if g == primary_group_name then
        # We don't need to create a secondary group for the user's primary
        # group
        next
    end
    group "#{g}_for_#{user_name}_membership" do
      group_name g
      members user_name
      append true
    end
  end

  # Change password status if requested
  # This doesn't work for LDAP users    
  if u['nologin'] && !ldap_user_exists then
    case node[:platform]
    when 'omnios', 'smartos', 'solaris'
      bash "set nologin status for user #{user_name}" do
        code "passwd -N #{user_name}"
        not_if "passwd -s #{user_name} | awk '{print $2}' | grep NL"
      end
    when 'centos', 'redhat', 'debian', 'ubuntu'
      Chef::Log.warn("'#{node[:platform]}' platform can't really set nologin password status - locking password instead")
      user "lock #{user_name}" do
        action :lock
        username user_name
      end
    else
      raise "I don't know how to lock/nologin a password on '#{node[:platform]}' platform"
    end
  end
end
