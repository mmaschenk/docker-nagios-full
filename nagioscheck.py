#!/usr/bin/env python

import sys
import telmessage
import os


def main():
    botid, destid = telmessage.getids()
    numdays = sys.argv.pop(0)
    files = os.popen("ls -rt /opt/nagios/var/archives/* | tail -n %s" % (numdays,)).read()
    files = files.split()
    files.append('/opt/nagios/var/nagios.log')
    grepcommand = "cat %s | grep -c ALERT" % (" ".join(files),)
    output = int(os.popen(grepcommand).read())

    if 'NAGIOS_IDLINE' in os.environ:
      myid = os.environ['NAGIOS_IDLINE']
    else:
      myid = 'Nagios'
    message = '''%s is guarding you. Sleep well...
There were %s alerts detected in the last %s days''' % (myid, output, numdays)
    telmessage.sendmessage(botid, destid, message)
    print 'OK - Statusmessage was sent'


if __name__ == "__main__":
    main()

