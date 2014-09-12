#!/usr/bin/perl -w
#
# Copyright (C) 2013-2014 Zentyal S.L.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

use warnings;
use strict;

package EBox::RemoteServices::Test;

use base 'Test::Class';

use EBox::Config::TestStub;
use EBox::GlobalImpl;
use EBox::Global::TestStub;
use EBox::Module::Config::TestStub;
use EBox::Test::RedisMock;
use EBox::TestStubs;
use Test::Exception;
use Test::MockObject::Extends;
use Test::More;
use POSIX;

sub setUpConfiguration : Test(startup)
{
    EBox::Global::TestStub::fake();
    EBox::Config::TestStub::fake();
}

sub clearConfiguration : Test(shutdown)
{
    EBox::Module::Config::TestStub::setConfig();
}

sub get_module : Test(setup)
{
    my ($self) = @_;
    my $redis = EBox::Test::RedisMock->new();
    $self->{rsMod} = EBox::RemoteServices->_create(redis => $redis);
}

sub use_remoteservices_ok : Test(startup => 1)
{
    use_ok('EBox::RemoteServices') or die;
}

sub test_isa_ok : Test
{
    my ($self) = @_;

    isa_ok($self->{rsMod}, 'EBox::RemoteServices');
}

sub test_ad_messages : Test(11)
{
    # It tests everything related to ad messages methods
    my ($self) = @_;

    my $rsMod = $self->{rsMod};
    is($rsMod->popAdMessage('tais-toi'), undef, 'No message with this name');
    cmp_ok($rsMod->adMessages()->{text}, 'eq', "", 'No ad messages');
    cmp_ok($rsMod->adMessages()->{name}, 'eq', 'remoteservices', 'The ad-message name');

    lives_ok { $rsMod->pushAdMessage('gas', 'drummers') } 'Pushing an ad message';
    lives_ok { $rsMod->pushAdMessage('miss', 'caffeina') } 'Pushing another message';
    like($rsMod->adMessages()->{text}, qr{drummers}, 'Ad messages');

    cmp_ok($rsMod->popAdMessage('gas'), 'eq', 'drummers', 'Pop a valid ad message');
    is($rsMod->popAdMessage('gas'), undef, 'You can only pop out once');

    lives_ok { $rsMod->pushAdMessage('back-to', 'decandence') } 'Pushing an ad message';
    lives_ok { $rsMod->pushAdMessage('back-to', 'uprising') } 'Overwritting an ad message';
    cmp_ok($rsMod->popAdMessage('back-to'), 'eq', 'uprising', 'Last one were updated');
}

sub test_check_ad_messages : Test
{
    my ($self) = @_;

    EBox::TestStubs::fakeModule(
        name => 'samba',
        subs => [ 'isEnabled' => sub { return 1; },
                  'realUsers' => sub { return [('user') x 100]; }]);

    my $rsMod = $self->{rsMod};
    my $mockedRSMod = new Test::MockObject::Extends($rsMod);
    $mockedRSMod->set_true('eBoxSubscribed');
    $mockedRSMod->mock('subscriptionInfo', sub { {'features' => { 'serverusers' => {'max' => 232}}}});

    # Dirty hack to set mocked RS in global
    EBox::GlobalImpl->instance()->{'mod_instances_rw'}->{remoteservices} = $mockedRSMod;

    lives_ok { $mockedRSMod->checkAdMessages(); } 'Check ad messages';
}

1;

END {
    EBox::RemoteServices::Test->runtests();
}
