#!/usr/bin/perl -w

# ------------------------------------------------------------------------------
# check_allnet.pl - checks the allnet environmental devices.
# Copyright (C) 2005  NETWAYS GmbH, www.netways.de
# Author: Marius Hein <mhein@netways.de>
# Version: $Id: check_allnet.pl 835 2005-04-20 08:53:05Z mhein $
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
# $Id: check_allnet.pl 835 2005-04-20 08:53:05Z mhein $
# ------------------------------------------------------------------------------

# basic requirements
use strict;
use Getopt::Long;
use File::Basename;
use Pod::Usage;
use LWP::UserAgent;
use XML::Simple;
use Data::Dumper;

# predeclared subs
use subs qw/print_help check_value bool_state trim/;

# predeclared vars
use vars qw (
    $PROGNAME
    $VERSION
    
    %states
    %state_names
    $state_out
    $bool_state
    
    $opt_help
    $opt_host
    $opt_port
    $opt_location
    $opt_user
    $opt_passwd
    $opt_timeout
    $opt_useragent
    $opt_unit
    $opt_warning
    $opt_critical
    $opt_bool
    $opt_legend
    $opt_man
    $opt_verbose
    
    $sensor_value
    $sensor_min
    $sensor_max
    $sensor_hi
    $sensor_lo
    $sensor_type
    
    $url
    $realm
    $ua
    $req
    $res
    $xs
    $xml_ref
    
    $out
    $perfdata
);

# Main values
$PROGNAME = basename($0);
$VERSION = '1.0';

# Nagios exit states
%states = (OK       =>  0,
           WARNING  =>  1,
           CRITICAL =>  2,
           UNKNOWN  =>  3);

# Nagios state names
%state_names = (0   =>  'OK',
                1   =>  'WARNING',
                2   =>  'CRITICAL',
                3   =>  'UNKNOWN');

# default values:
$opt_location = '/xml';
$opt_port = 80;
$opt_timeout = 10;
$opt_useragent = $PROGNAME. '/'. $VERSION. ' LWP/'. $LWP::VERSION;
$opt_legend = $PROGNAME;

# Get the options from cl
Getopt::Long::Configure ('bundling');
GetOptions ('h'         =>  \$opt_help,
            'H=s'       =>  \$opt_host,
            'p=i'       =>  \$opt_port,
            'U=s'       =>  \$opt_user,
            'P=s'       =>  \$opt_passwd,
            'L=s'       =>  \$opt_location,
            'T=i'       =>  \$opt_timeout,
            'A=s'       =>  \$opt_useragent,
            'u=i'       =>  \$opt_unit,
            'w=s'       =>  \$opt_warning,
            'c=s'       =>  \$opt_critical,
            'bool=i'    =>  \$opt_bool,
            'legend=s'  =>  \$opt_legend,
            'man'       =>  \$opt_man,
            'verbose'   =>  \$opt_verbose)
    || print_help(1, 'Please check your options!');

# If somebody wants to the help ...
if ($opt_help) {
    print_help(1);
}
elsif ($opt_man) {
    print_help(99);
}

