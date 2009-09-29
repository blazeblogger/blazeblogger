#!/usr/bin/env perl

# blaze-init, create or recover a BlazeBlogger repository
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
use File::Path;
use File::Spec::Functions;
use Getopt::Long;

# General script information:
use constant NAME    => basename($0, '.pl');        # Script name.
use constant VERSION => '1.0.0';                    # Script version.

# General script settings:
our $blogdir = '.';                                 # Repository location.
our $force   = 0;                                   # Force files rewrite?
our $verbose = 1;                                   # Verbosity level.

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
Usage: $NAME [-fqV] [-b directory]
       $NAME -h | -v

  -b, --blogdir directory     specify the directory where the BlazeBlogger
                              repository is to be placed
  -f, --force                 force rewrite of already existing files
  -q, --quiet                 avoid displaying unnecessary messages
  -V, --verbose               display all messages including the list of
                              created files
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

# Create the default configuration file:
sub create_conf {
  # Prepare the configuration file name:
  my $file = catfile($blogdir, '.blaze', 'config');

  # Skip existing file unless forced:
  return 1 if (-e $file && !$force);

  # Open the file for writing:
  open(FILE, ">$file") or return 0;

  # Write given string to the file:
  print FILE << 'END_CONFIG';
## This is the default BlazeBlogger configuration file. The recommended way
## to set up your blog is to leave this file intact and use blaze-config(1)
## instead.  Nevertheless, if you prefer to configure the settings by hand,
## simply replace the value next to the equal sign.

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
title=My Blog
subtitle=yet another blog
theme=default.html
style=default.css
lang=en_GB
posts=10
url=

## The following are the colour settings, affecting the way various outputs
## look. The options are as follows:
##
##   list - Whether to use coloured posts/pages listing;  the value  has to
##          be either true, or false.
##   log  - Whether to use coloured repository log listing;  the value  has
##          to be either true, or false.
##
[color]
list=false
log=false

## The following are the core settings,  affecting the way the BlazeBlogger
## works. The options are as follows:
##
##   encoding  - Records  encoding in the form  recognised by the  W3C HTML
##               4.01 standard (e.g. the default UTF-8).
##   extension - File extension for the generated pages.
##   editor    - An external text editor to be used for editing purposes.
##   processor - An optional external application to be used to process the
##               entries;  use %in% and %out% in place of input and  output
##               files, for example: markdown --html4tags %in% > %out%
##
[core]
encoding=UTF-8
extension=html
editor=
processor=

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
author=top
date=top
tags=top

## The following are the user related settings. The options are as follows:
##
##   user  - User's name  to be used as a default posts' author  and in the
##           copyright notice.
##   email - User's e-mail.
##
[user]
name=admin
email=admin@localhost
END_CONFIG

  # Close the file:
  close(FILE);

  # Report success:
  print "Created $file\n" if $verbose > 1;

  # Return success:
  return 1;
}

# Create the default theme file:
sub create_theme {
  # Prepare the theme file name:
  my $file = catfile($blogdir, '.blaze', 'theme', 'default.html');

  # Skip existing file unless forced:
  return 1 if (-e $file && !$force);

  # Open the file for writing:
  open(FILE, ">$file") or return 0;

  # Write given string to the file:
  print FILE << 'END_THEME';
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
                      "http://www.w3.org/TR/html4/strict.dtd">
<html>
<head>
  <!-- content-type -->
  <!-- generator -->
  <!-- date -->
  <!-- stylesheet -->
  <!-- rss -->
  <title><!-- page-title --></title>
</head>

<body>

<div id="wrapper">
  <div id="shadow">
    <div id="heading">
      <h1><a href="%home%"><!-- title --></a></h1>
      <!-- subtitle -->
    </div>

    <div id="menu">
      <ul>
<li><a href="%home%">Home</a></li>
<!-- pages -->
      </ul>
    </div>
  </div>

  <div id="content">
<!-- content -->
  </div>

  <div id="sidebar">
    <h2>Categories</h2>
    <ul>
<!-- tags -->
    </ul>

    <h2>Archive</h2>
    <ul>
<!-- archive -->
    </ul>

    <h2>Links</h2>
    <ul>
<li><a href="http://blaze.blackened.cz">BlazeBlogger</a></li>
    </ul>
  </div>

  <div id="footer">
    Copyright &copy; <!-- year --> <!-- name -->.
    Powered by <a href="http://blaze.blackened.cz/">BlazeBlogger</a>.
  </div>
</div>

</body>
</html>
END_THEME

  # Close the file:
  close(FILE);

  # Report success:
  print "Created $file\n" if $verbose > 1;

  # Return success:
  return 1;
}

