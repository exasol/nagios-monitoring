#!/usr/bin/python
import xmlrpclib, ssl, json
from os         import sep
from sys        import exit, argv, version_info, stdout, stderr
from urllib     import quote_plus
from getopt     import getopt
from xmlrpclib  import ServerProxy

pluginVersion           = "16.03"
hostName                = None
userName                = None
password                = None
logserviceId            = None
opts, args              = None, None

try:
    opts, args = getopt(argv[1:], 'hVH:i:u:p:')

except:
    print "Unknown parameter(s): %s" % argv[1:]
    opts = []
    opts.append(['-h', None])

for opt in opts:
    parameter = opt[0]
    value     = opt[1]
    
    if parameter == '-h':
        print """
EXAoperation XMLRPC log service monitor (version %s)
  Options:
    -h                      shows this help
    -V                      shows the plugin version
    -H <license server>     domain of IP of your license server
    -i <logservice id>      interger id of the used logservice
    -u <user login>         EXAoperation login user
    -p <password>           EXAoperation login password
""" % (pluginVersion)
        exit(0)
    
    elif parameter == '-V':
        print("EXAoperation XMLRPC log service monitor (version %s)" % pluginVersion)
        exit(0)

    elif parameter == '-H':
        hostName = value.strip()

    elif parameter == '-u':
        userName = value.strip()

    elif parameter == '-p':
        password = value.strip()

    elif parameter == '-i':
        logserviceId = int(value)

if not (hostName and userName and password and logserviceId != None):
    print('Please define at least the following parameters: -H -u -p -i')
    exit(4)

def XmlRpcCall(urlPath = ''):
    url = 'https://%s:%s@%s/cluster1%s' % (quote_plus(userName), quote_plus(password), hostName, urlPath)
    if hasattr(ssl, 'SSLContext'):
        sslcontext = ssl.SSLContext(ssl.PROTOCOL_TLSv1)
        sslcontext.verify_mode = ssl.CERT_NONE
        sslcontext.check_hostname = False
        return ServerProxy(url, context=sslcontext)
    return ServerProxy(url)

cluster = XmlRpcCall('/')
logservice = XmlRpcCall('/logservice%i' % logserviceId)
logserviceUserId = 'check_logservice_%s_%s_%i' % (hostName, userName, logserviceId)
logEntries = logservice.logEntriesTagged(logserviceUserId)
logMessages = ''
logPriority = 0
for logEntry in logEntries[2]:
    logEntryPriority = logEntry['priority']
    if logEntryPriority in ['Warning','Error']:
        logMessages += '\n%s' % logEntry['message'].replace('|', '!')
        if logEntryPriority == 'Warning': logPriority |= 1
        elif logEntryPriority == 'Error': logPriority |= 2

if logPriority > 0:
    if logPriority & 2:
        print('CRITICAL - log messages found - please check logservice on cluster | %s' % (logMessages))
        exit(2)
    elif logPriority & 1:
        print('WARNING - log messages found - please check logservice on cluster | %s' % (logMessages))
        exit(1)
        
else:
    print('OK - No new messages found')
exit(0)

