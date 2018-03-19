FROM debian:jessie
MAINTAINER EXASOL AG

# install packages
ADD apt-proxy /etc/apt/apt.conf.d
RUN bash -c 'echo "deb http://ftp.de.debian.org/debian/ jessie-backports main" >>/etc/apt/sources.list'
RUN apt-get -qy update
RUN apt-get install -qy locales nagios3 lighttpd php5-cgi pnp4nagios python-pyodbc odbcinst1debian2 netcat patch wget ssmtp nagios-snmp-plugins libdigest-hmac-perl unattended-upgrades cron

# debug section
RUN apt-get -qy install vim less python3-dialog

# configure apt and unattended upgrades
ADD etc/apt/apt.conf.d/* /etc/apt/apt.conf.d/

# configure lighttpd
ADD etc/lighttpd/conf-available/10-nagios3.conf /etc/lighttpd/conf-available/
RUN mkdir -p /etc/lighttpd/certificates
RUN chown www-data:www-data /etc/lighttpd/certificates
RUN ln -s /usr/local/bin/nagios-getconfig /usr/lib/cgi-bin/nagios3/getconfig.cgi 
RUN lighttpd-enable-mod cgi 
RUN lighttpd-enable-mod auth 
RUN lighttpd-enable-mod status
RUN lighttpd-enable-mod nagios3
RUN lighttpd-enable-mod fastcgi-php
RUN sed 's/"PHP_FCGI_CHILDREN" => "4"/"PHP_FCGI_CHILDREN" => "1"/g' /etc/lighttpd/conf-enabled/15-fastcgi-php.conf >/tmp/15-fastcgi-php.conf && mv -v /tmp/15-fastcgi-php.conf /etc/lighttpd/conf-enabled/15-fastcgi-php.conf

# configure nagios webinterface
RUN /bin/bash -c 'htpasswd -ic /etc/nagios3/htpasswd.users nagiosadmin <<< "admin"'

# configure nagios basic settings
RUN sed -r 's/^RUN="no"/RUN="yes"/' /etc/default/npcd >/tmp/npcd.cfg && mv -v /tmp/npcd.cfg /etc/default/npcd
RUN sed -r 's/check_external_commands\s*=\s*0/check_external_commands=1/g' /etc/nagios3/nagios.cfg >/tmp/nagios.cfg && mv -v /tmp/nagios.cfg /etc/nagios3/nagios.cfg
RUN sed -r 's/process_performance_data\s*=\s*0/process_performance_data=1/g' /etc/nagios3/nagios.cfg >/tmp/nagios.cfg && mv -v /tmp/nagios.cfg /etc/nagios3/nagios.cfg
RUN sed -r '/^#broker_module=\/somewhere\/module2.o/i broker_module=/usr/lib/pnp4nagios/npcdmod.o config_file=/etc/pnp4nagios/npcd.cfg' /etc/nagios3/nagios.cfg >/tmp/nagios.cfg && mv -v /tmp/nagios.cfg /etc/nagios3/nagios.cfg
ADD var/www/html/index.php /var/www/html/index.php
RUN /etc/init.d/nagios3 stop
RUN dpkg-statoverride --update --add nagios www-data 2710 /var/lib/nagios3/rw
RUN dpkg-statoverride --update --add nagios nagios 751 /var/lib/nagios3

# configure nagios setup and deploy plugins
ADD opt/exasol/monitoring/* /opt/exasol/monitoring/
ADD etc/nagios3/conf.d/* etc/nagios3/conf.d/
RUN sed -r 's# notify-service-by-email# exasol-notify-service-by-email#g' /etc/nagios3/conf.d/contacts_nagios2.cfg >/tmp/contacts_nagios2.cfg && mv -v /tmp/contacts_nagios2.cfg /etc/nagios3/conf.d/contacts_nagios2.cfg
ADD usr/local /usr/local
RUN chmod -v 755 /usr/local/bin/*

#install check_openmanage links
ADD opt/check_openmanage-3.7.12 /opt/check_openmanage-3.7.12
RUN ln -s /opt/check_openmanage-3.7.12/man/check_openmanage.8       /usr/share/man/man8
RUN ln -s /opt/check_openmanage-3.7.12/man/check_openmanage.conf.5  /usr/share/man/man5
RUN ln -s /opt/check_openmanage-3.7.12/check_openmanage             /usr/lib/nagios/plugins
RUN ln -s /opt/check_openmanage-3.7.12/dell_openmanage.cfg          /etc/nagios3/conf.d

#install check_hp:
ADD opt/check_hp-2.20 /opt/check_hp-2.20
RUN ln -s /opt/check_hp-2.20/check_hp                               /usr/lib/nagios/plugins
RUN ln -s /opt/check_hp-2.20/check_hp.cfg                           /etc/nagios3/conf.d

#install check_fujitsu_server plugin
ADD opt/fujitsu /opt/fujitsu
RUN ln -s /opt/fujitsu/ServerViewSuite/nagios/plugin/check_fujitsu_server.pl    /usr/lib/nagios/plugins
RUN ln -s /opt/fujitsu/ServerViewSuite/nagios/plugin/fujitsu_server.cfg         /etc/nagios3/conf.d

#configure ssmtp package (security)
RUN groupadd -r ssmtp
RUN chown :ssmtp /etc/ssmtp/ssmtp.conf
RUN chmod 640 /etc/ssmtp/ssmtp.conf
RUN chown :ssmtp /usr/sbin/ssmtp
RUN chmod g+s /usr/sbin/ssmtp

# add further patches
ADD opt/exasol/patches/* /opt/exasol/patches/
RUN bash -c 'patch -p1 /usr/share/nagios3/htdocs/side.php < /opt/exasol/patches/nagios-downloadbutton.patch'
RUN bash -c 'patch -l -p1 /etc/nagios3/stylesheets/common.css < /opt/exasol/patches/nagios-exasol-background.patch'
RUN ln -s /opt/exasol/patches/exasol_bg.png /usr/share/nagios3/htdocs/images/exasol_bg.png
RUN bash -c 'patch -p1 /opt/check_hp-2.20/check_hp < /opt/exasol/patches/check_hp_snmpv3_aes.patch'
RUN bash -c 'patch -p1 /opt/fujitsu/ServerViewSuite/nagios/plugin/check_fujitsu_server.pl < /opt/exasol/patches/check_fujitsu_server_snmpv3_verboselevelfix.patch'

#licenses
ADD 3rd_party_licenses/check_openmanage-3.7.12-GPLv3.txt /opt/check_openmanage-3.7.12/LICENSE
ADD 3rd_party_licenses/check_hp-2.20-GPL.txt /opt/check_hp-2.20/LICENSE
ADD 3rd_party_licenses/Fujitsu_ServerViewSuite_EULA.txt /opt/fujitsu/ServerViewSuite/LICENSE

# clean up and create entrypoint
RUN apt-get -yq clean
ENV TERM=xterm
ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8
RUN localedef -i en_US -f UTF-8 en_US.UTF-8
RUN /usr/local/bin/download-odbc-driver
ADD etc/dockerinit /etc/
ENTRYPOINT bash -c /etc/dockerinit
