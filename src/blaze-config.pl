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
use Getopt::Long;
use Digest::MD5;

# General script information:
use constant NAME    => basename($0, '.pl');        # Script name.
use constant VERSION => '0.9.1';                    # Script version.

# General script settings:
our $blogdir = '.';                                 # Repository location.
our $verbose = 1;                                   # Verbosity level.

# List of valid options and their default values:
our %opt = (
  # Blog related settings:
  'blog.title'     => 'My Blog',                    # Blog title.
  'blog.subtitle'  => 'yet another blog',           # Blog subtitle.
  'blog.theme'     => 'default.html',               # Blog template file.
  'blog.style'     => 'default.css',                # Blog stylesheet file.
  'blog.lang'      => 'en_GB',                      # Blog language.
  'blog.posts'     => '10',                         # Posts to display.
  'blog.url'       => '',                           # Blog base URL.

  # Colour related settings:
  'color.list'     => 'false',                      # Coloured listing?
  'color.log'      => 'false',                      # Coloured log?

  # Core settings:
  'core.editor'    => 'vi',                         # External text editor.
  'core.encoding'  => 'UTF-8',                      # Posts/pages codepage.
  'core.extension' => 'html',                       # File extension.

  # Post related settings:
  'post.author'    => 'top',                        # Post author location.
  'post.date'      => 'top',                        # Post date location.
  'post.tags'      => 'top',                        # Post tags location.

  # User related settings:
  'user.name'      => 'admin',                      # User's name.
  'user.email'     => 'admin@localhost',            # User's e-mail.
);

# Command-line options:
my  $edit = 0;                                      # Edit config directly?

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

# Display given warning message:
sub display_warning {
  my $message = shift || 'An unspecified warning was requested.';

  print STDERR "$message\n";
  return 1;
}

# Display usage information:
sub display_help {
  my $NAME = NAME;

  # Print the message to the STDOUT:
  print << "END_HELP";
Usage: $NAME [-qV] [-b directory] name [value...]
       $NAME -e [-b directory]
       $NAME -h | -v

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

# Read data from the INI file:
sub read_ini {
  my $file    = shift || die 'Missing argument';
  my $hash    = {};
  my $section = 'default';

  # Open the file for reading:
  open(INI, "$file") or return 0;

  # Process each line:
  while (my $line = <INI>) {
    # Parse line:
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

# Write data to the INI file:
sub write_ini {
  my $file = shift || 'Missing argument';
  my $hash = shift || 'Missing argument';

  # Open the file for writing:
  open(INI, ">$file") or return 0;

  # Process each section:
  foreach my $section (sort(keys(%$hash))) {
    # Write the section header:
    print INI "[$section]\n";

    # Process each option in the section:
    foreach my $option (sort(keys(%{$hash->{$section}}))) {
      # Write the option and its value:
      print INI "  $option = $hash->{$section}->{$option}\n";
    }
  }

  # Close the file:
  close(INI);

  # Return success:
  return 1;
}

# Read the configuration file:
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
    display_warning("Unable to read configuration.");

    # Return empty configuration:
    return {};
  }
}

# Read configuration from the temporary file and save it:
sub write_conf {
  my $conf = shift || die 'Missing argument';

  # Prepare the file name:
  my $file = catfile($blogdir, '.blaze', 'config');

  # Save the configuration file:
  unless (write_ini($file, $conf)) {
    # Report failure:
    display_warning("Unable to write configuration.");

    # Return failure:
    return 0;
  }

  # Return success:
  return 1;
}

# Create a human readable version of configuration file:
sub create_temp {
  my $conf = shift || die 'Missing argument';
  my $file = shift || catfile($blogdir, '.blaze', 'temp');

  # Prepare the blog related settings:
  my $blog_title     = $conf->{blog}->{title}     || $opt{'blog.title'};
  my $blog_subtitle  = $conf->{blog}->{subtitle}  || $opt{'blog.subtitle'};
  my $blog_theme     = $conf->{blog}->{theme}     || $opt{'blog.theme'};
  my $blog_style     = $conf->{blog}->{style}     || $opt{'blog.style'};
  my $blog_lang      = $conf->{blog}->{lang}      || $opt{'blog.lang'};
  my $blog_posts     = $conf->{blog}->{posts}     || $opt{'blog.posts'};
  my $blog_url       = $conf->{blog}->{url}       || $opt{'blog.url'};

  # Prepare the colour related settings:
  my $color_list     = $conf->{color}->{list}     || $opt{'color.list'};
  my $color_log      = $conf->{color}->{log}      || $opt{'color.log'};

  # Prepare the core settings:
  my $core_editor    = $conf->{core}->{editor}    || $opt{'core.editor'};
  my $core_encoding  = $conf->{core}->{encoding}  || $opt{'core.encoding'};
  my $core_extension = $conf->{core}->{extension} || $opt{'core.extension'};

  # Prepare the post related settings:
  my $post_author    = $conf->{post}->{author}    || $opt{'post.author'};
  my $post_date      = $conf->{post}->{date}      || $opt{'post.date'};
  my $post_tags      = $conf->{post}->{tags}      || $opt{'post.tags'};

  # Prepare the user related settings:
  my $user_name      = $conf->{user}->{name}      || $opt{'user.name'};
  my $user_email     = $conf->{user}->{email}     || $opt{'user.email'};

  # Open the file for writing:
  if(open(FILE, ">$file")) {
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

## The following are the colour settings, affecting the way various outputs
## look. The options are as follows:
##
##   list - Whether to use coloured posts/pages listing;  the value  has to
##          be either true, or false.
##   log  - Whether to use coloured repository log listing;  the value  has
##          to be either true, or false.
##
[color]
list=$color_list
log=$color_log

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

## The following are the post related settings, making it possible to alter
## the look of a single post even further. The options are as follows:
##
##  author - Location of the author; available  options are top, bottom, or
##           none.
##  date   - Location of the date of publishing; available options are top,
##           bottom, or none.
##  tags   - Location of tags;  available options are top, bottom, or none.
##
[post]
author=$post_author
date=$post_date
tags=$post_tags

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
  else {
    # Report failure:
    display_warning("Unable to create temporary file.");

    # Return failure:
    return 0;
  }
}

# Edit the configuration file:
sub edit_options {
  my ($before, $after);

  # Prepare the temporary file name:
  my $temp = catfile($blogdir, '.blaze', 'temp');

  # Read the configuration file:
  my $conf = read_conf();

  # Make sure the configuration was successfully read:
  return 0 if (scalar(keys %$conf) == 0);

  # Decide which editor to use:
  my $edit = $conf->{core}->{editor} || $ENV{EDITOR} || 'vi';

  # Create the temporary file:
  create_temp($conf, $temp) or return 0;

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
  unless (system("$edit $temp") == 0) {
    # Report failure:
    display_warning("Unable to run `$edit'.");

    # Return failure:
    return 0;
  }

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
      # Report abortion:
      display_warning("File have not been changed: aborting.");

      # Return success:
      exit 0;
    }
  }

  # Read configuration from the temporary file:
  if ($conf = read_ini($temp)) {
    # Save the configuration file:
    write_conf($conf) or return 0;

    # Return success:
    return 1;
  }
  else {
    # Report failure:
    display_warning("Unable to read temporary file.");

    # Return failure:
    return 0;
  }
}

