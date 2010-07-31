#!/usr/bin/env perl

# blaze-config - displays or sets BlazeBlogger configuration options
# Copyright (C) 2008, 2009, 2010 Jaromir Hradilek

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
use constant VERSION => '1.0.0';                    # Script version.

# General script settings:
our $blogdir = '.';                                 # Repository location.
our $editor  = '';                                  # Editor to use.
our $verbose = 1;                                   # Verbosity level.

# A list of valid options, and their default values:
our %opt = (
  # Blog related settings:
  'blog.title'       => 'My Blog',                  # Blog title.
  'blog.subtitle'    => 'yet another blog',         # Blog subtitle.
  'blog.theme'       => 'default.html',             # Blog theme.
  'blog.style'       => 'default.css',              # Blog style sheet.
  'blog.lang'        => 'en_US',                    # Blog localization.
  'blog.posts'       => '10',                       # Number of posts.

  # Colour related settings:
  'color.list'       => 'false',                    # Colored listing?
  'color.log'        => 'false',                    # Colored log?

  # Core settings:
  'core.encoding'    => 'UTF-8',                    # Character encoding.
  'core.extension'   => 'html',                     # File extension.
  'core.doctype'     => 'html',                     # Document type.
  'core.editor'      => '',                         # External text editor.
  'core.processor'   => '',                         # External processor.

  # Feed related settings:
  'feed.baseurl'     => '',                         # Base URL.
  'feed.posts'       => '10',                       # Number of posts.
  'feed.fullposts'   => 'false',                    # List full posts?

  # Post related settings:
  'post.author'      => 'top',                      # Post author location.
  'post.date'        => 'top',                      # Post date location.
  'post.tags'        => 'top',                      # Post tags location.

  # User related settings:
  'user.name'        => 'admin',                    # User's name.
  'user.nickname'    => '',                         # User's nickname.
  'user.email'       => 'admin@localhost',          # User's email.
);

# Command line options:
my  $edit = 0;                                      # Open in text editor?

# Set up the __WARN__ signal handler:
$SIG{__WARN__} = sub {
  print STDERR NAME . ": " . (shift);
};

# Display an error message, and terminate the script:
sub exit_with_error {
  my $message      = shift || 'An error has occurred.';
  my $return_value = shift || 1;

  # Display the error message:
  print STDERR NAME . ": $message\n";

  # Terminate the script:
  exit $return_value;
}

# Display a warning message:
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
Usage: $NAME [-qV] [-b DIRECTORY] [-E EDITOR] OPTION [VALUE...]
       $NAME -e [-b DIRECTORY]
       $NAME -h|-v

  -b, --blogdir DIRECTORY     specify a directory in which the BlazeBlogger
                              repository is placed
  -E, --editor EDITOR         specify an external text editor
  -e, --edit                  edit the configuration in a text editor
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

Copyright (C) 2008, 2009, 2010 Jaromir Hradilek
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
      # Add the option to the hash:
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
    # Write the section header to the file:
    print INI "[$section]\n";

    # Process each option in the section:
    foreach my $option (sort(keys(%{$hash->{$section}}))) {
      # Write the option and its value to the file:
      print INI "  $option = $hash->{$section}->{$option}\n";
    }
  }

  # Close the file:
  close(INI);

  # Return success:
  return 1;
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

# Read configuration from the temporary file, and save it:
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

