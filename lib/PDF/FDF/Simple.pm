package PDF::FDF::Simple;

use strict;
use warnings;

use vars qw($VERSION $deferred_result_FDF_OPTIONS);
use Data::Dumper;
use Parse::RecDescent;

$VERSION = '0.11';

#Parse::RecDescent environment variables: enable for Debugging
#$::RD_TRACE = 1;
#$::RD_HINT  = 1;

use Class::MethodMaker
 get_set => [
             'skip_undefined_fields',
             'filename',
             'content',
             'errmsg',
             'parser',
             'attribute_file',
             'attribute_ufile',
             'attribute_id',
            ],
 new_with_init => 'new',
 new_hash_init => 'hash_init',
 ;

sub _pre_init {
  my $self = shift;
  $self->errmsg ('');
  $self->skip_undefined_fields (0);
}

# setting up grammar
sub _post_init {
  my $self = shift;

  my $recdesc = new Parse::RecDescent (
       q(
         startrule : docstart objlist 'trailer' '<<' '/Root 1 0 R' '>>' /.*/
                      {
			$PDF::FDF::Simple::deferred_result_FDF_OPTIONS = {};
                        $return = $item{objlist};
                      }
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
                        $return =~ s/\\#([0-9A-F]{2})/sprintf ("%c",  hex($1))/eg;   # handle hex
                      }
                    | '/V' feature
                      {
                        $return = substr ($item{feature}, 1);
                        $return =~ s/\\\\(\d{3})/sprintf ("%c", oct($1))/eg;         # handle octal
                        $return =~ s/\\#([0-9A-F]{2})/sprintf ("%c",  hex($1))/eg;   # handle hex
                      }

         feature :  m!/[^\s/>]*!

         fieldname : '/T' '(' name ')'
                     {
                        $return = $item{name};
                        $return =~ s/\\\\(\d{3})/sprintf ("%c", oct($1))/eg;         # handle octal
                        $return =~ s/\\#([0-9A-F]{2})/sprintf ("%c",  hex($1))/eg;   # handle hex
                     }

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
               | '(' /([^()])*/ ')'
	         <defer: push (@{$PDF::FDF::Simple::deferred_result_FDF_OPTIONS->{ID}}, $item[1].$item[2].$item[3]); >

        ));

  $self->parser ($recdesc);
}

sub init {
  my $self = shift;
  $self->_pre_init(@_);
  $self->hash_init(@_);
  $self->_post_init(@_);
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
  my $output = $self->parser->startrule ($filecontent);

  # take over parser results
  $self->attribute_file ($PDF::FDF::Simple::deferred_result_FDF_OPTIONS->{F});   # /F
  $self->attribute_ufile ($PDF::FDF::Simple::deferred_result_FDF_OPTIONS->{UF}); # /UF
  $self->attribute_id ($PDF::FDF::Simple::deferred_result_FDF_OPTIONS->{ID});    # /ID
  $self->content ($self->_map_parser_output ($output));
  $self->errmsg ("Corrupt FDF file!\n") unless $self->content;

  return $self->content;
}

1;
