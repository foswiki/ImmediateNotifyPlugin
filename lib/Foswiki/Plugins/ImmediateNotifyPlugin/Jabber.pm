package Foswiki::Plugins::ImmediateNotifyPlugin::Jabber;

use strict;
use warnings;

use Net::XMPP qw(Client);

my $debug;
my $warning;
my $xmppUser;
my $xmppPass;
my $xmppServer;
my $xmppResource;
my $con;

# ========================
# initMethed - initializes a single notification method
sub initMethod {
    my $prefPrefix = "IMMEDIATENOTIFYPLUGIN_JABBER_";
    $xmppUser = $Foswiki::cfg{ImmediateNotifyPlugin}{Jabber}{Username} || Foswiki::Func::getPreferencesValue( $prefPrefix . "USERNAME" );
    $xmppPass = $Foswiki::cfg{ImmediateNotifyPlugin}{Jabber}{Password} || Foswiki::Func::getPreferencesValue( $prefPrefix . "PASSWORD" );
    $xmppServer =  $Foswiki::cfg{ImmediateNotifyPlugin}{Jabber}{Server} || Foswiki::Func::getPreferencesValue( $prefPrefix . "SERVER" );
    $xmppResource =
      'Foswiki';    #Foswiki::Func::getPreferencesValue( 'WIKITOOLNAME' );
    $debug   = \&Foswiki::Plugins::ImmediateNotifyPlugin::debug;
    $warning = \&Foswiki::Plugins::ImmediateNotifyPlugin::warning;
    &$debug("- Jabber init with $xmppUser,  $xmppPass, $xmppServer");

    return unless defined($xmppUser) && defined($xmppPass) && defined($xmppServer);

    $con = new Net::XMPP::Client;
    &$debug("- Jabber: Connecting to server $xmppServer...");
    $con->Connect( hostname => $xmppServer );
    unless ( $con->Connected() ) {
        &$warning("- Jabber: Could not connect to Jabber server $xmppServer");
        return 0;
    }
    &$debug(
        "- Jabber: Connected, logging in with ($xmppUser) and ($xmppPass)...");
    my @authResult = $con->AuthIQAuth(
        username => $xmppUser,
        password => $xmppPass,
        resource => $xmppResource,
    );
    if ( $authResult[0] ne 'ok' ) {
        &$warning(
"- Jabber: Could not log in to Jabber server $xmppServer ($xmppUser), ($xmppPass): $authResult[0] $authResult[1]"
        );
        $con->Disconnect();
        undef $con;
        return 0;
    }
    return 1;
}

# ========================
# handleNotify - handles notification for a single notification method
# Parameters: $userHash, $info
#    $userHash is a hash reference of the form username->user topic text
#    $info is a hash reference for an extended topicRevisionInfo of the saved topic
sub handleNotify {
    my $userHash    = shift;
    my $info        = shift;

    &$debug("- Jabber: Logged in OK, sending messages...");
    my $toolName = Foswiki::Func::getPreferencesValue("WIKITOOLNAME")
      || "Foswiki";
    foreach my $user ( keys %$userHash ) {

        &$debug(" processing $user");
        #&$debug(" userref = ".ref($userHash->{$user}));
        my %uHash = %{ $userHash->{$user} };

        # TODO:  Allow serverless ID's - substute in the @server for destination
        # get jabber userid
        my $jabberID;
        if ( $uHash{PARMS} ) {
            $jabberID = $uHash{PARMS};
            &$debug("- Jabber: User $user: $jabberID");
        }
        next unless $jabberID;
        my $message  = new Net::XMPP::Message;
        my $topicUrl = Foswiki::Func::getViewUrl( $info->{web}, $info->{topic} );
        my $body     = "$topicUrl on $toolName has been updated by $info->{user} to Revision r$info->{version}!";
        $message->SetMessage(
            to   => $jabberID,
            from => "$user\@$xmppServer",
            body => $body
        );
        $con->Send($message);
    }

    $con->Disconnect();
}

1;

