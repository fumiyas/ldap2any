LDAP to ANY gateway
======================================================================

  * Copyright (c) 2009-2013 SATOH Fumiyasu @ OSS Technology Corp., Japan
  * License: GNU General Public License version 3
  * URL: <https://GitHub.com/fumiyas/ldap2any>
  * Twitter: <https://twitter.com/satoh_fumiyasu>

What's this?
---------------------------------------------------------------------

For example, you can use this script as an LDAP to NIS gateway:

    $ cd /var/yp
    # /usr/local/ldap2any/bin/ldap2any
    ...

NOTE: Experimental and not COMPLETED!

Requirements
----------------------------------------------------------------------

  * GNU make (for installation only)
  * Perl 5.8+
  * Perl Net::LDAP module
  * OpenLDAP 2.4 server (slapd) with syncrepl provider config

Build and Installation
----------------------------------------------------------------------

    $ tar xf ldap2any-0.1.0.tar.gz
    $ cd ldap2any-0.1.0
    $ ./configure
    ...
    $ make
    ...
    $ sudo make install
    ...

TODO
----------------------------------------------------------------------

  * Make autotoolize
  * Add support LDAP with TLS / SSL
  * Add support Sun JSDS, OpenDS and 389 DS (persistent search?)
  * Add support shadow(5) file?
  * Lower-case username and groupname?

