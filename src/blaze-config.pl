#!/usr/bin/env perl

# blaze-config - displays or sets BlazeBlogger configuration options
# Copyright (C) 2008-2011 Jaromir Hradilek

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
use constant VERSION => '1.1.2';                    # Script version.

# General script settings:
our $blogdir = '.';                                 # Repository location.
our $editor  = '';                                  # Editor to use.
our $verbose = 1;                                   # Verbosity level.

# A list of valid options, and their default values:
our %opt = (
  # Blog related settings:
  'blog.title'       => 'Blog Title',               # Blog title.
  'blog.subtitle'    => 'blog subtitle',            # Blog subtitle.
  'blog.description' => 'blog description',         # Blog description.
  'blog.keywords'    => 'blog keywords',            # Blog keywords.
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

Copyright (C) 2008-2011 Jaromir Hradilek
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
    display_warning("Unable to write the configuration.");

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
  my $blog_desc      = $conf->{blog}->{description}||$opt{'blog.description'};
  my $blog_keywords  = $conf->{blog}->{keywords}  || $opt{'blog.keywords'};
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
##   description   A brief description of your blog.
##   keywords      A comma-separated list of keywords.
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
description=$blog_desc
keywords=$blog_keywords
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
      display_warning("The file has not been changed: aborting.");

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

blaze-config - displays or sets BlazeBlogger configuration options

=head1 SYNOPSIS

B<blaze-config> [B<-qV>] [B<-b> I<directory>] [B<-E> I<editor>] I<option>
[I<value>...]

B<blaze-config> B<-e> [B<-b> I<directory>]

B<blaze-config> B<-h>|B<-v>

=head1 DESCRIPTION

B<blaze-config> either sets BlazeBlogger configuration options, or displays
their current value. Additionally, it can also open a configuration file in
an external text editor.

=head1 OPTIONS

=head2 Command Line Options

=over

=item B<-b> I<directory>, B<--blogdir> I<directory>

Allows you to specify a I<directory> in which the BlazeBlogger repository
is placed. The default option is a current working directory.

=item B<-E> I<editor>, B<--editor> I<editor>

Allows you to specify an external text I<editor>. When supplied, this
option overrides the relevant configuration option.

=item B<-e>, B<--edit>

Allows you to edit the configuration in a text editor.

=item B<-q>, B<--quiet>

Disables displaying of unnecessary messages.

=item B<-V>, B<--verbose>

Enables displaying of all messages. This is the default option.

=item B<-h>, B<--help>

Displays usage information and exits.

=item B<-v>, B<--version>

Displays version information and exits.

=back

=head2 Configuration Options

=over

=item B<blog.title>=I<string>

A title of your blog.

=item B<blog.subtitle>=I<string>

A subtitle of your blog.

=item B<blog.description>=I<string>

A brief description of your blog.

=item B<blog.keywords>=I<list>

A comma-separated list of keywords.

=item B<blog.theme>=I<string>

A theme for your blog. Note that it must point to an existing file in the
C<.blaze/theme/> directory. The default option is C<default.html>.

=item B<blog.style>=I<string>

A style sheet for your blog. Note that it must point to an existing file in
the C<.blaze/style/> directory. The default option is C<default.css>.

=item B<blog.lang>=I<string>

A translation of your blog. Note that it must point to an existing file in
the C<.blaze/lang/> directory. The default option is C<en_US>.

=item B<blog.posts>=I<integer>

A number of blog posts to be listed on a single page. The default option is
C<10>.

=item B<color.list>=I<boolean>

A boolean to enable (C<true>) or disable (C<false>) colors in the
B<blaze-list> output. The default option is C<false>.

=item B<color.log>=I<boolean>

A boolean to enable (C<true>) or disable (C<false>) colors in the
B<blaze-log> output. The default option is C<false>.

=item B<core.doctype>=I<string>

A document type. It can be either C<html> for HTML, or C<xhtml> for the
XHTML standard. The default option is C<html>.

=item B<core.extension>=I<string>

A file extension. The default option is C<html>.

=item B<core.encoding>=I<string>

A character encoding. Note that it has to be in a form that is recognized
by W3C standards. The default option is C<UTF-8>.

=item B<core.editor>=I<string>

An external text editor. When supplied, this option overrides the
system-wide settings.

=item B<core.processor>=I<string>

An external application to be used to process newly added or edited blog
posts and pages. Note that you must supply C<%in%> and C<%out%> in place of
an input and output file name respectively. This option is disabled by
default.

=item B<feed.baseurl>=I<string>

A URL of your blog, for example C<http://example.com>.

=item B<feed.posts>=I<integer>

A number of blog posts to be listed in the feed. The default option is
C<10>.

=item B<feed.fullposts>=I<boolean>

A boolean to enable (C<true>) or disable (C<false>) inclusion of the whole
content of a blog post in the feed, even though the B<< <!-- break --> >>
form is used. The default option is C<false>.

=item B<post.author>=I<string>

A location of a blog post author name. It can be placed above the post
(C<top>), below it (C<bottom>), or nowhere on the page (C<none>). The
default option is C<top>.

=item B<post.date>=I<string>

A location of a date of publishing. It can be placed above the post
(C<top>), below it (C<bottom>), or nowhere on the page (C<none>). The
default option is top.

=item B<post.tags>=I<string>

A location of post tags. They can be placed above the post (C<top>), below
it (C<bottom>), or nowhere on the page (C<none>). The default option is
C<top>.

=item B<user.name>=I<string>

Your full name to be used in the copyright notice, and as the default post
author. The default option is C<admin>.

=item B<user.nickname>=I<string>

Your nickname to be used as the default post author. When supplied, it
overrides the B<user.name> setting. This option is disabled by default.

=item B<user.email>=I<string>

Your email address. The default option is C<admin@localhost>.

=back

=head1 ENVIRONMENT

=over

=item B<EDITOR>

Unless the B<core.editor> option is set, BlazeBlogger tries to use system-wide
settings to decide which editor to use.

=back

=head1 FILES

=over

=item I<.blaze/config>

A file containing the configuration.

=item I<.blaze/theme/>

A directory containing blog themes.

=item I<.blaze/style/>

A directory containing style sheets.

=item I<.blaze/lang/>

A directory containing language files.

=back

=head1 EXAMPLE USAGE

Configure the default text editor:

  ~]$ blaze-config core.editor nano
  The option has been successfully saved.

