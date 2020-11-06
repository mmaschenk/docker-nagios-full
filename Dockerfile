FROM mmaschenk/centos-supervisor:7

RUN yum -y install yum-plugin-ovl
RUN yum -y groupinstall 'Development Tools' && \
    yum -y install httpd perl perl-devel "perl(CPAN)" "perl(LWP)" php openssl openssl-devel gd gd-devel mailx postfix rsyslog \
                   perl-rrdtool perl-GD "perl(CGI)"
ENV NAGIOS_HOME=/opt/nagios \
    NAGIOS_USER=nagios \
    NAGIOS_GROUP=nagios \
    NAGIOS_CMDUSER=nagios \
    NAGIOS_CMDGROUP=nagios \
    NAGIOSADMIN_USER=nagiosadmin \
    NAGIOSADMIN_PASS=nagios \
    APACHE_RUN_USER=nagios \
    APACHE_RUN_GROUP=nagios \
    NAGIOS_TIMEZONE=Europe/Amsterdam \
    INITSCRIPT=/sbin/checktelegram.sh

#ADD http://downloads.sourceforge.net/project/nagios/nagios-4.x/nagios-4.0.8/nagios-4.0.8.tar.gz?r=&ts=1433237558&use_mirror=heanet /tmp/nagios.tgz
COPY nagios-4.4.6.tar.gz /tmp/nagios.tgz
#ADD http://nagios-plugins.org/download/nagios-plugins-2.0.3.tar.gz /tmp/nagios-plugins.tgz
COPY nagios-plugins-2.0.3.tar.gz /tmp/nagios-plugins.tgz
COPY bogus_warnings.patch /tmp/
COPY check_http_redirect.pl /opt/nagios/libexec/
#ADD http://downloads.sourceforge.net/project/nagiosgraph/nagiosgraph/1.5.2/nagiosgraph-1.5.2.tar.gz?r=http%3A%2F%2Fsourceforge.net%2Fprojects%2Fnagiosgraph%2Ffiles%2Fnagiosgraph%2F&ts=1433322468&use_mirror=heanet /tmp/nagiosgraph.tgz
COPY nagiosgraph-1.5.2.tar.gz /tmp/nagiosgraph.tgz
ADD Arana_nagiosstyle-HD.tar.gz /tmp/


