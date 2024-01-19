class profile::software_stack (
  Integer $min_uid = 1000,
  String $initial_profile = '',
  Array[String] $lmod_default_modules = [],
  Hash[String, String] $extra_site_env_vars = {},
) {
  include consul
  include profile::cvmfs::client

  package { 'cvmfs-config-eessi':
    ensure   => 'installed',
    provider => 'rpm',
    before   => Package['cvmfs'],
    source   => 'https://github.com/EESSI/filesystem-layer/releases/download/latest/cvmfs-config-eessi-latest.noarch.rpm',
  }

  package { 'computecanada-release-2.0-1.noarch':
    ensure   => 'installed',
    provider => 'rpm',
    source   => 'https://package.computecanada.ca/yum/cc-cvmfs-public/prod/RPM/computecanada-release-2.0-1.noarch.rpm',
  }

  package { 'cvmfs-config-computecanada':
    ensure  => 'installed',
    before  => Package['cvmfs'],
    require => [Package['computecanada-release-2.0-1.noarch']],
  }

  if $facts['software_stack'] == 'computecanada' or $facts['software_stack'] == 'alliance' {
    if $facts['os']['architecture'] != 'x86_64' {
      fail("${facts['software_stack']} software stack does not support: ${facts['os']['architecture']}")
    }

    file { '/etc/consul-template/z-00-rsnt_arch.sh.ctmpl':
      source => 'puppet:///modules/profile/software_stack/z-00-rsnt_arch.sh.ctmpl',
      notify => Service['consul-template'],
    }

    consul_template::watch { 'z-00-rsnt_arch.sh':
      require     => File['/etc/consul-template/z-00-rsnt_arch.sh.ctmpl'],
      config_hash => {
        perms       => '0644',
        source      => '/etc/consul-template/z-00-rsnt_arch.sh.ctmpl',
        destination => '/etc/profile.d/z-00-rsnt_arch.sh',
        command     => '/usr/bin/true',
      },
    }
    $software_stack_meta = { arch => $facts['cpu_ext'] }
  } else {
    $software_stack_meta = {}
  }

  $ensure_stack = $facts['software_stack'] != '' ? { true => 'present' , false => 'absent' }

  file { '/etc/profile.d/z-01-site.sh':
    ensure  => $ensure_stack,
    content => epp('profile/software_stack/z-01-site.sh',
      {
        'min_uid'              => $min_uid,
        'lmod_default_modules' => $lmod_default_modules,
        'initial_profile'      => $initial_profile,
        'extra_site_env_vars'  => $extra_site_env_vars,
      }
    ),
  }

  consul::service { 'software_stack':
    ensure  => $ensure_stack,
    require => Tcp_conn_validator['consul'],
    token   => lookup('profile::consul::acl_api_token'),
    meta    => $software_stack_meta,
  }
}
