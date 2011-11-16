package Build::Simple::Node;

use Mo qw/default required/;

has 'phony';

has skip_mkdir => (
	default   => sub {
		my $self = shift;
		return $self->phony;
	},
);

has dependencies => (
	default => sub { [] },
);

has action => (
	default => sub { sub {} },
);

1;

__END__

#ABSTRACT: A Build::Simple node