RUN ( egrep -i  "^${NAGIOS_GROUP}" /etc/group || groupadd $NAGIOS_GROUP ) && \
    ( egrep -i "^${NAGIOS_CMDGROUP}" /etc/group || groupadd $NAGIOS_CMDGROUP ) && \
    ( id -u $NAGIOS_USER || useradd --system $NAGIOS_USER -g $NAGIOS_GROUP -d $NAGIOS_HOME ) && \
    ( id -u $NAGIOS_CMDUSER || useradd --system -d $NAGIOS_HOME -g $NAGIOS_CMDGROUP $NAGIOS_CMDUSER ) && \
    # \
    cd /tmp && \
    tar -zxvf nagios.tgz && \
    cd nagios-4.4.6  && \
    ./configure --prefix=${NAGIOS_HOME} \
                --exec-prefix=${NAGIOS_HOME} \
                --enable-event-broker \
                --with-openssl \
                --with-nagios-command-user=${NAGIOS_CMDUSER} \
                --with-command-group=${NAGIOS_CMDGROUP} \
                --with-nagios-user=${NAGIOS_USER} \
                --with-nagios-group=${NAGIOS_GROUP} && \
    make all && \
    make install && \
    make install-config && \
    make install-commandmode && \
    make install-webconf && \
    cp -R contrib/eventhandlers/ ${NAGIOS_HOME}/libexec/ && \
    chown -R ${NAGIOS_USER}:${NAGIOS_GROUP} ${NAGIOS_HOME}/libexec/eventhandlers && \
    rm -rf /tmp/nagios.tgz /tmp/nagios-4.0.8 /tmp/bogus_warnings.patch && \
    # Set timezone \
    echo "use_timezone=$NAGIOS_TIMEZONE" >> ${NAGIOS_HOME}/etc/nagios.cfg && \
    echo "SetEnv TZ \"${NAGIOS_TIMEZONE}\"" >> /etc/httpd/conf.d/nagios.conf && \
    # Build nagios plugins \
    cd /tmp && \
    tar -zxvf nagios-plugins.tgz && \
    cd nagios-plugins-2.0.3 && \
    ./configure --prefix=${NAGIOS_HOME} \
                --with-openssl &&\
    make && \
    make install && \
    rm -rf /tmp/nagios-plugins.tgz /tmp/nagios-plugins-2.0.3 && \
    # Hateful thing: nagios is not allowed to ping otherwise! \
    chmod u+s /bin/ping && \
    # Setup password \
    htpasswd -c -b -s ${NAGIOS_HOME}/etc/htpasswd.users ${NAGIOSADMIN_USER} ${NAGIOSADMIN_PASS} && \
    chown -R nagios.nagios ${NAGIOS_HOME}/etc/htpasswd.users && \
    # Redirect plugin: \
    chmod 755 /opt/nagios/libexec/check_http_redirect.pl && \
    echo -e "define command{\n  command_name check_redirect\n  command_line \$USER1\$/check_http_redirect.pl -U \$ARG1\$ -R \$ARG2\$\n}\n" >> ${NAGIOS_HOME}/etc/objects/commands.cfg && \
    # Setting up nagiosgraph \
    cd /tmp && \
    tar xzf nagiosgraph.tgz && \
    cd /tmp/nagiosgraph-1.5.2 && \
    cp etc/* ${NAGIOS_HOME}/etc && \
    mkdir ${NAGIOS_HOME}/sbin/nagiosgraph && \
    cp cgi/* ${NAGIOS_HOME}/sbin/nagiosgraph && \
    cp lib/insert.pl ${NAGIOS_HOME}/bin && \
    mkdir ${NAGIOS_HOME}/share/nagiosgraph && \
    cp share/* ${NAGIOS_HOME}/share/nagiosgraph && \
    mkdir ${NAGIOS_HOME}/var/rdd && \
    chown ${NAGIOS_USER} ${NAGIOS_HOME}/var/rdd && \
    touch ${NAGIOS_HOME}/var/nagiosgraph.log && \
    chown ${NAGIOS_USER} ${NAGIOS_HOME}/var/nagiosgraph.log && \
    rm -rf /tmp/nagiosgraph.tgz /tmp/nagiosgraph-1.5.2 

RUN sed -i 's#use lib '"'/opt/nagiosgraph/etc';"'#use lib '"'"${NAGIOS_HOME}"/etc';"'#' \
      ${NAGIOS_HOME}/sbin/nagiosgraph/* ${NAGIOS_HOME}/bin/insert.pl && \
    sed -i -e 's#^logfile =.*#logfile = '${NAGIOS_HOME}'/var/nagiosgraph.log#' \
           -e 's#^cgilogfile =.*#cgilogfile = '${NAGIOS_HOME}'/var/nagiosgraph-cgi.log#' \
           -e 's#^perflog =.*#perflog = '${NAGIOS_HOME}'/var/perfdata.log#' \
           -e 's#^rrddir =.*#rrddir = '${NAGIOS_HOME}'/var/rrd#' \
           -e 's#^mapfile =.*#mapfile = '${NAGIOS_HOME}'/etc/map#' \
           -e 's#^nagiosgraphcgiurl =.*#nagiosgraphcgiurl = /nagios/cgi-bin/nagiosgraph#' \
           -e 's#^javascript =.*#javascript = /nagios/nagiosgraph/nagiosgraph.js#' \
           -e 's#^stylesheet =.*#stylesheet = /nagios/nagiosgraph/nagiosgraph.css#' \
           ${NAGIOS_HOME}/etc/nagiosgraph.conf && \
    sed -i -e 's#^process_performance_data=.*#process_performance_data=1#' ${NAGIOS_HOME}/etc/nagios.cfg && \
    echo "service_perfdata_command=process-service-nagiosgraph-perfdata" >> ${NAGIOS_HOME}/etc/nagios.cfg && \
    echo -e "define command{\n  command_name  process-service-nagiosgraph-perfdata\n  command_line ${NAGIOS_HOME}/bin/insert.pl  \"\$LASTSERVICECHECK\$||\$HOSTNAME\$||\$SERVICEDESC\$||\$SERVICEOUTPUT\$||\$SERVICEPERFDATA\$\"\n}" >> ${NAGIOS_HOME}/etc/objects/commands.cfg && \
    echo -e "define service {\n  name timegraphed-service\n  action_url /nagios/cgi-bin/nagiosgraph/show.cgi?host=\$HOSTNAME\$&service=\$SERVICEDESC\$&db=time' onMouseOver='showGraphPopup(this)' onMouseOut='hideGraphPopup()' rel='/nagios/cgi-bin/nagiosgraph/showgraph.cgi?host=\$HOSTNAME\$&service=\$SERVICEDESC\$&period=week&db=time\n  register 0\n}" >> ${NAGIOS_HOME}/etc/objects/templates.cfg && \
    echo -e "define service {\n  name graphed-service\n  action_url /nagios/cgi-bin/nagiosgraph/show.cgi?host=\$HOSTNAME\$&service=\$SERVICEDESC\$' onMouseOver='showGraphPopup(this)' onMouseOut='hideGraphPopup()' rel='/nagios/cgi-bin/nagiosgraph/showgraph.cgi?host=\$HOSTNAME\$&service=\$SERVICEDESC\$&period=week\n  register 0\n}" >> ${NAGIOS_HOME}/etc/objects/templates.cfg && \
    echo '<script type="text/javascript" src="/nagios/nagiosgraph/nagiosgraph.js"></script>' >> ${NAGIOS_HOME}/share/ssi/common-header.ssi && \
    # Create backup of config \
    cd ${NAGIOS_HOME} && \
    mkdir etc-orig && \
    cd etc && \
    tar cf - . | ( cd ../etc-orig ; tar xvf - ) && \
    # Fix postfix config \
    echo "myhostname = online-learning.tudelft.nl" >> /etc/postfix/main.cf && \
    echo "inet_protocols = ipv4" >> /etc/postfix/main.cf && \
    # Python modules \
    pip install urllib3==1.24.1 && \
    pip install simplejson telepot && \
    # Colors and install css: \
    sed -i.bak 's/background-color: #B2B2B2/background-color: #FFFFFF/' /tmp/htdocs/stylesheets/tac.css && \
    cd /tmp/htdocs && cp -r * ${NAGIOS_HOME}/share

RUN PERL_MM_USE_DEFAULT=1 cpan; exit 0
#RUN cpan install JSON::PP
#RUN cpan install LWP::Protocol::https
RUN cpan install OALDERS/LWP-Protocol-https-6.07.tar.gz

ADD nagios.conf apache.conf postfix.conf rsyslog.conf /etc/supervisor/conf.d/
ADD check_json check_ftp.pl check_lm_voltage check_lm_revs check_lm_temperature ${NAGIOS_HOME}/libexec/
ADD index.html ${NAGIOS_HOME}/share/
ADD checktelegram.sh telmessage.py init-config nagioscheck.py /sbin/

RUN yum -y install lm_sensors
ADD sensors3.conf /etc/

