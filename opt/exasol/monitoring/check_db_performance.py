#!/usr/bin/python3
import ssl, json, time, re, importlib.util, signal
#from signal             import signal, alarm, SIGALRM
from os.path            import isfile, getctime, isdir, join
from os                 import sep, getcwd
from sys                import exit, path, argv, version_info, stdout, stderr
from urllib.parse       import quote_plus
from getopt             import getopt
from xmlrpc.client      import ServerProxy
from time               import time

if not importlib.util.find_spec('ExasolDatabaseConnector'):
    print('Python module "ExasolDatabaseConnector" not installed. Please install this module using pip:')
    print('\tpython3 -m pip install ExasolDatabaseConnector')
    exit(4)

from ExasolDatabaseConnector import Database

pluginVersion           = '18.11'
databaseName            = None
databaseUser            = None
databasePassword        = None
hostName                = None
userName                = None
password                = None
logserviceId            = None
opts, args              = None, None
pluginTimeout           = 60 #seconds
maxInterval             = 300 #seconds (interval between checks)
minInterval             = 90 #seconds
transactionConflictWarnDuration = 3600 #seconds
trackSchemata           = False
schemaWarnThreshold     = 0

cacheDirectory          = r'/var/cache/nagios3'
if not isdir(cacheDirectory):
    from tempfile import gettempdir
    cacheDirectory = gettempdir()

try:
    opts, args = getopt(argv[1:], 'hVH:d:u:p:l:a:c:o:s:t:')

except:
    print("Unknown parameter(s): %s" % argv[1:])
    opts = []
    opts.append(['-h', None])

for opt in opts:
    parameter = opt[0]
    value     = opt[1]
    
    if parameter == '-h':
        print("""
EXAoperation XMLRPC backup run check (version %s)
  Options:
    -h                      shows this help
    -V                      shows the plugin version
    -H <license server>     domain of IP of your license server
    -d <db instance>        the name of your DB instance
    -u <user login>         EXAoperation login user
    -p <password>           EXAoperation login password
    -l <dbuser login>       DB instance login user
    -a <dbuser passwd>      DB instance login password
    -s <threshold>          (optional) monitor schemata, treshold = max. usage in percent
    -c <timeout in sec>     (optional) time until a transaction conflict creates a warning
    -t <timeout in sec>     (optional) plugin timeout (only capable on posix compliant machines)
""" % (pluginVersion))
        exit(0)
    
    elif parameter == '-V':
        print("EXAoperation XMLRPC backup run check (version %s)" % pluginVersion)
        exit(0)

    elif parameter == '-H':
        hostName = value.strip()

    elif parameter == '-u':
        userName = value.strip()

    elif parameter == '-p':
        password = value.strip()

    elif parameter == '-d':
        databaseName = value.strip()

    elif parameter == '-l':
        databaseUser = value.strip()

    elif parameter == '-a':
        databasePassword = value.strip()

    elif parameter == '-c':
        transactionConflictWarnDuration = int(value.strip())

    elif parameter == '-s':
        schemaWarnThreshold = int(value.strip())
        trackSchemata = True

    elif parameter == '-t':
        pluginTimeout = int(value.strip())


if not (hostName and 
        userName and 
        password and 
        databaseName and 
        databaseUser and 
        databasePassword):
    print('Please define at least the following parameters: -H -u -p -d -l -a')
    exit(4)

def pluginTimedOut(sig, frame):
    print('CRITICAL - Database did not respond within %i seconds' % (pluginTimeout))
    exit(2)

#set a timeout if "alarm" is available on signal module
if importlib.util.find_spec('signal') and hasattr(signal, "alarm"):
	signal.signal(signal.SIGALRM, pluginTimedOut)
	signal.alarm(pluginTimeout)

