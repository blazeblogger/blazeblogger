#!/usr/bin/env perl

# blaze-list, browse the content of the BlazeBlogger repository
# Copyright (C) 2009 Jaromir Hradilek

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
use Term::ANSIColor;
use Getopt::Long;

# General script information:
use constant NAME    => basename($0, '.pl');        # Script name.
use constant VERSION => '0.8.1';                    # Script version.

# General script settings:
our $blogdir    = '.';                              # Repository location.
our $verbose    = 1;                                # Verbosity level.
our $compact    = 0;                                # Use compact listing?
our $coloured   = undef;                            # Use coloured listing?

# Command-line options:
my  $type       = 'post';                           # Type: post or page.
my  $id         = '';                               # ID search pattern.
my  $title      = '';                               # Title search pattern.
my  $author     = '';                               # Name search pattern.
my  $year       = '';                               # Year search pattern.
my  $month      = '';                               # Month search pattern.
my  $day        = '';                               # Day search pattern.
my  $tag        = '';                               # Tag search pattern.

# Set up the __WARN__ signal handler:
$SIG{__WARN__}  = sub {
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
Usage: $NAME [-cpqsCPSV] [-b directory] [-I id] [-a author] [-t title]
                  [-T tag] [-d day] [-m month] [-y year]
       $NAME -h | -v

  -b, --blogdir directory     specify the directory where the BlazeBlogger
                              repository is placed
  -I, --id id                 display record with specified ID
  -a, --author author         list records by specified author
  -t, --title title           list records with matching title
  -T, --tag tag               list records with matching tag
  -d, --day day               list records from the day in the DD form
  -m, --month month           list records from the month in the MM form
  -y, --year year             list records from the year in the YYYY form
  -p, --pages                 list pages instead of blog posts
  -P, --posts                 list blog posts; the default option
  -S, --stats                 show repository statistics instead of posts
  -s, --short                 display each record on a single line
  -c, --color                 enable coloured output
  -C, --no-color              disable coloured output
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

Copyright (C) 2009 Jaromir Hradilek
This program is free software; see the source for copying conditions. It is
distributed in the hope  that it will be useful,  but WITHOUT ANY WARRANTY;
without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PAR-
TICULAR PURPOSE.
END_VERSION

  # Return success:
  return 1;
}

