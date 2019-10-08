FROM bizapps_monitor-stage3:latest
MAINTAINER Exasol AG
ARG environment=default


# remove icinga2 defaults
RUN rm -rf /etc/icinga2/conf.d/*.conf

# Add env converter script (breaks docker build, if non existant environment got supplied)
ADD scripts/conv.sh /tmp
RUN /tmp/conv.sh $environment


# Add custom check definitions 
ADD usr/share/icinga2/include /usr/share/icinga2/include
# Add custom check plugins
ADD usr/lib/nagios/plugins /usr/lib/nagios/plugins
# Enable new custom checks
RUN echo "include <plugins-custom>" >> /etc/icinga2/icinga2.conf

# Add customer check definitions 
ADD scripts/customer.sh /tmp
RUN /tmp/customer.sh $environment



ENV TERM=xterm
ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/nagios4/bin:/opt/nagios4/sbin:/opt/pnp4nagios/bin"
RUN localedef -i en_US -f UTF-8 en_US.UTF-8

ADD etc/dockerinit /etc/dockerinit
WORKDIR /root
ENTRYPOINT /etc/dockerinit
