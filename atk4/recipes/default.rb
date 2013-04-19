#
## Cookbook Name:: atk4
## Recipe:: default

Chef::Log.debug("atk4: entering default recipe: debug")

node[:deploy].each do |application, deploy|
  Chef::Log.debug("atk4 starting application #{application} deployment (#{deploy})")

  if deploy[:application_type] != 'php'
    Chef::Log.debug("Skipping atk4 deploy::php application #{application} as it is not an PHP app")
    next
  end

  Chef::Log.debug("#{deploy[:deploy_to]}/current - wonder if it exists?")
  # write out config.php
  template "#{deploy[:deploy_to]}/current/config.php" do
    cookbook 'atk4'
    source 'config.php.erb'
    mode '0640'
    owner deploy[:user]
    group deploy[:group]
    if deploy[:database][:host] == nil
        deploy[:database][:host] = 'localhost'
    end
    variables(
      :basedir => deploy[:deploy_to],
      :database => deploy[:database],
      :memcached => deploy[:memcached],
      :layers => node[:opsworks][:layers],
      :stack_name => node[:opsworks][:stack][:name]
    )
    only_if do
      File.exists?("#{deploy[:deploy_to]}/current")
    end
  end

  script "install_composer" do
    interpreter "bash"
    user "root"
    cwd "#{deploy[:deploy_to]}/current"
    code <<-EOH
    curl -s https://getcomposer.org/installer | php
    php composer.phar install
    EOH
  end

  Chef::Log.debug("atk4: composer installed")

  # write out .htaccess
  template "#{deploy[:deploy_to]}/current/public/.htaccess" do
    cookbook 'atk4'
    source 'htaccess.erb'
    mode '0640'
    owner deploy[:user]
    group deploy[:group]
    only_if do
      File.exists?("#{deploy[:deploy_to]}/current/public")
    end
  end

  # for filestore
  yum_package "php-pecl-imagick" do
  end

  directory "#{deploy[:deploy_to]}/current/logs" do
    owner deploy[:user]
    group deploy[:group]
    mode 02775
    action :create
  end

  directory "#{deploy[:deploy_to]}/shared/upload" do
    owner deploy[:user]
    group deploy[:group]
    mode 02775
    action :create
  end

  Chef::Log.debug("atk4: leaving default recipe")
end