# Translate given date to YYYY-MM-DD string:
sub date_to_string {
  my @date = localtime(shift);
  return sprintf("%d-%02d-%02d", ($date[5] + 1900), ++$date[4], $date[3]);
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

# Fix the erroneous or missing header data:
sub fix_header {
  my $data   = shift || die 'Missing argument';
  my @fields = qw( title author date tags url );

  # Process each field separately:
  foreach my $field (@fields) {
    # Strip forbidden characters:
    $data->{header}->{$field} =~ s/://g if $data->{header}->{$field};
  }

  # Supplement missing fields:
  $data->{header}->{date}   ||= 'XXXX-XX-XX';
  $data->{header}->{tags}   ||= '';
  $data->{header}->{author} ||= 'admin';
  $data->{header}->{url}    ||= '';
  $data->{header}->{title}  ||= '';

  # Return success:
  return 1;
}

# Return the list of posts/pages header records:
sub collect_headers {
  my $type    = shift || 'post';
  my $head    = catdir($blogdir, '.blaze', "${type}s", 'head');
  my @records = ();

  # Open the headers directory:
  opendir(HEAD, $head) or return @records;

  # Process each file:
  while (my $id = readdir(HEAD)) {
    # Skip both . and ..:
    next if $id =~ /^\.\.?$/;

    # Parse the header data:
    my $data = read_ini(catfile($head, $id)) or next;

    # Fix the erroneous or missing header data:
    fix_header($data);

    # Add the record to the beginning of the list:
    push(@records, $data->{header}->{date}   . ':' . $id . ':' .
                   $data->{header}->{tags}   . ':' .
                   $data->{header}->{author} . ':' .
                   $data->{header}->{url}    . ':' .
                   $data->{header}->{title});
  }

  # Close the directory:
  closedir(HEAD);

  # Return the result:
  return sort { $b cmp $a } @records;
}

# Display the list of matching records:
sub display_records {
  my $type    = shift || 'post';
  my $id      = shift || '.*';
  my $author  = shift || '.*';
  my $title   = shift || '';
  my $tag     = shift || '.*';
  my $year    = shift || '....';
  my $month   = shift || '..';
  my $day     = shift || '..';

  # Collect the pages/posts headers:
  my @headers = collect_headers($type);

  # Process each header:
  foreach(@headers) {
    # Decompose the header record:
    $_ =~ /^([^:]*):([^:]*):([^:]*):([^:]*):([^:]*):(.*)$/;
    my $record_date   = $1;
    my $record_id     = $2;
    my $record_tags   = $3;
    my $record_author = $4;
    my $record_title  = $6;

    # Check whether the record matches the pattern:
    unless ($record_date   =~ /^$year-$month-$day$/i &&
            $record_title  =~ /^.*$title.*$/i &&
            $record_tags   =~ /^(|.*, *)$tag(,.*|)$/i &&
            $record_author =~ /^$author$/i &&
            $record_id     =~ /^$id$/i) {
      # Skip the record:
      next;
    }

    # Check whether to use compact listing:
    unless ($compact) {
      # Check whether to use colours:
      unless ($coloured) {
        # Display the plain record header:
        print "ID: $record_id | $record_date | $record_author\n\n";
      }
      else {
        # Display the coloured record header:
        print colored ("ID: $record_id | $record_date | $record_author",
                       'yellow');
        print "\n\n";
      }

      # Display the record body:
      print wrap('    ', ' ' x 11, "Title: $record_title\n");
      print wrap('    ', ' ' x 11, "Tags:  $record_tags\n")
        if ($type eq 'post');
      print "\n";
    }
    else {
      # Display the short record:
      print "ID: $record_id | $record_date | $record_title\n";
    }
  }

  # Return success:
  return 1;
}

# Display repository statistics:
sub display_statistics {
  # Collect the necessary metadata:
  my @pages = collect_headers('page');
  my @posts = collect_headers('post');

  # Get desired values:
  my $pages_count = scalar @pages;
  my $posts_count = scalar @posts;
  my $first_post  = substr($posts[$#posts], 0, 10) if @posts;
  my $last_post   = substr($posts[0],       0, 10) if @posts;

  # Check whether to use compact listing:
  unless ($compact) {
    # Display the full results:
    print "Number of pages: $pages_count\n";
    print "Number of posts: $posts_count\n";
    print "Last post date:  $last_post\n"  if @posts;
    print "First post date: $first_post\n" if @posts;
  }
  else {
    # Display shortened results:
    printf("There is a total number of $posts_count blog post%s " .
           "and $pages_count page%s in the repository.\n",
           (($posts_count != 1) ? 's' : ''),
           (($pages_count != 1) ? 's' : ''));
  }

  # Return success:
  return 1;
}

# Set up the options parser:
Getopt::Long::Configure('no_auto_abbrev', 'no_ignore_case', 'bundling');

# Process command-line options:
GetOptions(
  'help|h'               => sub { display_help();    exit 0; },
  'version|v'            => sub { display_version(); exit 0; },
  'page|pages|p'         => sub { $type     = 'page';  },
  'post|posts|P'         => sub { $type     = 'post';  },
  'stats|S'              => sub { $type     = 'stats'; },
  'id|I=s'               => sub { $id       = $_[1];   },
  'author|a=s'           => sub { $author   = $_[1];   },
  'title|t=s'            => sub { $title    = $_[1];   },
  'tags|tag|T=s'         => sub { $tag      = $_[1];   },
  'year|y=i'             => sub { $year     = sprintf("%04d", $_[1]); },
  'month|m=i'            => sub { $month    = sprintf("%02d", $_[1]); },
  'day|d=i'              => sub { $day      = sprintf("%02d", $_[1]); },
  'short|s'              => sub { $compact  = 1;       },
  'no-color|no-colour|C' => sub { $coloured = 0;       },
  'color|colour|c'       => sub { $coloured = 1;       },
  'quiet|q'              => sub { $verbose  = 0;       },
  'verbose|V'            => sub { $verbose  = 1;       },
  'blogdir|b=s'          => sub { $blogdir  = $_[1];   },
);

# Detect superfluous options:
exit_with_error("Invalid option `$ARGV[0]'.", 22) if (scalar(@ARGV) != 0);

# Check the repository is present (however naive this method is):
exit_with_error("Not a BlazeBlogger repository! Try `blaze-init' first.",1)
  unless (-d catdir($blogdir, '.blaze'));

# Unless specified on the command line, read the colour setup from the
# configuration:
unless (defined $coloured) {
  # Read the configuration file:
  my $conf  = read_conf();

  # Read required data from the configuration:
  my $temp  = $conf->{color}->{list} || 'false';

  # Set up the output mode:
  $coloured = ($temp =~ /^(true|auto)\s*$/i) ? 1 : 0;
}

# Check whether to post/pages, or show statistics:
unless ($type eq 'stats') {
  # Prepare the list of reserved characters:
  my $reserved  = '[\\\\\^\.\$\|\(\)\[\]\*\+\?\{\}]';

  # Escape reserved characters:
  $id     =~ s/($reserved)/\\$1/g if $id;
  $author =~ s/($reserved)/\\$1/g if $author;
  $title  =~ s/($reserved)/\\$1/g if $title;
  $tag    =~ s/($reserved)/\\$1/g if $tag;
  $year   =~ s/($reserved)/\\$1/g if $year;
  $month  =~ s/($reserved)/\\$1/g if $month;
  $month  =~ s/($reserved)/\\$1/g if $day;

  # Display the list of matching records:
  display_records($type, $id, $author, $title, $tag, $year, $month, $day)
    or exit_with_error("Cannot read repository data.", 13);
}
else {
  # Display repository statistics:
  display_statistics()
    or exit_with_error("Cannot read repository data.", 13);
}

# Return success:
exit 0;

__END__

=head1 NAME

blaze-list - browse the content of the BlazeBlogger repository

=head1 SYNOPSIS

B<blaze-list> [B<-cpqsCPSV>] [B<-b> I<directory>] [B<-I> I<id>]
[B<-a> I<author>] [B<-t> I<title>] [B<-T> I<tag>] [B<-d> I<day>]
[B<-m> I<month>] [B<-y> I<year>]

B<blaze-list> B<-h> | B<-v>

=head1 DESCRIPTION

B<blaze-list> displays the content of the BlazeBlogger repository. All
items are listed by default, but desired subset can be easily selected via
additional options.

=head1 OPTIONS

=over

=item B<-b>, B<--blogdir> I<directory>

Specify the I<directory> where the BlazeBlogger repository is placed. The
default option is the current working directory.

=item B<-I>, B<--id> I<id>

Display the record with specified I<id> only.

=item B<-a>, B<--author> I<author>

List records by specified I<author> only.

=item B<-t>, B<--title> I<title>

List records with matching I<title>.

=item B<-T>, B<--tag> I<tag>

List records tagged as I<tag>.

=item B<-d>, B<--day> I<day>

List records from the specified day where I<day> is in the DD format. Do
not forget to specify the month and year as well, unless you, for example,
want to list all records from the first day of every month.

=item B<-m>, B<--month> I<month>

List records from the specified month where I<month> is in the MM format.
Do not forget to specify the year as well, unless you, for example, want to
list all july records.

=item B<-y>, B<--year> I<year>

List records from the specified year where I<year> is in the YYYY format.

=item B<-p>, B<--pages>

List pages instead of blog posts.

=item B<-P>, B<--posts>

List blog posts; this is the default option.

=item B<-S>, B<--stats>

Show repository statistics instead of blog posts.

=item B<-s>, B<--short>

Display each record on a single line.

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

Copyright (C) 2009 Jaromir Hradilek

This program is free software; see the source for copying conditions. It is
distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.

=cut
