package Build::Simple::Pattern;

use Mo qw/default required coerce/;
use File::Basename qw/basename/;
use Text::Glob qw/glob_to_regex/;

has pattern => (
	required => 1,
	coerce => sub {
		return glob_to_regex($_[0]);
	}
);

has skip_mkdir => (
	default   => sub {
		my $self = shift;
		return $self->phony;
	},
);

has subst => (
	default => sub { [] },
);

has action => (
	required => 1,
);

sub match {
	my ($self, $filename) = @_;
	if (basename($filename) =~ $self->pattern) {
		my @dependencies = $self->subst->($filename);
		return Build::Simple::Node->new(dependencies => \@dependencies, action => $self->action, phony => 0);
	}
	return;
}

1;

#ABSTRACT: A Build::Simple pattern

__END__

=begin Pod::Coverage

match

=end Pod::Coverage
