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

multi reduce-op(@expr, $pos, 'postcircumfix', :op($postfix)!) {
    my $expression = @expr[$pos]<oper><expr>:delete.head;
    my $operand  = @expr.splice($pos-1, 1).head;
    @expr[$pos-1] = %( :$postfix, :$operand, :$expression );
}

multi reduce-op(@expr, $pos, 'infix', :op($infix)!) {
    my $right = @expr.splice($pos+1, 1).head;
    my $left  = @expr.splice($pos-1, 1).head;
    @expr[$pos-1] = %( :$infix, :$left, :$right );
}

multi reduce-op(@expr, $pos, 'ternary', :op($ternary)!) {
    my $right = @expr.splice($pos+1, 1).head;
    my $mid   = @expr[$pos]<oper><expr>:delete.head;
    my $left  = @expr.splice($pos-1, 1).head;
    @expr[$pos-1] = %( :$ternary, :$left, :$mid, :$right );
}

sub reduce-expr(@expr, :$prec = Inf) {
    # find the next loosest precedence
    given @expr.grep({.does(Associative) && .<oper> && .<oper><slack> < $prec}).map(*<oper><slack>).max -> $prec {
        if $prec >= 0 {
            # reduce any inner higher precedence operations
            @expr.&reduce-expr(:$prec);
            # factor operations at this precedence level
            while (my @opns = @expr.grep: {.does(Associative) && .<oper> && .<oper><slack> == $prec}, :p) {
                my Pair $opn = @opns.head.value<oper><assoc> ~~ 'unary'|'left'
                                ?? @opns.shift
                                !! @opns.pop;
                given $opn.value<oper> {
                    my $op = .<op>;
                    @expr.&reduce-op($opn.key, .<type>, :$op);
                }
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
    make %( :$*slack, :$*assoc, :$*op );
}

method EXPR(Capture $/) {
    my @EXPR;
    @EXPR.append: .value.ast for $/.caps;
    @EXPR.&reduce-expr;
    make @EXPR;
}

multi method infixish($/ where $<OPER><EXPR>) {
    my %oper = $<OPER><O>.ast;
    %oper<type> = 'ternary';
    %oper<op> //= $<OPER>.Str; 
    %oper<expr> = $<OPER><EXPR>.ast;
   make (:%oper);
}

multi method infixish($/) {
    my %oper = $<OPER><O>.ast;
    %oper<type> = 'infix';
    %oper<op> //= $<OPER>.Str;
    make (:%oper);
}

method prefixish($/) {
    my %oper = $<OPER><O>.ast;
    %oper<type> = 'prefix';
    %oper<op> //= $<OPER>.Str;
    make (:%oper);
}

multi method postfixish($/ where $<OPER><EXPR>) {
    my %oper = $<OPER><O>.ast;
    %oper<type> = 'postcircumfix';
    %oper<op> //= $<OPER>.Str;
    %oper<expr> = $<OPER><EXPR>.ast;
    make (:%oper);
}

multi method postfixish($/) {
    my %oper = $<OPER><O>.ast;
    %oper<type> = 'postfix';
    %oper<op> //= $<OPER>.Str;
    make (:%oper);
}
