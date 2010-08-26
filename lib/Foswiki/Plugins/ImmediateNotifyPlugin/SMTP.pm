package Foswiki::Plugins::ImmediateNotifyPlugin::SMTP;

use strict;
use Foswiki::Net;

use vars
  qw($user $pass $server $wikiuser $web $topic $debug $warning $sendEmail);

# ========================
# initMethed - initializes a single notification method
# Parametrs $topic, $web, $user
#    $topic is the current topic
#    $web is the web in which the topic is stored
#    $user is the logged-in user
sub initMethod {
    ( $topic, $web, $wikiuser ) = @_;
    $server = "localhost";  #Foswiki::Func::getPreferencesValue("SMTPMAILHOST");
    $wikiuser  = $_[2];
    $debug     = \&Foswiki::Plugins::ImmediateNotifyPlugin::debug;
    $warning   = \&Foswiki::Plugins::ImmediateNotifyPlugin::warning;
    $sendEmail = \&Foswiki::Net::sendEmail;
    return defined($server);
}

# ========================
# handleNotify - handles notification for a single notification method
# Parameters: $users
#    $users is a hash reference of the form username->user topic text
sub handleNotify {
    my ($users)    = @_;
    my ($skin)     = Foswiki::Func::getPreferencesValue("SKIN");
    my ($template) = Foswiki::Func::readTemplate( 'smtp', 'immediatenotify' );

    # &$debug("- SMTP:  template read $template");
    my ($from) = Foswiki::Func::getPreferencesValue("WIKIWEBMASTER");

    $template =~ s/%EMAILFROM%/$from/go;
    $template =~ s/%WEB%/$web/go;
    $template =~ s/%TOPICNAME%/$topic/go;
    $template =~ s/%USER%/$wikiuser/go;

    $template = Foswiki::Func::expandCommonVariables( $template, $topic, $web );

    foreach my $userName ( keys %$users ) {

        my ($to);
        &$debug("- SMTP: userName $userName");
        my @emails = Foswiki::Func::wikinameToEmails($userName);
        foreach my $email (@emails) {
            $to .= $email . ",";
        }
        if ($to) {
            my $msg = $template;
            $msg =~ s/%EMAILTO%/$to/go;
            &$debug("- SMTP: Sending mail to $to ($userName)");
            &$debug("- SMTP: MESSAGE ($msg)");

            my $foswiki    = new Foswiki( $Foswiki::cfg{DefaultUserLogin} );
            my $foswikiNet = $foswiki->net();
            my $error      = $foswikiNet->sendEmail($msg);

            &$debug("- SMTP: Error ($error)") if ($error);
        }

    }
}

1;
