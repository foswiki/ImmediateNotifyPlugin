# ---+ Extensions
# ---++ ImmediateNotifyPlugin
# **BOOLEAN**
# Enable SMTP for mailing messages. Note:  This plugin uses Foswiki core email support for sending
# notifications.  See the "Mail and Proxies" tab for the configuration.
$Foswiki::cfg{Plugins}{ImmediateNotifyPlugin}{SMTP}{Enabled} = $FALSE;

# **REGEX**
# Define the regular expression that an email address entered in WebNotify
# must match to be identified as a legal email by the notifier. You can use
# this expression to - for example - filter email addresses on your company
# domain.<br />
# If this is not defined, then the default setting of
# <code>[A-Za-z0-9.+-_]+\@[A-Za-z0-9.-]+</code> is used.
$Foswiki::cfg{Plugins}{ImmediateNotifyPlugin}{SMTP}{EmailFilterIn} = '';

# **BOOLEAN**
# Enable XMPP (XMPP) for notifications.
$Foswiki::cfg{Plugins}{ImmediateNotifyPlugin}{XMPP}{Enabled} = $FALSE;

# **STRING 30**
# Hostname of the XMPP / XMPP server
$Foswiki::cfg{Plugins}{ImmediateNotifyPlugin}{XMPP}{Server} = '';

# **STRING 30**
# Username for the XMPP account used by the ImmediateNotifyPlugin.  If configured here, the
# topic based setting will be ignored.
$Foswiki::cfg{Plugins}{ImmediateNotifyPlugin}{XMPP}{Username} = '';

# **PASSWORD 30**
# Password for the XMPP account used by the ImmediateNotifyPlugin.  If configured here, the
# topic based setting will be ignored.
$Foswiki::cfg{Plugins}{ImmediateNotifyPlugin}{XMPP}{Password} = '';

