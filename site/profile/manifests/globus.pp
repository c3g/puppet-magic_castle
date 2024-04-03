class profile::globus(
  String $display_name,
  String $organization,
  String $owner,
  String $contact_email,
  Array[String] $accepted_domains,
  Array[String] $exposed_paths

) {
  package { 'wget':
    ensure => installed,
  }

$public_ip = lookup("terraform.instances.${facts['networking']['hostname']}.public_ip")
$users = lookup("profile::users::ldap::users")

class { 'globus':
  display_name   => $display_name,
  organization   => $organization,
  owner          => $owner,
  contact_email  => $contact_email,
  ip_address    => $public_ip,
  accepted_domains => $accepted_domains,
  exposed_paths => $exposed_paths,
  users => $users
}

#  class { 'globus':
#    display_name  => $globus::display_name,
#    contact_email => $globus::contact_email,
#    ip_address    => $public_ip,
#    organization  => $globus::organization,
#    owner         => $globus::owner,
#    require       => Package['wget'],
#  }
}
