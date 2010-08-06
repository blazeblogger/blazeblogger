#!/usr/bin/env perl

# blaze-log - displays the BlazeBlogger repository log
# Copyright (C) 2009, 2010 Jaromir Hradilek

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
use Getopt::Long;
use Term::ANSIColor;
use Text::Wrap;

# General script information:
use constant NAME    => basename($0, '.pl');        # Script name.
use constant VERSION => '1.0.0';                    # Script version.

# General script settings:
our $blogdir    = '.';                              # Repository location.
our $coloured   = undef;                            # Use colors?
our $compact    = 0;                                # Use compact listing?
our $number     = 0;                                # Listed records limit.
our $reverse    = 0;                                # Use reverse order?
our $verbose    = 1;                                # Verbosity level.

# Set up the __WARN__ signal handler:
$SIG{__WARN__}  = sub {
  print STDERR NAME . ": " . (shift);
};

# Display given message and terminate the script:
sub exit_with_error {
  my $message      = shift || 'An error has occurred.';
  my $return_value = shift || 1;

  # Display the error message:
  print STDERR NAME . ": $message\n";

  # Terminate the script:
  exit $return_value;
}

# Display given warning message:
sub display_warning {
  my $message = shift || 'A warning was requested.';

  # Display the warning message:
  print STDERR "$message\n";

  # Return success:
  return 1;
}

# Display usage information:
sub display_help {
  my $NAME = NAME;

  # Display the usage:
  print << "END_HELP";
Usage: $NAME [-cqrsCV] [-b DIRECTORY] [-n NUMBER]
       $NAME -h|-v

  -b, --blogdir DIRECTORY     specify a directory in which the BlazeBlogger
                              repository is placed
  -n, --number NUMBER         specify a number of log entries to be listed
  -s, --short                 display each log entry on a single line
  -r, --reverse               display log entries in reverse order
  -c, --color                 enable colored output
  -C, --no-color              disable colored output
  -q, --quiet                 do not display unnecessary messages
  -V, --verbose               display all messages
  -h, --help                  display this help and exit
  -v, --version               display version information and exit
END_HELP

  # Return success:
  return 1;
}

# Display version information:
sub display_version {
  my ($NAME, $VERSION) = (NAME, VERSION);

  # Display the version:
  print << "END_VERSION";
$NAME $VERSION

Copyright (C) 2009, 2010 Jaromir Hradilek
This program is free software; see the source for copying conditions. It is
distributed in the hope  that it will be useful,  but WITHOUT ANY WARRANTY;
without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PAR-
TICULAR PURPOSE.
END_VERSION

  # Return success:
  return 1;
}

# Read data from the INI file:
sub read_ini {
  my $file    = shift || die 'Missing argument';

  # Initialize required variables:
  my $hash    = {};
  my $section = 'default';

  # Open the file for reading:
  open(INI, "$file") or return 0;

  # Process each line:
  while (my $line = <INI>) {
    # Parse the line:
    if ($line =~ /^\s*\[([^\]]+)\]\s*$/) {
      # Change the section:
      $section = $1;
    }
    elsif ($line =~ /^\s*(\S+)\s*=\s*(\S.*)$/) {
      # Add option to the hash:
      $hash->{$section}->{$1} = $2;
    }
  }

  # Close the file:
  close(INI);

  # Return the result:
  return $hash;
}

# Read the content of the configuration file:
sub read_conf {
  # Prepare the file name:
  my $file = catfile($blogdir, '.blaze', 'config');

  # Parse the file:
  if (my $conf = read_ini($file)) {
    # Return the result:
    return $conf;
  }
  else {
    # Report failure:
    display_warning("Unable to read the configuration.");

    # Return an empty configuration:
    return {};
  }
}

# Display a log entry:
sub display_record {
  my $record = shift || die 'Missing argument';

  # Check whether to use compact listing:
  unless ($compact) {
    # Decompose the record:
    my ($date, $message) = split(/\s+-\s+/, $record, 2);

    # Check whether colors are enabled:
    unless ($coloured) {
      # Display plain record header:
      print "Date: $date\n\n";
    }
    else {
      # Display colored record header:
      print colored ("Date: $date", 'yellow');
      print "\n\n";
    }

    # Display the record body:
    print wrap('    ', '    ', $message);
    print "\n";
  }
  else {
    # Display the short record:
    print $record;
  }

  # Return success:
  return 1;
}

