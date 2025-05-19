# @summary Install a signed certificate on the target host.
#
# @param crt_content
#   The actual certificate content.
#
# @param crt_chain_content
#   The actual certificate chain content.
#
# @param ocsp_content
#   The OCSP data when the OCSP Must-Staple extension is enabled,
#   otherwise empty.
#
# @param domain
#   Unused, kept for compatibility with exported resources
#
# @api private
define acme::deploy::crt (
  String $crt_content,
  String $crt_chain_content,
  Optional[String] $domain = undef,
  Optional[String] $ocsp_content = undef,
) {
  $cfg_dir = $acme::cfg_dir
  $crt_dir = $acme::crt_dir
  $key_dir = $acme::key_dir
  $key_mode = $acme::key_mode

  $user = $acme::user
  $group = $acme::group

  $crt = "${crt_dir}/${name}/cert.pem"
  $ocsp = "${crt_dir}/${name}/cert.ocsp"
  $key = "${key_dir}/${name}/private.key"
  $dh = "${cfg_dir}/${name}/params.dh"
  $crt_chain = "${crt_dir}/${name}/chain.pem"
  $crt_full_chain = "${crt_dir}/${name}/fullchain.pem"
  $crt_full_chain_with_key = "${key_dir}/${name}/fullchain_with_key.pem"

  file { $crt:
    ensure  => file,
    owner   => 'root',
    group   => $group,
    content => $crt_content,
    mode    => '0644',
  }

  if !empty($ocsp_content) {
    file { $ocsp:
      ensure  => file,
      owner   => 'root',
      group   => $group,
      content => base64('decode', $ocsp_content),
      mode    => '0644',
    }
  } else {
    file { $ocsp:
      ensure => absent,
      force  => true,
    }
  }

  concat { $crt_full_chain:
    owner => 'root',
    group => $group,
    mode  => '0644',
  }

  concat { $crt_full_chain_with_key:
    owner => 'root',
    group => $group,
    mode  => $key_mode,
  }

  concat::fragment { "${name}_key":
    target => $crt_full_chain_with_key,
    source => $key,
    order  => '01',
  }

  concat::fragment { "${name}_fullchain":
    target    => $crt_full_chain_with_key,
    source    => $crt_full_chain,
    order     => '10',
    subscribe => Concat[$crt_full_chain],
  }

  concat::fragment { "${name}_crt":
    target  => $crt_full_chain,
    content => $crt_content,
    order   => '10',
  }

  concat::fragment { "${name}_dh":
    target => $crt_full_chain,
    source => $dh,
    order  => '30',
  }

  if ($crt_chain_content and $crt_chain_content =~ /BEGIN CERTIFICATE/) {
    file { $crt_chain:
      ensure  => file,
      owner   => 'root',
      group   => $group,
      content => $crt_chain_content,
      mode    => '0644',
    }
    concat::fragment { "${name}_ca":
      target  => $crt_full_chain,
      content => $crt_chain_content,
      order   => '50',
    }
  } else {
    file { $crt_chain:
      ensure => absent,
      force  => true,
    }
  }
}
