# to make sure the nexus node is created before the other nodes, we
# have to force a --no-parallel execution.
ENV['VAGRANT_NO_PARALLEL'] = 'yes'

nexus_domain = 'nexus.example.com'
nexus_ip = '192.168.56.3'

Vagrant.configure(2) do |config|
  config.vm.provider :libvirt do |lv, config|
    lv.memory = 2048
    lv.cpus = 4
    lv.cpu_mode = 'host-passthrough'
    lv.keymap = 'pt'
    lv.random :model => 'random'
  end

  config.vm.define :nexus do |config|
    config.vm.box = 'ubuntu-22.04-uefi-amd64'
    config.vm.hostname = nexus_domain
    config.vm.network 'private_network', ip: nexus_ip
    config.vm.provider :libvirt do |lv, config|
      lv.memory = 3*1024
      lv.machine_virtual_size = 32 # [GiB]
      config.vm.synced_folder '.', '/vagrant', type: 'nfs', nfs_version: '4.2', nfs_udp: false
    end
    config.vm.provision :shell, path: 'provision/provision-resize-disk.sh'
    config.vm.provision :shell, path: 'provision/provision-base.sh'
    config.vm.provision :shell, path: 'provision/provision-docker.sh'
    config.vm.provision :shell, path: 'provision/provision-nexus.sh'
    config.vm.provision :shell, path: 'provision/use-docker-repository.sh'
    config.vm.provision :shell, path: 'provision/use-raw-repository.sh'
    config.vm.provision :shell, path: 'provision/use-apt-repository.sh'
    config.vm.provision :shell, path: 'provision/use-maven-repository-from-mvn.sh'
    config.vm.provision :shell, path: 'provision/use-maven-repository-from-gradle.sh'
    config.vm.provision :shell, path: 'provision/use-nuget-repository.sh'
    config.vm.provision :shell, path: 'provision/use-npm-repository.sh'
    config.vm.provision :shell, path: 'provision/use-pypi-repository.sh'
    config.vm.provision :shell, path: 'provision/summary.sh'
  end

  config.vm.define :windows do |config|
    config.vm.box = 'windows-2022-uefi-amd64'
    config.vm.network 'private_network', ip: '192.168.56.4'
    config.vm.provider :libvirt do |lv, config|
      config.vm.synced_folder '.', '/vagrant', type: 'smb', smb_username: ENV['USER'], smb_password: ENV['VAGRANT_SMB_PASSWORD']
    end
    config.vm.provision :shell, inline: "echo '#{nexus_ip} #{nexus_domain}' | Out-File -Encoding Ascii -Append c:/Windows/System32/drivers/etc/hosts"
    config.vm.provision :shell, path: 'provision/windows/ps.ps1', args: ['provision-base.ps1', nexus_domain]
    config.vm.provision :shell, path: 'provision/windows/ps.ps1', args: ['use-chocolatey-repository.ps1', nexus_domain]
    config.vm.provision :shell, path: 'provision/windows/ps.ps1', args: ['use-powershell-repository.ps1', nexus_domain]
    config.vm.provision :shell, path: 'provision/windows/ps.ps1', args: ['use-npm-repository.ps1', nexus_domain]
  end

  config.trigger.before :up do |trigger|
    trigger.only_on = 'nexus'
    ldap_ca_cert_path = '../windows-domain-controller-vagrant/tmp/ExampleEnterpriseRootCA.der'
    trigger.run = {inline: "sh -c 'mkdir -p shared && cp #{ldap_ca_cert_path} shared'"} if File.file? ldap_ca_cert_path
  end
end
