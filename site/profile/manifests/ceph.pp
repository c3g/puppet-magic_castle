type BindMount = Struct[{
    'src'  => Stdlib::Unixpath,
    'dst'  => Stdlib::Unixpath,
    'type' => Optional[Enum['file', 'directory']],
}]

type CephFS = Struct[
  {
    'share_name' => String,
    'access_key' => String,
    'export_path' => Stdlib::Unixpath,
    'bind_mounts' => Optional[Array[BindMount]],
    'binds_fcontext_equivalence' => Optional[Stdlib::Unixpath],
  }
]

class profile::ceph::client (
  Array[String] $mon_host,
  Hash[String, CephFS] $shares,
) {
  require profile::ceph::client::install

  $mon_host_string = join($mon_host, ',')
  $ceph_conf = @("EOT")
    [global]
    admin socket = /var/run/ceph/$cluster-$name-$pid.asok
    client reconnect stale = true
    debug client = 0/2
    fuse big writes = true
    mon host = ${mon_host_string}
    [client]
    client quota = true
    | EOT

  file { '/etc/ceph/ceph.conf':
    content => $ceph_conf,
  }

  ensure_resources(profile::ceph::client::share, $shares, { 'mon_host' => $mon_host, 'bind_mounts' => [] })
}

class profile::ceph::client::install {
  include epel

  yumrepo { 'ceph-stable':
    ensure        => present,
    enabled       => true,
    baseurl       => "https://download.ceph.com/rpm-quincy/el${$::facts['os']['release']['major']}/${::facts['architecture']}/",
    gpgcheck      => 1,
    gpgkey        => 'https://download.ceph.com/keys/release.asc',
    repo_gpgcheck => 0,
  }

  if versioncmp($::facts['os']['release']['major'], '8') >= 0 {
    $argparse_pkgname = 'python3-ceph-argparse'
  } else {
    $argparse_pkgname = 'python-ceph-argparse'
  }

  package {
    [
      'libcephfs2',
      'python-cephfs',
      'ceph-common',
      $argparse_pkgname,
      # 'ceph-fuse',
    ]:
      ensure  => installed,
      require => [Yumrepo['epel'], Yumrepo['ceph-stable']],
  }
}

define profile::ceph::client::share (
  Array[String] $mon_host,
  String $share_name,
  String $access_key,
  Stdlib::Unixpath $export_path,
  Array[BindMount] $bind_mounts,
  Optional[Stdlib::Unixpath] $binds_fcontext_equivalence = undef,
) {
  $client_fullkey = @("EOT")
    [client.${share_name}]
    key = ${access_key}
    | EOT

  file { "/etc/ceph/ceph.client.${share_name}.keyring":
    content => $client_fullkey,
    mode    => '0600',
    owner   => 'root',
    group   => 'root',
  }

  file { "/mnt/${name}":
    ensure => directory,
  }

  $mon_host_string = join($mon_host, ',')
  mount { "/mnt/${name}":
    ensure  => 'mounted',
    fstype  => 'ceph',
    device  => "${mon_host_string}:${export_path}",
    options => "name=${share_name},mds_namespace=cephfs_4_2,x-systemd.device-timeout=30,x-systemd.mount-timeout=30,noatime,_netdev,rw",
    require => File['/etc/ceph/ceph.conf'],
  }

  $bind_mounts.each |$mount| {
    file { $mount['dst']:
      ensure  => pick($mount['type'], 'directory'),
    }
    mount { $mount['dst']:
      ensure  => 'mounted',
      fstype  => 'none',
      options => 'rw,bind',
      device  => "/mnt/${name}${mount['src']}",
      require => [
        File[$mount['dst']],
        Mount["/mnt/${name}"]
      ],
    }

    if ($binds_fcontext_equivalence and $binds_fcontext_equivalence != $mount['dst']) {
      selinux::fcontext::equivalence { $mount['dst']:
        ensure  => 'present',
        target  => $binds_fcontext_equivalence,
        require => Mount[$mount['dst']],
      }
    }
  }
}
