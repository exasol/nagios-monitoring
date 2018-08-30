#!/usr/bin/python
import ssl, json, time
from os.path    import isfile, getctime
from os         import sep, remove, name
from sys        import exit, argv, version_info, stdout, stderr
from urllib     import quote_plus
from getopt     import getopt
from xmlrpclib  import ServerProxy

pluginVersion               = "18.08"
tempUsageWarningTreshold    = 60.0 #percent
tempUsageCriticalTreshold   = 80.0 #percent
cacheDuration               = 3600 #seconds
warningTreshold             = 80 #seconds
criticalTreshold            = 90 #seconds
databaseName                = None
hostName                    = None
userName                    = None
password                    = None
opts, args                  = None, None
cacheDirectory              = None

if name == 'nt':            #OS == Windows
    from tempfile import gettempdir
    cacheDirectory          = gettempdir()
elif name == 'posix':       #OS == Linux, Unix, etc.
    cacheDirectory          = r'/var/cache/nagios3'


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
    -w <0..100>             warning treshold for disk image usage of you db instance (optional)
    -c <0..100>             critical treshold for disk usage of your db instance (optional)
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

    elif parameter == '-w':
        validator = False
        if value.isdigit():
            a = int(value)
            if a >= 0 and a <= 100:
                warningTreshold = int(value)
                validator = True
        if not validator:
            print('warning treshold must be an integer number between 0 and 100')
            exit(4)

    elif parameter == '-c':
        validator = False
        if value.isdigit():
            a = int(value)
            if a >= 0 and a <= 100:
                criticalTreshold = int(value)
                validator = True
        if not validator:
            print('critical treshold must be an integer number between 0 and 100')
            exit(4)

if not (databaseName and hostName and userName and password):
    print('Please define at least the following parameters: -d -H -u -p')
    exit(4)

def XmlRpcCall(urlPath = ''):
    url = 'https://%s:%s@%s/cluster1%s' % (quote_plus(userName), quote_plus(password), hostName, urlPath)
    if hasattr(ssl, 'SSLContext'):
        sslcontext = ssl.SSLContext(ssl.PROTOCOL_TLSv1_2)
        sslcontext.verify_mode = ssl.CERT_NONE
        sslcontext.check_hostname = False
        return ServerProxy(url, context=sslcontext)
    return ServerProxy(url)

cacheFile = '%s%scheck_db_size_%s_%s.cache' % (cacheDirectory, sep, databaseName, hostName)
cluster = XmlRpcCall('/')
storage = XmlRpcCall('/storage')
database = XmlRpcCall('/db_' + quote_plus(databaseName))

