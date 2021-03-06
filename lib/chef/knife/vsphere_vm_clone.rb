# Author:: Ezra Pagel (<ezra@cpan.org>)
# Contributor:: Jesse Campbell (<hikeit@gmail.com>)
# Contributor:: Bethany Erskine (<bethany@paperlesspost.com>)
# Contributor:: Adrian Stanila (https://github.com/sacx)
# Contributor:: Ryan Hass (rhass@chef.io)
# License:: Apache License, Version 2.0
#

require 'chef/knife'
require 'chef/knife/base_vsphere_command'
require 'rbvmomi'
require 'netaddr'
require 'securerandom'
require 'chef/knife/winrm_base'
require 'chef/knife/customization_helper'
require 'ipaddr'

class Chef::Knife::VsphereVmClone < Chef::Knife::BaseVsphereCommand
  banner 'knife vsphere vm clone VMNAME (options)'

  AUTO_MAC = 'auto'
  NO_IPS = ''

  include Chef::Knife::WinrmBase
  include CustomizationHelper
  deps do
    require 'chef/json_compat'
    require 'chef/knife/bootstrap'
    Chef::Knife::Bootstrap.load_deps
  end

  common_options

  option :dest_folder,
         long: '--dest-folder FOLDER',
         description: 'The folder into which to put the cloned VM'

  option :datastore,
         long: '--datastore STORE',
         description: 'The datastore into which to put the cloned VM'

  option :datastorecluster,
         long: '--datastorecluster STORE',
         description: 'The datastorecluster into which to put the cloned VM'

  option :host,
         long: '--host HOST',
         description: 'The host into which to put the cloned VM'

  option :resource_pool,
         long: '--resource-pool POOL',
         description: 'The resource pool or cluster into which to put the cloned VM'

  option :source_vm,
         long: '--template TEMPLATE',
         description: 'The source VM / Template to clone from'

  option :linked_clone,
         long: '--linked-clone',
         description: 'Indicates whether to use linked clones.',
         boolean: false

  option :thin_provision,
         long: '--thin-provision',
         description: 'Indicates whether disk should be thin provisioned.',
         boolean: true

  option :annotation,
         long: '--annotation TEXT',
         description: 'Add TEXT in Notes field from annotation'

  option :customization_spec,
         long: '--cspec CUST_SPEC',
         description: 'The name of any customization specification to apply'

  option :customization_plugin,
         long: '--cplugin CUST_PLUGIN_PATH',
         description: 'Path to plugin that implements KnifeVspherePlugin.customize_clone_spec and/or KnifeVspherePlugin.reconfig_vm'

  option :customization_plugin_data,
         long: '--cplugin-data CUST_PLUGIN_DATA',
         description: 'String of data to pass to the plugin.  Use any format you wish.'

  option :customization_vlan,
         long: '--cvlan CUST_VLANS',
         description: 'Comma-delimited list of VLAN names for network adapters to join'

  option :customization_sw_uuid,
         long: '--sw-uuid SWITCH_UUIDS',
         description: "Comma-delimited list of distributed virtual switch UUIDs for network adapter to connect, use 'auto' to automatically assign"

  option :customization_macs,
         long: '--cmacs CUST_MACS',
         description: 'Comma-delimited list of MAC addresses for network adapters',
         default: AUTO_MAC

  option :customization_ips,
         long: '--cips CUST_IPS',
         description: 'Comma-delimited list of CIDR IPs for customization',
         default: NO_IPS

  option :customization_dns_ips,
         long: '--cdnsips CUST_DNS_IPS',
         description: 'Comma-delimited list of DNS IP addresses'

  option :customization_dns_suffixes,
         long: '--cdnssuffix CUST_DNS_SUFFIXES',
         description: 'Comma-delimited list of DNS search suffixes'

  option :customization_gw,
         long: '--cgw CUST_GW',
         description: 'CIDR IP of gateway for customization'

  option :customization_hostname,
         long: '--chostname CUST_HOSTNAME',
         description: 'Unqualified hostname for customization'

  option :customization_domain,
         long: '--cdomain CUST_DOMAIN',
         description: 'Domain name for customization'

  option :customization_tz,
         long: '--ctz CUST_TIMEZONE',
         description: "Timezone invalid 'Area/Location' format"

  option :customization_cpucount,
         long: '--ccpu CUST_CPU_COUNT',
         description: 'Number of CPUs'

  option :customization_memory,
         long: '--cram CUST_MEMORY_GB',
         description: 'Gigabytes of RAM'

  option :power,
         long: '--start',
         description: 'Indicates whether to start the VM after a successful clone',
         boolean: false

  option :bootstrap,
         long: '--bootstrap',
         description: 'Indicates whether to bootstrap the VM',
         boolean: false

  option :environment,
         long: '--environment ENVIRONMENT',
         description: 'Environment to add the node to for bootstrapping'

  option :fqdn,
         long: '--fqdn SERVER_FQDN',
         description: 'Fully qualified hostname for bootstrapping'

  option :bootstrap_msi_url,
         long: '--bootstrap-msi-url URL',
         description: 'Location of the Chef Client MSI. The default templates will prefer to download from this location.'

  option :bootstrap_protocol,
         long: '--bootstrap-protocol protocol',
         description: 'Protocol to bootstrap windows servers. options: winrm/ssh',
         proc: proc { |key| Chef::Config[:knife][:bootstrap_protocol] = key },
         default: nil

  option :ssh_user,
         short: '-x USERNAME',
         long: '--ssh-user USERNAME',
         description: 'The ssh username',
         default: 'root'

  option :ssh_password,
         short: '-P PASSWORD',
         long: '--ssh-password PASSWORD',
         description: 'The ssh password'

  option :ssh_port,
         short: '-p PORT',
         long: '--ssh-port PORT',
         description: 'The ssh port',
         default: '22'

  option :identity_file,
         short: '-i IDENTITY_FILE',
         long: '--identity-file IDENTITY_FILE',
         description: 'The SSH identity file used for authentication'

  option :chef_node_name,
         short: '-N NAME',
         long: '--node-name NAME',
         description: 'The Chef node name for your new node'

  option :prerelease,
         long: '--prerelease',
         description: 'Install the pre-release chef gems',
         boolean: false

  option :bootstrap_version,
         long: '--bootstrap-version VERSION',
         description: 'The version of Chef to install',
         proc: proc { |v| Chef::Config[:knife][:bootstrap_version] = v }

  option :bootstrap_proxy,
         long: '--bootstrap-proxy PROXY_URL',
         description: 'The proxy server for the node being bootstrapped',
         proc: proc { |p| Chef::Config[:knife][:bootstrap_proxy] = p }

  option :bootstrap_vault_file,
         long: '--bootstrap-vault-file VAULT_FILE',
         description: 'A JSON file with a list of vault(s) and item(s) to be updated'

  option :bootstrap_vault_json,
         long: '--bootstrap-vault-json VAULT_JSON',
         description: 'A JSON string with the vault(s) and item(s) to be updated'

  option :bootstrap_vault_item,
         long: '--bootstrap-vault-item VAULT_ITEM',
         description: 'A single vault and item to update as "vault:item"',
         proc: proc { |i|
           (vault, item) = i.split(/:/)
           Chef::Config[:knife][:bootstrap_vault_item] ||= {}
           Chef::Config[:knife][:bootstrap_vault_item][vault] ||= []
           Chef::Config[:knife][:bootstrap_vault_item][vault].push(item)
           Chef::Config[:knife][:bootstrap_vault_item]
         }

  option :distro,
         short: '-d DISTRO',
         long: '--distro DISTRO',
         description: 'Bootstrap a distro using a template; default is "chef-full"',
         proc: proc { |d| Chef::Config[:knife][:distro] = d },
         default: 'chef-full'

  option :tags,
         long: '--tags TAGS',
         description: 'Comma separated list of tags to apply to the node',
         proc: ->(tags) { tags.split(/[\s,]+/) },
         default: []

  option :template_file,
         long: '--template-file TEMPLATE',
         description: 'Full path to location of template to use'

  option :run_list,
         short: '-r RUN_LIST',
         long: '--run-list RUN_LIST',
         description: 'Comma separated list of roles/recipes to apply',
         proc: -> (o) { o.split(/[\s,]+/) },
         default: []

  option :secret_file,
         long: '--secret-file SECRET_FILE',
         description: 'A file containing the secret key to use to encrypt data bag item values',
         proc: ->(secret_file) { Chef::Config[:knife][:secret_file] = secret_file }

  # rubocop:disable Style/Blocks
  option :hint,
         long: '--hint HINT_NAME[=HINT_FILE]',
         description: 'Specify Ohai Hint to be set on the bootstrap target.  Use multiple --hint options to specify multiple hints.',
         proc: proc { |h|
           Chef::Config[:knife][:hints] ||= {}
           name, path = h.split('=')
           Chef::Config[:knife][:hints][name] = path ? JSON.parse(::File.read(path)) : {}
         },
         default: ''
  # rubocop:enable Style/Blocks

  option :no_host_key_verify,
         long: '--no-host-key-verify',
         description: 'Disable host key verification',
         boolean: true

  option :node_ssl_verify_mode,
         long: '--node-ssl-verify-mode [peer|none]',
         description: 'Whether or not to verify the SSL cert for all HTTPS requests when bootstrapping'

  option :first_boot_attributes,
         short: '-j JSON_ATTRIBS',
         long: '--json-attributes',
         description: 'A JSON string to be added to the first run of chef-client',
         proc: ->(o) { JSON.parse(o) },
         default: {}

  option :disable_customization,
         long: '--disable-customization',
         description: 'Disable default customization',
         boolean: true,
         default: false

  option :log_level,
         short: '-l LEVEL',
         long: '--log_level',
         description: 'Set the log level (debug, info, warn, error, fatal) for chef-client',
         proc: ->(l) { l.to_sym }

  option :mark_as_template,
         long: '--mark_as_template',
         description: 'Indicates whether to mark the new vm as a template',
         boolean: false

  option :random_vmname,
         long: '--random-vmname',
         description: 'Creates a random VMNAME starts with vm-XXXXXXXX',
         boolean: false

  option :random_vmname_prefix,
         long: '--random-vmname-prefix PREFIX',
         description: 'Change the VMNAME prefix',
         default: 'vm-'

  option :sysprep_timeout,
         long: '--sysprep_timeout TIMEOUT',
         description: 'Wait TIMEOUT seconds for sysprep event before continuing with bootstrap',
         default: 600

  option :bootstrap_nic,
         long: '--bootstrap-nic INTEGER',
         description: 'Network interface to use when multiple NICs are defined on a template.',
         default: 0

  option :bootstrap_ipv4,
         long: '--bootstrap-ipv4',
         description: 'Force using an IPv4 address when a NIC has both IPv4 and IPv6 addresses.',
         default: false

  def run
    $stdout.sync = true

    unless using_supplied_hostname? ^ using_random_hostname?
      show_usage
      fatal_exit('You must specify a virtual machine name OR use --random-vmname')
    end

    abort '--template or knife[:source_vm] must be specified' unless config[:source_vm]

    if get_config(:datastore) && get_config(:datastorecluster)
      abort 'Please select either datastore or datastorecluster'
    end

    if get_config(:customization_macs) != AUTO_MAC && get_config(:customization_ips) == NO_IPS
      abort('Must specify IP numbers with --cips when specifying MAC addresses with --cmacs, can use "dhcp" as placeholder')
    end

    config[:chef_node_name] = vmname unless get_config(:chef_node_name)
    config[:vmname] = vmname

    vim = vim_connection
    vim.serviceContent.virtualDiskManager

    dc = datacenter

    src_folder = find_folder(get_config(:folder)) || dc.vmFolder

    src_vm = find_in_folder(src_folder, RbVmomi::VIM::VirtualMachine, config[:source_vm]) ||
             abort('VM/Template not found')

    create_delta_disk(src_vm) if get_config(:linked_clone)

    clone_spec = generate_clone_spec(src_vm.config)

    cust_folder = config[:dest_folder] || get_config(:folder)

    dest_folder = cust_folder.nil? ? src_vm.vmFolder : find_folder(cust_folder)

    task = src_vm.CloneVM_Task(folder: dest_folder, name: vmname, spec: clone_spec)
    puts "Cloning template #{config[:source_vm]} to new VM #{vmname}"

    pp clone_spec if log_verbose?

    task.wait_for_completion
    puts "Finished creating virtual machine #{vmname}"

    if customization_plugin && customization_plugin.respond_to?(:reconfig_vm)
      target_vm = find_in_folder(dest_folder, RbVmomi::VIM::VirtualMachine, vmname) || abort("VM could not be found in #{dest_folder}")
      customization_plugin.reconfig_vm(target_vm)
    end

    return if get_config(:mark_as_template)
    if get_config(:power) || get_config(:bootstrap)
      vm = find_in_folder(dest_folder, RbVmomi::VIM::VirtualMachine, vmname) ||
           fatal_exit("VM #{vmname} not found")
      vm.PowerOnVM_Task.wait_for_completion
      puts "Powered on virtual machine #{vmname}"
    end

    return unless get_config(:bootstrap)

    connect_host = guest_address(vm)
    Chef::Log.debug("Connect Host for Bootstrap: #{connect_host}")
    connect_port = get_config(:ssh_port)
    protocol = get_config(:bootstrap_protocol)
    if windows?(src_vm.config)
      protocol ||= 'winrm'
      # Set distro to windows-chef-client-msi
      config[:distro] = 'windows-chef-client-msi' if config[:distro].nil? || config[:distro] == 'chef-full'
      unless config[:disable_customization]
        # Wait for customization to complete
        puts 'Waiting for customization to complete...'
        CustomizationHelper.wait_for_sysprep(vm, vim, Integer(get_config(:sysprep_timeout)), 10)
        puts 'Customization Complete'
      end
      wait_for_access(connect_host, connect_port, protocol)
      ssh_override_winrm
      bootstrap_for_windows_node.run
    else
      protocol ||= 'ssh'
      wait_for_access(connect_host, connect_port, protocol)
      ssh_override_winrm
      bootstrap_for_node.run
    end
  end

  def ipv4_address(vm)
    puts 'Waiting for a valid IPv4 address...'
    # Multiple reboots occur during guest customization in which a link-local
    # address is assigned. As such, we need to wait until a routable IP address
    # becomes available. This is most commonly an issue with Windows instances.
    sleep 2 while vm.guest.net[bootstrap_nic_index].ipConfig.ipAddress.detect { |addr| IPAddr.new(addr.ipAddress).ipv4? }.origin == 'linklayer'
    vm.guest.net[bootstrap_nic_index].ipAddress.detect { |addr| IPAddr.new(addr).ipv4? }
  end

  def guest_address(vm)
    puts 'Waiting for network interfaces to become available...'
    sleep 2 while vm.guest.net.empty? || !vm.guest.ipAddress
    ui.info "Found address #{vm.guest.ipAddress}" if log_verbose?
    config[:fqdn] = if config[:bootstrap_ipv4]
                      ipv4_address(vm)
                    elsif config[:fqdn]
                      get_config(:fqdn)
                    else
                      # Use the first IP which is not a link-local address.
                      # This is the closest thing to vm.guest.ipAddress but
                      # allows specifying a NIC.
                      vm.guest.net[bootstrap_nic_index].ipConfig.ipAddress.detect do |addr|
                        addr.origin != 'linklayer'
                      end.ipAddress
                    end
  end

  def wait_for_access(connect_host, connect_port, protocol)
    if protocol == 'winrm'
      load_winrm_deps
      if get_config(:winrm_transport) == 'ssl' && get_config(:winrm_port) == '5985'
        config[:winrm_port] = '5986'
      end
      connect_port = get_config(:winrm_port)
      print "\n#{ui.color("Waiting for winrm access to become available on #{connect_host}:#{connect_port}", :magenta)}"
      print('.') until tcp_test_winrm(connect_host, connect_port) do
        sleep 10
        puts('done')
      end
    else
      print "\n#{ui.color("Waiting for sshd access to become available on #{connect_host}:#{connect_port}", :magenta)}"
      print('.') until tcp_test_ssh(connect_host, connect_port) do
        sleep 10
        puts('done')
      end
    end
    connect_port
  end

  def create_delta_disk(src_vm)
    disks = src_vm.config.hardware.device.grep(RbVmomi::VIM::VirtualDisk)
    disks.select { |disk| disk.backing.parent.nil? }.each do |disk|
      spec = {
        deviceChange: [
          {
            operation: :remove,
            device: disk
          },
          {
            operation: :add,
            fileOperation: :create,
            device: disk.dup.tap do |new_disk|
              new_disk.backing = new_disk.backing.dup
              new_disk.backing.fileName = "[#{disk.backing.datastore.name}]"
              new_disk.backing.parent = disk.backing
            end
          }
        ]
      }
      src_vm.ReconfigVM_Task(spec: spec).wait_for_completion
    end
  end

  def find_available_hosts
    hosts = traverse_folders_for_computeresources(datacenter.hostFolder)
    fatal_exit('No ComputeResource found - Use --resource-pool to specify a resource pool or a cluster') if hosts.empty?
    hosts.reject!(&:nil?)
    hosts.reject! { |host| host.host.all? { |h| h.runtime.inMaintenanceMode } }
    fatal_exit 'All hosts in maintenance mode!' if hosts.empty?
    if get_config(:datastore)
      hosts.reject! { |host| !host.datastore.include?(find_datastore(get_config(:datastore))) }
    end

    fatal_exit "No hosts have the requested Datastore available! #{get_config(:datastore)}" if hosts.empty?

    if get_config(:datastorecluster)
      hosts.reject! { |host| !host.datastore.include?(find_datastorecluster(get_config(:datastorecluster))) }
    end

    fatal_exit "No hosts have the requested DatastoreCluster available! #{get_config(:datastorecluster)}" if hosts.empty?

    if get_config(:customization_vlan)
      vlan_list = get_config(:customization_vlan).split(',')
      vlan_list.each do |network|
        hosts.reject! { |host| !host.network.include?(find_network(network)) }
      end
    end

    fatal_exit "No hosts have the requested Network available! #{get_config(:customization_vlan)}" if hosts.empty?
    hosts
  end

  def all_the_hosts
    hosts = traverse_folders_for_computeresources(datacenter.hostFolder)
    all_hosts = []
    hosts.each do |host|
      if host.is_a? RbVmomi::VIM::ClusterComputeResource
        all_hosts.concat(host.host)
      else
        all_hosts.push host
      end
    end
    all_hosts
  end

  def find_host(host_name)
    host = all_the_hosts.find { |host| host.name == host_name }
    raise "Can't find #{host_name}. I found #{all_the_hosts.map(&:name)}" unless host
    host
  end

  # Builds a CloneSpec
  def generate_clone_spec(src_config)
    rspec = RbVmomi::VIM.VirtualMachineRelocateSpec

    case
    when get_config(:host)
      rspec.host = find_host(get_config(:host))
      hosts = find_available_hosts
      rspec.pool = hosts.first.resourcePool
    when get_config(:resource_pool)
      rspec.pool = find_pool(get_config(:resource_pool))
    else
      hosts = find_available_hosts
      rspec.pool = hosts.first.resourcePool
    end

    rspec.diskMoveType = :moveChildMostDiskBacking if get_config(:linked_clone)

    if get_config(:datastore)
      rspec.datastore = find_datastore(get_config(:datastore))
    end

    if get_config(:datastorecluster)
      dsc = find_datastorecluster(get_config(:datastorecluster))

      dsc.childEntity.each do |store|
        if rspec.datastore.nil? || rspec.datastore.summary[:freeSpace] < store.summary[:freeSpace]
          rspec.datastore = store
        end
      end
    end

    rspec.transform = :sparse if get_config(:thin_provision)

    is_template = !get_config(:mark_as_template).nil?
    clone_spec = RbVmomi::VIM.VirtualMachineCloneSpec(location: rspec, powerOn: false, template: is_template)

    clone_spec.config = RbVmomi::VIM.VirtualMachineConfigSpec(deviceChange: [])

    if get_config(:annotation)
      clone_spec.config.annotation = get_config(:annotation)
    end

    if get_config(:customization_cpucount)
      clone_spec.config.numCPUs = get_config(:customization_cpucount)
    end

    if get_config(:customization_memory)
      clone_spec.config.memoryMB = Integer(get_config(:customization_memory)) * 1024
    end

    mac_list = if get_config(:customization_macs) == AUTO_MAC
                 [AUTO_MAC] * get_config(:customization_ips).split(',').length
               else
                 get_config(:customization_macs).split(',')
               end

    if get_config(:customization_sw_uuid)
      unless get_config(:customization_vlan)
        abort('Must specify VLANs with --cvlan when specifying switch UUIDs with --sw-uuids')
      end
      swuuid_list = if get_config(:customization_sw_uuid) == 'auto'
                      ['auto'] * get_config(:customization_ips).split(',').length
                    else
                      get_config(:customization_sw_uuid).split(',').map { |swuuid| swuuid.gsub(/((\w+\s+){7})(\w+)\s+(.+)/, '\1\3-\4') }
                    end
    end

    if get_config(:customization_vlan)
      vlan_list = get_config(:customization_vlan).split(',')
      sw_uuid   = get_config(:customization_sw_uuid)
      networks  = vlan_list.map { |vlan| find_network(vlan, sw_uuid) }

      cards = src_config.hardware.device.grep(RbVmomi::VIM::VirtualEthernetCard)

      networks.each_with_index do |network, index|
        card = cards[index] || abort("Can't find source network card to customize for vlan #{vlan_list[index]}")
        begin
          if get_config(:customization_sw_uuid) && (swuuid_list[index] != 'auto')
            switch_port = RbVmomi::VIM.DistributedVirtualSwitchPortConnection(
              switchUuid: swuuid_list[index], portgroupKey: network.key
            )
          else
            switch_port = RbVmomi::VIM.DistributedVirtualSwitchPortConnection(
              switchUuid: network.config.distributedVirtualSwitch.uuid, portgroupKey: network.key
            )
          end
          card.backing.port = switch_port
        rescue
          # not connected to a distibuted switch?
          card.backing = RbVmomi::VIM::VirtualEthernetCardNetworkBackingInfo(network: network, deviceName: network.name)
        end
        card.macAddress = mac_list[index] if get_config(:customization_macs) && mac_list[index] != AUTO_MAC
        dev_spec = RbVmomi::VIM.VirtualDeviceConfigSpec(device: card, operation: 'edit')
        clone_spec.config.deviceChange.push dev_spec
      end
    end

    cust_spec = if get_config(:customization_spec)
                  csi = find_customization(get_config(:customization_spec)) ||
                    fatal_exit("failed to find customization specification named #{get_config(:customization_spec)}")

                  csi.spec
                else
                  global_ipset = RbVmomi::VIM.CustomizationGlobalIPSettings
                  identity_settings = RbVmomi::VIM.CustomizationIdentitySettings
                  RbVmomi::VIM.CustomizationSpec(globalIPSettings: global_ipset, identity: identity_settings)
                end

    if get_config(:disable_customization)
      clone_spec.customization = get_config(:customization_spec) ? cust_spec : nil
      return clone_spec
    end

    if get_config(:customization_dns_ips)
      cust_spec.globalIPSettings.dnsServerList = get_config(:customization_dns_ips).split(',')
    end

    if get_config(:customization_dns_suffixes)
      cust_spec.globalIPSettings.dnsSuffixList = get_config(:customization_dns_suffixes).split(',')
    end

    if config[:customization_ips] != NO_IPS
      cust_spec.nicSettingMap = config[:customization_ips].split(',').map.with_index { |cust_ip, index|
        generate_adapter_map(cust_ip, get_config(:customization_gw), mac_list[index])
      }
    end

    # TODO: why does the domain matter?
    use_ident = config[:customization_hostname] || get_config(:customization_domain) || cust_spec.identity.props.empty?

    # TODO: How could we not take this? Only if the identity were empty, but that's statically defined as empty above
    if use_ident
      hostname = config[:customization_hostname] || config[:vmname]

      if windows?(src_config)
        # We should get here with the customizations set, either by a plugin or a --cspec
        fatal_exit 'Windows clones need a customization identity. Try passing a --cspec or making a --cplugin' if cust_spec.identity.props.empty?

        identification = RbVmomi::VIM.CustomizationIdentification(
          joinWorkgroup: cust_spec.identity.identification.joinWorkgroup
        )
        license_file_print_data = RbVmomi::VIM.CustomizationLicenseFilePrintData(
          autoMode: cust_spec.identity.licenseFilePrintData.autoMode
        )

        user_data = RbVmomi::VIM.CustomizationUserData(
          fullName: cust_spec.identity.userData.fullName,
          orgName: cust_spec.identity.userData.orgName,
          productId: cust_spec.identity.userData.productId,
          computerName: RbVmomi::VIM.CustomizationFixedName(name: hostname)
        )

        gui_unattended = RbVmomi::VIM.CustomizationGuiUnattended(
          autoLogon: cust_spec.identity.guiUnattended.autoLogon,
          autoLogonCount: cust_spec.identity.guiUnattended.autoLogonCount,
          password: RbVmomi::VIM.CustomizationPassword(
            plainText: cust_spec.identity.guiUnattended.password.plainText,
            value: cust_spec.identity.guiUnattended.password.value
          ),
          timeZone: cust_spec.identity.guiUnattended.timeZone
        )
        runonce = RbVmomi::VIM.CustomizationGuiRunOnce(
          commandList: ['cust_spec.identity.guiUnattended.commandList']
        )
        ident = RbVmomi::VIM.CustomizationSysprep
        ident.guiRunOnce = runonce
        ident.guiUnattended = gui_unattended
        ident.identification = identification
        ident.licenseFilePrintData = license_file_print_data
        ident.userData = user_data
        cust_spec.identity = ident
      elsif linux?(src_config)
        ident = RbVmomi::VIM.CustomizationLinuxPrep
        ident.hostName = RbVmomi::VIM.CustomizationFixedName(name: hostname)

        ident.domain = if get_config(:customization_domain)
                         get_config(:customization_domain)
                       else
                         ''
                       end
        cust_spec.identity = ident
      else
        ui.error('Customization only supports Linux and Windows currently.')
        exit 1
      end
    end
    clone_spec.customization = cust_spec

    if customization_plugin && customization_plugin.respond_to?(:customize_clone_spec)
      clone_spec = customization_plugin.customize_clone_spec(src_config, clone_spec)
    end
    clone_spec
  end

  # Loads the customization plugin if one was specified
  # @return [KnifeVspherePlugin] the loaded and initialized plugin or nil
  def customization_plugin
    if @customization_plugin.nil?
      cplugin_path = get_config(:customization_plugin)
      if cplugin_path
        if File.exist? cplugin_path
          require cplugin_path
        else
          abort "Customization plugin could not be found at #{cplugin_path}"
        end

        if Object.const_defined? 'KnifeVspherePlugin'
          @customization_plugin = Object.const_get('KnifeVspherePlugin').new
          cplugin_data = get_config(:customization_plugin_data)
          if cplugin_data
            if @customization_plugin.respond_to?(:data=)
              @customization_plugin.data = cplugin_data
            else
              abort 'Customization plugin has no :data= accessor to receive the --cplugin-data argument.  Define both or neither.'
            end
          end
        else
          abort "KnifeVspherePlugin class is not defined in #{cplugin_path}"
        end
      end
    end

    @customization_plugin
  end

  # Retrieves a CustomizationSpecItem that matches the supplied name
  # @param vim [Connection] VI Connection to use
  # @param name [String] name of customization
  # @return [RbVmomi::VIM::CustomizationSpecItem]
  def find_customization(name)
    csm = vim_connection.serviceContent.customizationSpecManager
    csm.GetCustomizationSpec(name: name)
  end

  # Generates a CustomizationAdapterMapping (currently only single IPv4 address) object
  # @param ip [String] Any static IP address to use, or "dhcp" for DHCP
  # @param gw [String] If static, the gateway for the interface, otherwise network address + 1 will be used
  # @return [RbVmomi::VIM::CustomizationIPSettings]
  def generate_adapter_map(ip = nil, gw = nil, mac = nil)
    settings = RbVmomi::VIM.CustomizationIPSettings

    if ip.nil? || ip.downcase == 'dhcp'
      settings.ip = RbVmomi::VIM::CustomizationDhcpIpGenerator.new
    else
      cidr_ip = NetAddr::CIDR.create(ip)
      settings.ip = RbVmomi::VIM::CustomizationFixedIp(ipAddress: cidr_ip.ip)
      settings.subnetMask = cidr_ip.netmask_ext

      # TODO: want to confirm gw/ip are in same subnet?
      # Only set gateway on first IP.
      if config[:customization_ips].split(',').first == ip
        if gw.nil?
          settings.gateway = [cidr_ip.network(Objectify: true).next_ip]
        else
          gw_cidr = NetAddr::CIDR.create(gw)
          settings.gateway = [gw_cidr.ip]
        end
      end
    end

    adapter_map = RbVmomi::VIM.CustomizationAdapterMapping
    adapter_map.macAddress = mac if !mac.nil? && (mac != AUTO_MAC)
    adapter_map.adapter = settings
    adapter_map
  end

  def bootstrap_common_params(bootstrap)
    bootstrap.config[:run_list] = config[:run_list]
    bootstrap.config[:bootstrap_version] = get_config(:bootstrap_version)
    bootstrap.config[:distro] = get_config(:distro)
    bootstrap.config[:template_file] = get_config(:template_file)
    bootstrap.config[:environment] = get_config(:environment)
    bootstrap.config[:prerelease] = get_config(:prerelease)
    bootstrap.config[:first_boot_attributes] = get_config(:first_boot_attributes)
    bootstrap.config[:hint] = get_config(:hint)
    bootstrap.config[:chef_node_name] = get_config(:chef_node_name)
    bootstrap.config[:bootstrap_vault_file] = get_config(:bootstrap_vault_file)
    bootstrap.config[:bootstrap_vault_json] = get_config(:bootstrap_vault_json)
    bootstrap.config[:bootstrap_vault_item] = get_config(:bootstrap_vault_item)
    # may be needed for vpc mode
    bootstrap.config[:no_host_key_verify] = get_config(:no_host_key_verify)
    bootstrap.config[:node_ssl_verify_mode] = get_config(:node_ssl_verify_mode)
    bootstrap.config[:tags] = get_config(:tags)
    bootstrap
  end

  def bootstrap_for_windows_node
    Chef::Knife::Bootstrap.load_deps
    if get_config(:bootstrap_protocol) == 'winrm' || get_config(:bootstrap_protocol).nil?
      bootstrap = Chef::Knife::BootstrapWindowsWinrm.new
      bootstrap.name_args = [config[:fqdn]]
      bootstrap.config[:winrm_user] = get_config(:winrm_user)
      bootstrap.config[:winrm_password] = get_config(:winrm_password)
      bootstrap.config[:winrm_transport] = get_config(:winrm_transport)
      bootstrap.config[:winrm_port] = get_config(:winrm_port)
    elsif get_config(:bootstrap_protocol) == 'ssh'
      bootstrap = Chef::Knife::BootstrapWindowsSsh.new
      bootstrap.config[:ssh_user] = get_config(:ssh_user)
      bootstrap.config[:ssh_password] = get_config(:ssh_password)
      bootstrap.config[:ssh_port] = get_config(:ssh_port)
    else
      ui.error('Unsupported Bootstrapping Protocol. Supports : winrm, ssh')
      exit 1
    end
    bootstrap.config[:msi_url] = get_config(:bootstrap_msi_url)
    bootstrap_common_params(bootstrap)
  end

  def bootstrap_for_node
    Chef::Knife::Bootstrap.load_deps
    bootstrap = Chef::Knife::Bootstrap.new
    bootstrap.name_args = [config[:fqdn]]
    bootstrap.config[:secret_file] = get_config(:secret_file)
    bootstrap.config[:ssh_user] = get_config(:ssh_user)
    bootstrap.config[:ssh_password] = get_config(:ssh_password)
    bootstrap.config[:ssh_port] = get_config(:ssh_port)
    bootstrap.config[:identity_file] = get_config(:identity_file)
    bootstrap.config[:use_sudo] = true unless get_config(:ssh_user) == 'root'
    bootstrap.config[:use_sudo_password] = true unless get_config(:ssh_user) == 'root'
    bootstrap.config[:log_level] = get_config(:log_level)
    bootstrap_common_params(bootstrap)
  end

  def ssh_override_winrm
    # unchanged ssh_user and changed winrm_user, override ssh_user
    if get_config(:ssh_user).eql?(options[:ssh_user][:default]) &&
       !get_config(:winrm_user).eql?(options[:winrm_user][:default])
      config[:ssh_user] = get_config(:winrm_user)
    end

    # unchanged ssh_port and changed winrm_port, override ssh_port
    if get_config(:ssh_port).eql?(options[:ssh_port][:default]) &&
       !get_config(:winrm_port).eql?(options[:winrm_port][:default])
      config[:ssh_port] = get_config(:winrm_port)
    end

    # unset ssh_password and set winrm_password, override ssh_password
    if get_config(:ssh_password).nil? &&
       !get_config(:winrm_password).nil?
      config[:ssh_password] = get_config(:winrm_password)
    end

    # unset identity_file and set kerberos_keytab_file, override identity_file
    return unless get_config(:identity_file).nil? && !get_config(:kerberos_keytab_file).nil?

    config[:identity_file] = get_config(:kerberos_keytab_file)
  end

  def tcp_test_ssh(hostname, ssh_port)
    tcp_socket = TCPSocket.new(hostname, ssh_port)
    readable = IO.select([tcp_socket], nil, nil, 5)
    if readable
      ssh_banner = tcp_socket.gets
      if ssh_banner.nil? || ssh_banner.empty?
        false
      else
        Chef::Log.debug("sshd accepting connections on #{hostname}, banner is #{ssh_banner}")
        yield
        true
      end
    else
      false
    end
  rescue SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ENETUNREACH, IOError
    Chef::Log.debug("ssh failed to connect: #{hostname}")
    sleep 2
    false
  rescue Errno::EPERM, Errno::ETIMEDOUT
    Chef::Log.debug("ssh timed out: #{hostname}")
    false
  rescue Errno::ECONNRESET
    Chef::Log.debug("ssh reset its connection: #{hostname}")
    sleep 2
    false
  ensure
    tcp_socket && tcp_socket.close
  end

  def tcp_test_winrm(hostname, port)
    tcp_socket = TCPSocket.new(hostname, port)
    yield
    true
  rescue SocketError
    sleep 2
    false
  rescue Errno::ETIMEDOUT
    false
  rescue Errno::EPERM
    false
  rescue Errno::ECONNREFUSED
    sleep 2
    false
  rescue Errno::EHOSTUNREACH
    sleep 2
    false
  rescue Errno::ENETUNREACH
    sleep 2
    false
  ensure
    tcp_socket && tcp_socket.close
  end

  def load_winrm_deps
    require 'winrm'
    require 'chef/knife/winrm'
    require 'chef/knife/bootstrap_windows_winrm'
    require 'chef/knife/bootstrap_windows_ssh'
    require 'chef/knife/core/windows_bootstrap_context'
  end

  private

  def vmname
    supplied_hostname || random_hostname
  end

  def using_random_hostname?
    config[:random_vmname]
  end

  def using_supplied_hostname?
    !supplied_hostname.nil?
  end

  def supplied_hostname
    @name_args[0]
  end

  def random_hostname
    @random_hostname ||= config[:random_vmname_prefix] + SecureRandom.hex(4)
  end

  def bootstrap_nic_index
    Integer(get_config(:bootstrap_nic))
  end
end
