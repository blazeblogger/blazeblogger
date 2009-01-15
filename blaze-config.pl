#!/usr/bin/env perl

# blaze-config, display or set the Blaze repository options
# Copyright (C) 2008, 2009 Jaromir Hradilek

# This program is  free software:  you can redistribute it and/or modify it
# under  the terms  of the  GNU General Public License  as published by the
# Free Software Foundation, version 3 of the License.
# 
# This program  is  distributed  in the hope  that it will  be useful,  but
# WITHOUT  ANY WARRANTY;  without  even the implied  warranty of MERCHANTA-
# BILITY  or  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
# License for more details.
# 
# You should have received a copy of the  GNU General Public License  along
# with this program. If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;
use File::Basename;
use File::Spec::Functions;
use Config::IniHash;
use Getopt::Long;
use POSIX qw(strftime);

# General script information:
use constant NAME    => basename($0, '.pl');        # Script name.
use constant VERSION => '0.0.1';                    # Script version.

# General script settings:
our $destdir = '.';                                 # Destination folder.
our $verbose = 1;                                   # Verbosity level.

# List of valid options:
our %options = (
  # User related settings:
  'user.name'     => "User's name to be used as a default posts' author.",
  'user.email'    => "User's e-mail; not to be used anywhere so far.",

  # Blog related settings:
  'blog.title'    => "Blog title.",
  'blog.subtitle' => "Blog subtitle.",
  'blog.codepage' => "Blog encoding in a form recognized by HTML 4.01.",
  'blog.theme'    => "Blog theme; the .html suffix can be omitted.",
  'blog.style'    => "Blog stylesheet; the .css suffix can be omitted.",
);

# Set up the __WARN__ signal handler:
$SIG{__WARN__} = sub {
  my $message  = shift;
  print STDERR NAME . ": $message";
};

# Display given message and terminate the script:
sub exit_with_error {
  my $message      = shift || 'An unspecified error has occured.';
  my $return_value = shift || 1;

  print STDERR NAME . ": $message\n";
  exit $return_value;
}

# Display usage information:
sub display_help {
  my $NAME = NAME;

  print << "END_HELP";
Usage: $NAME [-q] [-d directory] option [value]
       $NAME -h | -v

  -d, --destdir directory     specify the destination directory
  -q, --quiet                 avoid displaying unnecessary messages
  -h, --help                  display this help and exit
  -v, --version               display version information and exit
END_HELP
}

# Display version information:
sub display_version {
  my ($NAME, $VERSION) = (NAME, VERSION);

  print << "END_VERSION";
$NAME $VERSION

Copyright (C) 2008, 2009 Jaromir Hradilek
This program is free software; see the source for copying conditions. It is
distributed in the hope  that it will be useful,  but WITHOUT ANY WARRANTY;
without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PAR-
TICULAR PURPOSE.
END_VERSION
}

# Set up the options parser:
Getopt::Long::Configure('no_auto_abbrev', 'no_ignore_case', 'bundling');

# Process command-line options:
GetOptions(
  'help|h'        => sub { display_help();    exit 0; },
  'version|v'     => sub { display_version(); exit 0; },
  'quiet|q'       => sub { $verbose = 0;     },
  'destdir|d=s'   => sub { $destdir = $_[1]; },
);

# Check for missing options::
exit_with_error("Missing option.", 22) if (scalar(@ARGV) == 0);

# Read the configuration file:
my $filename = catfile($destdir, '.blaze', 'config');
my $config   = ReadINI($filename)
               or exit_with_error("Unable to read `$filename'.", 13);

# Check whether the option is valid:
if (exists $options{$ARGV[0]}) {
  # Get option key pair:
  my ($section, $key) = split(/\./, shift(@ARGV));

  # Decide whether to get or set the value:
  if (scalar(@ARGV) != 0) {
    # Use the rest of the arguments as a value:
    $config->{$section}->{$key} = join(' ', @ARGV);

    # Save the configuration file:
    WriteINI($filename, $config)
      or exit_with_error("Unable to write to `$filename'.", 13);
  }
  else {
    # Check whether the option is set:
    if (my $value = $config->{$section}->{$key}) {
      # Display the value:
      print "$value\n";
    }
    else {
      # Return failure:
      exit 1;
    }
  }
}
else {
  # Report failure:
  exit_with_error("Invalid option `$ARGV[0]'.", 22);
}

# Return success:
exit 0;
