#!/usr/bin/env perl

# blaze-add, add a blog post or a page to the Blaze repository
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
use Config::IniHash;
use Getopt::Long;
use POSIX qw(strftime);

# General script information:
use constant NAME    => basename($0, '.pl');        # Script name.
use constant VERSION => '0.0.1';                    # Script version.

# General script settings:
our $type    = 'post';                              # Type: post or page.
our $file    = '';                                  # File to add.
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
Usage: $NAME [-pqP] [-d directory] [-f file]
       $NAME -h | -v

  -d, --destdir directory     specify the destination directory
  -f, --file file             specify the file to add
  -p, --page                  add the static page instead of the post
  -P, --post                  add the blog post; the default option
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

# Translate given date to YYYY-MM-DD string:
sub date_to_string {
  my @date = localtime(shift);
  return sprintf("%d-%02d-%02d", ($date[5] + 1900), ++$date[4], $date[3]);
}

# Return the first unused ID:
sub choose_id {
  my $head   = shift || die "Missing argument";
  my @used   = ();
  my $chosen = 1;

  # Open the heads directory:
  if (opendir(HEADS, $head)) {
    # Build a list of used IDs:
    @used = grep {! /^\.\.?$/ } readdir(HEADS);

    # Find a first unused ID:
    foreach my $id (sort {$a <=> $b} @used) {
      $chosen++ if ($chosen == $id);
    }

    # Close the directory:
    closedir(HEADS);
  }
  else {
    # Report failure:
    exit_with_error("Unable to access `$head' directory.", 13);
  }

  # Return the result:
  return $chosen;
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
  'file|f=s'      => sub { $file    = $_[1];  },
);

# Check missing options:
exit_with_error("Invalid option `$ARGV[0]'.", 22) if (scalar(@ARGV) != 0);

# Check the repository is present (however naive this method is):
exit_with_error("Not a Blaze repository! Try `blaze-init' first.", 1)
  unless (-d catdir($destdir, '.blaze'));

# Unless the file is supplied, create a new one:
unless ($file) {
  $file = catfile($destdir, '.blaze', 'temp');

  # Read the configuration file:
  my $temp = catfile($destdir, '.blaze', 'config');
  my $conf = ReadINI($temp)
             or exit_with_error("Unable to read `$temp'.", 13);

  # Prepare the data for the temporary file header:
  my $name = $conf->{user}->{name} || 'Replace this with your name';
  my $date = date_to_string(time);

  # Decide which editor to use:
  my $edit = $conf->{core}->{editor} || $ENV{EDITOR} || 'vi';

  # Write the temporary file:
  write_to_file($file, << "END_TEMP");
# This and following lines beginning with `#' are the $type header.  Please
# take your time and replace these options with desired values. Just remem-
# ber that the date has to be in an YYYY-MM-DD form and that  the tags is a
# comma separated list of categories the post (pages ignore these)  belong.
#
#   title:  Replace this with your $type title
#   author: $name
#   date:   $date
#   tags:
# 
# The header ends here. The rest is the content of your $type.

END_TEMP

  # Open the temporary file in the external editor:
  system($edit, $file) == 0 or exit_with_error("Unable to run `$edit'.",1);
}

# Open the temporary file for reading:
if (open(TEMP, "$file")) {
  my $header = {};
  my $line   = '';

  # Choose the first available ID:
  my $id   = choose_id(catdir($destdir, '.blaze', "${type}s", 'head'));

  # Prepare the file names:
  my $head = catfile($destdir, '.blaze', "${type}s", 'head', $id);
  my $body = catfile($destdir, '.blaze', "${type}s", 'body', $id);
  my $log  = catfile($destdir, '.blaze', 'log');

  # Process the header:
  while ($line = <TEMP>) {
    # Header ends with first line not beginning with `#':
    last unless $line =~ /^#/;

    # Parse header data:
    if ($line =~ / (title|author|date|tags):\s*(\S.*)$/) {
      $header->{'header'}->{$1} = $2;
    }
  }

  # Write the header:
  WriteINI($head, $header)
    or exit_with_error("Unable to write to `$head'.", 13);

  # Write the body:
  write_to_file($body, $line . do { local $/; <TEMP> });

  # Log the record addition:
  add_to_log($log, "Added the $type with ID $id.");

  # Report success:
  print "The $type has been successfully added with ID $id.\n" if $verbose;
}
else {
  # Report failure:
  exit_with_error("Unable to read `$file'.", 13);
}

# Return success:
exit 0;

__END__

=head1 NAME

blaze-add - add a blog post or a page to the Blaze repository

=head1 SYNOPSIS

B<blaze-add> [B<-pqP>] [B<-d> I<directory>] [B<-f> I<file>]

B<blaze-add> B<-h> | B<-v>

=head1 DESCRIPTION

B<blaze-add> adds new blog posts or static pages to the Blaze repository.
If supplied, it tries to read data from the existing I<file>, otherwise an
external editor is opened to let you create a new content.

=head1 OPTIONS

=over

=item B<-d>, B<--destdir> I<directory>

Use selected destination I<directory> instead of the default current
working one.

=item B<-f>, B<--file> I<file>

Add the I<file> instead of opening an external text editor.

=item B<-p>, B<--page>

Add the static page instead of the blog post.

=item B<-P>, B<--post>

Add the blog post; this is the default option.

=item B<-q>, B<--quiet>

Avoid displaying messages that are not necessary.

=item B<-h>, B<--help>

Display usage information and exit.

=item B<-v>, B<--version>

Display version information and exit.

=back

=head1 ENVIRONMENT

=over

=item B<EDITOR>

Unless the Blaze specific option I<core.editor> is set, blaze-edit tries to
use system wide settings to decide which editor to run. If neither of these
options are supplied, the B<vi> is used instead as a considerably
reasonable choice.

=back

=head1 FILES

=over

=item I<.blaze/config>

Blaze configuration file.

=back

=head1 SEE ALSO

B<blaze-config>(1), B<perl>(1).

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
