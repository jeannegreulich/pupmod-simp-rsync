require 'spec_helper_acceptance'

test_name 'rsync class'

describe 'rsync class' do
  let(:manifest) {
    <<-EOS
      include '::rsync::server::global'

      include '::iptables'

      iptables::listen::tcp_stateful { 'ssh':
        dports       => 22,
        trusted_nets => ['any']
      }

      file { '/srv/rsync':
        ensure => 'directory'
      }

      file { '/srv/rsync/test':
        ensure => 'directory'
      }

      file { '/srv/rsync/test/test_file':
        ensure  => 'file',
        content => 'What a Test File'
      }

      rsync::server::section { 'test':
        auth_users => ['test_user'],
        comment    => 'A test system',
        path       => '/srv/rsync/test',
        require    => File['/srv/rsync/test/test_file']
      }

      rsync::retrieve { 'test_pull':
        user         => 'test_user',
        pass         => passgen('test_user'),
        source_path  => 'test/test_file',
        target_path  => '/tmp',
        rsync_server => '127.0.0.1',
        require      => Rsync::Server::Section['test']
      }
    EOS
  }

  let(:hieradata) {
    <<-EOS
---
use_simp_pki : false

pki_dir : '/etc/pki/simp-testing/pki'

stunnel::ca_source : "%{hiera('pki_dir')}/cacerts"
stunnel::cert : "%{hiera('pki_dir')}/public/%{fqdn}.pub"
stunnel::key : "%{hiera('pki_dir')}/public/%{fqdn}.pem"

rsync::server::stunnel : false
    EOS
  }

  hosts.each do |host|
    # Using puppet_apply as a helper
    it 'should work with no errors' do
      set_hieradata_on(host, hieradata)
      apply_manifest_on(host, manifest, :catch_failures => true)
    end

=begin
    it 'should be idempotent' do
      apply_manifest(manifest, {:catch_changes => true})
    end
=end

    it 'should have a file transferred' do
      on(host, 'ls /tmp/test_file', :acceptable_exit_codes => [0])
    end
  end
end
