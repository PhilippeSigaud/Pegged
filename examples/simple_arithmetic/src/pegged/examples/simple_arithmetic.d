/**
This module contains a simple example of a arithmetic expression grammar and
how use the ParseTree to calculate a expression.
*/
module pegged.examples.simple_arithmetic;

import std.conv: to;

import pegged.grammar;
import pegged.defaultparsetree : ParseTree = DefaultParseTree;
mixin(grammar(`
Arithmetic:
    Term     < Factor (Add / Sub)*
    Add      < "+" Factor
    Sub      < "-" Factor
    Factor   < Primary (Mul / Div)*
    Mul      < "*" Primary
    Div      < "/" Primary
    Primary  < Parens / Neg / Number / Variable
    Parens   < :"(" Term :")"
    Neg      < "-" Primary
    Number   < ~([0-9]+)
    Variable <- identifier
`));

/// Example interpreter
float interpreter(string expr)
{
    auto p = Arithmetic(expr);

    // Travels the ParseTree, calculting the expresion value
    float value(ParseTree p)
    {
        switch (p.name)
        {
            case "Arithmetic":
                return value(p.children[0]);
            case "Arithmetic.Term":
                float v = 0.0;
                foreach(child; p.children) v += value(child);
                return v;
            case "Arithmetic.Add":
                return value(p.children[0]);
            case "Arithmetic.Sub":
                return -value(p.children[0]);
            case "Arithmetic.Factor":
                float v = 1.0;
                foreach(child; p.children) v *= value(child);
                return v;
            case "Arithmetic.Mul":
                return value(p.children[0]);
            case "Arithmetic.Div":
                return 1.0/value(p.children[0]);
            case "Arithmetic.Primary":
                return value(p.children[0]);
            case "Arithmetic.Parens":
                return value(p.children[0]);
            case "Arithmetic.Neg":
                return -value(p.children[0]);
            case "Arithmetic.Number":
                return to!float(p.matches[0]);
            default:
                return float.nan;
        }
    }

    return value(p);
}

unittest
{
    assert(interpreter("1") == 1.0);
    assert(interpreter("-1") == -1.0);
    assert(interpreter("1+1") == 2.0);
    assert(interpreter("1-1") == 0.0);

    assert(interpreter("1+1+1") == 3.0);
    assert(interpreter("1-1-1") == -1.0);
    assert(interpreter("1+1-1") == 1.0);
    assert(interpreter("1-1+1") == 1.0);
    assert(interpreter("-1+1+1") == 1.0);

    assert(interpreter("(-1+1)+1") == 1.0);
    assert(interpreter("-1+(1+1)") == 1.0);
    assert(interpreter("(-1+1+1)") == 1.0);
    assert(interpreter("1-(1-1)") == 1.0);

    assert(interpreter("1*1") == 1.0);
    assert(interpreter("1/1") == 1.0);
    assert(interpreter("-1*1") == -1.0);
    assert(interpreter("-1/1") == -1.0);

    assert(interpreter("1+2*3") == 7.0);
    assert(interpreter("1-2*3") == -5.0);
    assert(interpreter("-1-2*-3") == 5.0);
    assert(interpreter("-1+2*-3") == -7.0);

    assert(interpreter("1/2/(1/2)") == 1.0);
    assert(interpreter("1/2/1/2") == .25);
    assert(interpreter("1 - 2*3 - 2*3") == -11.0);

    assert(interpreter("2*3*3 - 3*3+3*4") == 21.0);
    assert(interpreter("2 * 3 * 3 - 3 * (3 + 3 * 4)") == -27.0);
}
