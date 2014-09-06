check_all4000
=============

Checks the allnet environmental devices for Icinga.
The plugin recieves the XML data from the allnet devices. It can check thresholds and boolean states of the connected probes.

### Usage
    check_allnet.pl -h

    check_allnet.pl --man

    check_allnet.pl -H <host> -u <probe> -w <warning> -c <critical> [-U
    username] [-P password] [-p web_port] [-L /to_xml_data] [-A my_agent/1.0
    ] [-T timeout] [--bool=value_of_false] [--legend=rz6_temp]


### Options

    -h      Display this helpmessage.

    -H      The hostname or ipaddress of the allnet device.

    -p      The port where the HTTP service runs, default is 80.

    -U      The HTTP user which is authorized to view the data of the probes

    -P      The password for the HTTP user.

    -L      The weblocation where the xml data is located. Default is
            '/xml'. Don't forget the leading slash!

    -T      Timeout for the LWP::Useragent. Default is ten seconds.

    -A      Value for the Useragent, if you want to set a special value for
            it. Default is a mix of $PROGNAME and $VERSION and
            $LWP::VERSION.

    -u      The port where the probe is connected to. On a AllNet 3000 there
            a ports from 0 to 7

    -w      The warning threshold. If you use the -bool option, the
            threshold syntax is only 'on', 'off' and 'none'.

    -c      The critical threshold. If you use the -bool option, the
            threshold syntax is only 'on', 'off' and 'none'.

    --bool  Instruct the plugin to use the boolean mode. Thresholds are set
            only with 'on', 'off' or 'none'. You have to set a value which
            specifies the 'false' or 'off' status. For example you set
            '--bool=0' then the status will be off if the probe value is
            '0'. All other values set the status to on. If a threshold is
            set to 'none', the appropriate NAGIOS state will be considered
            as not exist.

    --legend
            Changes the NAGIOS pluginoutput in the Webinterface. This
            feature is intendet for the Webfrontend to identify the service
            easier.

    --man   Display's the complete perldoc manpage.

    --verbose
            Display's some more output, not intended for use with NAGIOS.

### Threshold formats
    1. start <= end

    The startvalue have to be less than the endvalue

    2. start and ':' is not required if start=0>

    If you set a threshold of '12' it's the same like '0:12'

    3. if range is of format "start:" and end is not specified,
    assume end is infinity

    4. to specify negative infinity, use '~' (tilde)

    For example: ~10:~2 the threshold is from -10 to -2.

    5. alert is raised if metric is outside start and end range
    (inclusive of endpoints)

    6. if range starts with "@", then alert if inside this range
    (inclusive of endpoints)


### Author

NETWAYS GmbH, 2005, http://www.netways.de.

Written by Marius Hein <mhein@netways.de>.

Please report bugs through the contact of Icinga Exchange,
http://exchange.icinga.org.

