package SOAP::Data::Builder;

# Copyright (c) 2003 Surrey Technologies, Ltd ( http://www.surreytech.co.uk )

# This Module provides a quick and easy way to build complex SOAP data
# and header structures for use with SOAP::Lite.

# It primarily provides a wrapper around SOAP::Serializer and SOAP::Data
# (or SOAP::Header) enabling you to generate complex XML within your SOAP
# request or response.

=head1 NAME

  SOAP::Data::Builder - A wrapper simplifying SOAP::Data and SOAP::Serialiser

=head1 DESCRIPTION

  This Module provides a quick and easy way to build complex SOAP data
  and header structures for use with SOAP::Lite.
 
  It primarily provides a wrapper around SOAP::Serializer and SOAP::Data
  (or SOAP::Header) enabling you to generate complex XML within your SOAP
  request or response.

=head1 SYNOPSIS

use SOAP::Lite ( +trace => 'all', maptype => {} );

use SOAP::Data::Builder;

# create new Builder object
my $soap_data_builder = SOAP::Data::Builder->new();

#<eb:MessageHeader eb:version="2.0" SOAP:mustUnderstand="1">
$soap_data_builder->add_elem(name => 'eb:MessageHeader', header=>1, attributes => {"eb:version"=>"2.0", "SOAP::mustUnderstand"=>"1"});

#   <eb:From>
#        <eb:PartyId>uri:example.com</eb:PartyId>
#        <eb:Role>http://rosettanet.org/roles/Buyer</eb:Role>
#   </eb:From>
$soap_data_builder->add_elem(name=>'eb:From', parent=>$soap_data_builder->get_elem('eb:MessageHeader'));
$soap_data_builder->add_elem(name=>'eb:PartyId', parent=>$soap_data_builder->get_elem('eb:MessageHeader/eb:From'), 
                             value=>'uri:example.com');
$soap_data_builder->add_elem(name=>'eb:Role',
                             parent=>$soap_data_builder->get_elem('eb:MessageHeader/eb:From'), 
                             value=>'http://path.to/roles/foo');

#   <eb:DuplicateElimination/>
$soap_data_builder->add_elem(name=>'eb:DuplicateElimination', parent=>$soap_data_builder->get_elem('eb:MessageHeader'));


# fetch Data
my $data =  SOAP::Data->name('SOAP:ENV' =>
			     \SOAP::Data->value( $soap_data_builder->to_soap_data )
			      );

# serialise Data using SOAP::Serializer
my $serialized_xml = SOAP::Serializer->autotype(0)->serialize( $data );

# serialise Data using wrapper
my $wrapper_serialised_xml = $soap_data_builder->serialise();

# make SOAP request with data

my $foo  = SOAP::Lite
    -> uri('http://www.liverez.com/SoapDemo')
    -> proxy('http://www.liverez.com/soap.pl')
    -> getTest( $soap_data_builder->to_soap_data )
    -> result;


=cut

use SOAP::Lite ( +trace => 'all', maptype => {} );

use Data::Dumper;
use strict;

our $VERSION = "0.2";

=head1 METHODS

=head2 new(autotype=>0)

Constructor method for this class, it instantiates and returns the Builder object,
taking named options as parameters

my $builder = SOAP::Data::Builder->new( autotype=>0 ); # new object with no autotyping

supported options are autotype which switches on/off SOAP::Serializers autotype

=cut

sub new {
    my ($class,%args) = @_;

    my $self = { elements => [], };
    bless ($self,ref $class || $class);
    foreach my $key (keys %args) {
      $self->{options}{$key} = $args{$key};
    }

    return $self;
}

=head2 serialise()

Wrapper for SOAP::Serializer (sic), serialises the contents of the Builder object
and returns the XML as a string

# serialise Data using wrapper
my $wrapper_serialised_xml = $soap_data_builder->serialise();

This method does not accept any arguments

NOTE: serialise is spelt properly using the King's English

=cut

sub serialise {
  my $self = shift;
  my $data =  SOAP::Data->name('SOAP:ENV' =>
			       \SOAP::Data->value( $self->to_soap_data )
			      );
  my $serialized = SOAP::Serializer->autotype($self->autotype)->serialize( $data );
}

=head2 autotype()

returns whether the object currently uses autotype when serialising

=cut

sub autotype {
  return shift->{options}{autotype} || 0;
}

=head2 to_soap_data()

  returns the contents of the object as a list of SOAP::Data and/or SOAP::Header objects

  NOTE: make sure you call this in array context!

=cut

sub to_soap_data {
  my $self = shift;
  warn "sub : to_soap_data called\n";
  my @data = ();
  foreach my $elem ( $self->elems ) {
    push(@data,$self->get_as_data($elem,1));
  }
  return @data;
}

