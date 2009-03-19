#!/usr/bin/env perl

# blaze-config, display or set the BlazeBlogger repository options
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
use Digest::MD5;

# General script information:
use constant NAME    => basename($0, '.pl');        # Script name.
use constant VERSION => '0.8.0-rc2';                # Script version.

# General script settings:
our $blogdir = '.';                                 # Repository location.
our $verbose = 1;                                   # Verbosity level.

# Command-line options:
my  $edit = 0;                                      # Edit config directly?

# List of valid options:
our %options = (
  # Blog related settings:
  'blog.title'     => "Blog title.",
  'blog.subtitle'  => "Blog subtitle.",
  'blog.theme'     => "Blog theme.",
  'blog.style'     => "Blog stylesheet.",
  'blog.lang'      => "Blog language.",
  'blog.posts'     => "Number of posts to be listed on a single page.",
  'blog.url'       => "Blog base url.",

  # Core settings:
  'core.editor'    => "Text editor to be used for editing purposes.",
  'core.encoding'  => "File encoding in a form recognized by HTML 4.01.",
  'core.extension' => "File extension for the generated pages.",

  # User related settings:
  'user.name'      => "User's name to be used as a default posts' author.",
  'user.email'     => "User's e-mail.",
);

# Set up the __WARN__ signal handler:
$SIG{__WARN__} = sub {
  print STDERR NAME . ": " . (shift);
};

# Display given message and terminate the script:
sub exit_with_error {
  my $message      = shift || 'An unspecified error has occurred.';
  my $return_value = shift || 1;

  print STDERR NAME . ": $message\n";
  exit $return_value;
}

# Display usage information:
sub display_help {
  my $NAME = NAME;

  # Print the message to the STDOUT:
  print << "END_HELP";
Usage: $NAME [-qV] [-b directory] name [value...]
       $NAME -e | -h | -v

  -b, --blogdir directory     specify the directory where the BlazeBlogger
                              repository is placed
  -e, --edit                  open the config file in the text editor
  -q, --quiet                 avoid displaying unnecessary messages
  -V, --verbose               display all messages; the default option
  -h, --help                  display this help and exit
  -v, --version               display version information and exit
END_HELP

  # Return success:
  return 1;
}

# Display version information:
sub display_version {
  my ($NAME, $VERSION) = (NAME, VERSION);

  # Print the message to the STDOUT:
  print << "END_VERSION";
$NAME $VERSION

Copyright (C) 2008, 2009 Jaromir Hradilek
This program is free software; see the source for copying conditions. It is
distributed in the hope  that it will be useful,  but WITHOUT ANY WARRANTY;
without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PAR-
TICULAR PURPOSE.
END_VERSION

  # Return success:
  return 1;
}

# Create a human readable version of configuration file:
sub read_config {
  my $file = shift || die 'Missing argument';
  my $conf = shift || die 'Missing argument';

  # Prepare the blog related settings:
  my $blog_title     = $conf->{blog}->{title}     || 'My Blog';
  my $blog_subtitle  = $conf->{blog}->{subtitle}  || 'yet another blog';
  my $blog_theme     = $conf->{blog}->{theme}     || 'default.html';
  my $blog_style     = $conf->{blog}->{style}     || 'default.css';
  my $blog_lang      = $conf->{blog}->{lang}      || 'en_GB';
  my $blog_posts     = $conf->{blog}->{posts}     || '10';
  my $blog_url       = $conf->{blog}->{url}       || '';

  # Prepare the core settings:
  my $core_editor    = $conf->{core}->{editor}    || 'vi';
  my $core_encoding  = $conf->{core}->{encoding}  || 'UTF-8';
  my $core_extension = $conf->{core}->{extension} || 'html';

  # Prepare the user related settings:
  my $user_name      = $conf->{user}->{name}      || 'admin';
  my $user_email     = $conf->{user}->{email}     || 'admin@localhost';

  # Open the file for writing:
  open(FILE, ">$file") or return 0;

  # Write to the temporary file:
  print FILE << "END_TEMP";
## The following are the blog related settings, having the direct influence
## on the way the whole thing looks. The options are as follows:
##
##   title    - The blog title.
##   subtitle - The blog subtitle, supposedly a brief, single-line descrip-
##              tion of what should the occasional visitor  expect to find.
##   theme    - The blog theme;  the value should point to an existing file
##              in the .blaze/theme directory.
##   style    - The blog style; the value should point to an existing file,
##              either  in  .blaze/style,  or in the  destination directory
##              where the static content is to be placed.
##   lang     - The blog language;  the value  should point to an  existing
##              file in the .blaze/lang directory.
##   posts    - Number of posts to be listed on a single page;  the default
##              value is 10.
##   url      - The blog base url; required for RSS feed only.
##
[blog]
title=$blog_title
subtitle=$blog_subtitle
theme=$blog_theme
style=$blog_style
lang=$blog_lang
posts=$blog_posts
url=$blog_url

## The following are the core settings,  affecting the way the BlazeBlogger
## works. The options are as follows:
##
##   editor    - An external text editor to be used for editing purposes.
##   encoding  - Records  encoding in the form  recognised by the  W3C HTML
##               4.01 standard (e.g. the default UTF-8).
##   extension - File extension for the generated pages.
##
[core]
editor=$core_editor
encoding=$core_encoding
extension=$core_extension

## The following are the user related settings. The options are as follows:
##
##   user  - User's name  to be used as a default posts' author  and in the
##           copyright notice.
##   email - User's e-mail.
##
[user]
name=$user_name
email=$user_email
END_TEMP

  # Close the file:
  close(FILE);

  # Return success:
  return 1;
}

