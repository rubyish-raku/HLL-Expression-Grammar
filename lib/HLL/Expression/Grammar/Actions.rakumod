unit role HLL::Expression::Grammar::Actions;

use Method::Also;

multi reduce-op(@expr, $pos, 'prefix', :op($prefix)!) {
    my $operand = @expr.splice($pos+1, 1).head;
    @expr[$pos] = %( :$prefix, :$operand );
}

multi reduce-op(@expr, $pos, 'postfix', :op($postfix)!) {
    my $operand = @expr.splice($pos-1, 1).head;
    @expr[$pos-1] = %( :$postfix, :$operand );
}

multi reduce-op(@expr, $pos, 'infix', :op($infix)!) {
    my $right = @expr.splice($pos+1, 1).head;
    my $left  = @expr.splice($pos-1, 1).head;
    @expr[$pos-1] = %( :$infix, :$left, :$right );
}

sub reduce-expr(@expr, :prec($prev-prec) = Inf) {
    # find the loosest precedence
    my $prec = @expr.grep({.<oper> && .<oper><slack> < $prev-prec}).map(*<oper><slack>).max;
    if $prec >= 0 {
        # reduce any inner higher precedence operations
        @expr.&reduce-expr(:$prec);
        # factor operations at this precedenced level
        while (my @opns = @expr.grep: {.<oper> && .<oper><slack> == $prec}, :p) {
            my Pair $opn = @opns.head.value<oper><assoc> ~~ 'unary'|'left'
                             ?? @opns.shift
                             !! @opns.pop;
            given $opn.value<oper> {
                my $op = .<op>;
                @expr.&reduce-op($opn.key, .<type>, :$op);
            }
        }
    }

    @expr;
}

method termish($/) {
    my @terms;
    @terms.append: @<prefixish>>>.ast;
    @terms.push: $<term>.ast;
    @terms.append: @<postfixish>>>.ast;
    make @terms;
}

method O($/) {
    make %( :$*slack, :$*assoc );
}

method EXPR(Capture $/) {
    my @EXPR;
    @EXPR.append: .value.ast for $/.caps;
    @EXPR.&reduce-expr;
    make @EXPR;
}

method infixish($/) {
    my %oper = $<OPER><O>.ast;
    %oper<op> = $<OPER>.Str;
    %oper<type> = 'infix';
    make (:%oper);
}

method prefixish($/) {
    my %oper = $<OPER><O>.ast;
    %oper<op> = $<OPER>.Str;
    %oper<type> = 'prefix';
    make (:%oper);
}

method postfixish($/) {
    my %oper = $<OPER><O>.ast;
    %oper<op> = $<OPER>.Str;
    %oper<type> = 'postfix';
    make (:%oper);
}