try:
    #get informations about the database
    databaseInfo = database.getDatabaseInfo()
    databaseNodes       = databaseInfo['nodes']['active']
    databaseUsage       = databaseInfo['usage persistent']
    databaseTempUsage   = databaseInfo['usage temporary']
    databaseVolume      = databaseInfo['persistent volume']
    databaseTempVolume  = databaseInfo['temporary volume']

    if databaseInfo['state'] != 'running':
        print('CRITICAL - database instance is not running.')
        exit(2)

    #get volume and segment infos on the database instance
    databaseSegments = []
    databaseVolumeInfo = storage.getVolumeInfo(databaseVolume)
    storagePartition = databaseVolumeInfo['disk']

    for redundancyLayer in range(0, databaseVolumeInfo['redundancy']):
        databaseSegments += databaseVolumeInfo['segments'][redundancyLayer]

    databaseTempVolumeInfo = storage.getVolumeInfo(databaseTempVolume) #redundancy of temporary volumes is always 1
    databaseTempSegments = databaseTempVolumeInfo['segments'][0]

    #calculate database segment sizes
    databaseSegmentUsage =      (databaseUsage      / float(len(databaseSegments)))     * databaseVolumeInfo['redundancy']
    databaseTempSegmentUsage =  (databaseTempUsage  / float(len(databaseTempSegments)))

    #get partitioning informations from all nodes and store the available sizes in a key table
    #and use a simple caching system for this expensive function (more nodes => more calls!)
    storagePartitionSizes = {}
    if isfile(cacheFile) and time.time() - getctime(cacheFile) < cacheDuration:
        with open(cacheFile, 'r') as f:
            storagePartitionSizes = json.load(f)
    else:
        for node in sorted(set(databaseSegments)):
            nodeXmlRpc = XmlRpcCall('/' + node)
            partitions = nodeXmlRpc.getDiskStates()
            for partition in partitions:
                if partition['name'] == storagePartition:
                    size = float(partition['size'])
                    storagePartitionSizes[node] = size
        with open(cacheFile, 'w') as f:
            json.dump(storagePartitionSizes, f,  separators=(',',':'))

    #get informations about all volumes and subtract sizes from all nodes used by the database
    for volume in storage.getVolumeList():
        if volume.startswith('v') and volume not in [databaseVolume, databaseTempVolume]:
            volumeInfo = storage.getVolumeInfo(volume)
            volumeSizePerNode = (volumeInfo['size'] / float(len(volumeInfo['segments'][0])))
            
            allSegments = []
            for redundancyLayer in range(0, volumeInfo['redundancy']):
                allSegments += volumeInfo['segments'][redundancyLayer]

            for node in allSegments:
                if node in storagePartitionSizes.keys():
                    storagePartitionSizes[node] -= volumeSizePerNode

        #subtract actual database segement size from partitions
        elif volume == databaseVolume:
            for node in databaseSegments:
                storagePartitionSizes[node] -= databaseSegmentUsage

        elif volume == databaseTempVolume:
            for node in databaseTempSegments:
                storagePartitionSizes[node] -= databaseTempSegmentUsage


    minPartitionSize = None
    minPartitionNode = ''
    for node in storagePartitionSizes:
        if not minPartitionSize or storagePartitionSizes[node] < minPartitionSize:
            minPartitionSize = storagePartitionSizes[node]
            minPartitionNode = node


    usedSegmentSpace =  ((databaseSegmentUsage * databaseSegments.count(minPartitionNode)) + #valid redundancy even for streched storage
                        databaseTempSegmentUsage)                                            #temp is always red=1

    spaceUsage = 100.0 * usedSegmentSpace / (usedSegmentSpace + minPartitionSize) 

    output = 'Disk space usage of %s = %3.1f%%, Usage in GiB = %.1fGiB, Free space = %.1fGiB' % (
            databaseName, 
            spaceUsage, 
            usedSegmentSpace * len(databaseNodes), 
            minPartitionSize * len(databaseNodes)
    )

    performaceData = "usage_percent=%.1f%%;%.1f;%.1f usage=%.1fGiB free=%.1fGiB temp=%.1fGiB temp_usage_ratio=%.1f%%;%.1f;%.1f" % (
            spaceUsage,
            warningTreshold,
            criticalTreshold,
            usedSegmentSpace * len(databaseNodes),
            minPartitionSize * len(databaseNodes),
            databaseTempUsage,
            (float(databaseTempUsage + 0.1) / float(databaseUsage + 0.1)) * 100,
            tempUsageWarningTreshold,
            tempUsageCriticalTreshold
    )

    if (spaceUsage >= warningTreshold):
        print('WARNING - %s|%s' % (output, performaceData))
        exit(1)
    elif (spaceUsage >= criticalTreshold):
        print('CRITICAL - %s|%s' % (output, performaceData))
        exit(2)
    else:
        print('OK - %s|%s' % (output, performaceData))
    exit(0)

except Exception as e:
    message = str(e).replace('%s:%s@%s' % (userName, password, hostName), hostName)
    if 'unauthorized' in message.lower():
        print 'no access to EXAoperation: username or password wrong'

    elif 'Unexpected Zope exception: NotFound: Object' in message:
        print 'database instance not found'

    else:
        print('UNKNOWN - internal error %s | ' % message.replace('|', '!').replace('\n', ';'))
    exit(3)
