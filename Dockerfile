FROM debian:stable
MAINTAINER Exasol AG

# install packages
ADD apt-proxy /etc/apt/apt.conf.d
RUN apt-get -qy update
RUN apt-get install -qy locales lighttpd php-cgi python3-pip python3-pyodbc unixodbc netcat patch wget ssmtp libdigest-hmac-perl unattended-upgrades apache2-utils cron nagios-plugins nagios-snmp-plugins
RUN python3 -m pip install ExasolDatabaseConnector

# debug section
RUN apt-get -qy install vim less python3-dialog

#install custom scripts and build nagios core
ADD usr/local /usr/local
RUN chmod -v 755 /usr/local/bin/*
RUN install-nagios4
RUN install-pnp4nagios

# configure apt and unattended upgrades
ADD etc/apt/apt.conf.d/* /etc/apt/apt.conf.d/

# configure lighttpd
ADD etc/lighttpd/conf-available/10-nagios4.conf /etc/lighttpd/conf-available/
RUN mkdir -p /etc/lighttpd/certificates
RUN chown www-data:www-data /etc/lighttpd/certificates
RUN ln -s /usr/local/bin/nagios-getconfig /opt/nagios4/sbin/getconfig.cgi 
RUN lighttpd-enable-mod cgi 
RUN lighttpd-enable-mod auth 
RUN lighttpd-enable-mod status
RUN lighttpd-enable-mod nagios4
RUN lighttpd-enable-mod fastcgi-php
RUN sed 's/"PHP_FCGI_CHILDREN" => "4"/"PHP_FCGI_CHILDREN" => "1"/g' /etc/lighttpd/conf-enabled/15-fastcgi-php.conf >/tmp/15-fastcgi-php.conf && mv -v /tmp/15-fastcgi-php.conf /etc/lighttpd/conf-enabled/15-fastcgi-php.conf

# configure nagios webinterface
RUN /bin/bash -c 'htpasswd -ic /etc/nagios/htpasswd.users nagiosadmin <<< "admin"'

# configure nagios basic settings
ADD var/www/html/index.php /var/www/html/index.php

# configure nagios setup and deploy plugins
ADD opt/exasol/monitoring/* /opt/exasol/monitoring/
ADD etc/nagios/*.cfg /etc/nagios/
ADD etc/nagios/conf.d/* /etc/nagios/conf.d/
RUN find /etc/nagios/conf.d -type f -print0 |xargs -0 chown nagios:nagios
RUN find /etc/nagios/conf.d -type f -print0 |xargs -0 chmod 775
RUN sed -r 's# notify-service-by-email# exasol-notify-service-by-email#g' /etc/nagios/conf.d/contacts_nagios2.cfg >/tmp/contacts_nagios2.cfg && mv -v /tmp/contacts_nagios2.cfg /etc/nagios/conf.d/contacts_nagios2.cfg

#install check_openmanage links
ADD opt/check_openmanage-3.7.12 /opt/check_openmanage-3.7.12
RUN ln -s /opt/check_openmanage-3.7.12/man/check_openmanage.8       /usr/share/man/man8
RUN ln -s /opt/check_openmanage-3.7.12/man/check_openmanage.conf.5  /usr/share/man/man5
RUN ln -s /opt/check_openmanage-3.7.12/check_openmanage             /usr/lib/nagios/plugins
RUN ln -s /opt/check_openmanage-3.7.12/dell_openmanage.cfg          /etc/nagios/conf.d

#install check_hp:
ADD opt/check_hp-2.20 /opt/check_hp-2.20
RUN ln -s /opt/check_hp-2.20/check_hp                               /usr/lib/nagios/plugins
RUN ln -s /opt/check_hp-2.20/check_hp.cfg                           /etc/nagios/conf.d

#install check_fujitsu_server plugin
ADD opt/fujitsu /opt/fujitsu
RUN ln -s /opt/fujitsu/ServerViewSuite/nagios/plugin/check_fujitsu_server.pl    /usr/lib/nagios/plugins
RUN ln -s /opt/fujitsu/ServerViewSuite/nagios/plugin/fujitsu_server.cfg         /etc/nagios/conf.d

#configure ssmtp package (security)
RUN groupadd -r ssmtp
RUN chown :ssmtp /etc/ssmtp/ssmtp.conf
RUN chmod 640 /etc/ssmtp/ssmtp.conf
RUN chown :ssmtp /usr/sbin/ssmtp
RUN chmod g+s /usr/sbin/ssmtp

# add further patches
ADD opt/exasol/patches/* /opt/exasol/patches/
RUN ln -s "/opt/exasol/patches/exasol_bg.png" "/opt/nagios4/share/images"
RUN cp -f "/opt/exasol/patches/nagios-main.php" "/opt/nagios4/share/main.php"
RUN bash -c 'patch -p1 /opt/nagios4/share/stylesheets/common.css < /opt/exasol/patches/nagios-exasol-background.patch'
RUN bash -c 'patch -p1 /opt/check_hp-2.20/check_hp < /opt/exasol/patches/check_hp_snmpv3_aes.patch'
RUN bash -c 'patch -p1 /opt/fujitsu/ServerViewSuite/nagios/plugin/check_fujitsu_server.pl < /opt/exasol/patches/check_fujitsu_server_snmpv3_verboselevelfix.patch'

#licenses
ADD 3rd_party_licenses/check_openmanage-3.7.12-GPLv3.txt /opt/check_openmanage-3.7.12/LICENSE
ADD 3rd_party_licenses/check_hp-2.20-GPL.txt /opt/check_hp-2.20/LICENSE
ADD 3rd_party_licenses/Fujitsu_ServerViewSuite_EULA.txt /opt/fujitsu/ServerViewSuite/LICENSE
ADD 3rd_party_licenses/NagiosCore-GPLv2.txt /opt/nagios4/LICENSE
ADD 3rd_party_licenses/pnp4nagios-GPLv2.txt /opt/pnp4nagios/LICENSE

# clean up and create entrypoint
RUN apt-get -yq clean
ENV TERM=xterm
ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/nagios4/bin:/opt/nagios4/sbin:/opt/pnp4nagios/bin"
RUN localedef -i en_US -f UTF-8 en_US.UTF-8
RUN /usr/local/bin/download-odbc-driver
RUN rm -rf /usr/src/*
RUN bash -c 'find /etc/nagios/conf.d -print0 |xargs -0 tar cvzf /etc/nagios/conf.d_dist.tar.gz'
RUN bash -c 'find /var/lib/nagios -print0 |xargs -0 tar cvzf /var/lib/nagios_dist.tar.gz'
ADD etc/dockerinit /etc/
WORKDIR /root
ENTRYPOINT /etc/dockerinit