Configure the user information:

  ~]$ blaze-config user.name Jaromir Hradilek
  The option has been successfully saved.
  ~]$ blaze-config user.email jhradilek@gmail.com
  The option has been successfully saved.

Configure the blog appearance:

  ~]$ blaze-config blog.title BlazeBlogger
  The option has been successfully saved.
  ~]$ blaze-config blog.subtitle a CMS without boundaries
  The option has been successfully saved.
  ~]$ blaze-config blog.theme keepitsimple.html
  The option has been successfully saved.
  ~]$ blaze-config blog.style keepitsimple.css
  The option has been successfully saved.

Configure the RSS feed:

  ~]$ blaze-config feed.fullposts true
  The option has been successfully saved.
  ~]$ blaze-config feed.posts 10
  The option has been successfully saved.
  ~]$ blaze-config feed.baseurl http://blaze.blackened.cz/
  The option has been successfully saved.

Open the configuration in a text editor:

  ~]$ blaze-config -e

=head1 SEE ALSO

B<blaze-init>(1)

=head1 BUGS

To report a bug or to send a patch, please, add a new issue to the bug
tracker at <http://code.google.com/p/blazeblogger/issues/>, or visit the
discussion group at <http://groups.google.com/group/blazeblogger/>.

=head1 COPYRIGHT

Copyright (C) 2008-2011 Jaromir Hradilek

This program is free software; see the source for copying conditions. It is
distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.

=cut
