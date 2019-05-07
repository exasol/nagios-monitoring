FROM debian:stable
MAINTAINER Exasol AG

# install packages
ADD apt-proxy /etc/apt/apt.conf.d
RUN apt-get -qy update
RUN apt-get install -qy locales apache2 php7.0 libapache2-mod-php7.0 python3-pip python3-pyodbc unixodbc netcat patch wget ssmtp libdigest-hmac-perl unattended-upgrades apache2-utils cron nagios-plugins nagios-snmp-plugins icingaweb2 icinga2 icinga2-bin mysql-server 
RUN python3 -m pip install ExasolDatabaseConnector

# debug section
RUN apt-get -qy install vim less python3-dialog

# for convinience -- remove after intergration has been comleted
RUN apt-get -qy install ssh

#install custom scripts and icinga
ADD usr/local /usr/local
RUN chmod -v 755 /usr/local/bin/*

# configure apt and unattended upgrades
ADD etc/apt/apt.conf.d/* /etc/apt/apt.conf.d/

# configure icinga2
RUN /usr/local/bin/configure-icinga2

# copy further configuration files
ADD etc/apache2/conf-available/* /etc/apache2/conf-available/
ADD etc/apache2/conf-enabled/* /etc/apache2/conf-enabled/
ADD etc/icinga2/* /etc/icinga2/
ADD etc/icingaweb2/* /etc/icingaweb2/
ADD etc/icingaweb2/modules/monitoring/* /etc/icingaweb2/modules/monitoring/
RUN chown root:icingaweb2 /etc/icingaweb2 -R
RUN chmod 770 /etc/icingaweb2 -R
RUN chmod g+s /etc/icingaweb2 -R


# enable further features
#RUN icinga2 feature enable api
#RUN icinga2 feature enable graphite
#RUN icinga2 feature enable influxdb
RUN icinga2 feature enable perfdata
RUN icinga2 feature enable statusdata
RUN icinga2 feature enable livestatus
RUN icinga2 feature enable ido-mysql
# enable icingaweb2 modules
RUN icingacli module enable monitoring
RUN icingacli module enable setup
RUN icingacli module enable doc
RUN icingacli module enable translation

# configure icingaadmin password
RUN /bin/bash -c 'htpasswd -ic /etc/icingaweb2/htpasswd.users icingaadmin <<< "admin"'

#install check_openmanage links
ADD opt/check_openmanage-3.7.12 /opt/check_openmanage-3.7.12
RUN ln -s /opt/check_openmanage-3.7.12/man/check_openmanage.8       /usr/share/man/man8
RUN ln -s /opt/check_openmanage-3.7.12/man/check_openmanage.conf.5  /usr/share/man/man5
RUN ln -s /opt/check_openmanage-3.7.12/check_openmanage             /usr/lib/nagios/plugins
RUN ln -s /opt/check_openmanage-3.7.12/dell_openmanage.cfg          /etc/icinga2/conf.d

#install check_hp:
ADD opt/check_hp-2.20 /opt/check_hp-2.20
RUN ln -s /opt/check_hp-2.20/check_hp                               /usr/lib/nagios/plugins
RUN ln -s /opt/check_hp-2.20/check_hp.cfg                           /etc/icinga2/conf.d

#install check_fujitsu_server plugin
ADD opt/fujitsu /opt/fujitsu
RUN ln -s /opt/fujitsu/ServerViewSuite/nagios/plugin/check_fujitsu_server.pl    /usr/lib/nagios/plugins
RUN ln -s /opt/fujitsu/ServerViewSuite/nagios/plugin/fujitsu_server.cfg         /etc/icinga2/conf.d

#configure ssmtp package (security)
RUN groupadd -r ssmtp
RUN chown :ssmtp /etc/ssmtp/ssmtp.conf
RUN chmod 640 /etc/ssmtp/ssmtp.conf
RUN chown :ssmtp /usr/sbin/ssmtp
RUN chmod g+s /usr/sbin/ssmtp

# add further patches
ADD opt/exasol/patches/* /opt/exasol/patches/
#RUN ln -s "/opt/exasol/patches/exasol_bg.png" "/opt/nagios4/share/images"
#RUN cp -f "/opt/exasol/patches/nagios-main.php" "/opt/nagios4/share/main.php"
#RUN bash -c 'patch -p1 /opt/nagios4/share/stylesheets/common.css < /opt/exasol/patches/nagios-exasol-background.patch'
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
RUN chown www-data:www-data /usr/share/icingaweb2/public -R
#RUN bash -c 'find /etc/nagios/conf.d -print0 |xargs -0 tar cvzf /etc/nagios/conf.d_dist.tar.gz'
#RUN bash -c 'find /var/lib/nagios -print0 |xargs -0 tar cvzf /var/lib/nagios_dist.tar.gz'
ADD etc/dockerinit /etc/
WORKDIR /root
ENTRYPOINT /etc/dockerinit
