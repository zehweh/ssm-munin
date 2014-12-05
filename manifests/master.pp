# munin::master - Define a munin master
#
# The munin master will install munin, and collect all exported munin
# node definitions as files into /etc/munin/munin-conf.d/.
#
# Parameters:
#
# - node_definitions: A hash of node definitions used by
#   create_resources to make static node definitions.
#
# - host_name: A host name for this munin master, matched with
#   munin::node::mastername for collecting nodes. Defaults to $::fqdn
#
# - graph_strategy: 'cgi' (default) or 'cron'
#   Controls if munin-graph graphs all services ('cron') or if graphing is done
#   by munin-cgi-graph (which must configured seperatly)
#
# - html_strategy: 'cgi' (default) or 'cron'
#   Controls if munin-html will recreate all html pages every run interval
#   ('cron') or if html pages are generated by munin-cgi-graph (which must
#   configured seperatly)
#
# - config_root: the root directory of the munin master configuration.
#   Default: /etc/munin on most platforms.
#
# - collect_nodes: 'enabled' (default), 'disabled', 'mine' or
#   'unclaimed'. 'enabled' makes the munin master collect all exported
#   node_definitions. 'disabled' disables it. 'mine' makes the munin
#   master collect nodes matching $munin::master::host_name, while
#   'unclaimed' makes the munin master collect nodes not tagged with a
#   host name.
#
# - dbdir: Path to the munin dbdir, where munin stores everything
#
# - htmldir: Path to where munin will generate HTML documents and
#   graphs, used if graph_strategy is cron.
#
# - rundir: Path to directory munin uses for pid and lock files.
#
# - tls: 'enabled' or 'disabled' (default). Controls the use of TLS
#   globally for master to node communications.
#
# - tls_certificate: Path to a file containing a TLS certificate. No
#   default. Required if tls is enabled.
#
# - tls_private_key: Path to a file containing a TLS key. No default.
#   Required if tls is enabled.
#
# - tls_verify_certificate: 'yes' (default) or 'no'.
#
# - extra_config: Extra lines of config to put in munin.conf.

class munin::master (
  $node_definitions       = $munin::params::master::node_defintions,
  $graph_strategy         = $munin::params::master::graph_strategy,
  $html_strategy          = $munin::params::master::html_strategy,
  $config_root            = $munin::params::master::config_root,
  $collect_nodes          = $munin::params::master::collect_nodes,
  $dbdir                  = $munin::params::master::dbdir,
  $htmldir                = $munin::params::master::htmldir,
  $logdir                 = $munin::params::master::logdir,
  $rundir                 = $munin::params::master::rundir,
  $tls                    = $munin::params::master::tls,
  $tls_certificate        = $munin::params::master::tls_certificate,
  $tls_private_key        = $munin::params::master::tls_private_key,
  $tls_verify_certificate = $munin::params::master::tls_verify_certificate,
  $host_name              = $munin::params::master::host_name,
  $extra_config           = $munin::params::master::extra_config,
  ) inherits munin::params::master {

  if $node_definitions {
    validate_hash($node_definitions)
  }
  if $graph_strategy {
    validate_re($graph_strategy, [ '^cgi$', '^cron$' ])
  }
  if $html_strategy {
    validate_re($html_strategy, [ '^cgi$', '^cron$' ])
  }
  validate_re($collect_nodes, [ '^enabled$', '^disabled$', '^mine$',
                                '^unclaimed$' ])
  validate_absolute_path($config_root)

  validate_re($tls, [ '^enabled$', '^disabled$' ])

  if $tls == 'enabled' {
    validate_re($tls_verify_certificate, [ '^yes$', '^no$' ])
    validate_absolute_path($tls_private_key)
    validate_absolute_path($tls_certificate)
  }

  if $host_name {
    validate_string($host_name)
    if ! is_domain_name("${host_name}") {
      fail('host_name should be a valid domain name')
    }
  }

  validate_array($extra_config)

  # The munin package and configuration
  package { 'munin':
    ensure => latest,
  }

  File {
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    require => Package['munin'],
  }

  file { "${config_root}/munin.conf":
    content => template('munin/munin.conf.erb'),
  }

  file { "${config_root}/munin-conf.d":
    ensure  => directory,
    recurse => true,
    purge   => true,
    force   => true,
  }

  case $collect_nodes {
    'enabled': {
      Munin::Master::Node_definition <<| |>>
    }
    'mine': {
      # Collect nodes explicitly tagged with this master
      Munin::Master::Node_definition <<| tag == "munin::master::${host_name}" |>>
    }
    'unclaimed': {
      # Collect all exported node definitions, except the ones tagged
      # for a specific master
      Munin::Master::Node_definition <<| tag == 'munin::master::' |>>
    }
    'disabled',
    default: {
      # do nothing
    }
  }

  # Create static node definitions
  if $node_definitions {
    create_resources(munin::master::node_definition, $node_definitions, {})
  }
}
