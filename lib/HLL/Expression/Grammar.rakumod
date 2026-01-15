unit role HLL::Expression::Grammar;

proto token term { <...> }
proto token prefix { <...> }
proto token infix(|c) { <...> }
proto token postfix { <...> }
proto token circumfix { <...> }
proto token postcircumfix { <...> }

token O(:$*slack!, :$*assoc!, :$*op) { <?> }

multi token EXPR {
    <termish> *% <infixish>
}

token termish {:s <prefixish>* <term> <postfixish>* }

token infixish {:s <OPER=.infix> }
token prefixish {:s <OPER=.prefix> }
token postfixish {:s
      <OPER=.postfix>
    | <OPER=.postcircumfix>
}