# Read configuration from the temporary file and save it:
sub save_config {
  my $temp = shift || die 'Missing argument';
  my $file = shift || die 'Missing argument';

  # Read the temporary file:
  my $conf = ReadINI($temp) or return 0;

  # Save the configuration file:
  WriteINI($file, $conf) or return 0;

  # Return success:
  return 1;
}

# Edit the configuration file:
sub edit_config {
  my ($before, $after);

  # Prepare the temporary file name:
  my $temp = catfile($blogdir, '.blaze', 'temp');

  # Read the configuration file:
  my $file = catfile($blogdir, '.blaze', 'config');
  my $conf = ReadINI($file) or return 0;

  # Decide which editor to use:
  my $edit = $conf->{core}->{editor} || $ENV{EDITOR} || 'vi';

  # Create the temporary file:
  read_config($temp, $conf)
    or exit_with_error("Unable to create the temporary file.", 13);

  # Open the file for reading:
  if (open(FILE, "$temp")) {
    # Set the IO handler to binmode:
    binmode(FILE);

    # Count checksum:
    $before = Digest::MD5->new->addfile(*FILE)->hexdigest;

    # Close the file:
    close(FILE);
  }

  # Open the temporary file in the external editor:
  system($edit, $temp) == 0 or exit_with_error("Unable to run `$edit'.",1);

  # Open the file for reading:
  if (open(FILE, "$temp")) {
    # Set the IO handler to binmode:
    binmode(FILE);

    # Count checksum:
    $after = Digest::MD5->new->addfile(*FILE)->hexdigest;

    # Close the file:
    close(FILE);

    # Compare the checksum:
    if ($before eq $after) {
      # Report aborting:
      print STDERR "File have not been changed: aborting.\n";

      # Return failure:
      return 0;
    }
  }

  # Save the configuration file:
  save_config($temp, $file)
    or exit_with_error("Ubable to save the configuration file.", 13);

  # Return success:
  return 1;
}

# Set the option:
sub set_option {
  my $option = shift || die 'Missing argument';
  my $value  = shift || die 'Missing argument';

  # Get the option pair:
  my ($section, $key) = split(/\./, $option);

  # Read the configuration file:
  my $file = catfile($blogdir, '.blaze', 'config');
  my $conf = ReadINI($file)
             or print STDERR "Unable to read configuration.\n";

  # Set up the option:
  $conf->{$section}->{$key} = $value;

  # Save the configuration file:
  WriteINI($file, $conf) or return 0;

  # Return success:
  return 1;
}

# Display the option:
sub display_option {
  my $option = shift || die 'Missing argument';

  # Get the option pair:
  my ($section, $key) = split(/\./, $option);

  # Read the configuration file:
  my $file = catfile($blogdir, '.blaze', 'config');
  my $conf = ReadINI($file) or return 0;

  # Check whether the option is set:
  if (my $value = $conf->{$section}->{$key}) {
    # Display the value:
    print "$value\n";
  }

  # Return success:
  return 1;
}

# Set up the options parser:
Getopt::Long::Configure('no_auto_abbrev', 'no_ignore_case', 'bundling');

# Process command-line options:
GetOptions(
  'help|h'        => sub { display_help();    exit 0; },
  'version|v'     => sub { display_version(); exit 0; },
  'edit|e'        => sub { $edit    = 1;     },
  'quiet|q'       => sub { $verbose = 0;     },
  'verbose|V'     => sub { $verbose = 1;     },
  'blogdir|b=s'   => sub { $blogdir = $_[1]; },
);

