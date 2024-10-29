# SNMP::Info::Layer3::F5
#
# Copyright (c) 2012 Eric Miller
# All Rights Reserved
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#     * Redistributions of source code must retain the above copyright notice,
#       this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of the University of California, Santa Cruz nor the
#       names of its contributors may be used to endorse or promote products
#       derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR # ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

package SNMP::Info::Layer3::F5;

use strict;
use warnings;
use Exporter;
use SNMP::Info::Layer3;

@SNMP::Info::Layer3::F5::ISA       = qw/SNMP::Info::Layer3 Exporter/;
@SNMP::Info::Layer3::F5::EXPORT_OK = qw//;

our ($VERSION, %GLOBALS, %FUNCS, %MIBS, %MUNGE);

$VERSION = '3.972002';

%MIBS = (
    %SNMP::Info::Layer3::MIBS,
    'F5-BIGIP-SYSTEM-MIB' => 'sysAttrArpMaxEntries',
);

%GLOBALS = (
    %SNMP::Info::Layer3::GLOBALS,
    'os_ver'     => 'sysProductVersion',
    'mkt_name'   => 'sysPlatformInfoMarketingName',
    'ps1_status' => 'sysChassisPowerSupplyStatus.1',
    'ps2_status' => 'sysChassisPowerSupplyStatus.2',

    # Named serial1 to override serial1 in L3 serial method
    'serial1'    => 'sysGeneralChassisSerialNum',
    'qb_vlans'   => 'sysVlanNumber',
    'ports'      => 'sysInterfaceNumber',

);

%FUNCS = (
    %SNMP::Info::Layer3::FUNCS,

    # sysInterfaceTable
    'sys_i_description' => 'sysInterfaceName',
    'sys_i_mtu'         => 'sysInterfaceMtu',
    'sys_i_speed'       => 'sysInterfaceMediaActiveSpeed',
    'sys_i_up_admin'    => 'sysInterfaceEnabled',
    'sys_i_up'          => 'sysInterfaceStatus',
    'sys_i_duplex'      => 'sysInterfaceMediaActiveDuplex',

    # sysChassisFanTable
    'fan_state' => 'sysChassisFanStatus',

    # sysVlanTable
    'sys_v_id' => 'sysVlanId',
    'sys_v_name'   => 'sysVlanVname',

    # sysVlanMemberTable
    'sys_vm_tagged' => 'sysVlanMemberTagged',
    'sys_vm_name'   => 'sysVlanMemberVmname',
    'sys_vmp_name'  => 'sysVlanMemberParentVname',
);

%MUNGE = ( %SNMP::Info::Layer3::MUNGE, );

sub _convert_f5id_stdid {
    my $f5      = shift;
    my $partial = shift;
    my $id = shift;
    my $sys_i_description = $f5->sys_i_description($partial) || {};
    my $i_name = $f5->i_name($partial) || {};
   
    if (exists($sys_i_description->{$id})) {
        my @result = grep { $i_name->{$_} eq $sys_i_description->{$id} } keys %$i_name;
        if (scalar @result eq 1) {
            return $result[0];
        }
    }
    return $id;
};

sub vendor {
    return 'f5';
}

sub os {
    return 'f5';
}

sub fan {
    my $f5        = shift;
    my $fan_state = $f5->fan_state();
    my $ret       = "";
    my $s         = "";
    foreach my $i ( sort { $a <=> $b } keys %$fan_state ) {
        $ret .= $s . $i . ': ' . $fan_state->{$i};
        $s = ', ';
    }
    return if ( $s eq "" );
    return $ret;
}

sub model {
    my $f5 = shift;

    my $name = $f5->mkt_name();

    if ( defined $name ) { return $name; }

    my $id    = $f5->id();
    my $model = &SNMP::translateObj($id);
    if ( !defined $model ) { return $id; }

    return $model;
}