# Create a human readable version of the configuration file:
sub create_temp {
  my $conf = shift || die 'Missing argument';
  my $file = shift || catfile($blogdir, '.blaze', 'temp');

  # Prepare the general blog settings:
  my $blog_title     = $conf->{blog}->{title}     || $opt{'blog.title'};
  my $blog_subtitle  = $conf->{blog}->{subtitle}  || $opt{'blog.subtitle'};
  my $blog_theme     = $conf->{blog}->{theme}     || $opt{'blog.theme'};
  my $blog_style     = $conf->{blog}->{style}     || $opt{'blog.style'};
  my $blog_lang      = $conf->{blog}->{lang}      || $opt{'blog.lang'};
  my $blog_posts     = $conf->{blog}->{posts}     || $opt{'blog.posts'};

  # Prepare the color settings:
  my $color_list     = $conf->{color}->{list}     || $opt{'color.list'};
  my $color_log      = $conf->{color}->{log}      || $opt{'color.log'};

  # Prepare the advanced BlazeBlogger settings:
  my $core_doctype   = $conf->{core}->{doctype}   || $opt{'core.doctype'};
  my $core_editor    = $conf->{core}->{editor}    || $opt{'core.editor'};
  my $core_encoding  = $conf->{core}->{encoding}  || $opt{'core.encoding'};
  my $core_extension = $conf->{core}->{extension} || $opt{'core.extension'};
  my $core_processor = $conf->{core}->{processor} || $opt{'core.processor'};

  # Prepare the RSS feed settings:
  my $feed_baseurl   = $conf->{feed}->{baseurl}   || $opt{'feed.baseurl'};
  my $feed_posts     = $conf->{feed}->{posts}     || $opt{'feed.posts'};
  my $feed_fullposts = $conf->{feed}->{fullposts} || $opt{'feed.fullposts'};

  # Prepare the advanced post settings:
  my $post_author    = $conf->{post}->{author}    || $opt{'post.author'};
  my $post_date      = $conf->{post}->{date}      || $opt{'post.date'};
  my $post_tags      = $conf->{post}->{tags}      || $opt{'post.tags'};

  # Prepare the user settings:
  my $user_name      = $conf->{user}->{name}      || $opt{'user.name'};
  my $user_nickname  = $conf->{user}->{nickname}  || $opt{'user.nickname'};
  my $user_email     = $conf->{user}->{email}     || $opt{'user.email'};

  # Handle the deprecated settings. This is for backward compatibility
  # reasons only, and to be removed in the near future:
  if ((defined $conf->{blog}->{url}) && (not $feed_baseurl)) {
    # Assign the value to the proper option:
    $feed_baseurl    = $conf->{blog}->{url};
  }

  # Open the temporary file for writing:
  if(open(FILE, ">$file")) {
    # Write the configuration to the file:
    print FILE << "END_TEMP";
## General blog settings. Available options are:
##
##   title         A title of your blog.
##   subtitle      A subtitle of your blog.
##   theme         A theme for your blog. It must point to an existing file
##                 in the .blaze/theme/ directory.
##   style         A style sheet for your blog.  It must point to  an exis-
##                 ting file in the .blaze/style/ directory.
##   lang          A translation of your blog. It must point to an existing
##                 file in the .blaze/lang/ directory.
##   posts         A number of blog posts to be listed on a single page.
##
[blog]
title=$blog_title
subtitle=$blog_subtitle
theme=$blog_theme
style=$blog_style
lang=$blog_lang
posts=$blog_posts

## Color settings. Available options are:
##
##   list          A boolean  to enable (true) or disable (false) colors in
##                 the blaze-list output.
##   log           A boolean  to enable (true) or disable (false) colors in
##                 the blaze-log output.
##
[color]
list=$color_list
log=$color_log

## Advanced BlazeBlogger settings. Available options are:
##
##   doctype       A document type.  It can be  either  html  for HTML,  or
##                 xhtml for the XHTML standard.
##   extension     A file extension.
##   encoding      A character encoding. It has to be in a form that is re-
##                 cognized by W3C standards.
##   editor        An external  text  editor.  When  supplied, this  option
##                 overrides the system-wide settings.
##   processor     An external application  to be used to process newly ad-
##                 ded or edited blog posts and pages. You must supply %in%
##                 and %out% in place of an input and output file name res-
##                 pectively.
##
[core]
doctype=$core_doctype
extension=$core_extension
encoding=$core_encoding
editor=$core_editor
processor=$core_processor

## RSS feed settings. Available options are:
##
##  baseurl        A URL of your blog, for example "http://example.com/".
##  posts          A number of blog posts to be listed in the feed.
##  fullposts      A boolean to enable (true)  or disable (false) inclusion
##                 of the whole content of a blog post in the feed.
##
[feed]
baseurl=$feed_baseurl
posts=$feed_posts
fullposts=$feed_fullposts

## Advanced post settings. Available options are:
##
##  author         A location of a blog post author name.  It can either be
##                 placed above the post (top),  below it (bottom),  or no-
##                 where on the page (none).
##  date           A location  of a date  of publishing.  It can  either be
##                 placed above the post (top),  below it (bottom),  or no-
##                 where on the page (none).
##  tags           A location of post tags. They can either be placed above
##                 the post (top),  below it (bottom),  or  nowhere  on the
##                 page (none).
##
[post]
author=$post_author
date=$post_date
tags=$post_tags

## User settings. Available options are:
##
##   name          Your full name to be used in the copyright notice,  and
##                 as the default post author.
##   nickname      Your nickname  to be used  as the  default  post author.
##                 When supplied, this option overrides the  above setting.
##   email         Your email address.
##
[user]
name=$user_name
nickname=$user_nickname
email=$user_email

END_TEMP

    # Close the file:
    close(FILE);

    # Return success:
    return 1;
  }
  else {
    # Report failure:
    display_warning("Unable to create the temporary file.");

    # Return failure:
    return 0;
  }
}

