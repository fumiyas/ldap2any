LDAP to ANY gateway
======================================================================

  * Copyright (c) 2009-2013 SATOH Fumiyasu @ OSS Technology Corp., Japan
  * License: GNU General Public License version 3
  * URL: <https://GitHub.com/fumiyas/ldap2any>
  * Twitter: <https://twitter.com/satoh_fumiyasu>

What's this?
---------------------------------------------------------------------

For example, you can use this script as an LDAP to NIS gateway:

    # cd /var/yp
    # /path/to/install/bin/ldap2any.pl \
        ldap://localhost \
        dc=example,dc=jp \
        ;
    ...

NOTE: Experimental and not COMPLETED!

Requirements
----------------------------------------------------------------------

  * Perl 5.8+
  * Perl Net::LDAP module
  * OpenLDAP 2.4 server (slapd) with syncrepl provider config

TODO
----------------------------------------------------------------------

  * Make autotoolize
  * Add support LDAP with TLS / SSL
  * Add support Sun JDS, OpenDS and Fedora DS (persistent search?)
  * Add support shadow(5) file?
  * Lower-case username and groupname?

