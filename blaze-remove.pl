#!/usr/bin/env perl

# blaze-remove, remove a blog post or a page from the Blaze repozitory
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
use Text::Wrap;
use File::Basename;
use File::Spec::Functions;
use Getopt::Long;
use POSIX qw(strftime);

# General script information:
use constant NAME    => basename($0, '.pl');        # Script name.
use constant VERSION => '0.0.1';                    # Script version.

# General script settings:
our $type    = 'post';                              # Type: post or page.
our $destdir = '.';                                 # Destination folder.
our $verbose = 1;                                   # Verbosity level.

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
Usage: $NAME [-pqP] [-d directory] id
       $NAME -h | -v

  -d, --destdir directory     specify the destination directory
  -p, --page                  remove the static page instead of the post
  -P, --post                  remove the blog post; the default option
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

# Add given string to the log file
sub add_to_log {
  my $file = shift || die "Missing argument";
  my $text = shift || '';

  # Try to open the log file:
  if (open(LOG, ">>$file")) {
    # Write to the log file: 
    print LOG "Date: ".strftime("%a %b %e %H:%M:%S %Y", localtime)."\n\n";
    print LOG wrap('    ', '    ', $text);
    print LOG "\n\n";

    # Close the file:
    close(LOG);
  }
  else {
    # Report failure and exit:
    exit_with_error("Unable to write to `$file'.", 13);
  }
}

# Set up the options parser:
Getopt::Long::Configure('no_auto_abbrev', 'no_ignore_case', 'bundling');

# Process command-line options:
GetOptions(
  'help|h'        => sub { display_help();    exit 0; },
  'version|v'     => sub { display_version(); exit 0; },
  'page|p'        => sub { $type    = 'page'; },
  'post|P'        => sub { $type    = 'post'; },
  'quiet|q'       => sub { $verbose = 0;      },
  'destdir|d=s'   => sub { $destdir = $_[1];  },
);

# Check missing options:
exit_with_error("Wrong number of options.", 22) if (scalar(@ARGV) != 1);

# Check the repository is present (however naive this method is):
exit_with_error("Not a Blaze repository! Try `blaze-init' first.", 1)
  unless (-d catdir($destdir, '.blaze'));

# Prepare the file names:
my $head = catfile($destdir, '.blaze', "${type}s", 'head', $ARGV[0]);
my $body = catfile($destdir, '.blaze', "${type}s", 'body', $ARGV[0]);
my $log  = catfile($destdir, '.blaze', 'log');

# Check whether the record exists:
unless (-e $head) {
  # Report failure:
  print "There is no $type with ID $ARGV[0].\n" if $verbose;

  # Return failure:
  exit 1; 
}

# Remove the files:
unlink($head) || exit_with_error("Unable to delete `$head'.", 13);
unlink($body) || exit_with_error("Unable to delete `$body'.", 13);

# Log the record deletion:
add_to_log($log, "Removed the $type with ID $ARGV[0].");

# Report success:
print "The $type has been successfully removed.\n" if $verbose;

# Return success:
exit 0;

__END__

=head1 NAME

blaze-remove - remove a blog post or a page from the Blaze repozitory

=head1 SYNOPSIS

B<blaze-remove> [B<-pqP>] [B<-d> I<directory>] I<id>

B<blaze-remove> B<-h> | B<-v>

=head1 DESCRIPTION

B<blaze-remove> deletes the blog post or static page with given I<id> from
the Blaze repository.

=head1 OPTIONS

=over

=item B<-d>, B<--destdir> I<directory>

Use selected destination I<directory> instead of the default current
working one.

=item B<-p>, B<--page>

Remove the static page instead of the blog post.

=item B<-P>, B<--post>

Remove the blog post; this is the default option.

=item B<-q>, B<--quiet>

Avoid displaying messages that are not necessary.

=item B<-h>, B<--help>

Display usage information and exit.

=item B<-v>, B<--version>

Display version information and exit.

=back

=head1 SEE ALSO

B<perl>(1).

=head1 AUTHOR

Written by Jaromir Hradilek <jhradilek@gmail.com>.

Permission is granted to copy, distribute and/or modify this document under
the terms of the GNU Free Documentation License, Version 1.3 or any later
version published by the Free Software Foundation; with no Invariant
Sections, no Front-Cover Texts, and no Back-Cover Texts.

A copy of the license is included as a file called FDL in the main
directory of the blaze source package.

=head1 COPYRIGHT

Copyright (C) 2008, 2009 Jaromir Hradilek

This program is free software; see the source for copying conditions. It is
distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.

=cut
