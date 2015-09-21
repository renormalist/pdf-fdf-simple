package PDF::FDF::Simple;
# ABSTRACT: Read and write (Acrobat) FDF files.

use strict;
use warnings;

use vars qw($VERSION $deferred_result_FDF_OPTIONS);
use Data::Dumper;
use Parse::RecDescent;
use IO::File;

use base 'Class::Accessor::Fast';
PDF::FDF::Simple->mk_accessors(qw(
                                     skip_undefined_fields
                                     filename
                                     content
                                     errmsg
                                     parser
                                     attribute_file
                                     attribute_ufile
                                     attribute_id
                                ));

$VERSION = '0.22';

#Parse::RecDescent environment variables: enable for Debugging
#$::RD_TRACE = 1;
#$::RD_HINT  = 1;

sub new {
  my $class = shift;

  my $parser;
  if ($ENV{PDF_FDF_SIMPLE_IGNORE_PRECOMPILED_GRAMMAR}) {
          # use external grammar file
          require File::ShareDir;
          my $grammar_file = File::ShareDir::module_file('PDF::FDF::Simple', 'grammar');
          open GRAMMAR_FILE, $grammar_file or die "Cannot open grammar file ".$grammar_file;
          local $/;
          my $grammar = <GRAMMAR_FILE>;
          $parser     = Parse::RecDescent->new($grammar);
  } else {
          # use precompiled grammar
          require PDF::FDF::Simple::Grammar;
          $parser = new PDF::FDF::Simple::Grammar;
  }

  my %DEFAULTS = (
                  errmsg                => '',
                  skip_undefined_fields => 0,
                  parser                => $parser
                 );
  # accept hashes or hash refs for backwards compatibility
  my %ARGS = ref($_[0]) =~ /HASH/ ? %{$_[0]} : @_;
  my $self = Class::Accessor::new($class, { %DEFAULTS, %ARGS });
  return $self;
}

sub _fdf_header {
  my $self = shift;

  my $string = "%FDF-1.2\n\n1 0 obj\n<<\n/FDF << /Fields 2 0 R";
  # /F
  if ($self->attribute_file){
    $string .= "/F (".$self->attribute_file.")";
  }
  # /UF
  if ($self->attribute_ufile){
    $string .= "/UF (".$self->attribute_ufile.")";
  }
  # /ID
  if ($self->attribute_id){
    $string .= "/ID[";
    $string .= $_ foreach @{$self->attribute_id};
    $string .= "]";
  }
  $string .= ">>\n>>\nendobj\n2 0 obj\n[";
  return $string;
}

sub _fdf_footer {
  my $self = shift;
  return <<__EOT__;
]
endobj
trailer
<<
/Root 1 0 R

>>
%%EOF
__EOT__
}

sub _quote {
  my $self = shift;
  my $str = shift;
  $str =~ s,\\,\\\\,g;
  $str =~ s,\(,\\(,g;
  $str =~ s,\),\\),g;
  $str =~ s,\n,\\r,gs;
  return $str;
}

sub _fdf_field_formatstr {
  my $self = shift;
  return "<< /T(%s)/V(%s) >>\n"
}

sub as_string {
  my $self = shift;
  my $fdf_string = $self->_fdf_header;
  foreach (sort keys %{$self->content}) {
    my $val = $self->content->{$_};
    if (not defined $val) {
      next if ($self->skip_undefined_fields);
      $val = '';
    }
    $fdf_string .= sprintf ($self->_fdf_field_formatstr,
                            $_,
                            $self->_quote($val));
  }
  $fdf_string .= $self->_fdf_footer;
  return $fdf_string;
}

sub save {
  my $self = shift;
  my $filename = shift || $self->filename;
  open (F, "> ".$filename) or do {
    $self->errmsg ('error: open file ' . $filename);
    return 0;
  };

  print F $self->as_string;
  close (F);

  $self->errmsg ('');
  return 1;
}

sub _read_fdf {
  my $self = shift;
  my $filecontent;

  # read file to be checked
  unless (open FH, "< ".$self->filename) {
    $self->errmsg ('error: could not read file ' . $self->filename);
    return undef;
  } else {
    local $/;
    $filecontent = <FH>;
  }
  close FH;
  $self->errmsg ('');
  return $filecontent;
}

sub _map_parser_output {
  my $self   = shift;
  my $output = shift;

  my $fdfcontent = {};
  foreach my $obj ( @$output ) {
    foreach my $contentblock ( @$obj ) {
      foreach my $keys (keys %$contentblock) {
        $fdfcontent->{$keys} = $contentblock->{$keys};
      }
    }
  }
  return $fdfcontent;
}

sub load {
  my $self = shift;
  my $filecontent = shift;

  # prepare content
  unless ($filecontent) {
    $filecontent = $self->_read_fdf;
    return undef unless $filecontent;
  }

  # parse
  my $output;
  {
      local $SIG{'__WARN__'} = sub { warn $_[0] unless $_[0] =~ /Deep recursion on subroutine/ };
      $output = $self->parser->startrule ($filecontent);
  }

  # take over parser results
  $self->attribute_file ($PDF::FDF::Simple::deferred_result_FDF_OPTIONS->{F});   # /F
  $self->attribute_ufile ($PDF::FDF::Simple::deferred_result_FDF_OPTIONS->{UF}); # /UF
  $self->attribute_id ($PDF::FDF::Simple::deferred_result_FDF_OPTIONS->{ID});    # /ID
  $self->content ($self->_map_parser_output ($output));
  $self->errmsg ("Corrupt FDF file!\n") unless $self->content;

  return $self->content;
}