# Create the default style file:
sub create_style {
  # Prepare the style file name:
  my $file = catfile($blogdir, '.blaze', 'style', 'default.css');

  # Skip existing file unless forced:
  return 1 if (-e $file && !$force);

  # Open the file for writing:
  open(FILE, ">$file") or return 0;

  # Write given string to the file:
  print FILE << 'END_STYLE';
/* default.css - the default BlazeBlogger theme
 * Copyright (C) 2009 Jaromir Hradilek
 *
 * This program is free software:  you can redistribute it and/or modify it
 * under  the terms of the  GNU General Public License  as published by the
 * Free Software Foundation, version 3 of the License.
 *
 * This program  is  distributed  in the hope  that it will  be useful, but
 * WITHOUT  ANY WARRANTY;  without  even the implied warranty of MERCHANTA-
 * BILITY or  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 * License for more details.
 *
 * You should have received a copy of the  GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

body {
  margin: 0px 0px 10px 0px;
  padding: 0px;
  color: #000000;
  background-color: #e7e7e7;
  font-family: "DejaVu Sans", Arial, sans;
  font-size: small;
}

#wrapper {
  margin: auto;
  padding: 0px;
  width: 768px;
  border-left: 1px solid #d6d6d6;
  border-right: 1px solid #d6d6d6;
  border-bottom: 1px solid #d6d6d6;
  background-color: #ffffff;
}

#shadow {
  margin: 0px;
  padding: 0px;
  border-bottom: 2px solid #e7e7e7;
}

#heading {
  width: 728px;
  padding: 20px;
  background-color: #2e2e2e;
  border-bottom: 2px solid #2a2a2a;
  border-top: 2px solid #323232;
  color: #d0d0d0;
}

#heading a, #heading h1 {
  margin: 0px;
  text-decoration: none;
  color: #ffffff;
}

#heading a:hover {
  text-decoration: underline;
}

#menu {
  width: 768px;
  border-top: 1px solid #5f5f5f;
  border-bottom: 1px solid #3d3d3d;
  background-color: #4e4e4e;
}

#menu ul {
  padding: 4px 15px 4px 15px;
  margin: 0px;
  list-style-type: none;
}

#menu li {
  display: inline;
  padding: 4px 10px 5px 10px;
  margin: 0px;
}

#menu li:hover {
  background-color: #3d3d3d;
  border-bottom: 2px solid #dddddd;
  border-top: 1px solid #4e4e4e;
}

#menu a {
  color: #ffffff;
  font-size: x-small;
  text-decoration: none;
}

#menu a:hover {
  text-decoration: underline;
}

#content {
  float: left;
  margin: 0px;
  padding: 10px 10px 20px 20px;
  width: 528px;
  text-align: justify;
}

#content h2.post {
  margin-bottom: 0px;
  padding-bottom: 0px;
}

#content .post a {
  text-decoration: none;
  color: #9acd32;
}

#content a {
  text-decoration: none;
  color: #4e9a06;
}

#content a:hover {
  text-decoration: underline;
}

#content .information {
  font-size: x-small;
  color: #4e4e4e;
}

#content .information a {
  color: #4e9a06;
  text-decoration: underline;
}

#content .information a:hover {
  text-decoration: none;
}

#content .post-footer {
  font-size: x-small;
  color: #4e4e4e;
  padding: 4px 2px 4px 2px;
  border-top: 1px solid #e7e7e7;
  border-bottom: 1px solid #e7e7e7;
  background-color: #f8f8f8;
}

#content .post-footer a {
  color: #4e9a06;
  text-decoration: underline;
}

#content .post-footer a:hover {
  text-decoration: none;
}

#content .section {
  text-align: right;
  font-size: x-small;
  color: #808080;
}

#content .previous {
  padding: 10px 0px 10px 0px;
  float: left;
}

#content .next {
  padding: 10px 0px 10px 0px;
  float: right;
}

#sidebar {
  float: right;
  margin: 0px;
  padding: 10px 20px 20px 0px;
  width: 180px;
}

#sidebar h2 {
  font-size: small;
}

#sidebar ul {
  list-style-type: none;
  padding-left: 1em;
  margin-left: 0px;
}

#sidebar a {
  text-decoration: underline;
  color: #4e9a06;
}

#sidebar a:hover {
  text-decoration: none;
}

#footer {
  clear: both;
  margin: 0px;
  padding: 10px 20px 10px 20px;
  border-top: 2px solid #e7e7e7;
  border-bottom: 1px solid #3d3d3d;
  background-color: #4e4e4e;
  text-align: right;
  font-size: x-small;
  color: #d0d0d0;
}

#footer a {
  color: #ffffff;
  text-decoration: none;
}

#footer a:hover {
  text-decoration: underline;
}
END_STYLE

  # Close the file:
  close(FILE);

  # Report success:
  print "Created $file\n" if $verbose > 1;

  # Return success:
  return 1;
}

# Create the default language file:
sub create_lang {
  # Prepare the language file name:
  my $file = catfile($blogdir, '.blaze', 'lang', 'en_GB');

  # Skip existing file unless forced:
  return 1 if (-e $file && !$force);

  # Open the file for writing:
  open(FILE, ">$file") or return 0;

  # Write given string to the file:
  print FILE << 'END_LANG';
[lang]
archive=Archive for
tags=Posts tagged as
taglist=List of tags
previous=&laquo; Previous
next=Next &raquo;
more=Read more &raquo;
postedon=
postedby=by
taggedas=tagged as
january=January
february=February
march=March
april=April
may=May
june=June
july=July
august=August
september=September
october=October
november=November
december=December
END_LANG

  # Close the file:
  close(FILE);

  # Report success:
  print "Created $file\n" if $verbose > 1;

  # Return success:
  return 1;
}

# Add given string to the log file:
sub add_to_log {
  my $text = shift || 'Something miraculous has just happened!';

  # Prepare the log file name:
  my $file = catfile($blogdir, '.blaze', 'log');

  # Open the log file for appending:
  open(LOG, ">>$file") or return 0;

  # Write to the log file:
  print LOG localtime(time) . " - $text\n";

  # Close the file:
  close(LOG);

  # Return success:
  return 1;
}

# Set up the options parser:
Getopt::Long::Configure('no_auto_abbrev', 'no_ignore_case', 'bundling');

# Process command-line options:
GetOptions(
  'help|h'        => sub { display_help();    exit 0; },
  'version|v'     => sub { display_version(); exit 0; },
  'force|f'       => sub { $force   = 1;     },
  'quiet|q'       => sub { $verbose = 0;     },
  'verbose|V'     => sub { $verbose = 2;     },
  'blogdir|b=s'   => sub { $blogdir = $_[1]; },
);

# Detect superfluous options:
exit_with_error("Invalid option `$ARGV[0]'.", 22) if (scalar(@ARGV) != 0);

# Decide whether to create or recover the repository:
my $action = (-d catdir($blogdir, '.blaze')) ? 'Recovered' : 'Created';

# Create the directory tree:
eval {
  mkpath(
    catdir($blogdir, '.blaze', 'lang'),
    catdir($blogdir, '.blaze', 'theme'),
    catdir($blogdir, '.blaze', 'style'),
    catdir($blogdir, '.blaze', 'pages', 'head'),
    catdir($blogdir, '.blaze', 'pages', 'body'),
    catdir($blogdir, '.blaze', 'pages', 'raw'),
    catdir($blogdir, '.blaze', 'posts', 'head'),
    catdir($blogdir, '.blaze', 'posts', 'body'),
    catdir($blogdir, '.blaze', 'posts', 'raw'),
    { verbose => 0 }
  );
};

# Make sure the directory tree creation was successful:
exit_with_error("Creating directory tree: $@", 13) if $@;

# Create the default configuration file:
create_conf()
  or display_warning("Unable to create the configuration file.");

# Create the default theme file:
create_theme()
  or display_warning("Unable to create the default theme file.");

# Create the default style file:
create_style()
  or display_warning("Unable to create the default style file.");

# Create the default language file:
create_lang()
  or display_warning("Unable to create the default language file.");

# Write to / create the log file:
add_to_log("$action a BlazeBlogger repository.")
  or display_warning("Unable to log the event.");

# Report success:
print "$action a BlazeBlogger repository in " .
      catdir($blogdir, '.blaze') . ".\n" if $verbose;

# Return success:
exit 0;

__END__

=head1 NAME

blaze-init - create or recover a BlazeBlogger repository

=head1 SYNOPSIS

B<blaze-init> [B<-fqV>] [B<-b> I<directory>]

B<blaze-init> B<-h> | B<-v>

=head1 DESCRIPTION

B<blaze-init>'s job is either to create a fresh new BlazeBlogger
repository, or to recover an existing one, optionally changing the
configuration and template files back to their original state while leaving
the user data (i.e. both pages and blog posts) untouched.

=head1 OPTIONS

=over

=item B<-b>, B<--blogdir> I<directory>

Specify the I<directory> where the BlazeBlogger repository is to be placed.
The default option is the current working directory.

=item B<-f>, B<--force>

Force rewrite of already existing configuration, style, theme and language
files.

=item B<-q>, B<--quiet>

Avoid displaying messages that are not necessary.

=item B<-V>, B<--verbose>

Display all messages including the list of created files.

=item B<-h>, B<--help>

Display usage information and exit.

=item B<-v>, B<--version>

Display version information and exit.

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

Copyright (C) 2008, 2009 Jaromir Hradilek

This program is free software; see the source for copying conditions. It is
distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.

=cut
