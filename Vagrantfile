Vagrant.configure(2) do |config|
  config.vm.box = 'ubuntu-16.04-amd64'
  config.vm.hostname = 'nexus.example.com'
  config.vm.network 'private_network', ip: '192.168.56.3'
  config.vm.provider 'virtualbox' do |vb|
    vb.linked_clone = true
    vb.cpus = 2
    vb.memory = 4096
  end
  config.vm.provision :shell, path: 'provision/provision-base.sh'
  config.vm.provision :shell, path: 'provision/provision-nexus.sh'
  config.vm.provision :shell, path: 'provision/test.sh'
  config.vm.provision :shell, path: 'provision/summary.sh'
end
