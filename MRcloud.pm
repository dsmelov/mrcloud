#! /usr/bin/env perl
package MRcloud;

use lib $ENV{'SHUTTER_ROOT'}.'/share/shutter/resources/modules';

use utf8;
use strict;
use POSIX qw(strftime setlocale);
use Locale::gettext;
use Glib qw/TRUE FALSE/; 

use Shutter::Upload::Shared;
our @ISA = qw(Shutter::Upload::Shared);

my $d = Locale::gettext->domain("shutter-upload-plugins");
$d->dir( $ENV{'SHUTTER_INTL'} );

my %upload_plugin_info = (
  'module' => "MRcloud",
  'url' => "https://cloud.mail.ru/",
  'registration' => "https://mail.ru/signup",
  'description' => $d->get( "Upload screenshots into your CloudMailRu" ),
  'supports_anonymous_upload' => TRUE,
  'supports_authorized_upload' => FALSE,
  'supports_oauth_upload' => FALSE,
);

binmode( STDOUT, ":utf8" );
if ( exists $upload_plugin_info{$ARGV[ 0 ]} ) {
  print $upload_plugin_info{$ARGV[ 0 ]};
  exit;
}

sub new {
  my $class = shift;
  my $self = $class->SUPER::new( shift, shift, shift, shift, shift, shift );
  bless $self, $class;
  return $self;
}

sub init {
  my $self = shift;
  return TRUE;
}

sub upload {
  my ( $self, $upload_filename ) = @_;

  my $dir = '/Screenshots';

  my $name = $upload_filename;
  $name =~ s/.*\///;
  my $uptime = strftime "%Y-%m-%d_%Hh%Mm%Ss", localtime;

  system('mrcloud', '-u', "$upload_filename,$dir/$uptime\_$name");
  my @link = `mrcloud -p "$dir/$uptime\_$name"`;
  chomp @link;

  $self->{_links}->{'main_link'} = $link[0];
  $self->{_links}->{'direct_link'} = $link[1];
  $self->{_links}->{'remove_link'} = "mrcloud -r \"$dir/$uptime\_$name\"";

  $self->{_links}{'status'} = 200;
  return %{ $self->{_links} };
}
#upload();
1;
