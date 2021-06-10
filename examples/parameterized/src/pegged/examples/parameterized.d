module pegged.examples.parameterized;

import pegged.grammar;

/**
 * Example of parameterized rules. Pick and chose the ones you need.
 */
enum parameterizedExamples = `
Parameterized:

# Standard list: skip spaces, drop the separator
# Minimum one Elem
List(Elem, Sep) < Elem (:Sep Elem)*

# A list accepting 0 element as a valid input
List0(Elem, Sep) < List(Elem, Sep)?

# Standard comma-separated list
CommaList(Elem) < List(Elem, ',')

# Standard space-separated list
SpaceList(Elem) < List(Elem, ' ')

# Standard array rule: [1, 2, ... ].
Array(Elem) < :'[' List0(Elem, ',') :']'


# Apply Pattern until End
Until(Pattern, End) <- (!End Pattern)* :End

# Everything but the End marker. Concatenates the entire match
But(End) <~ Until(., End)

# Input delimited by a begin and a close marker
Delimited(Begin, Close) <- :Begin But(Close)

# Standard double-quoted string
String <- Delimited(doublequote, doublequote)

# Line (everything to the end of the line)
Line <- Delimited(eps, endOfLine)

# Line comment
LineComment <- Delimited(:"//", endOfLine)
`;

mixin(grammar(parameterizedExamples));

unittest
{
    mixin(grammar("
    ParamTest1:
        A <- Parameterized.List(identifier, ',')
    "));

    assert(ParamTest1("abc, def, ghi").successful);
    assert(ParamTest1("abc, def, ghi").matches == ["abc", "def", "ghi"]);
    assert(ParamTest1("abc, def, ").successful);
    assert(ParamTest1("abc, def, ").matches == ["abc", "def"]);
    assert(ParamTest1("abc,      def, ghi").successful);
    assert(ParamTest1("abc,      def, ghi").matches == ["abc", "def", "ghi"]);
    assert(ParamTest1("abc,").successful);
    assert(ParamTest1("a").successful);
    // stops before the end:
    assert(ParamTest1("abc,, def, ghi").successful);
    assert(ParamTest1("abc,, def, ghi").matches == ["abc"]);
    // not lists:
    assert(!ParamTest1("").successful);
    assert(!ParamTest1(",abc, def, ghi").successful);

    mixin(grammar("
    ParamTest2:
        A <- Parameterized.List(identifier, ' ')
    "));

    assert(ParamTest2("abc def ghi").successful);
    assert(ParamTest2("abc def ").successful);
    assert(ParamTest2("abc      def ghi").successful);
    assert(ParamTest2("abc ").successful);
    assert(ParamTest2("a").successful);
    // not lists:
    assert(!ParamTest2("").successful);
    assert(!ParamTest2("  ").successful);

    mixin(grammar("
    ParamTest3:
        A <- Parameterized.Array( ~[0-9]+ )
    "));

    assert(ParamTest3("[1]").successful);
    assert(ParamTest3("[]").successful);
    assert(ParamTest3("[1, 2, 3]").successful);
    assert(ParamTest3("[1, 2, 3]").matches == ["1", "2", "3"]);
    assert(ParamTest3("[123,456,789]").successful);
    assert(ParamTest3("[123,456,789]").matches == ["123", "456", "789"]);
    // not arrays:
    assert(!ParamTest3("[1,2,]").successful, "Trailing comma.");
    assert(!ParamTest3("[1,,2,3]").successful, "Two commas in a row.");
    assert(!ParamTest3("[1,2,3").successful, "Missing closing ']'.");
    assert(!ParamTest3("1,2,3]").successful, "Missing opening '['.");
    assert(!ParamTest3("[,]").successful, "No numbers in array.");

    mixin(grammar("
    ParamTest4:
        A <- Parameterized.String
    "));

    assert(ParamTest4(`"abc"`).matches == [`abc`]);
    assert(ParamTest4(`""`).matches == []);

    mixin(grammar("
    ParamTest5:
        A <- Parameterized.LineComment
    "));

    auto p5 = ParamTest5("// This is a comment!
    This is not a comment.
    End.");
    assert(p5.successful);
    assert(p5.matches == [" This is a comment!"]);
}
