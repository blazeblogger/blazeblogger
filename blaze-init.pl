#!/usr/bin/env perl

# blaze-init, create or recover a Blaze repository
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
Usage: $NAME [-q] [-d directory]
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

# Create given directories:
sub make_directories {
  my $dirs = shift || die "Missing argument";
  my $mask = shift || 0777;

  # Process each directory:
  foreach my $dir (sort @$dirs) {
    # Skip existing directories:
    unless (-d $dir) {
      # Create the directory:
      mkdir($dir, $mask) || exit_with_error("Creating `$dir': $!", 13);
    }
  }
}

# Write string to the given file:
sub write_to_file {
  my $file = shift || die "Missing argument";
  my $text = shift || '';

  # Try to open the file for writing:
  if (open(FOUT, ">$file")) {
    # Write given string:
    print FOUT $text;

    # Close the file:
    close(FOUT);
  }
  else {
    # Report failure and exit:
    exit_with_error("Unable to write to `$file'.", 13);
  }
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
  'quiet|q'       => sub { $verbose = 0;     },
  'destdir|d=s'   => sub { $destdir = $_[1]; },
);

# Create the directory tree:
make_directories [
  catdir($destdir, '.blaze'),                       # Root directory.
  catdir($destdir, '.blaze', 'theme'),              # Templates.
  catdir($destdir, '.blaze', 'style'),              # Stylesheets.
  catdir($destdir, '.blaze', 'pages'),              # Static pages.
  catdir($destdir, '.blaze', 'pages', 'head'),      # Pages' headers.
  catdir($destdir, '.blaze', 'pages', 'body'),      # Pages' bodies.
  catdir($destdir, '.blaze', 'posts'),              # Blog posts.
  catdir($destdir, '.blaze', 'posts', 'head'),      # Posts' headers.
  catdir($destdir, '.blaze', 'posts', 'body'),      # Posts' bodies.
];

# Create the default configuration file:
write_to_file(catfile($destdir, '.blaze', 'config'), << "END_CONFIG");
;TODO: Write configuration file template.
END_CONFIG

# Create the default theme file:
write_to_file(catfile($destdir, '.blaze', 'theme', 'default.html'),
              << "END_THEME");
TODO: Write default theme.
END_THEME

# Create the default stylesheet:
write_to_file(catfile($destdir, '.blaze', 'style', 'default.css'),
              << "END_STYLE");
TODO: Write default stylesheet.
END_STYLE

# Get the log file name:
my $logfile = catfile($destdir, '.blaze', 'log');

# Write to / create the log file:
unless (-r $logfile) {
  # Create the new log file:
  add_to_log($logfile, "Created an empty Blaze repository.");
}
else {
  # Log the repository recovery:
  add_to_log($logfile, "Recovered the Blaze repository.");
}

# Report success:
print "Created/recovered a Blaze repository in " .
      catdir($destdir, '.blaze') . ".\n" if $verbose;

# Return success:
exit 0;

__END__

=head1 NAME

blaze-init - create or recover a Blaze repository

=head1 SYNOPSIS

B<blaze-init> [B<-q>] [B<-d> I<directory>]

B<blaze-init> B<-h> | B<-v>

=head1 DESCRIPTION

B<blaze-init>'s job is either to create a fresh new Blaze repository, or to
recover an existing one, changing the configuration and template files back
to their original state while leaving the user data (i.e. both static pages
and blog posts) untouched.

=head1 OPTIONS

=over

=item B<-d>, B<--destdir> I<directory>

Use selected destination I<directory> instead of the default current
working one.

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
