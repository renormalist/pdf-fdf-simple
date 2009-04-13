package PDF::FDF::Simple;

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

$VERSION = '0.18';

#Parse::RecDescent environment variables: enable for Debugging
#$::RD_TRACE = 1;
#$::RD_HINT  = 1;

sub new {
  my $class = shift;
  my %DEFAULTS = (
                  errmsg                => '',
                  skip_undefined_fields => 0,
                  parser                => new Parse::RecDescent (
       q(
	 {
		use Compress::Zlib;

		# Local variable init - RJH
		my $strname;
		my $strcontent;
		my $fh = new IO::File;

		# RJH Can't include standard Perl in the parser so define a function
		# here so it's included in its namespace
		sub write_file
		{
			my($file,$content) = @_;

			my $x = inflateInit()
			      or die "Cannot create a inflation stream\n";
			$fh->open(">$file") or die "Failed to create file $file - $!";

			my $buffer = $$content;
			my $sync = $x->inflateSync($buffer);
			print "SYNC: $sync\n";

			my($output, $status) = $x->inflate($buffer);
			print "STATUS:$status\n";
			print $fh $output;
			$fh->close();
		};
	}
         startrule : docstart objlist xref(?) 'trailer' '<<' '/Root' objreference /[^>]*/ '>>' /.*/
                     {
                       $PDF::FDF::Simple::deferred_result_FDF_OPTIONS = {};
                       $return = $item{objlist};
                     }

         xref : 'xref' /\d+/ /\d+/ xrefentry(s)

         xrefentry : /\d+/ /\d+/ /[fn]/

         docstart : /%FDF-[0-9]+\.[0-9]+/ garbage
                  | # empty

         garbage : /%[^0-9]*/
                 | # empty

         objlist : obj objlist
                   {
                     push ( @{$return}, $item{obj}, @{$item{objlist}} );
                   }
                 | # empty
                   {
                      $return = [];
                   }

         obj : /\d+/ /\d+/ 'obj' objbody 'endobj'
               {
                 $return = $item{objbody};
               }

         objbody : '<<' '/FDF' '<<' attributes '/Fields' '[' fieldlist ']' attributes '>>' '>>'
                   {
                     $return = $item{fieldlist};
                   }
                 | '[' fieldlist ']'
                   {
                     $return = $item{fieldlist};
                   }
                 | '<<' '/FDF' '<<' attributes '/Fields' objreference attributes '>>' '>>'
                   {
                     $return = [];
                   }
                 | '<<' '/F' filename '/EF' '<<' '/F' objreference '>>' '/Type/Filespec' '>>'
                   {
			$::strname = $item[3];
			$::strcontent = ''; # clear ready for next file
                     $return = [];
                   }
		| '<<' '/Length' m#\d+# filter(?) subtype(?) params(?) dl(?) stream
		   {
			#print "STRNAME = $::strname\nSTRCONTENT = $::strcontent\n";
			# RJH don't write until FlateDecode developed
			#&write_file($::strname,\$::strcontent);
			
                     $return = [];
		   }
		| '<<' '/StemV' m#\d+# stemparams stemstream
		   {
			$return = [];
		   }

	stemparams : stemparam stemparams
		| # empty

	stemparam : '/' m#\w+#

	stemstream : streamcont 'endstream'
		{
		  $return = $item[1];
		}

	dl : '/DL' m#\d+# '>>'

	filename : '(' name ')'
		{
			$return = $item[2];
		}

# RJH
	stream : 'stream' streamcont 'endstream'
               {
		 $return = $item[2];
		 1;
               }

	streamcont : streamline streamcont
		{
			$return = $item[1];
		}
		| # empty

	streamline : ...!'endstream' m#.*#
		{
			$::strcontent .= $item[2];
			$return = $item[2];
		}
	
	filter : '/Filter' filtertype

	filtertype : '/FlateDecode'

	subtype : '/Subtype' '/application#2Fpdf'

	params : '/Params' '<<' paramlist '>>'

	paramlist : param paramlist
		| # empty

	param : paramname paramvalue(?)

	paramname : '/' m#\w+#

	paramvalue : '(' m#[^\)]*# ')'
		| '<' m#\w*# '>'
		| m#\w+#



         objreference : /\d+/ /\d+/ 'R'

         fieldlist : field fieldlist
                     {
                       push ( @{$return}, $item{field}, @{$item{fieldlist}} );
                     }
	 # TODO: How do I optimize the next two alternatives,
	 #       which in fact execute the same code?
	 #       Can the code block be written only once?
                   | '<<' fieldname kids '>>' fieldlist
                     {
                       my $fieldlist;
                       foreach my $ref ( @{$item{kids}} ) {
                         my %kids = %{$ref};
                         foreach my $key (keys %kids) {
                           push (@{$fieldlist},{$item{fieldname}.".".$key=>$kids{$key}});
                         }
                       }
                       push ( @{$return}, @{$fieldlist}, @{$item{fieldlist}} );
                     }
                   | '<<' kids fieldname '>>' fieldlist
                     {
                       my $fieldlist;
                       foreach my $ref ( @{$item{kids}} ) {
                         my %kids = %{$ref};
                         foreach my $key (keys %kids) {
                           push (@{$fieldlist},{ $item{fieldname}.".".$key=>$kids{$key}});
                         }
                       }
                       push ( @{$return}, @{$fieldlist}, @{$item{fieldlist}} );
                     }
                   | # empty
                     {
                      $return = [];
                     }

         kids : '/Kids' '[' fieldlist ']'
                {
                  $return = $item{fieldlist};
                }

         field : '<<' fieldname fieldvalue '>>'
                 {
                   $return = { $item{fieldname} => $item{fieldvalue} };
                 }
               | '<<' fieldvalue fieldname '>>'
                 {
                   $return = { $item{fieldname} => $item{fieldvalue} };
                 }
               | '<<' fieldname '>>'
                 {
                   $return = { $item{fieldname} => undef };
                 }

         fieldvalue : '/V' '(' <skip:""> value <skip:$item[3]> ')'
                      {
                        $return = $item{value};
                        $return =~ s/\\\\(\d{3})/sprintf ("%c", oct($1))/eg;         # handle octal
                        #$return =~ s/\\#([0-9A-F]{2})/sprintf ("%c",  hex($1))/eg;   # handle hex
                      }
                    | '/V' '[' valarray ']'
                      {
                        $return = $item{valarray};
                      }
                    | '/V' feature
                      {
                        $return = substr ($item{feature}, 1);
                        $return =~ s/\\\\(\d{3})/sprintf ("%c", oct($1))/eg;         # handle octal
                        $return =~ s/\\#([0-9A-F]{2})/sprintf ("%c",  hex($1))/eg;   # handle hex
                      }
# RJH
		    | '/V' objreference

         feature :  m!/[^\s/>]*!

         fieldname : '/T' '(' name ')'
                     {
                        $return = $item{name};
                        $return =~ s/\\\\(\d{3})/sprintf ("%c", oct($1))/eg;         # handle octal
                        $return =~ s/\\#([0-9A-F]{2})/sprintf ("%c",  hex($1))/eg;   # handle hex
                     }

         valarray : '(' <skip:""> value <skip:$item[2]> ')' valarray
                      {
                        push @{$return}, $item{value}, @{$item{valarray}};
                      }
                      | # empty
                      { $return = []; }

	 value : valuechar value
             {
               $return = $item{valuechar}.$item{value};
             }
           | # empty
             {
               $return = "";
             }

	 # This handles different whitespace artefacts that exist
	 # in this world and handles them similar to FDFToolkit.
	 # (Remember: backslashes must be doubled within a Parse::RecDescent grammar,
	 # except if they occur single.)
         valuechar : '\\\\\\\\'
                     {
                       $return = chr(92);
                     }
                   | '\\\\#'
                     {
                      $return = "#";
                     }
                   | '\\\\\\\\r'
                     {
                       $return = '\r';
                     }
                   | '\\\\\\\\t'
                     {
                       $return = '\t';
                     }
                   | '\\\\\\\\n'
                     {
                       $return = '\n';
                     }
                   | '\\\\\r'
                     {
                       $return = '';
                     }
                   | '\\\\\n'
                     {
                       $return = '';
                     }
                   | '\\\\r'
                     {
                       $return = chr(13);
                     }
                   | '\\\\n'
                     {
                       $return = chr(10);
                     }
                   | '\r'
                     {
                       $return = '';
                     }
                   | '\t'
                     {
                       $return = "\t";
                     }
                   | ''
                     {
                       $return = chr(10);
                     }
                   | '\\\\'
                     {
                       $return = '';
                     }
                   | /\n/
                     {
                       $return = '';
                     }
                   |  m/\\\\/ m/\n/
                     {
                       $return = ''
                     }
                   | '\\\\('
                     {
                       $return = '(';
                     }
                   | '\\\\)'
                     {
                       $return = ')';
                     }
	 # The next two rules work closely together:
	 #
	 # - the first matches every *single* character 
	 #   that is in the exclude list of the second rule.
	 #
	 # - the second rule matches blocks of
	 #   successive "non-problematic" characters
	 #
	 #   (All the "problematic" chars and chains of them
	 #   are already handled in the rules above.)
                   | /[\r\t\n\\\\ ]/
                     {
                       $return = $item[1];
                     }
                   | /([^()\r\t\n\\\\ ]+)/
                     {
                       $return = $item[1];
                     }

         attributes : '/F' '(' <skip:""> value <skip:$item[3]> ')' attributes
                      <defer: $PDF::FDF::Simple::deferred_result_FDF_OPTIONS->{F} = $item[4];>
                      {
                        $return = $item{value};
                      }
                    | '/UF' '(' <skip:""> value <skip:$item[3]> ')' attributes
                      <defer: $PDF::FDF::Simple::deferred_result_FDF_OPTIONS->{UF} = $item[4];>
                      {
                        $return = $item{value};
                      }
                    | '/ID' '[' idnum(s?) ']' attributes
                    | # empty

         name : /([^\)][\s]*)*/   # one symbol but not \)

         idnum : '<' /[\w]*/ '>'
                 <defer: push (@{$PDF::FDF::Simple::deferred_result_FDF_OPTIONS->{ID}}, $item[1].$item[2].$item[3]); >
               | '(' idnumchars ')'
                 <defer: push (@{$PDF::FDF::Simple::deferred_result_FDF_OPTIONS->{ID}}, $item[1].$item{idnumchars}.$item[3]); >

         idnumchar : '\\\\\)'
                     { $return = $item[1]; }
                   | '\\\\\('
                     { $return = $item[1]; }
                   | /[^()]/
                     { $return = $item[1]; }

         idnumchars : idnumchar idnumchars
                      {
                        $return = $item{idnumchar}.$item{idnumchars};
                      }
                    | # empty
                      {
                        $return = "";
                      }

        )),
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
  return "<< /T (%s) /V (%s) >>\n"
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
