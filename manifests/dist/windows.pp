# Windows-specific handling

class graylogcollectorsidecar::dist::windows (
  $api_url,
  $tags,
  $update_interval   = undef,
  $tls_skip_verify   = undef,
  $send_status       = undef,
  $list_log_files    = undef,
  $node_id           = undef,
  $collector_id      = undef,
  $log_path          = undef,
  $log_rotation_time = undef,
  $log_max_age       = undef,
  $backends          = undef,
  $version           = '0.1.4',
  $mirror_url        = 'https://github.com/Graylog2/collector-sidecar/releases/download',
) {

  $graylog_install_directory = 'C:\\Program Files\\Graylog\\collector-sidecar'

  if ($::installed_sidecar_version == $version) {
    debug("Already installed sidecard version ${version}")
  } else {
    # Download package
    archive { 'C:\\Temp\\collector-sidecar.exe':
      ensure  => present,
      source  => "${mirror_url}/${version}/collector_sidecar_installer_${version}-1.exe",
      creates => 'C:\\Temp\\collector-sidecar.exe',
      cleanup => false,
    }

    #  Install the package

    exec { 'install_sidecar':
      command     => "C:\\Temp\\collector-sidecar.exe /S -SERVERURL=${api_url} -TAGS=Windows",
      refreshonly => true,
    }

    exec { 'install_sidecar_service':
      command     => "\"${graylog_install_directory}\\Graylog-collector-sidecar.exe\" -service install",
      refreshonly => true,
    }

    Archive[ 'C:\\Temp\\collector-sidecar.exe' ]
    ~> Exec[ 'install_sidecar' ]
    ~> Exec[ 'install_sidecar_service' ]
    -> Class['graylogcollectorsidecar::configure']
    -> Service['sidecar']

  }

  # Configure it

  $_collector_id = pick(
    $collector_id,
    "file:${graylog_install_directory}\\collector-id"
  )

  $_log_path = pick(
    $log_path,
    "${graylog_install_directory}\\logs"
  )

  $_backends = pick(
    $backends,
    [
      {
        name               => 'nxlog',
        enabled            => false,
        binary_path        => "C:\\Program Files (x86)\\nxlog\\nxlog.exe",
        configuration_path =>
          "${graylog_install_directory}\\generated\\nxlog.conf"
      },
      {
        name               => 'winlogbeat',
        enabled            => true,
        binary_path        => "${graylog_install_directory}\\winlogbeat.exe",
        configuration_path =>
          "${graylog_install_directory}\\generated\\winlogbeat.yml"
      },
      {
        name               => 'filebeat',
        enabled            => true,
        binary_path        => "${graylog_install_directory}\\filebeat.exe",
        configuration_path =>
          "${graylog_install_directory}\\generated\\filebeat.yml"
      },
    ]
  )

  class { '::graylogcollectorsidecar::configure':
    sidecar_yaml_file =>
      "${graylog_install_directory}\\collector_sidecar.yml",
    api_url           => $api_url,
    tags              => $tags,
    update_interval   => $update_interval,
    tls_skip_verify   => $tls_skip_verify,
    send_status       => $send_status,
    list_log_files    => $list_log_files,
    node_id           => $node_id,
    collector_id      => $_collector_id,
    log_path          => $_log_path,
    log_rotation_time => $log_rotation_time,
    log_max_age       => $log_max_age,
    backends          => $_backends,
  } ~> Service['sidecar']

  # Start the service

  Service { 'sidecar':
    ensure => running,
    name   => 'collector-sidecar',
  }

}



