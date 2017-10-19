nexus_domain = 'nexus.example.com'
nexus_ip = '192.168.56.3'

Vagrant.configure(2) do |config|
  config.vm.provider 'virtualbox' do |vb|
    vb.linked_clone = true
    vb.cpus = 2
    vb.memory = 2048
  end

  config.vm.define :nexus do |config|
    config.vm.box = 'ubuntu-16.04-amd64'
    config.vm.hostname = nexus_domain
    config.vm.network 'private_network', ip: nexus_ip
    config.vm.provision :shell, path: 'provision/provision-base.sh'
    config.vm.provision :shell, path: 'provision/provision-nexus.sh'
    config.vm.provision :shell, path: 'provision/test.sh'
    config.vm.provision :shell, path: 'provision/summary.sh'
  end

  config.vm.define :windows do |config|
    config.vm.box = 'windows-2016-amd64'
    config.vm.network 'private_network', ip: '192.168.56.4'
    config.vm.provider :virtualbox do |v, override|
      v.customize ['modifyvm', :id, '--vram', 64]
      v.customize ['modifyvm', :id, '--clipboard', 'bidirectional']
    end
    config.vm.provision :shell, inline: "echo '#{nexus_ip} #{nexus_domain}' | Out-File -Encoding Ascii -Append c:/Windows/System32/drivers/etc/hosts"
    config.vm.provision :shell, path: 'provision/windows/ps.ps1', args: ['provision-base.ps1', nexus_domain]
    config.vm.provision :shell, path: 'provision/windows/ps.ps1', args: ['use-chocolatey-repository.ps1', nexus_domain]
  end
end
