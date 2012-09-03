package Build::Simple::Node;

use Moo;

has phony => (
	is => 'ro',
);

has skip_mkdir => (
	is => 'ro',
	default   => sub {
		my $self = shift;
		return $self->phony;
	},
);

has dependencies => (
	is => 'ro',
	default => sub { [] },
);

has action => (
	is => 'ro',
	default => sub { sub {} },
);

1;

#ABSTRACT: A Build::Simple node

__END__

