#!/usr/bin/python
import ssl, json, time
from os.path    import isfile, getctime
from os         import sep, remove, name
from sys        import exit, argv, version_info, stdout, stderr, maxint
from urllib     import quote_plus
from getopt     import getopt
from xmlrpclib  import ServerProxy
from datetime   import datetime

pluginVersion               = "17.11"
databaseName                = None
hostName                    = None
userName                    = None
password                    = None
opts, args                  = None, None
backupAge                   = 7 #days

try:
    opts, args = getopt(argv[1:], 'hVw:c:H:d:u:p:b:')

except:
    print "Unknown parameter(s): %s" % argv[1:]
    opts = []
    opts.append(['-h', None])


for opt in opts:
    parameter = opt[0]
    value     = opt[1]
    
    if parameter == '-h':
        print """
EXAoperation XMLRPC database disk usage monitor (version %s)
  Options:
    -h                      shows this help
    -V                      shows the plugin version
    -H <license server>     domain of IP of your license server
    -d <db instance>        the name of your DB instance
    -u <user login>         EXAoperation login user
    -p <password>           EXAoperation login password
    -b <backup age in days> (optional) maximum age of the last valid backup
""" % (pluginVersion)
        exit(0)
    
    elif parameter == '-V':
        print("EXAoperation XMLRPC database disk usage monitor (version %s)" % pluginVersion)
        exit(0)

    elif parameter == '-H':
        hostName = value.strip()

    elif parameter == '-u':
        userName = value.strip()

    elif parameter == '-p':
        password = value.strip()

    elif parameter == '-d':
        databaseName = value.strip()

    elif parameter == '-b':
        backupAge = int(value.strip())

if not (databaseName and hostName and userName and password):
    print('Please define at least the following parameters: -d -H -u -p')
    exit(4)

def XmlRpcCall(urlPath = ''):
    url = 'https://%s:%s@%s/cluster1%s' % (quote_plus(userName), quote_plus(password), hostName, urlPath)
    if hasattr(ssl, 'SSLContext'):
        sslcontext = ssl.SSLContext(ssl.PROTOCOL_TLSv1)
        sslcontext.verify_mode = ssl.CERT_NONE
        sslcontext.check_hostname = False
        return ServerProxy(url, context=sslcontext)
    return ServerProxy(url)

def stringToTimestamp(data):
    if data.strip() != '':
        backupDate = datetime.strptime(data, '%Y-%m-%d %H:%M')
        return int(time.mktime(backupDate.timetuple()))
    else: #empty string = no expiration
        return maxint

try:
    cluster = XmlRpcCall('/')
    storage = XmlRpcCall('/storage')
    database = XmlRpcCall('/db_' + quote_plus(databaseName))

    backupList = database.getBackupList()
    backups = []
    latestBackupInfo = None

    #fill up backups list with latest backup data (if available)
    for backup in reversed(backupList):
        backupInfo = database.getBackupInfo(backup[0]) #backup ids are not unique on systems with multiple archive volumes
        if backupInfo['usable'] == True:
            latestBackupInfo = backupInfo
            volume = backupInfo['volume'][0]
            for backupId in latestBackupInfo['dependencies']:
                backups.append(database.getBackupInfo((backupId, volume))) #together with volume id it's unique again
            backups.append(backupInfo)
            break

    if len(backups) == 0:
        print('CRITICAL - No usable backup available')
        exit(2)

    #check for backup age of latest backup
    now = int(time.time())
    expirationDate = now - (backupAge * 3600 * 24)
    if stringToTimestamp(latestBackupInfo['timestamp']) < expirationDate:
        print('WARNING - Latest backup (ID %i on %s) is older than %d days' % (latestBackupInfo['id'], latestBackupInfo['volume'][0], backupAge))
        exit(1)

    #depency expiration date check
    oldExpiration = maxint
    oldBackup = 0
    for backup in backups:
        newBackup = backup
        newExpiration = stringToTimestamp(backup['expire date'])
        if oldExpiration < newExpiration:
            print('WARNING - Base backup (ID %i on %s) expires before its dependency (ID %i)' % (oldBackup['id'], oldBackup['volume'][0], newBackup['id']))
            exit(1)
        oldBackup = newBackup
        oldExpiration = newExpiration 

    #all checks passed
    print ('OK - There is a valid backup')
    exit(0)

except Exception as e:
    if 'unauthorized' in str(e).lower():
        print 'no access to EXAoperation: username or password wrong'

    elif 'Unexpected Zope exception: NotFound: Object' in str(e):
        print 'database instance not found'

    else:
        from pprint import pprint
        print('WARNING - internal error| ')
        pprint(e)
