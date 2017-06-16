#!/usr/bin/python
import ssl, json, time
from os.path    import isfile, getctime
from os         import sep, remove, name
from sys        import exit, argv, version_info, stdout, stderr
from urllib     import quote_plus
from getopt     import getopt
from xmlrpclib  import ServerProxy
from datetime   import datetime


pluginVersion               = "02.06"
databaseName                = None
hostName                    = None
userName                    = None
password                    = None
opts, args                  = None, None
backupAge                   = 7 #days

try:
    opts, args = getopt(argv[1:], 'hVw:c:H:d:u:p:')

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

cluster = XmlRpcCall('/')
storage = XmlRpcCall('/storage')
database = XmlRpcCall('/db_' + quote_plus(databaseName))

def getDate(stDate):
    return datetime.strptime(stDate.split(' ')[0],'%Y-%m-%d').date()


def getBackupByIdV6(backups,bid): 
    for i in backups: 
        if i['bid']==int(bid):
            return i
    return None

def dependencyCheckV6(backups):
    last_backup=backups[-1]
    if last_backup['dependencies']!='-':
        listOfDependencies=last_backup['dependencies'].split(',')
        for bid in listOfDependencies:
            baseBackup = getBackupByIdV6(backups, bid) 
            if baseBackup==None or baseBackup['expired']:
                return last_backup['id'], None
            elif getDate(last_backup['expire'])>getDate(baseBackup['expire']):
                return last_backup['id'], baseBackup['id']
    return None
                

#If there is no backup or all backups are expired
def checkExpiredV6(backups): 
    for i in backups: 
        if not i['expired']:
            return False
    return True

def latestBackupStatusV6():
    backups = database.getBackups()

    if checkExpiredV6(backups):  
        print ('CRITICAL - Backup does not exist or expired')
        exit(2)
    elif len(backups)==1 and getDate(backups[0]['expire'])==datetime.today().date():
        print ('WARNING - Backup %s expires today and there is no other backup' % (backups[0]['id']))
        exit(1)
    elif (datetime.today().date()-getDate(backups[-1]['expire'])).days>=backupAge:
        print ('WARNING - Latest backup %s is older than %d days' % (backups[-1]['id'], backupAge))
        exit(1)
    elif dependencyCheckV6(backups) is not None:
        depBackup, baseBackup = dependencyCheckV6(backups)
        if baseBackup == None: 
            print ('CRITICAL - Base backup for %s does not exist or expired' % depBackup)
            exit(2)
        else:
            print ('WARNING - Base backup %s expires before its dependency %s' % (baseBackup,depBackup))
            exit(1)
    else: 
        print ('OK - There is a valid backup')
        exit(0)

def getBackupByIdV5(backups, bid): 
    for i in backups: 
        if i[1]==int(bid): 
            return database.getBackupInfo(bid)
    return None

def dependencyCheckV5(backups):
    last_backup = backups[-1]
    backup = database.getBackupInfo(last_backup[1])
    if len(backup['dependencies'])!=0:
        listOfDependencies=backup['dependencies']
        for bid in listOfDependencies:
            baseBackup = getBackupByIdV5(backups,bid)
            if baseBackup == None:
                return backup['files'][0], None
            elif getDate(backup['expire date'])>getDate(baseBackup['expire date']):
                return backup['files'][0], baseBackup['files'][0]

    return None

def checkExpiredV5(backups):
    for i in backups: 
        backupInfo = database.getBackupInfo(i[1])
        if getDate(backupInfo['expire date'])>=datetime.today().date(): 
                  return False 
    return True

def latestBackupStatusV5():
    backups = database.getBackupList()
    latestBackupInfo =  database.getBackupInfo(backups[-1][1])

    if checkExpiredV5(backups): 
        print ('CRITICAL - Backup does not exist or expired')
        exit(2)
    elif len(backups)==1 and getDate(latestBackupInfo['expire date'])==datetime.today().date():
        print ('WARNING - Backup %s expires today and there is no other backup' % (backups))
        exit(1)
    elif (datetime.today().date()-getDate(backups[-1][0])).days>=backupAge:
        backup = latestBackupInfo['files'][0]
        print ('WARNING - Latest backup %s is older than %d days' % (backup, backupAge))
        exit(1)
    elif dependencyCheckV5(backups) is not None:
        depBackup, baseBackup = dependencyCheckV5(backups)
        if baseBackup == None:
            print ('CRITICAL - Base backup for %s does not exist' % depBackup)
            exit(2)
        else:
            print ('WARNING - Base backup %s expires before its dependency %s' % (baseBackup,depBackup))
            exit(1)
    else:
        print ('OK - There is a valid backup')
        exit(0)

def main():
    try:
        exaMajorVersion = int(cluster.getEXASuiteVersion().split('.')[0])
        if exaMajorVersion >= 6:
            latestBackupStatusV6()
        else: 
            latestBackupStatusV5()

    except Exception as e:
        if 'unauthorized' in str(e).lower():
            print 'no access to EXAoperation: username or password wrong'

        elif 'Unexpected Zope exception: NotFound: Object' in str(e):
            print 'database instance not found'

        else:
            from pprint import pprint
            print('WARNING - internal error| ')
            pprint(e)

        exit(1)

if __name__=="__main__":
    main()
