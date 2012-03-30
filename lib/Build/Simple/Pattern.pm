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
	coerce => sub {
		my $arg = shift;
		return $arg if ref($arg) eq 'CODE';
		if (ref($arg) eq 'ARRAY') {
			my ($pattern, $replacement) = @{$arg};
			return sub {
				my $filename = shift;
				$filename =~ s/$pattern/$replacement/;
				return $filename
			};
		}
	},
	required => 1,
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