# Edit the configuration file in a text editor:
sub edit_options {
  # Initialize required variables:
  my ($before, $after);

  # Prepare the temporary file name:
  my $temp = catfile($blogdir, '.blaze', 'temp');

  # Read the configuration file:
  my $conf = read_conf();

  # Make sure the configuration was read successfully:
  return 0 if (scalar(keys %$conf) == 0);

  # Decide which editor to use:
  my $edit = $editor || $conf->{core}->{editor} || $ENV{EDITOR} || 'vi';

  # Create the temporary file:
  create_temp($conf, $temp) or return 0;

  # Open the file for reading:
  if (open(FILE, "$temp")) {
    # Set the input/output handler to "binmode":
    binmode(FILE);

    # Count the checksum:
    $before = Digest::MD5->new->addfile(*FILE)->hexdigest;

    # Close the file:
    close(FILE);
  }

  # Open the temporary file in the text editor:
  unless (system("$edit $temp") == 0) {
    # Report failure:
    display_warning("Unable to run `$edit'.");

    # Remove the temporary file:
    unlink $temp;

    # Return failure:
    return 0;
  }

  # Open the file for reading:
  if (open(FILE, "$temp")) {
    # Set the input/output handler to "binmode":
    binmode(FILE);

    # Count the checksum:
    $after = Digest::MD5->new->addfile(*FILE)->hexdigest;

    # Close the file:
    close(FILE);

    # Compare the checksums:
    if ($before eq $after) {
      # Report the abortion:
      display_warning("File has not been changed: aborting.");

      # Remove the temporary file:
      unlink $temp;

      # Return success:
      exit 0;
    }
  }

  # Read the configuration from the temporary file:
  if ($conf = read_ini($temp)) {
    # Save the configuration file:
    write_conf($conf) or return 0;

    # Remove the temporary file:
    unlink $temp;

    # Return success:
    return 1;
  }
  else {
    # Report failure:
    display_warning("Unable to read the temporary file.");

    # Remove the temporary file:
    unlink $temp;

    # Return failure:
    return 0;
  }
}

# Set a configuration option:
sub set_option {
  my $option = shift || die 'Missing argument';
  my $value  = shift;

  # Make sure the value is supplied, but accept empty strings and zero:
  die 'Missing argument' unless defined $value;

  # Get the option pair:
  my ($section, $key) = split(/\./, $option);

  # Read the configuration file:
  my $conf = read_conf();

  # Make sure the configuration was read successfully:
  return 0 if (scalar(keys %$conf) == 0);

  # Set up the option:
  $conf->{$section}->{$key} = $value;

  # Handle deprecated settings. This is for backward compatibility reasons
  # only, and to be removed in the near future:
  if (defined $conf->{blog}->{url}) {
    # Check whether the current option is the affected one:
    if ($option ne 'feed.baseurl') {
      # Assign the value to the proper option:
      $conf->{feed}->{baseurl} = $conf->{blog}->{url};
    }

    # Remove the deprecated option from the configuration:
    delete $conf->{blog}->{url};
  }

  # Save the configuration file:
  write_conf($conf) or return 0;

  # Return success:
  return 1;
}

# Display an option:
sub display_option {
  my $option = shift || die 'Missing argument';

  # Get the option pair:
  my ($section, $key) = split(/\./, $option);

  # Read the configuration file:
  my $conf = read_conf();

  # Make sure the configuration was read successfully:
  return 0 if (scalar(keys %$conf) == 0);

  # Check whether the option is set:
  if (my $value = $conf->{$section}->{$key}) {
    # Display the value:
    print "$value\n";
  }
  else {
    # Display the default value:
    print $opt{"$section.$key"}, "\n";
  }

  # Return success:
  return 1;
}

# Set up the option parser:
Getopt::Long::Configure('no_auto_abbrev', 'no_ignore_case', 'bundling');