def XmlRpcCall(urlPath = ''):
    url = 'https://%s:%s@%s/cluster1%s' % (quote_plus(userName), quote_plus(password), hostName, urlPath)
    sslcontext = ssl.SSLContext(ssl.PROTOCOL_TLSv1_2)
    sslcontext.verify_mode = ssl.CERT_NONE
    sslcontext.check_hostname = False
    return ServerProxy(url, context=sslcontext)

try:
    returnCode = 0
    longDescription = '\n'
    interval = maxInterval
    intervalFileName = join(cacheDirectory, 'check_db_perf_%s_%s.interval' % (hostName, databaseName))
    if isfile(intervalFileName):
        with open(intervalFileName, 'r+') as f:
            intervalNew = int(time() - float(f.read()))
            interval = intervalNew if intervalNew <= interval else interval #limit max interval duration to inital value
            interval = interval if interval >= minInterval else minInterval #prevent empty results if there is no entry
            f.seek(0, 0)
            f.truncate()
            f.write(str(time()))
    else:
        with open(intervalFileName, 'w') as f:
            f.write(str(time()))

    cluster = XmlRpcCall('/')
    database = XmlRpcCall('/db_' + quote_plus(databaseName))

    if not database.getDatabaseState() == 'running':
        print('CRITICAL - database instance is not running.')
        exit(2)

    db = Database(database.getDatabaseConnectionString(), databaseUser, databasePassword, autocommit = True)
    sqlCommand = """select  MEDIAN(LOAD) LOAD, 
                            MEDIAN(CPU) CPU, 
                            MEDIAN(TEMP_DB_RAM) TEMP_DB_RAM, 
                            MEDIAN(HDD_READ) HDD_READ, 
                            MEDIAN(HDD_WRITE) HDD_WRITE,
                            MEDIAN(NET) NET, 
                            MEDIAN(SWAP) SWAP
                    from EXA_STATISTICS.EXA_MONITOR_LAST_DAY
                    where MEASURE_TIME between ADD_SECONDS(NOW(), -%i) and NOW();
                    """ % (interval)
    result = db.execute(sqlCommand)[0] #fetch a single line
    output = ''
    if not None in result:
        output += 'load=%.1f;cpu=%.1f%%;tmp_dbram=%.1fGiB;hdd_read=%.1fMBps;hdd_write=%.1fMBps;net=%.1fMBps;swap=%.1fMBps;' % (
	    float(result[0]),                   #LOAD
	    float(result[1]),                   #CPU
	    float(result[2]) / 1024.0,          #TEMP_DB_RAM
	    float(result[3]),                   #HDD_READ
	    float(result[4]),                   #HDD_WRITE
	    float(result[5]),                   #NET
	    float(result[6])                    #SWAP
	)

    sqlCommand = """select  MEDIAN(USERS) USERS,
                            MEDIAN(QUERIES) QUERIES
                    from EXA_STATISTICS.EXA_USAGE_LAST_DAY
                    where MEASURE_TIME between ADD_SECONDS(NOW(), -%s) and NOW();
                """ % (interval)
    result = db.execute(sqlCommand)[0]
    if not None in result:
        output += 'users=%i;queries=%i;' % (
                int(result[0]),			#USERS
                int(result[1])			#QUERIES
        )

    sqlCommand = "select SESSION_ID, ACTIVITY, DURATION from EXA_DBA_SESSIONS where substr(ACTIVITY, 0, 19) = 'Waiting for session';"
    result = db.execute(sqlCommand)
    conflictedSessionPattern = re.compile('session\s+(\d+)\s*$')
    durationPattern = re.compile('\s*(\d+):(\d+):(\d+)\s*$')
    numberOfConflicts = 0
    maxDuration = 0
    transactionConflictWarning = False
    if not None in result:
        numberOfConflicts = len(result)
        for row in result:
            sessionId = str(row[0])
            conflictedSessionId = None
            conflictedSessionIdMatch = conflictedSessionPattern.search(row[1])
            if conflictedSessionIdMatch:
                conflictedSessionId = conflictedSessionIdMatch.group(1)
            duration = None
            durationMatch = durationPattern.search(row[2])
            if durationMatch:
                duration = int(durationMatch.group(3)) + (int(durationMatch.group(2)) * 60) + (int(durationMatch.group(1)) * 3600)
            if maxDuration < duration: maxDuration = duration
            longDescription += 'transaction conflict between %s and %s - duration: %s seconds\n' % (sessionId, conflictedSessionId, duration)

        output += 'number_of_tacs=%i;duration_tac_max=%is;' % (
                numberOfConflicts,
                maxDuration
        )
        transactionConflictWarning = maxDuration > transactionConflictWarnDuration
    else:
        output += 'number_of_tacs=0;duration_tac_max=0s;'

    #if tracking of schema size is activated, this will only work in Exasol 6.0 and newer
    schemaUsageWarning = None
    if trackSchemata:
        sqlCommand = """select 	(min(HDD_FREE) + sum(VOLUME_SIZE * REDUNDANCY * (100 - "USAGE") / 100.0)) / max(REDUNDANCY) as AVAIL_SPACE,
		                sum(VOLUME_SIZE * REDUNDANCY * "USAGE"/100.0) / max(REDUNDANCY) as USED_SPACE
                        from (
                                select 
                                        sum(HDD_FREE)       as HDD_FREE, 
                                        sum(VOLUME_SIZE)    as VOLUME_SIZE, 
                                        max(USE)            as "USAGE",
                                        REDUNDANCY,
                                        TABLESPACE, 
                                        VOLUME_ID
                                from SYS.EXA_VOLUME_USAGE
                                group by VOLUME_ID, TABLESPACE, REDUNDANCY
                        ); """ #it's a quite complex logic, see SOL-366 for details
        result = db.execute(sqlCommand)[0]
        availSpace = None
        usedSpace = None
        usagePercent = 0
        schemaName = ''

        if not None in result:
            availSpace = float(result[0] ) # AVAIL_SPACE / get the available space (it's calculated in the same redundancy as the DB instance
            usedSpace = float(result[1]) # USED_SPACE
        sqlCommand = """select OBJECT_NAME, (MEM_OBJECT_SIZE/1024.0/1024.0/1024.0) AS USAGE_GIB 
			from SYS.EXA_DBA_OBJECT_SIZES
                        where OBJECT_TYPE = 'SCHEMA'
                        order by MEM_OBJECT_SIZE desc
                        limit 1;"""
        result = db.execute(sqlCommand)[0]
        if not None in result:
            usageGiB = float(result[1]) #USAGE_GIB
            usagePercent = 100.0 * usageGiB / (availSpace + usedSpace)
            output += 'biggest_schema=%.1fGiB;' % (usageGiB)
            schemaName = result[0] #OBJECT_NAME
            schemaUsageWarning = (schemaWarnThreshold <= usagePercent)

    #closing performance data section and starting with status section
    output = ' | ' + output
    if longDescription.strip() != '':
        output += longDescription

    if transactionConflictWarning:
        output = 'WARNING - transaction conflict found' + output
        returnCode = 1

    if schemaUsageWarning:
        output = 'WARNING - schema "%s" is using %.1f%% (%.1f GiB) of overall space' % (schemaName, usagePercent, usageGiB) + output
        returnCode = 1
            
    if returnCode == 0:
        output = 'OK - performance data transferred' + output

    db.close()
    print(output)
    exit(returnCode)

except Exception as e:
    message = str(e).replace('%s:%s@%s' % (userName, password, hostName), hostName)
    if 'unauthorized' in message.lower():
        print('no access to EXAoperation: username or password wrong')

    elif 'Unexpected Zope exception: NotFound: Object' in message:
        print('database instance not found')

    else:
        print('UNKNOWN - internal error %s | ' % message.replace('|', '!').replace('\n', ';'))
    exit(3)