# internal method

sub elems {
  my $self = shift;
  my @elems = @{$self->{elements}};
  return @elems;
}

=head1 add_elem(name=>'ns:Name')

This method adds an element to the structure, either to the root list
or a specified element.

optional parameters are : parent, value, attributes, header, isEntity

parent should be an element fetched using get_elem

value should be a string, to add child nodes use add_elem(parent=>get_elem('name/of/parent'), .. )

attributes should be a hashref : { 'ns:foo'=> bar, .. }

header should be 1 or 0 specifying whether the element should be built using SOAP::Data or SOAP::Header

=cut

sub add_elem {
  my ($self,%args) = @_;
  my $elem = {
	      name => $args{name},
	      attr => {},
	      value => [ ],
	     };
  $elem->{isMethod} = $args{isMethod} || 0;
  $elem->{header} = $args{header} || 0;
  $elem->{attr} = $args{attributes}, if ( $args{attributes}, );
  $elem->{value} = [ $args{value} ] if ( $args{value} );
  if ( $args{parent} ) {
    push(@{$args{parent}{value}},$elem);
    warn "added new sub elem ($args{name}) to elem ($args{parent}{name})\n";
#    warn "dump : ", Dumper($args{parent}), "\n";
  } else {
    push(@{$self->{elements}},$elem);
  }
}

=head2 get_elem('ns:elementName')

returns an element (which is an internal data structure rather than an object)

returns the first element with the name passed as an argument,
sub elements can be referred to as 'grandparent/parent/element'

This structure is passed to other object methods and may change in behaviour, 
type or structure without warning as the class is developed

=cut

sub get_elem {
  my ($self,$name) = (@_,'');
  warn "get_elem ($name)\n";
  my ($a,$b);
  my @keys = split (/\//,$name);
  warn "have keys : ", join (', ',@keys), "\n";
  foreach my $elem ( $self->elems) {
#    warn "handling elem : $elem->{name} - matching against $keys[0]\n";
    if ($elem->{name} eq $keys[0]) {
      $a = $elem;
      $b = shift(@keys);
#      warn " found match : $elem->{name} / key : $b \n";
      last;
    }
  }

#  warn "still have keys : ", join (', ',@keys), "\n";

  my $elem = $a;
  while ($b = shift(@keys) ) {
#    warn "fetching with subkey $b\n";
    $elem = $self->find_elem($elem,$b,@keys);
  }

#  warn "returning element :\n", Dumper($elem), "\n";

  return $elem;
}

# internal method

sub find_elem {
  warn "find_elem ..\n";
  my ($self,$parent,$key,@keys) = @_;
  my ($a,$b);
  warn "have key : $key \n";
#  warn "have keys : ", join (', ',@keys), "\n";
#  warn "parent : ", Dumper( $parent ), "\n";
  foreach my $elem ( @{$parent->{value}}) {
    next unless ref $elem;
#    warn "handling elem : $elem->{name} - matching against $key\n";
    if ($elem->{name} eq $key) {
      $a = $elem;
      $b = $key;
#      warn " found match : $elem->{name} / key : $b \n";
      last;
    }
  }

#  warn "still have keys : ", join (', ',@keys), "\n";

  my $elem = $a;
  while ($b = shift(@keys) ) {
#    warn "fetching sub key $b\n";
    $elem = $self->find_elem($elem,$b,@keys);
  }
  return $elem;
}

# internal method

sub get_as_data {
  my ($self,$elem) = @_;
  warn "-- sub : get_as_data called with $elem->{name}\n"; 
  my @values;
  foreach my $value ( @{$elem->{value}} ) {
    warn "-- -- value : $value ";
    if (ref $value) {
      warn " ..is ref\n";
      push(@values,$self->get_as_data($value))
    } else {
      warn " ..is scalar\n";
      push(@values,$value);
    }
  }

  my @data = ();

  warn "\n##################\n values : \n ";
  warn Dumper(@values);
  warn "\n##################\n ";

  if (ref $values[0]) {
    $data[0] = \SOAP::Data->value( @values );
  } else {
    @data = @values;
  }

  if ($elem->{header}) {
    $data[0] = SOAP::Header->name($elem->{name} => $data[0])->attr($elem->{attr});
  } else {
    if ($elem->{isMethod}) {
      @data = ( SOAP::Data->name($elem->{name} )->attr($elem->{attr}) => SOAP::Data->value( @values ) );
    } else {
      $data[0] = SOAP::Data->name($elem->{name} => $data[0])->attr($elem->{attr});
    }
  }

  return @data;
}


#############################################################################
#############################################################################

1;