1;
__END__

=head1 SYNOPSIS

  my $fdf = PDF::FDF::Simple->new({ filename => '/tmp/test.fdf' });
  $fdf->skip_undefined_fields (1);
  $fdf->content ({
                  'name'                 => 'Fred Madison',
                  'organisation'         => 'Luna Lounge Ltd.',
                  'dotted.field.name'    => 'Hello world.',
                  'language.radio.value' => 'French',
                  'my.checkbox.value'    => 'On',   # 'On' / 'Off'
                 });
  $fdf->save or print $fdf->errmsg;
  $fdf->save ('otherfile.fdf');
  my $fdfcontent = $fdf->load;
  $fdfcontent = $fdf->load ($fdfstring);
  print $fdf->{'organisation'};
  print $fdf->{'dotted.field.name'};
  print $fdf->as_string;
  print "Corresponding PDF (attribute /F): ".$fdf->attribute_file."\n";
  print "IDs (attribute /ID): ";
  print $_ foreach @{$fdf->attribute_id}; print "\n";

=head1 DESCRIPTION

Helps creating and extracting the content of FDF files. It is meant to
be a simple replacement for the Adobe FdfToolkit. Therefore some of
it's behavior, especially handling of diverse whitespace/newline
artefacts is orientated on FdfToolkit's handling.

After the extraction process the content is available within a hash
reference.

For creating FDF files it currently only supports setting text
values. Anyway, this should be enough to create FDF files for text
fields, text areas, checkboxes and radio buttons.

PDF::FDF::Simple uses Parse::RecDescent and understands both, the
"Kids" notation and the "dotted" notation for field names. Saving will
always use the "dotted"- notation.

=head2 Text fields / Text areas

Text fields and text areas are simply filled with the given text.

=head2 Radio button groups

In a radio button group the entry that matches exactly the field value
is selected. The entries and their values are defined in the PDF where
the FDF is loaded into.

=head2 Checkboxes

In the PDF document into which the FDF is loaded a checkbox field is
set to checked/unchecked with field values 'On' or 'Off',
respectively.

=head1 API Methods

=head2 new

Constructor. Takes a hash reference for arguments.

=head2 skip_undefined_fields

Option, default is 0. If set to a true value (e.g., 1), then fields
whose value is undefined are not contained in generated fdf. By
default undefined field values are converted to empty string ('').

=head2 filename

Get/set target filename (string).

=head2 content

Get/set content of fields (hashref).

=head2 attribute_file

Get/set the corresponding PDF filename of the form.
This method corresponds to the /F attribute in FDF content.

=head2 attribute_ufile

Get/set the corresponding PDF filename of the form.  This method
corresponds to the /UF attribute in FDF content. It is not perfectly
clear whether the /UF means the same as /F. It was used when Acrobat 8
appeared, but it seems to be not documented. I named it just "ufile"
due to lack of better knowledge.

=head2 attribute_id

Get/set the list (array reference) of form IDs.
This method corresponds to the /ID attribute in FDF content.

=head2 load

Load an existing FDF file named via C<filename> and stores the
information in a hashref (see also C<content>).

An optional parameter can be given that contains FDF content. In that
case it is not read from file C<filename>.

=head2 save (optional_filename)

Save the FDF content into a file, using either the directly given
C<optional_filename> parameter or (if C<optional_filename> is not
given) the filename that was set via C<filename>.

=head2 as_string

Returns the FDF content as scalar string, so you can work with it
without the need to save into file.

=head2 errmsg

Get/set error message. Will be set internally when an error
occured. Just read it, setting it is useless.


=head1 Internal Methods

Those methods are used internally and can be overwritten in derived
classes. You shouldn't use them directly.

=head2 _pre_init

Overwritable method for setting default values for initialization
before overtaking constructor params.

=head2 _post_init

Overwritable method for setting default values for initialization
after overtaking constructor params and building Parse::RecDescent
grammar.

=head2 init

Takes over the values from the given constructor hash.

=head2 _fdf_header

Returns a string which will be written before all field data.

=head2 _fdf_footer

Returns a string which will be written after all field data.

=head2 _quote

Does all quoting for field value strings.

=head2 _fdf_field_formatstr

Returns a format string for use in sprintf that creates key/value
pairs.

=head2 _map_parser_output

Puts the Parse::RecDescent output from a nested hash into a simple
hash and returns its reference.

=head1 A COMMENT ABOUT PARSING

For whose who are interested, the grammar doesn't implement a fully
PDF or FDF specification (FDF is just a subset of PDF). The approach
is rather pragmatic. It only searches for /Fields and tries to ignore
the surrounding rest. This "works for me" (TM) but it doesn't
guarantee that all possible FDFs can be parsed. If you have a strange
FDF that cannot be parsed please send it to me with the expected
content description or extend the parser by yourself and send me a
patch.
