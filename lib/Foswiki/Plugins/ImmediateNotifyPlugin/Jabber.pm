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

# ========================
# initMethed - initializes a single notification method
sub initMethod {
    my $prefPrefix = "IMMEDIATENOTIFYPLUGIN_JABBER_";
    $xmppUser = Foswiki::Func::getPreferencesValue( $prefPrefix . "USERNAME" );
    $xmppPass = Foswiki::Func::getPreferencesValue( $prefPrefix . "PASSWORD" );
    $xmppServer = Foswiki::Func::getPreferencesValue( $prefPrefix . "SERVER" );
    $xmppResource =
      'Foswiki';    #Foswiki::Func::getPreferencesValue( 'WIKITOOLNAME' );
    $debug   = \&Foswiki::Plugins::ImmediateNotifyPlugin::debug;
    $warning = \&Foswiki::Plugins::ImmediateNotifyPlugin::warning;
    &$debug("- Jabber init with $xmppUser,  $xmppPass, $xmppServer");
    return defined($xmppUser) && defined($xmppPass) && defined($xmppServer);
}

# ========================
# handleNotify - handles notification for a single notification method
# Parameters: $userHash, $web, $topic, $wikiuser
#    $userHash is a hash reference of the form username->user topic text
#    $web is the web in which the topic is stored
#    $topic is the current topic
#    $wikiuser is the logged-in user who saved the topic
sub handleNotify {
    my $userHash = shift;
    my $web      = shift;
    my $topic    = shift;
    my $wikiuser = shift;

    my $con = new Net::XMPP::Client;
    &$debug("- Jabber: Connecting to server $xmppServer...");
    $con->Connect( hostname => $xmppServer );
    unless ( $con->Connected() ) {
        &$warning("- Jabber: Could not connect to Jabber server $xmppServer");
        return;
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
        return;
    }
    &$debug("- Jabber: Logged in OK, sending messages...");
    my $mainWeb = Foswiki::Func::getPreferencesValue("MAINWEB") || "Main";
    my $toolName = Foswiki::Func::getPreferencesValue("WIKITOOLNAME")
      || "Foswiki";
    foreach my $user ( keys %$userHash ) {

        #&$debug(" userref = ".ref($userHash->{$user}));
        my %uHash = %{ $userHash->{$user} };

        #foreach my $kkk (keys %uHash) {
        #    &$debug(" DUMP kkk $kkk $uHash{$kkk} ");
        #    }

        # get jabber userid
        my $jabberID;
        if ( $uHash{PARMS} ) {
            $jabberID = $uHash{PARMS};
            &$debug("- Jabber: User $user: $jabberID");
        }
        next unless $jabberID;
        my $message  = new Net::XMPP::Message;
        my $topicUrl = Foswiki::Func::getViewUrl( $web, $topic );
        my $body     = "$topicUrl on $toolName has been updated by $wikiuser!";
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

