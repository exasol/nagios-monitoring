#!/usr/bin/python
import ssl, json, time, pyodbc, re
from os.path    import isfile, getctime, join
from os         import sep, name
from sys        import exit, argv, version_info, stdout, stderr
from urllib     import quote_plus
from getopt     import getopt
from xmlrpclib  import ServerProxy
from time       import time

odbcDriver              = '/opt/exasol/EXASOL_ODBC-6.0.4/lib/linux/x86_64/libexaodbc-uo2214lv2.so'
pluginVersion           = '17.11'
databaseName            = None
databaseUser            = None
databasePassword        = None
hostName                = None
userName                = None
password                = None
logserviceId            = None
opts, args              = None, None
maxInterval             = 300 #seconds (interval between checks)
minInterval             = 90 #seconds
transactionConflictWarnDuration = 2600 #seconds

if name == 'nt':            #OS == Windows
    from tempfile import gettempdir
    cacheDirectory          = gettempdir()
elif name == 'posix':       #OS == Linux, Unix, etc.
    cacheDirectory          = r'/var/cache/nagios3'

try:
    opts, args = getopt(argv[1:], 'hVH:d:u:p:l:a:c:')

except:
    print "Unknown parameter(s): %s" % argv[1:]
    opts = []
    opts.append(['-h', None])

for opt in opts:
    parameter = opt[0]
    value     = opt[1]
    
    if parameter == '-h':
        print """
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
    -c <timeout in sec>     (optional) time until a transaction conflict creates a warning
""" % (pluginVersion)
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

if not (hostName and 
        userName and 
        password and 
        databaseName and 
        databaseUser and 
        databasePassword):
    print('Please define at least the following parameters: -H -u -p -d -l -a -s')
    exit(4)

def XmlRpcCall(urlPath = ''):
    url = 'https://%s:%s@%s/cluster1%s' % (quote_plus(userName), quote_plus(password), hostName, urlPath)
    if hasattr(ssl, 'SSLContext'):
        sslcontext = ssl.SSLContext(ssl.PROTOCOL_TLSv1)
        sslcontext.verify_mode = ssl.CERT_NONE
        sslcontext.check_hostname = False
        return ServerProxy(url, context=sslcontext)
    return ServerProxy(url)

try:
    longDescription = '\n'
    returnCode = 0
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
    odbcConnectionString = 'Driver=%s;AUTOCOMMIT=Y;CONNECTTIMEOUT=2;QUERYTIMEOUT=30;EXASCHEMA=EXA_STATISTICS;EXAHOST=%s;EXAUID=%s;EXAPWD=%s;' % (
            odbcDriver,
            database.getDatabaseConnectionString(),
            databaseUser,
            databasePassword
    )
    if not database.getDatabaseState() == 'running':
        print('CRITICAL - database instance is not running.')
        exit(2)

    sqlConnection = pyodbc.connect(odbcConnectionString, autocommit=True)
    sqlCursor = sqlConnection.cursor()
    sqlCommand = """select  MEDIAN(LOAD) LOAD, 
                            MEDIAN(CPU) CPU, 
                            MEDIAN(TEMP_DB_RAM) TEMP_DB_RAM, 
                            MEDIAN(HDD_READ) HDD_READ, 
                            MEDIAN(HDD_WRITE) HDD_WRITE,
                            MEDIAN(NET) NET, 
                            MEDIAN(SWAP) SWAP
                    from EXA_STATISTICS.EXA_MONITOR_LAST_DAY
                    where MEASURE_TIME between ADD_SECONDS(NOW(), -%s) and NOW();
                    """ % (interval)
    sqlExec = sqlCursor.execute(sqlCommand)
    output = ''
    result = sqlExec.fetchone()
    if not None in result:
        output += 'load=%.1f;cpu=%.1f%%;tmp_dbram=%.1fGiB;hdd_read=%.1fMBps;hdd_write=%.1fMBps;net=%.1fMBps;swap=%.1fMBps;' % (
            float(result.LOAD),
            float(result.CPU),
            float(result.TEMP_DB_RAM) / 1024.0,
            float(result.HDD_READ),
            float(result.HDD_WRITE),
            float(result.NET),
            float(result.SWAP)
        )

    sqlCommand = """select  MEDIAN(USERS) USERS,
                            MEDIAN(QUERIES) QUERIES
                    from EXA_STATISTICS.EXA_USAGE_LAST_DAY
                    where MEASURE_TIME between ADD_SECONDS(NOW(), -%s) and NOW();
                """ % (interval)
    sqlExec = sqlCursor.execute(sqlCommand)
    result = sqlExec.fetchone()
    if not None in result:
        output += 'users=%i;queries=%i;' % (
                int(result.USERS),
                int(result.QUERIES)
        )

    sqlCommand = "select SESSION_ID, ACTIVITY, DURATION from EXA_DBA_SESSIONS where substr(ACTIVITY, 0, 19) = 'Waiting for session';"
    sqlExec = sqlCursor.execute(sqlCommand)
    result = sqlExec.fetchall()
    conflictedSessionPattern = re.compile('session\s+(\d+)\s*$')
    durationPattern = re.compile('\s*(\d+):(\d+):(\d+)\s*$')

    numberOfConflicts = 0
    maxDuration = 0
    
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
        if maxDuration > transactionConflictWarnDuration: returnCode = 1

    else:
        output += 'number_of_tacs=0;duration_tac_max=0s;'

    if longDescription.strip() != '':
        output += longDescription
        if returnCode == 0:
            output = 'OK - performance data transferred | ' + output
        else:
            output = 'WARNING - transaction conflict found | ' + output 
   
    sqlConnection.close()
    print(output)
    exit(returnCode)

except Exception as e:
    print(e)
    exit(2)

