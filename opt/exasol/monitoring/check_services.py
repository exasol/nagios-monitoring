#!/usr/bin/python
import ssl, json, time
from os.path    import isfile, getctime
from sys        import exit, argv, version_info, stdout, stderr
from urllib     import quote_plus
from pipes      import quote
from getopt     import getopt
from xmlrpclib  import ServerProxy

pluginVersion = "16.03"

opts, args = None, None
try:
    opts, args = getopt(argv[1:], 'hVH:u:p:')

except:
    print "Unknown parameter(s): %s" % argv[1:]
    opts = []
    opts.append(['-h', None])

hostName = None
userName = None
password = None

for opt in opts:
    parameter = opt[0]
    value     = opt[1]
    
    if parameter == '-h':
        print """
EXAoperation XMLRPC services monitor (version %s)
  Options:
    -h                      shows this help
    -V                      shows the plugin version
    -H <license server>     domain of IP of your license server
    -u <user login>         EXAoperation login user
    -p <password>           EXAoperation login password
""" % (pluginVersion)
        exit(0)
    
    elif parameter == '-V':
        print("EXAoperation XMLRPC services monitor (version %s)" % pluginVersion)
        exit(0)

    elif parameter == '-H':
        hostName = value.strip()

    elif parameter == '-u':
        userName = value.strip()

    elif parameter == '-p':
        password = value.strip()

    elif parameter == '-d':
        database = value.strip()

if not (hostName and userName and password):
    print('Please define at least the following parameters: -H -u -p')
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
serviceState = cluster.getServiceState()
criticalServices = {}
criticalServiceOutput = ''
for service in serviceState:
    serviceName = service[0]
    serviceState = service[1]
    if serviceState != 'OK':
        criticalServices[serviceName] = serviceState
        criticalServiceOutput += ('%s - %s; ' % (serviceName, serviceState))

if len(criticalServices) > 0:
    print('CRITICAL - some service are not OK: %s' % (criticalServiceOutput))
    exit(2)
else:
    print('OK - all node services are OK')
exit(0)