# Set the option:
sub set_option {
  my $option = shift || die 'Missing argument';
  my $value  = shift || die 'Missing argument';

  # Get the option pair:
  my ($section, $key) = split(/\./, $option);

  # Read the configuration file:
  my $conf = read_conf();

  # Make sure the configuration was successfully read:
  return 0 if (scalar(keys %$conf) == 0);

  # Set up the option:
  $conf->{$section}->{$key} = $value;

  # Save the configuration file:
  write_conf($conf) or return 0;

  # Return success:
  return 1;
}

# Display the option:
sub display_option {
  my $option = shift || die 'Missing argument';

  # Get the option pair:
  my ($section, $key) = split(/\./, $option);

  # Read the configuration file:
  my $conf = read_conf();

  # Make sure the configuration was successfully read:
  return 0 if (scalar(keys %$conf) == 0);

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
  edit_options() or exit_with_error("Cannot edit configuration.", 13);

  # Report success:
  print "Your changes have been successfully saved.\n" if $verbose;
}
else {
  # Check missing options:
  exit_with_error("Missing option.", 22) if (scalar(@ARGV) == 0);

  # Check whether the option is valid:
  exit_with_error("Invalid option `$ARGV[0]'.", 22)
    unless (exists $opt{$ARGV[0]});

  # Decide whether to set or display the option:
  if (scalar(@ARGV) > 1) {
    # Set the option:
    set_option(shift(@ARGV), join(' ', @ARGV))
      or exit_with_error("Cannot set the option.", 13);

    # Report success:
    print "The option has been successfully saved.\n" if $verbose;
  }
  else {
    # Display the option:
    display_option(shift(@ARGV))
      or exit_with_error("Cannot display the option.", 13);
  }
}

# Return success:
exit 0;

__END__

=head1 NAME

blaze-config - display or set the BlazeBlogger repository options

=head1 SYNOPSIS

B<blaze-config> [B<-qV>] [B<-b> I<directory>] I<name> [I<value...>]

B<blaze-config> B<-e> [B<-b> I<directory>]

B<blaze-config> B<-h> | B<-v>

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

=item B<color.list>

Whether to use coloured post/pages listing; the value has to be either
C<true>, or C<false>. Colours are turned off by default.

=item B<color.log>

Whether to use coloured log listing; the value has to be either C<true>, or
C<false>. Colours are turned off by default.

=item B<core.editor>

Text editor to be used for editing purposes.

=item B<core.encoding>

Records encoding in the form recognised by the W3C HTML 4.01 standard (e.g.
the default UTF-8).

=item B<core.extension>

File extension for the generated pages. By default, the C<html> is used as
a reasonable choice.

=item B<post.author>

Location of the post author information; available options are C<top>,
C<bottom>, or C<none>. Author is placed above the post (below its heading)
by default.

=item B<post.date>

Location of the post date of publishing information; available options are
C<top>, C<bottom>, or C<none>. Date of publishing is placed above the post
(below its heading) by default.

=item B<post.tags>

Location of the post tags; available options are C<top>, C<bottom>, or
C<none>. Tags are placed above the post (below its heading) by default.

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