# Check the repository is present (however naive this method is):
exit_with_error("Not a BlazeBlogger repository! Try `blaze-init' first.",1)
  unless (-d catdir($blogdir, '.blaze'));

# Decide which action to perform:
if ($edit) {
  # Check superfluous options:
  exit_with_error("Wrong number of options.", 22) if (scalar(@ARGV) != 0);

  # Edit the configuration file:
  edit_config() or exit 1;

  # Report success:
  print "Your changes have been successfully saved.\n" if $verbose;
}
else {
  # Check missing options:
  exit_with_error("Missing option.", 22) if (scalar(@ARGV) == 0);

  # Check whether the option is valid:
  exit_with_error("Invalid option `$ARGV[0]'.", 22)
    unless (exists $options{$ARGV[0]});

  # Decide whether to set or display the option:
  if (scalar(@ARGV) > 1) {
    # Set the option:
    set_option(shift(@ARGV), join(' ', @ARGV))
      or exit_with_error("Unable to save the configuration.", 13);

    # Report success:
    print "The option has been successfully saved.\n" if $verbose;
  }
  else {
    # Display the option:
    display_option(shift(@ARGV))
      or exit_with_error("Unable to read the configuration.", 13);
  }
}

# Return success:
exit 0;

__END__

=head1 NAME

blaze-config - display or set the BlazeBlogger repository options

=head1 SYNOPSIS

B<blaze-config> [B<-qV>] [B<-b> I<directory>] I<name> [I<value...>]

B<blaze-config> B<-e> | B<-h> | B<-v>

=head1 DESCRIPTION

B<blaze-config> is a simple configuration tool for the BlazeBlogger.
Depending on the number of given command-line arguments, it either displays
the current value of the specified option, or sets/replaces it with the new
one.

The accepted option I<name> is in the form of dot separated section and key
(e.g. user.name). For the complete list of available options along with the
explanation of their meaning, see the appropriate section below.

=head1 OPTIONS

=head2 Command-line options

=over

=item B<-b>, B<--blogdir> I<directory>

Specify the I<directory> where the BlazeBlogger repository is placed. The
default option is the current working directory.

=item B<-e>, B<--edit>

Open the configuration file in the external text editor.

=item B<-q>, B<--quiet>

Avoid displaying messages that are not necessary.

=item B<-V>, B<--verbose>

Display all messages. This is the default option.

=item B<-h>, B<--help>

Display usage information and exit.

=item B<-v>, B<--version>

Display version information and exit.

=back

=head2 Available option names

=over

=item B<blog.title>

Blog title.

=item B<blog.subtitle>

Blog subtitle, supposedly a brief, single-line description of what should
an occasional visitor expect to find.

=item B<blog.theme>

Blog theme; the value should point to an existing file in the .blaze/theme
directory.

=item B<blog.style>

Blog stylesheet; the value should point to an existing file, either in
C<.blaze/style> (recommended), or in the destination directory where the
static content is to be placed.

=item B<blog.lang>

Blog language; the value should point to an existing file in the
C<.blaze/lang> directory.

=item B<blog.posts>

Number of posts to be listed on a single page; the default value is 10.

=item B<blog.url>

Blog base url; required for RSS feeds only.

=item B<core.editor>

Text editor to be used for editing purposes.

=item B<core.encoding>

Records encoding in the form recognised by the W3C HTML 4.01 standard (e.g.
the default UTF-8).

=item B<core.extension>

File extension for the generated pages. By default, the C<html> is used as
a reasonable choice.

=item B<user.name>

User's name to be used as a default posts' author and optionally anywhere
on the page, depending on the theme (e.g. in the copyright notice).

=item B<user.email>

User's e-mail. Depending on the theme, it can be used anywhere on the page
(e.g. in the copyright notice). However, non of the official themes
actually use it.

=back

=head1 ENVIRONMENT

=over

=item B<EDITOR>

Unless the BlazeBlogger specific option I<core.editor> is set, blaze-edit
tries to use system wide settings to decide which editor to run. If neither
of these options are supplied, the B<vi> is used instead as a considerably
reasonable choice.

=back

=head1 FILES

=over

=item I<.blaze/config>

BlazeBlogger configuration file.

=back

=head1 SEE ALSO

B<perl>(1).

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

Copyright (C) 2008, 2009 Jaromir Hradilek

This program is free software; see the source for copying conditions. It is
distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.

=cut
