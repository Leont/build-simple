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

sub run {
	my ($self, $name, $graph, $options) = @_;
	if (!$self->phony) {
		my @files = grep { !$graph->_is_phony($_) } sort @{ $self->dependencies };
		return if -e $name and List::MoreUtils::none { not -e $_ or (not -d $_ and -M $name > -M $_) } @files;
	}
	File::Path::mkpath(File::Basename::dirname($name)) if !$self->skip_mkdir;
	$self->action->(name => $name, dependencies => $self->dependencies, %{$options});
	return;
}

1;

#ABSTRACT: A Build::Simple node

=begin Pod::Coverage

run

=end Pod::Coverage