# Check if all needed options present.
unless ($opt_host && $opt_unit>=0 && length($opt_unit) > 0 && $opt_warning && $opt_critical && $opt_legend && $opt_timeout) {
    print_help (1, 'Too few option!');
}
else {
    # build the url from options strings
    $url = 'http://'. $opt_host. ':'. $opt_port. $opt_location;
    
    # Creating a LWP Useragent object.
    $ua = LWP::UserAgent->new;
    $ua->agent($opt_useragent);
    $ua->timeout($opt_timeout);
    
    # Creating a HTTP Request object
    $req = HTTP::Request->new(GET => $url);
    
    # If a user and passwd comes with, validate it...
    if ($opt_user && $opt_passwd) {
        # sending a first bogus request to determine the auth realm from the server
        $res = $ua->request($req);
        
        # extracting the realm or give up!
        if ($res->header('WWW-Authenticate') && $res->header('WWW-Authenticate') =~ m/realm=\"(.*?)\"/i) {
            $ua->credentials($opt_host. ':'. $opt_port,
                             $1,
                             $opt_user => $opt_passwd);
        }
        
        else {
            print_help(0, "No HTTP Auth realm could be found. Please check if you need basic auth!");
        }
    }
    
    # Checking bool states
    if (defined($opt_bool) && $opt_bool >= 0 && length($opt_bool) > 0 && !($opt_warning =~ m/^on|off|none$/i && $opt_critical =~ /^on|off|none$/i) ) {
        print_help (0, 'If you use the boolean operator only on, off and none are allowed as thresholds!');
    }
    
    # If no bool option is present, check the input values match the threshold format description
    # see: http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT
    if (!defined($opt_bool) &&
        !($opt_warning =~ m/^\@*~*(\d*\.*\d+):*~*(\d*\.*\d+)*$/ &&
          $opt_critical =~ m/^\@*~*(\d*\.*\d+):*~*(\d*\.*\d+)*$/) ) {
        
        print_help (0, 'If using nummeric thresholds, please use only numbers and the threshold values!');
    }
    
    # Sending the 'real' http request to receive the xml stuff
    $res = $ua->request($req);
    
    # Some other code than 200, give up!
    unless($res->is_success) {
        print_help(0, 'LWP Error: '. $res->status_line);
    }
    else {
        # creating a simple xml instance
        $xs = XML::Simple->new();
        
        # a hash reference for the xmldata
        $xml_ref = $xs->XMLin($res->content);
        $xml_ref = $xml_ref->{data};
        
        # collect all sensor values from the wanted unit.
        $sensor_value = trim($xml_ref->{'t'. $opt_unit});
        $sensor_min = trim($xml_ref->{'min'. $opt_unit});
        $sensor_max = trim($xml_ref->{'max'. $opt_unit});
        
        $sensor_hi = $xml_ref->{'h'. $opt_unit};
        $sensor_lo = $xml_ref->{'l'. $opt_unit};
        $sensor_type = $xml_ref->{'s'. $opt_unit};
        
        # if the data is bad, give up!
        unless (length($res->content) > 0 && $sensor_value && $sensor_type) {
            print_help(0, "Some bogus xml data returned from '$opt_host'. Please check over the configuration!");
        }
        
        # Check the values for CRITICAL (CRITICAL has first precedence!)
        if (check_value($opt_critical, $sensor_value, $opt_bool)) {
            $state_out = $states{CRITICAL};
        }
        # Check thhe values for WARNING
        elsif (check_value($opt_warning, $sensor_value, $opt_bool)) {
            $state_out = $states{WARNING};
        }
        # if nothing above returned true, seems to be okay.
        else {
            $state_out = $states{OK};
        }
        
        if ($opt_verbose) {
            print "\n", Dumper ($xml_ref), "\n\n";
        }
        
        # add the first part of the output ...
        $out = $opt_legend. ': '. $state_names{$state_out}. ' (';
        $perfdata = '|';
        
        # if is boolean probe requested, adding the bool state to output
        if (defined ($opt_bool) && $opt_bool >= 0 && length($opt_bool) > 0) {
            $bool_state = bool_state($sensor_value, $opt_bool);
            $out .= 'STATE='. $bool_state. ', ';
            if ($bool_state =~ m/on/i) {
                $perfdata .= 'state=1;';
            }
            else {
                $perfdata .= 'state=0;';
            }
        }
        
        # adding once more some values
        $out .= 'VALUE='. $sensor_value. ', ';
        $perfdata .= 'value='. $sensor_value. ';';
        $out .= 'PORT='. $opt_unit;
        $perfdata .= 'port='. $opt_unit. ';';
        
        # closing the bracket in the output val and add some basic stuff to perfdata.
        $perfdata .= "$opt_warning;$opt_critical;$sensor_min;$sensor_max";
        $out .= ')';
        
        # Sending to STDOUT and exit with the right state.
        print $out, $perfdata;
        exit ($state_out);
        
    }
}


# Exit unknown ... per default
exit ($states{UNKNOWN});

# -------------------------
# THE SUBS:
# -------------------------

# bool_state($value, $bool);
# returns NONE, OFF or if value <> $bool ON
sub bool_state {
    my ($value, $bool) = @_;
    my $state = 'NONE';
    
    if ($value == $bool) {
        $state = 'OFF';
    }
    elsif ($value != $bool) {
        $state = 'ON';
    }
    
    return ($state);
}