# Process command line options:
GetOptions(
  'help|h'        => sub { display_help();    exit 0; },
  'version|v'     => sub { display_version(); exit 0; },
  'edit|e'        => sub { $edit    = 1;     },
  'quiet|q'       => sub { $verbose = 0;     },
  'verbose|V'     => sub { $verbose = 1;     },
  'blogdir|b=s'   => sub { $blogdir = $_[1]; },
  'editor|E=s'    => sub { $editor  = $_[1]; },
);

# Check whether the repository is present, no matter how naive this method
# actually is:
exit_with_error("Not a BlazeBlogger repository! Try `blaze-init' first.",1)
  unless (-d catdir($blogdir, '.blaze'));

# Decide which action to perform:
if ($edit) {
  # Check superfluous options:
  exit_with_error("Wrong number of options.", 22) if (scalar(@ARGV) != 0);

  # Edit the configuration file:
  edit_options() or exit_with_error("Cannot edit the configuration.", 13);

  # Report success:
  print "Your changes have been saved successfully.\n" if $verbose;
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
    print "The option has been saved successfully.\n" if $verbose;
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

B<blaze-config> [B<-qV>] [B<-b> I<directory>] [B<-E> I<editor>] I<name>
[I<value...>]

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

=head2 Command-line Options

=over

=item B<-b>, B<--blogdir> I<directory>

Specify the I<directory> where the BlazeBlogger repository is placed. The
default option is the current working directory.

=item B<-E>, B<--editor> I<editor>

Specify the external text I<editor> to be used for editing purposes. By
default, the C<core.editor> configuration option is used, and unless it is
set, BlazeBlogger tries to use the system wide settings by looking for the
C<EDITOR> environment variable. If neither of these options is supplied,
then C<vi> is used as a considerably reasonable option.

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

=head2 Available Option Names

=over

=item B<blog.title>

Blog title.

=item B<blog.subtitle>

Blog subtitle, supposedly a brief, single-line description of what should
an occasional visitor expect to find.

=item B<blog.theme>

Blog theme; the value should point to an existing file in the
C<.blaze/theme> directory.

=item B<blog.style>

Blog stylesheet; the value should point to an existing file, either in
C<.blaze/style> (recommended), or in the destination directory where the
static content is to be placed.

=item B<blog.lang>

Blog language; the value should point to an existing file in the
C<.blaze/lang> directory.

=item B<blog.posts>

Number of posts to be listed on a single page; the default value is C<10>.

=item B<color.list>

Whether to use coloured post/pages listing; the value has to be either
C<true>, or C<false>. Colours are turned off by default.

=item B<color.log>

Whether to use coloured log listing; the value has to be either C<true>, or
C<false>. Colours are turned off by default.

=item B<core.doctype>

The document type; the value has to be either C<html>, or C<xhtml>. By
default, C<html> is used as a reasonable choice.

=item B<core.extension>

File extension for the generated pages. By default, C<html> is used as a
reasonable choice.

=item B<core.encoding>

Records encoding in the form recognised by the W3C (e.g., the default
C<UTF-8>).

=item B<core.editor>

Text editor to be used for editing purposes. Unless this option is set,
BlazeBlogger tries to use system wide settings by looking for C<EDITOR>
environment variable, and if neither of these options is supplied, C<vi> is
used as a considerably reasonable option.

=item B<core.processor>

Optional external application to be used to process the entries; use
C<%in%> and C<%out%> in place of input and output file names (e.g.
C<< markdown --html4tags %in% > %out% >>). Nevertheless, if you intend to
write your content in HTML directly, feel free to leave this option empty
(the default setting).

=item B<feed.baseurl>

The blog base URL (e.g. C<http://blog.example.com>).

=item B<feed.posts>

Number of posts to be listed in the feed; the default value is C<10>.

=item B<feed.fullposts>

Whether to list full posts or just excerpts; the value has to be either
C<true>, or C<false>. Full posts are turned off by default.

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

User's name; this is typically used in the copyright notice, but depending
on the theme, it can be shown anywhere on the page. Also, the value of this
option is used as the default post author when the C<user.nickname> is left
empty.

=item B<user.nickname>

User's nickname; to be used as the default post author. Unless this option
is set, the value of C<user.name> is used by default.

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

Copyright (C) 2008, 2009, 2010 Jaromir Hradilek

This program is free software; see the source for copying conditions. It is
distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.

=cut
