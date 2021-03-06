#!/usr/bin/perl
# vim: set ts=2 sw=2 et:

use strict;
use Term::ANSIColor;
use Getopt::Long;
use Data::Dump qw(pp);
use IO::Handle;

my $maxlines = 0;         # > 0: output lines 0 .. $maxlines
my $taillines = 0;        # > 0: output lines -$taillines .. -1
my $follow = 0;           # set: follow output with `tail -f`
my $hideraw = 1;          # set: hide *.messaging.ops.raw messages
#my $hideheartbeat = 1;    # set: hide ConnectionHeartbeat commands
my @skipsources = ();     # set: skip messages with these sources
my @skipmessages = ();    # set: skip messages with these message types
my $strip_u = 1;          # clothes are optional when reading logfiles (strip 'u' designator on unicode strings)
my $highlightcontent = 1; # set: highlight the 'content=' key in message bodies
my $debug = 0;
GetOptions(
  'maxlines=i'         => \$maxlines,
  'taillines=i'        => \$taillines,
  'follow'             => \$follow,
  'hideraw!'           => \$hideraw,
  'skipsource=s@'      => \@skipsources,
  'skipmessagetype=s@' => \@skipmessages,
  'stripu!'            => \$strip_u,
  'highlightcontent!'  => \$highlightcontent,
  'debug!'             => \$debug
);

  
# Strip off quotes
@skipsources = map { if (/^('|")(.+)\1$/) { $2 } else { $_ } } @skipsources;
@skipmessages = map { if (/^('|")(.+)\1$/) { $2 } else { $_ } } @skipmessages;

print STDERR "'$_'\n" foreach(@skipmessages);

print STDERR "Initializing...\n" if $debug;

if (($taillines || $follow) && $ARGV[0])
{
  my $tailopts = '-';
  $tailopts .= $taillines if $taillines;
  $tailopts .= 'f' if $follow;
  $ARGV[0] = "tail $tailopts $ARGV[0] |";
  print STDERR "Using tail as STDIN...\n" if $debug;
}

if (-t STDOUT && (-t STDIN || $taillines) && !$follow)
{
  if (!system('command -v less >/dev/null'))
  {
    my $kid_pid = open(LESSOUT, "-|");
    if ($kid_pid)
    {
      STDIN->fdopen(fileno(LESSOUT), 'r') or die "unable to reopen STDIN";

      *STDIN = *LESSOUT;
      exec 'less -R'
    }
  }
}

my $valid_operations = join('|', qw(OPEN SENT RECV RCVD REST READ RETR RACK));
my $valid_levels = join('|', qw(ERROR INFO DEBUG AUDIT WARNING));

sub print_detailed_msg($$$;$)
{
  my ($operation, $some_num, $body) = (shift, shift, shift);
  my $msg_type = shift or 0;

  print colored("$operation", 'magenta'), " ";
  print colored("[$some_num]", 'bold'), " ";
  $body =~ s/(content)=/colored($1, 'bold') . '='/e if ($highlightcontent);

  if ($msg_type)
  {
    print_msg_body($body, $msg_type)
  }
  else
  {
    print_msg_body($body)
  }
}

sub print_msg_body($;$)
{
  my $body = shift;
  my $msg_type = shift or 0;
  if ($strip_u) # waring: X-Rated code, viewer discretion advised
  {
    $body =~ s/u'(.+?)(?!\\)'/'$1'/g;

    print colored($msg_type, 'bright_yellow') if $msg_type;
    print "$body\n";
  }
  else
  {
    print colored($msg_type, 'bright_yellow') if $msg_type;
    print "$body\n";
  }

  STDOUT->flush() unless -t STDOUT; # if STDOUT is a pipe, then perl will use block buffering.  Instead, we really want to hand whatever is at the end of the pipe one line at a time, so we force a flush.  If we're outputing to a terminal, perl will flush on "\n"
}

sub print_header($$$$$$)
{
  my ($date, $time, $pid, $lvl, $src, $req_id) = @_; 
  print colored("$date $time", 'yellow'), " $pid ";
  if ($lvl eq 'DEBUG')
  {
    print colored($lvl, 'bold cyan');
  }
  elsif ($lvl eq 'INFO')
  {
    print colored($lvl, 'bold green');
  }
  elsif ($lvl eq 'ERROR')
  {
    print colored($lvl, 'bold red');
  }
  elsif ($lvl eq 'WARNING')
  {
    print colored($lvl, 'bold magenta');
  }
  else
  {
    print colored($lvl, 'bold');
  }
  print " ", colored("$src", 'blue'), colored(" [$req_id] ", 'bold');
}

print STDERR "Beginning read loop...\n" if $debug;

my $cnt = 0;
LINE: while(<>)
{
  print STDERR "Read...\n" if $debug;
  last if $maxlines && $cnt > $maxlines;
  $cnt++;
  chomp; # take care of newline
  my $orig = $_;

  my @metadata = (/^(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2}\.\d{1,3}) (\d+) ($valid_levels) ([a-zA-Z0-9_.]+) \[(-|(?:[a-zA-Z0-9\-]+ .+ .+))\] (.+)$/);
  my ($date, $time, $pid, $lvl, $src, $req_id, $rest) = @metadata;

  unless ($lvl && $date && $time && $src && $pid)
  {
    print colored("ERROR: ", 'bold white on_bright_red'), colored("$orig", "on_bright_red"), "\n";
    next LINE;
  }

  next if $hideraw && $src =~ /^\w+\.messaging\.io\.raw$/;
  for my $skip_src (@skipsources)
  {
    next LINE if $src =~ qr/^$skip_src$/;
  }

  # my %line = (date => $date, time => $time, pid => $pid, level => $lvl, source => $src, req_id => $req_id, raw => $orig);

  if ($rest =~ /^($valid_operations)\[([a-f0-9]+)\]: (.+)$/)
  {
    # $line{msg} = {operation => $1, some_num => $2, body => $3};
    my ($operation, $some_num, $body) = ($1, $2, $3);
    if ($body =~ /^(\w+)(\(.+)$/)
    {
      my $msg_type = $1;
      my $body = $2;
      foreach my $skip_msg (@skipmessages)
      {
        next LINE if $msg_type =~ qr/^$skip_msg$/;
      }

      print_header($date, $time, $pid, $lvl, $src, $req_id);
      print_detailed_msg($operation, $some_num, $body, $msg_type);
    }
    else
    {
      print_header($date, $time, $pid, $lvl, $src, $req_id);
      print_detailed_msg($operation, $some_num, $body)
    }
  }
  else
  {
    # $line{msg} = {body => $rest};
    print_header($date, $time, $pid, $lvl, $src, $req_id);
    print_msg_body($rest);
  }
}

print STDERR "Ending read loop...\n" if $debug;
close(STDOUT);

close(LESSOUT) if (tell(LESSOUT) > 0);
close(SPECIALIN) if (tell(SPECIALIN) > 0);

print STDERR "Exiting...\n" if $debug;
