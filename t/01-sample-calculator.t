use Test;

# A simple calculator
# - integer values
# - arithimetic infix: + - * /
# - prefix: + -
# - factorial postfix: !
# - circumfix subexpressions
grammar Calculator {
    use HLL::Expression::Grammar;
    also does HLL::Expression::Grammar;

    token TOP {
        ^ ~ $ <EXPR> || <.panic('Syntax error')>
    }
    my $slack = 0;
    my %methodop       = :$slack, :assoc<unary>; # method call
    $slack++;
    my %unary          = :$slack, :assoc<unary>; # + - (unary)
    $slack++;
    my %multiplicative = :$slack, :assoc<left>;  # * /
    $slack++;
    my %additive       = :$slack, :assoc<left>;  # + -

    rule separator       { ';' | \n }
    rule stmtlist { [ <stmt>? ] *%% <.separator> }
    token prefix:sym<+>  { <sym> <O(|%unary)> }
    token prefix:sym<->  { <sym> <O(|%unary)> }
    token postfix:sym<!> { <sym> <O(|%unary)> }
    token infix:sym<+>   { <sym> <O(|%additive)> }
    token infix:sym<->   { <sym> <O(|%additive)> }
    token infix:sym<*>   { <sym> <O(|%unary)> }
    token infix:sym</>   { <sym> <O(|%unary)> }
    # Parenthesis
    token circumfix:sym<( )> { '(' ~ ')' <EXPR> <O(|%methodop)> }
    token term:sym<circumfix> {:s <circumfix> }
    token term:sym<value> { <value> }

    proto token value {*}
    token value:sym<number> { <num=.integer> | <num=.decimal-number> }
    # todo check reference implementations
    token integer { \d+ }
    token decimal-number { \d* '.' \d* }

    method panic($err) { die $err }

    class Actions {
        use HLL::Expression::Grammar::Actions;
        also does HLL::Expression::Grammar::Actions;

        method TOP($/)  {
            make $<EXPR>.ast.head.&calc;
        }

        method value:sym<number>($/) { make $<num>.ast }
        method term:sym<value>($/)   { make $<value>.ast }
        method circumfix:sym<( )>($/)  { make $<EXPR>.ast.head.&calc }
        method term:sym<circumfix>($/) {
            make $<circumfix>.ast
        }

        method integer($/) { make $/.Int }
        method decimal-number($/) { make $/.Rat }

        multi sub calc(% (:$infix!, :$left!, :$right!)) {
            my $v1 = calc $left;
            my $v2 = calc $right;
            given $infix {
                when '+' { $v1 + $v2 }
                when '-' { $v1 - $v2 }
                when '*' { $v1 * $v2 }
                when '/' { $v1 / $v2 }
                default { fail "Unhandled infix operator: {.raku}" }
            }
        }
        multi sub calc(% (:$prefix!, :$operand!)) {
            my $v = calc $operand;
            given $prefix {
                when '+' { + $v }
                when '-' { - $v }
                default { fail "Unhandled prefix operator: {.raku}" }
            }
        }
        multi sub calc(% (:$postfix!, :$operand!)) {
            my $v = calc $operand;
            given $postfix {
                when '!' { $v.&factorial }
                default { fail "Unhandled postfix operator: {.raku}" }
            }
        }
        multi sub calc($v) { $v }

        multi sub factorial(1) { 1 }
        multi sub factorial(UInt:D $n) { $n * factorial($n - 1) }
    }
}

 subtest "parse sanity", {
     for "4!" => 24, "4!+-3" => 21, "4+2+36" => 42, "-42" => -42, "4.2" => 4.2, "2++40" => 42, "(2+3)!"=> 120, "2 + 3 * 5" => 17, "(2+3)*5" => 25, "8/2" => 4.0, "((4*3)-(3*2))" => 6 {
         my $expr = .key;
         my $expected-result = .value;
         my Calculator::Actions $actions .= new;
         subtest $expr, {
             ok Calculator.parse($expr, :$actions), "parse";
             is-deeply $/.ast, $expected-result, "calculation";
         }
    }
}

done-testing();

    
