HLL-Expression-Grammar
==================

Synopsis
----

```raku
# A simple calculator
# - integer and decimal values
# - arithimetic infix: + - * /
# - prefix: + -
# - parenthesised (circumfix) subexpressions
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
    my %additive       = :$slack, :assoc<left>;  # + - (infix)
    $slack++;

    token prefix:sym<+>  { <sym> <O(|%unary)> }
    token prefix:sym<->  { <sym> <O(|%unary)> }
    token infix:sym<+>   { <sym> <O(|%additive)> }
    token infix:sym<->   { <sym> <O(|%additive)> }
    token infix:sym<*>   { <sym> <O(|%multiplicative)> }
    token infix:sym</>   { <sym> <O(|%multiplicative)> }

    # Parenthesis
    token circumfix:sym<( )> { '(' ~ ')' <EXPR> <O(|%methodop)> }

    # terms
    token term:sym<circumfix> {:s <circumfix> }
    token term:sym<value> { <value> }

    # values
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

        method circumfix:sym<( )>($/)  { make $<EXPR>.ast.head.&calc }

        method term:sym<value>($/)     { make $<value>.ast }
        method term:sym<circumfix>($/) { make $<circumfix>.ast }

        method value:sym<number>($/)   { make $<num>.ast }

        method integer($/) { make $/.Int }
        method decimal-number($/) { make $/.Rat }

        multi sub calc(% (:$infix!, :$left!, :$right!)) {
            my $l = $left.&calc;
            my $r = $right.&calc;
            given $infix {
                when '+'  { $l + $r }
                when '-'  { $l - $r }
                when '*'  { $l * $r }
                when '/'  { $l / $r }
                default { fail "Unhandled infix operator: {.raku}" }
            }
        }
        multi sub calc(% (:$prefix!, :$operand!)) {
            my $v = $operand.&calc;
            given $prefix {
                when '+' { + $v }
                when '-' { - $v }
                default { fail "Unhandled prefix operator: {.raku}" }
            }
        }
        multi sub calc($v) { $v }
    }
}

# Some sample calculations
for ("4+2+36", "-42", "4.2", "2++40", "2 + 3 * 5",
     "(2+3)*5", "8/2", "((4*3)-(3*2))",) -> $expr {
    my Calculator::Actions $actions .= new;
    Calculator.parse($expr, :$actions);
    say "$expr = " ~ $/.ast;
}
```

Description
------

Simple, minimalist  grammar/actions roles for defining high-level language expressions, notably:

- `term`s & `value`s
- `prefix`, `infix`, `postfix` and `circumfix` operators.
- precedence rules

Under construction. For further examples, please see `t/01-sample-calculator.t`.

AUTHOR
======

David Warring <david.warring@gmail.com>

COPYRIGHT AND LICENSE
=====================

Copyright 2026 David Warring

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.
