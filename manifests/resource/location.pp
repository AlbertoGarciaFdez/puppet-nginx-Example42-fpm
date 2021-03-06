# define: nginx::resource::location
#
# This definition creates a new location entry within a virtual host
#
# Parameters:
#   [*ensure*]             - Enables or disables the specified location (present|absent)
#   [*vhost*]              - Defines the default vHost for this location entry to include with
#   [*location*]           - Specifies the URI associated with this location entry
#   [*www_root*]           - Specifies the location on disk for files to be read from. Cannot be set in conjunction with $proxy
#   [*index_files*]        - Default index files for NGINX to read when traversing a directory
#   [*proxy*]              - Proxy server(s) for a location to connect to. Accepts a single value, can be used in conjunction
#                            with nginx::resource::upstream
#   [*proxy_read_timeout*] - Override the default the proxy read timeout value of 90 seconds
#   [*ssl*]                - Indicates whether to setup SSL bindings for this location.
#   [*option*]             - Reserved for future use
#
# Actions:
#
# Requires:
#
# Sample Usage:
#  nginx::resource::location { 'test2.local-bob':
#    ensure   => present,
#    www_root => '/var/www/bob',
#    location => '/bob',
#    vhost    => 'test2.local',
#  }
define nginx::resource::location(
  $ensure             = present,
  $vhost              = undef,
  $www_root           = undef,
  $index_files        = ['index.html', 'index.htm', 'index.php'],
  $proxy              = undef,
  $proxy_read_timeout = '90',
  $proxy_set_header   = ['Host $host', 'X-Real-IP $remote_addr', 'X-Forwarded-For $proxy_add_x_forwarded_for', 'X-Forwarded-Proto $scheme' ],
  $ssl                = false,
  $option             = undef,
  $template_proxy     = 'nginx/vhost/vhost_location_proxy.erb',
  $template_directory = 'nginx/vhost/vhost_location_directory.erb',
  $location
) {
  File {
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
    notify => $nginx::manage_service_autorestart,
  }

  ## Shared Variables
  $ensure_real = $ensure ? {
    'absent' => absent,
    default  => file,
  }

  # Use proxy template if $proxy is defined, otherwise use directory template.
  if ($proxy != undef) {
    $content_real = template("${template_proxy}")
  } else {
    $content_real = template("${template_directory}")
  }

  ## Check for various error condtiions
  if ($vhost == undef) {
    fail('Cannot create a location reference without attaching to a virtual host')
  }
  if (($www_root == undef) and ($proxy == undef)) {
    fail('Cannot create a location reference without a www_root or proxy defined')
  }
  if (($www_root != undef) and ($proxy != undef)) {
    fail('Cannot define both directory and proxy in a virtual host')
  }

  ## Create stubs for vHost File Fragment Pattern
  concat::fragment { "${vhost}+50.tmp":
    ensure  => $ensure,
    order   => '50',
    content => $content_real,
    target  => "${nginx::config_dir}/sites-available/${vhost}.conf",
  }

  ## Only create SSL Specific locations if $ssl is true.
  concat::fragment { "${vhost}+80-ssl.tmp":
    ensure  => $ssl,
    order   => '80',
    content => $content_real,
    target  => "${nginx::config_dir}/sites-available/${vhost}.conf",
  }
}