# check_value($threshold, $value, $bool);
# checks the threshold syntax and return 1 or 0
sub check_value {
    my ($inside, $v_start, $v_end);
    my ($threshold, $value, $bool) = @_;
    my $re = 0;
    
    if (defined ($bool) && $bool >=0 && length($bool) > 0) {
        
        $value = lc ($value);
        
        if ($bool == $value && $threshold eq 'off') {
            $re = 1;
        }
        elsif ($bool != $value && $threshold eq 'on') {
            $re = 1;
        }
        else {
            $re = 0;
        }
    }
    else {
    
        if ($threshold =~ m/^\@/i) {
            $inside = 1;
            $threshold =~ s/^\@//i;
        }
        
        if ($threshold =~ m/.*?:.*?/i) {
            ($v_start, $v_end) = split(/\:/, $threshold);
            unless ($v_end && length($v_end) >= 0) { $v_end = 'inf'; }
        }
        else {
            $v_start = 0;
            $v_end = $threshold;
        }
        
        if ($v_start =~ m/^\~/) {
            $v_start =~ s/\~//;
            $v_start *= -1;
        }
        
        if ($v_end ne 'inf' && $v_end =~ m/^\~/) {
            $v_end =~ s/\~//;
            $v_end *= -1;
        }
        
        # check infinity end and inside start
        if ($inside && $v_end eq 'inf' && $value >= $v_start) {
            $re = 1;
        }
        # check outside infinity end and start
        elsif (!$inside && $v_end eq 'inf' && $value < $v_start) {
            $re = 1;
        }
        # check inside between start and end
        elsif ($inside && ($value >= $v_start && $value <= $v_end) ) {
            $re = 1;
        }
        # check outside from start between end
        elsif (!$inside && ($value < $v_start || $value > $v_end) ) {
            $re = 1;
        }
    
    }
    return ($re);
}

# trim($string);
# return the left and right trimmed value
sub trim {
    my ($string) = @_;
    for ($string) {
        s/^\s+//;
        s/\s+$//;
    }
    return ($string);
}

# print_help($level, $msg);
# prints some message and the POD DOC
sub print_help {
    my ($level, $msg) = @_;
    $level = 0 unless ($level);
    pod2usage ({
                -message => $msg,
                -verbose => $level
                });
    
    exit ($states{UNKNOWN});
}

1;

__END__

=head1 NAME

check_allnet.pl - Checks the allnet environmental devies for NAGIOS.

=head1 SYNOPSIS

check_allnet.pl -h

check_allnet.pl --man

check_allnet.pl -H <host> -u <probe> -w <warning> -c <critical>
[-U username] [-P password]
[-p web_port] [-L /to_xml_data] [-A my_agent/1.0 ] [-T timeout]
[--bool=value_of_false] [--legend=rz6_temp]

=head1 DESCRIPTION

B<check_allnet.pl> recieves the XML data from the allnet devices. It can check thresholds and
boolean states of the connected probes.

=head1 OPTIONS

=over 8

=item B<-h>

Display this helpmessage.

=item B<-H>

The hostname or ipaddress of the allnet device.

=item B<-p>

The port where the HTTP service runs, default is 80.

=item B<-U>

The HTTP user which is authorized to view the data of the probes

=item B<-P>

The password for the HTTP user.

=item B<-L>

The weblocation where the xml data is located. Default is '/xml'. Don't forget the leading slash!

=item B<-T>

Timeout for the LWP::Useragent. Default is ten seconds.

=item B<-A>

Value for the Useragent, if you want to set a special value for it. Default is a
mix of $PROGNAME and $VERSION and $LWP::VERSION.

=item B<-u>

The port where the probe is connected to. On a AllNet 3000 there a ports from 0 to 7

=item B<-w>

The warning threshold. If you use the -bool option, the threshold syntax is only
'on', 'off' and 'none'.

=item B<-c>

The critical threshold. If you use the -bool option, the threshold syntax is only
'on', 'off' and 'none'.

=item B<--bool>

Instruct the plugin to use the boolean mode. Thresholds are set only with 'on', 'off' or 'none'.
You have to set a value which specifies the 'false' or 'off' status. For example you set '--bool=0' then
the status will be off if the probe value is '0'. All other values set the status to on. If a threshold is
set to 'none', the appropriate NAGIOS state will be considered as not exist.

=item B<--legend>

Changes the NAGIOS pluginoutput in the Webinterface. This feature is intendet for the Webfrontend to
identify the service easier.

=item B<--man>

Display's the complete perldoc manpage.

=item B<--verbose>

Display's some more output, not intended for use with NAGIOS.

=cut

=head1 THRESHOLD FORMATS

B<1.> start <= end

The startvalue have to be less than the endvalue

B<2.> start and ':' is not required if start=0>

If you set a threshold of '12' it's the same like '0:12'

B<3.> if range is of format "start:" and end is not specified, assume end is infinity

B<4.> to specify negative infinity, use '~' (tilde)

For example: ~10:~2 the threshold is from -10 to -2.

B<5.> alert is raised if metric is outside start and end range (inclusive of endpoints)

B<6.> if range starts with "@", then alert if inside this range (inclusive of endpoints)

=head1 VERSION

Plugin is under development, beta status:

$Id: check_allnet.pl 835 2005-04-20 08:53:05Z mhein $

=head1 AUTHOR

NETWAYS GmbH, 2005, http://www.netways.de.

Written by Marius Hein <mhein@netways.de>.

Please report bugs at https://www.netways.org/projects/plugins