# Display log entries:
sub display_log {
  # Initialize required variables:
  my @lines = ();
  my $count = 0;

  # Prepare the file name:
  my $file  = catfile($blogdir, '.blaze', 'log');

  # Open the log file for reading:
  open(LOG, "$file") or return 0;

  # Process each entŕy:
  while (my $record = <LOG>) {
    # Check whether to use reverse order:
    if ($reverse) {
      # Display the log entry immediately:
      display_record($record);

      # Check whether the limited number of displayed entries is requested:
      if ($number > 0) {
        # Increase the displayed entries counter:
        $count++;

        # End loop when the counter reaches the limit:
        last if $count == $number;
      }
    }
    else {
      # Prepend the log entry to the list of records to be displayed later:
      unshift(@lines, $record);
    }
  }

  # Close the file:
  close(LOG);

  # Unless the reverse order was requested, and therefore records have been
  # already displayed, display them now:
  unless ($reverse) {
    # Process each log entry:
    foreach my $record (@lines) {
      # Display the log entry:
      display_record($record);

      # Check whether the limited number of displayed entries is requested:
      if ($number > 0) {
        # Increase the displayed entries counter:
        $count++;

        # End loop when the counter reaches the limit:
        last if $count == $number;
      }
    }
  }

  # Return success:
  return 1;
}

# Set up the option parser:
Getopt::Long::Configure('no_auto_abbrev', 'no_ignore_case', 'bundling');

# Process command line options:
GetOptions(
  'help|h'               => sub { display_help();    exit 0; },
  'version|v'            => sub { display_version(); exit 0; },
  'reverse|r'            => sub { $reverse  = 1;      },
  'short|s'              => sub { $compact  = 1;      },
  'no-color|no-colour|C' => sub { $coloured = 0;      },
  'color|colour|c'       => sub { $coloured = 1;      },
  'quiet|q'              => sub { $verbose  = 0;      },
  'verbose|V'            => sub { $verbose  = 1;      },
  'blogdir|b=s'          => sub { $blogdir  = $_[1];  },
  'number|n=i'           => sub { $number   = $_[1];  },
);

# Detect superfluous options:
exit_with_error("Invalid option `$ARGV[0]'.", 22) if (scalar(@ARGV) != 0);

# Check whether the repository is present, no matter how naive this method
# actually is:
exit_with_error("Not a BlazeBlogger repository! Try `blaze-init' first.",1)
  unless (-d catdir($blogdir, '.blaze'));

# Unless specified on the command line, read the color setup from the
# configuration file:
unless (defined $coloured) {
  # Read the configuration file:
  my $conf  = read_conf();

  # Read required data from the configuration:
  my $temp  = $conf->{color}->{log} || 'false';

  # Set up the output mode:
  $coloured = ($temp =~ /^(true|auto)\s*$/i) ? 1 : 0;
}

# Display log records:
display_log()
  or exit_with_error("Cannot read the log file.", 13);

# Return success:
exit 0;

__END__

=head1 NAME

blaze-log - display the BlazeBlogger repository log

=head1 SYNOPSIS

B<blaze-log> [B<-cqrsCV>] [B<-b> I<directory>] [B<-n> I<number>]

B<blaze-log> B<-h> | B<-v>

=head1 DESCRIPTION

B<blaze-log> displays the content of the BlazeBlogger repository log.

=head1 OPTIONS

=over

=item B<-b>, B<--blogdir> I<directory>

Specify the I<directory> where the BlazeBlogger repository is placed. The
default option is the current working directory.

=item B<-n>, B<--number> I<number>

List selected number of log records only.

=item B<-s>, B<--short>

Display each log record on a single line.

=item B<-r>, B<--reverse>

Display log records in reverse order.

=item B<-c>, B<--color>, B<--colour>

Enable coloured output, no matter what is set in the configuration.

=item B<-C>, B<--no-color>, B<--no-colour>

Disable coloured output, no matter what is set in the configuration.

=item B<-q>, B<--quiet>

Avoid displaying messages that are not necessary.

=item B<-V>, B<--verbose>

Display all messages. This is the default option.

=item B<-h>, B<--help>

Display usage information and exit.

=item B<-v>, B<--version>

Display version information and exit.

=back

=head1 FILES

=over

=item I<.blaze/log>

BlazeBlogger repository log file.

=back

=head1 SEE ALSO

B<blaze-config>(1), B<perl>(1).

=head1 BUGS

To report bug or even send patch, either add new issue to the project
bugtracker at <http://code.google.com/p/blazeblogger/issues/>, or visit
the discussion group at <http://groups.google.com/group/blazeblogger/>. You
can also contact the author directly via e-mail.

=head1 AUTHOR

Written by Jaromir Hradilek <jhradilek@gmail.com>.

Permission is granted to copy, distribute and/or modify this document under
the terms of the GNU Free Documentation License, Version 1.3 or any later
version published by the Free Software Foundation; with no Invariant
Sections, no Front-Cover Texts, and no Back-Cover Texts.

A copy of the license is included as a file called FDL in the main
directory of the BlazeBlogger source package.

=head1 COPYRIGHT

Copyright (C) 2009 Jaromir Hradilek

This program is free software; see the source for copying conditions. It is
distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.

=cut