# Override L3 i_mtu
sub i_mtu {
    my $f5      = shift;
    my $partial = shift;

    my $mtu = $f5->sys_i_mtu($partial) || {};
    my $i_mtu = {};
    while (my ($iid,$value) = each( %$mtu )) {
        $i_mtu->{$f5->_convert_f5id_stdid($partial,$iid)} = $value;
    }
    
    return $i_mtu;
}

# Override L3 i_duplex
sub i_duplex {
    my $f5      = shift;
    my $partial = shift;

    my $duplexes = $f5->sys_i_duplex() || {};

    my $i_duplex = {};
    while (my ($iid,$duplex) = each( %$duplexes )) {
        next unless defined $duplex;
        next if ( $duplex eq 'none' );

        $i_duplex->{$f5->_convert_f5id_stdid($partial,$iid)} = $duplex;
    }
    return $i_duplex;
}

# Override Bridge v_index
sub v_index {
    my $f5      = shift;
    my $partial = shift;

    my $v_idx = $f5->sys_v_id($partial);
    my $v_index = {};
    while (my ($vid,$value) = each( %$v_idx )) {
        $v_index->{$vid =~ s/\.//gr} = $value;
    }

    return $v_index;
}

# Override Bridge v_name
sub v_name {
    my $f5      = shift;
    my $partial = shift;

    my $vlan_names = $f5->sys_v_name($partial) || {};
    my $v_name = {};
    while (my ($vid,$value) = each( %$vlan_names )) {
        $v_name->{$vid =~ s/\.//gr} = $value;
    }

    return $v_name;
}

sub i_vlan {
    my $f5      = shift;
    my $partial = shift;

    my $index  = $f5->interfaces($partial) || {};
    my $tagged = $f5->sys_vm_tagged()   || {};
    my $vlans  = $f5->v_index()         || {};

    my $i_vlan = {};
    foreach my $iid ( keys %$tagged ) {
        my $tag = $tagged->{$iid};
        next if ( $tag eq 'true' );

        # IID is length.vlan name index.length.interface index
        # Split out and use as the IID to get the VLAN ID and ifIndex
        my @iid_array = split(/\./, $iid);
        my $len       = $iid_array[0];
        my $v_idx     = join('', ( splice @iid_array, 0, $len + 1 ));
        my $idx       = $f5->_convert_f5id_stdid($partial,join('.', @iid_array));

        # Check to make sure we can map to a port
        my $p_idx = $index->{$idx};
        next unless $p_idx;

        my $vlan = $vlans->{$v_idx};
        next unless $vlan;

        $i_vlan->{$idx} = $vlan;
    }
    return $i_vlan;
}

sub i_vlan_membership {
    my $f5      = shift;
    my $partial = shift;

    my $index  = $f5->interfaces($partial) || {};
    my $tagged = $f5->sys_vm_tagged()   || {};
    my $vlans  = $f5->v_index()         || {};

    my $i_vlan_membership = {};
    foreach my $iid ( keys %$tagged ) {

        # IID is length.vlan name index.length.interface index
        # Split out and use as the IID to get the VLAN ID and ifIndex
        my @iid_array = split (/\./, $iid);
        my $len       = $iid_array[0];
        my $v_idx     = join ('.', ( splice @iid_array, 0, $len + 1 ));
        my $idx       = $f5->_convert_f5id_stdid($partial,join ('.', @iid_array));

        # Check to make sure we can map to a port
        my $p_idx = $index->{$idx};
        next unless $p_idx;

        my $vlan = $vlans->{$v_idx};
        next unless $vlan;

        push( @{ $i_vlan_membership->{$idx} }, $vlan );
    }
    return $i_vlan_membership;
}

sub i_vlan_membership_untagged {
    my $f5      = shift;
    my $partial = shift;

    my $index  = $f5->interfaces($partial) || {};
    my $tagged = $f5->sys_vm_tagged()   || {};
    my $vlans  = $f5->v_index()         || {};

    my $i_vlan_membership = {};
    foreach my $iid ( keys %$tagged ) {

        next unless $tagged->{$iid} eq 'false';
        # IID is length.vlan name index.length.interface index
        # Split out and use as the IID to get the VLAN ID and ifIndex
        my @iid_array = split (/\./, $iid);
        my $len       = $iid_array[0];
        my $v_idx     = join ('.', ( splice @iid_array, 0, $len + 1 ));
        my $idx       = $f5->_convert_f5id_stdid($partial,join ('.', @iid_array));

        # Check to make sure we can map to a port
        my $p_idx = $index->{$idx};
        next unless $p_idx;

        my $vlan = $vlans->{$v_idx};
        next unless $vlan;

        push( @{ $i_vlan_membership->{$idx} }, $vlan );
    }
    return $i_vlan_membership;
}

1;
__END__

=head1 NAME

SNMP::Info::Layer3::F5 - SNMP Interface to F5 network devices.

=head1 AUTHOR

Eric Miller

=head1 SYNOPSIS

 # Let SNMP::Info determine the correct subclass for you.
 my $f5 = new SNMP::Info(
                          AutoSpecify => 1,
                          Debug       => 1,
                          DestHost    => 'myswitch',
                          Community   => 'public',
                          Version     => 2
                        )
    or die "Can't connect to DestHost.\n";

 my $class      = $f5->class();
 print "SNMP::Info determined this device to fall under subclass : $class\n";

=head1 DESCRIPTION

Abstraction subclass for F5 network devices.

=head2 Inherited Classes

=over

=item SNMP::Info::Layer3

=back

=head2 Required MIBs

=over

=item F<F5-BIGIP-COMMON-MIB>

=item F<F5-BIGIP-SYSTEM-MIB>

=item Inherited Classes' MIBs

See L<SNMP::Info::Layer3/"Required MIBs"> for its own MIB requirements.

=back

=head1 GLOBALS

These are methods that return scalar value from SNMP

=over

=item $f5->model()

Return (C<sysPlatformInfoMarketingName>), otherwise tries to reference
$f5->id() to F<F5-BIGIP-COMMON-MIB>.

=item $f5->vendor()

Returns 'f5'

=item $f5->os()

Returns 'f5'

=item $f5->os_ver()

Returns the software version reported by C<sysProductVersion>

=item $f5->fan()

Combines (C<sysChassisFanStatus>) into a single string.

=item $f5->ps1_status()

Returns status of primary power supply

=item $f5->ps2_status()

Returns status of redundant power supply

=back

=head2 Globals imported from SNMP::Info::Layer3

See documentation in L<SNMP::Info::Layer3/"GLOBALS"> for details.

=head1 TABLE METHODS

These are methods that return tables of information in the form of a
reference to a hash.

=head2 Overrides

=over

=item $f5->i_duplex()

Returns reference to hash.  Maps port operational duplexes to IIDs.

(C<sysInterfaceMediaActiveDuplex>).

=item $f5->i_mtu()

Returns reference to hash.  Maps port operational MTU to IIDs

(C<sysInterfaceMtu>).

=item $f5->i_vlan()

Returns a mapping between C<ifIndex> and the default VLAN.

=item $f5->i_vlan_membership()

Returns reference to hash of arrays: key = C<ifIndex>, value = array of VLAN
IDs.

  Example:
  my $interfaces = $f5->interfaces();
  my $vlans      = $f5->i_vlan_membership();

  foreach my $iid (sort keys %$interfaces) {
    my $port = $interfaces->{$iid};
    my $vlan = join(',', sort(@{$vlans->{$iid}}));
    print "Port: $port VLAN: $vlan\n";
  }

=item $f5->i_vlan_membership_untagged()

Returns reference to hash of arrays: key = C<ifIndex>, value = array of VLAN
IDs.  These are the VLANs which are members of the untagged egress list for
the port.

=item $f5->v_index()

Returns VLAN IDs

=item $f5->v_name()

Human-entered name for vlans.

=back

=head2 Table Methods imported from SNMP::Info::Layer3

See documentation in L<SNMP::Info::Layer3/"TABLE METHODS"> for details.

=cut

# vim: expandtab tabstop=4 shiftwidth=4
