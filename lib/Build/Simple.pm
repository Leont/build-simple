package Build::Simple;

use Moo;

use Carp;
use File::Path;
use List::MoreUtils;

use Build::Simple::Node;
use Build::Simple::Pattern;

has _nodes => (
	is => 'ro',
	default => sub { {} },
);

sub _get_node {
	my ($self, $key) = @_;
	return $self->_nodes->{$key};
}

sub has_file {
	my ($self, $key) = @_;
	return exists $self->_nodes->{$key};
}

sub add_file {
	my ($self, $name, %args) = @_;
	Carp::croak("File '$name' already exists in database") if !$args{override} && $self->_get_node($name);
	my $node = Build::Simple::Node->new(%args, phony => 0);
	$self->_nodes->{$name} = $node;
	push @{ $self->_get_node($_)->dependencies }, $name for @{ $args{dependents} };
	return;
}

sub add_phony {
	my ($self, $name, %args) = @_;
	Carp::croak("Phony '$name' already exists in database") if !$args{override} && $self->_get_node($name);
	my $node = Build::Simple::Node->new(%args, phony => 1);
	$self->_nodes->{$name} = $node;
	push @{ $self->_get_node($_)->dependencies }, $name for @{ $args{dependents} };
	return;
}

has _patterns => (
	is => 'ro',
	default => sub { [] },
);

sub add_pattern {
	my ($self, $pattern, %args) = @_;
	push @{ $self->_patterns }, Build::Simple::Pattern->new(%args, pattern => $pattern);
	return;
}

sub _match_pattern {
	my ($self, $filename) = @_;
	for my $pattern (@{ $self->_patterns }) {
		my $node = $pattern->match($filename);
		return $node if $node;
	}
	return;
}

sub _node_sorter {
	my ($self, $current, $callback, $seen, $loop) = @_;
	Carp::croak("$current has a circular dependency, aborting!\n") if exists $loop->{$current};
	return if $seen->{$current}++;
	my $node = $self->_get_node($current) || $self->_match_pattern($current) or -f $current ? return : Carp::croak("Node $current doesn't exist");
	local $loop->{$current} = 1;
	$self->_node_sorter($_, $callback, $seen, $loop) for @{ $node->dependencies };
	$callback->($current);
	return;
}

sub _sort_nodes {
	my ($self, $startpoint) = @_;
	my @ret;
	$self->_node_sorter($startpoint, sub { push @ret, $_[0] }, {}, {});
	return @ret;
}

sub _is_phony {
	my ($self, $key) = @_;
	my $node = $self->_get_node($key);
	return $node ? $node->phony : 0;
}

sub _run_node {
	my ($self, $node_name, $options) = @_;
	my $node = $self->_get_node($node_name) || $self->_match_pattern($node_name);
	die "Node for $node_name if not defined" if not defined $node;
	if (!$node->phony) {
		my @files = grep { !$self->_is_phony($_) } sort @{ $node->dependencies };
		return if -e $node_name and List::MoreUtils::none { not -e $_ or (!-d $_ and -M $node_name > -M $_) } @files;
	}
	File::Path::mkpath(File::Basename::dirname($node_name)) if !$node->skip_mkdir;
	$node->action->(name => $node_name, dependencies => $node->dependencies, %{$options});
}

sub run {
	my ($self, $startpoint, %options) = @_;
	$self->_node_sorter($startpoint, sub { $self->_run_node($_[0], \%options) }, {}, {});
	return;
}

1;

#ABSTRACT: A minimalistic dependency system

__END__

=head1 DESCRIPTION

Build::Simply is a simple but effective dependency engine. It tries to support 

=method add_file($filename, %options)

Add a file to the build graph. It can take the following options:

=over 4

=item * action

A subref to the action that needs to be performed.

=item * dependencies

The nodes the action depends on. Defaults to an empty list.

=item * skip_mkdir

Block C<mkdir(dirname($filename))> from being executed before the action. Defaults to false.

=back

=method add_phony($filename, %options)

Add a phony dependency to the graph. It takes the same options as add_file does, except that skip_mkdir defaults to true.

=method run($goal, %options)

Make all of C<$goal>'s dependencies, and then C<$goal> itself.

=method exists($filename)

Returns true if a node exists in the graph, returns false otherwise.

=begin Pod::Coverage

add_pattern
has_file

=end Pod::Coverage
