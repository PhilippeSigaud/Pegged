/**
   This module contains the engine behind Pegged, the expression templates building blocks to create a top-down
   recursive-descent parser.

   The terminals and non-terminals described here are meant to be used inside a Pegged grammar.
   As such, they are a bit less user-friendly than what's output by pegged.grammar.
   For example they take a ParseTree as input, not a string.

   See the /docs directory for the full documentation as markdown files.
*/
module pegged.peg;

/*
  NOTE:
  Do not use the GrammarTester for unittesting in this module.  This module needs
  to be able to pass its unittests before the GrammarTester is even trustable.
  Writing tests the long way is preferred here, as it will avoid the circular
  dependency.
*/

import std.algorithm: equal, map, startsWith, max, countUntil, maxElement, filter;
import std.uni : isAlpha, icmp;
import std.array;
import std.conv;
import std.string: strip;
import std.typetuple;
import pegged.parsetree : isParseTree;
import std.exception : assumeUnique;

// Returns quoted and escaped version of the input, but if the input is null, then return `"end of input"`.
string stringified(string inp) @safe
{
    import std.format : format;

    if (inp is null)
        return `"end of input"`;

    string[1] shell = [inp];
    return "%(%s%)".format(shell);
}

@safe unittest // Run- & Compile-time.
{
    static bool doTest()
    {
        const caseSuit1 = [
            "" : `""`,

            "\0" : `"\0"`,
            "\n" : `"\n"`,
            "\t" : `"\t"`,

            `"` : `"\""`,
            "`" : q{"`"},
            "'" : `"'"`,

            "42"              : `"42"`,
            "\"some text\"\n" : `"\"some text\"\n"`
            ];

        const caseSuit2 = [cast(string)null : `"end of input"`];

        const auto testSuit = [caseSuit1, caseSuit2];

        foreach (const ref suit; testSuit)
        {
            foreach (const ref value, const ref expected; suit)
            {
                import std.format : format;

                const result = value.stringified;
                assert(result == expected, "from %s expected %s but got %s".format(value, expected, result));
            }
        }

        return true;
    }

    // Result is always true, but here, we just force CTFE-mode.
    doTest;                // Run-time.
    static assert(doTest); // Compile-time.
}

struct GetName {}

string getName(alias expr)() @property
{
    static if (is(typeof( { expr(GetName()); })))
        return expr(GetName());
    else
        return __traits(identifier, expr);
}

/// To compare two trees for content (not bothering with node names)
/// That's useful to compare the results from two different grammars.
bool softCompare(ParseTree)(const ParseTree p1, const ParseTree p2) @safe if (isParseTree!ParseTree) {
    return p1.successful == p2.successful
        && p1.matches == p2.matches
        && p1.begin == p2.begin
        && p1.end == p2.end
        && equal!(softCompare)(p1.children, p2.children); // the same for children
}

/**
   Predefined parser: matches word boundaries, as \b for regexes.
*/
ParseTree wordBoundary(ParseTree)(const ParseTree p) @safe if (isParseTree!ParseTree) {
    // TODO: I added more indexing guards and now this could probably use
    //         some simplification.  Too tired to write it better. --Chad
    bool matched =  (p.end == 0 && isAlpha(p.input.front()))
        || (p.end == p.input.length && isAlpha(p.input.back()))
        || (p.end > 0 && isAlpha(p.input[p.end-1])  && p.end < p.input.length && !isAlpha(p.input[p.end]))
        || (p.end > 0 && !isAlpha(p.input[p.end-1]) && p.end < p.input.length &&  isAlpha(p.input[p.end]));
    if (matched)
        return ParseTree("wordBoundary", matched, [], p.input, p.end, p.end, null);
    else
        return ParseTree("wordBoundary", matched, ["word boundary"], p.input, p.end, p.end, null);
}


/**
   CT Switch for testing 'keywords' implementations
*/
enum
{
    IFCHAIN,
    TRIE
}
enum KEYWORDS = IFCHAIN;

/// To record a position in a text
struct Position
{
    size_t line;/// line number (starts at 0)
    size_t col;/// column number (starts at 0)
    size_t index;/// index (starts at 0)
}

/**
   Given an input string, returns the position corresponding to the end of the string.

   For example:
   ---
   assert(position("abc") == Position(0,3,3));
   assert(position("abc
   ") == Position(1,0,4));
   assert(position("abc

   ") == Position(2,4,8));
   ---
*/
Position position(string s) @safe
{
    size_t col, line, index, prev_i;
    char prev_c;
    foreach(i,c; s)
    {
        if ((c == '\n' && !(i == prev_i + 1 && prev_c == '\r')) ||  // new line except when directly following a carriage return.
            c == '\r')
        {
            col = 0;
            ++line;
            ++index;
            prev_i = i;
            prev_c = c;
        }
        else
        {
            if (c != '\n')
                ++col;
            ++index;
        }
    }

    return Position(line,col,index);
}


/**
   Same as previous overload, but from the begin of P.input to p.end
*/
Position position(ParseTree)(const ParseTree p) @safe if(isParseTree!ParseTree)
{
    return position(p.input[0..p.end]);
}

@safe unittest
{
    assert(position("") == Position(0,0,0), "Null string, position 0.");
    assert(position("abc") == Position(0,3,3), "length 3 string, no line feed.");
    assert(position("abc
") == Position(1,0,4), "One end of line.");
    assert(position("abc

----") == Position(2,4,9), "Three lines (second one empty).");
    assert(position("abc
----
----") == Position(2,4,13), "Three lines.");
    assert(position("


") == Position(3,0,3), "Four lines, all empty.");
    assert(position("one\r\ntwo\r\nthree") == Position(2, 5, 15), "Three lines, DOS line endings");
}


struct PeggedT(ParseTree) {

//    import pegged.peg : fail, eoi, wordBoundary, eps;
//    mixin ParseCollections!ParseTree;
    version (tracer)
        {
            import std.experimental.logger;
            import std.algorithm.comparison : min;

            // Function pointers.
            private static bool function(string ruleName, const ref ParseTree p) traceConditionFunction;
            private static bool delegate(string ruleName, const ref ParseTree p) traceConditionDelegate;
            private static int traceLevel;
            private static bool traceBlocked;
            private static bool logTraceLevel = false;

            private void incTraceLevel()
            {
                if (!__ctfe)
                    traceLevel++;
            }

            private void decTraceLevel()
            {
                if (!__ctfe)
                    traceLevel--;
            }

            private bool shouldTrace(string ruleName, const ref ParseTree p)
            {
                if (__ctfe || traceBlocked)
                    return false;
                if (traceConditionDelegate != null)
                    return traceConditionDelegate(ruleName, p);
                if (traceConditionFunction != null)
                    return traceConditionFunction(ruleName, p);
                return false;
            }

            static this()
            {
                traceLevel = 0;
                traceNothing();
                traceBlocked = false;
            }

            /++ Supply a function to dynamically switch tracing on and off based on the rule name.
             +
             + Example:
             + ---
             + /* Exclude build-in parsers, only trace parsers generated from MyGrammar. */
             + setTraceConditionFunction(ruleName => ruleName.startsWith("MyGrammar"));
             + ---
             +/
            static void setTraceConditionFunction(bool delegate(string ruleName, const ref ParseTree p) condition)
            {
                traceConditionDelegate = condition;
                traceConditionFunction = null;
            }

            /// ditto
            static void setTraceConditionFunction(bool function(string ruleName, const ref ParseTree p) condition)
            {
                traceConditionFunction = condition;
                traceConditionDelegate = null;
            }

            /** Trace all rules.
             *
             * This can produce a lot of output.
             */
            static void traceAll()
            {
                setTraceConditionFunction(function(string ruleName, const ref ParseTree p) {return true;});
            }

            /** Do not trace any rules. */
            static void traceNothing()
            {
                traceConditionFunction = null;
                traceConditionDelegate = null;
            }

            private static string traceMsg(const ParseTree p, string expression, string name)
            {
                import std.format;
                Position pos = position(p);
                enum inputLength = 15;
                string result;
                for (auto i = 1; i <= traceLevel; i++)
                    result ~= format("%d|", i);
                result ~= format(" (l:%d, c:%d, i:%d)\t", pos.line + 1, pos.col + 1, pos.index) ~
                    expression.stringified ~ " considering rule " ~ name.stringified ~ " on " ~
                    p.input[p.end .. min(p.input.length, p.end + inputLength)].stringified ~
                    (p.end + inputLength > p.input.length ? "" : "...");
                return result;
            }

            private static string traceResultMsg(const ParseTree p, string name)
            {
                import std.format;
                import std.range: chain;
                import std.algorithm.iteration: joiner;
                Position pos = position(p);
                enum inputLength = 15;
                string result;
                for (auto i = 1; i <= traceLevel; i++)
                    result ~= format("%d|", i);
                if (p.successful)
                {
                    string consumed;
                    foreach (match; p.matches)
                        consumed ~= match;
                    result ~= format(" (l:%d, c:%d, i:%d)\t", pos.line + 1, pos.col + 1, pos.index) ~ name.stringified ~ " SUCCEEDED on " ~
                        consumed.stringified;
                }
                else
                    result ~= format(" (l:%d, c:%d, i:%d)\t", pos.line + 1, pos.col + 1, pos.index) ~ name.stringified ~ " FAILED on " ~
                        p.input[p.end .. min(p.input.length, p.end + inputLength)].stringified ~
                        (p.end + inputLength > p.input.length ? "" : "...");
                return result;
            }

            /**
               Overrides FileLogger to remove the time stamp.

               Example:
               ---
               sharedLog = new TraceLogger("TraceLog.txt");
               ---
            */
            static class TraceLogger : FileLogger
            {
                this(in string fn) @safe
                    {
                        super(fn);
                    }
                import std.concurrency : Tid;
                import std.datetime : SysTime;
                override protected void beginLogMsg(string file, int line, string funcName,
                    string prettyFuncName, string moduleName, LogLevel logLevel,
                    Tid threadId, SysTime timestamp, Logger logger)
                    @safe
                    {
                    }
            }
        }

//    alias endOfInput = PEG.eoi; /// helper alias.
    static ParseTree wordBoundary(string input)
        {
            return ParseTree("wordBoundary", isAlpha(input.front()), [], input, 0,0, null);
        }

/// ditto
    static string wordBoundary(GetName g)
        {
            return "wordBoundary";
        }

}

version(unittest) {
    private {
        private import pegged.defaultparsetree : DefaultParseTree;
        private alias ParseTree = DefaultParseTree;
        private import PEG=pegged.parsetree;
//        mixin ParseCollections!ParseTree;
//        private alias PEG=PeggedT!ParseTree;
//        mixin DefaultParsePatterns!PEG;
    }
}

@safe unittest // ParseTree testing
{
    ParseTree p;
    assert(p == p, "Self-identity on null tree.");

    p = ParseTree("Name", true, ["abc", "", "def"], "input", 0, 1, null);
    assert(p == p, "Self identity on non-null tree.");

    ParseTree child = ParseTree("Child", true, ["abc", "", "def"], "input", 0, 1, null);
    p.children = [child, child];

    assert(p.children[0] == p[0], "override opIndex allows to write less verbose code to navigate the tree");
    assert(p.children == p[] );
    assert(p.children[0..1] == p[0..1] );
    assert(p.children[0..$] == p[0..$] );

    ParseTree q = p;
    assert(p == q, "Copying creates equal trees.");

    assert(p.children == q.children);
    p.children = [child, child, child];
    assert(q.children != p.children, "Disconnecting children.");

    p = ParseTree("Name", true, ["abc", "", "def"], "input", 0, 1, null);
    p.children = [child, child];

    q = p.dup;
    assert(p == q, "Dupping creates equal trees.");

    assert(p.children == q.children, "Equal children for dupped trees.");
    p.children = null;
    assert(q.children != p.children);

    immutable iq = p.idup;
    q = iq.dup;
    assert(p == q, "Dupping to/from immutable creates equal trees.");

    q.children = [p,p];
    assert(p != q, "Tree with different children are not equal.");

    p.children = [p,p];
    assert(p == q, "Adding equivalent children is OK.");

    p.matches = null;
    assert(p != q, "Nulling matches makes trees unequal.");

    p.matches = q.matches;
    assert(p == q, "Copying matches makes equal trees.");

    p.children[0].successful = false;
    assert(p.children[0].failMsg == `Failure at line 0, col 1, after "i" expected "def", but got "nput"`);
    assert(p.children[1].failMsg == "Sucess");
    assert(p.failMsg == `Failure at line 0, col 1, after "i" expected "def", but got "nput"`);
}

@safe unittest // softCompare
{
    ParseTree p = ParseTree("Name", true, ["abc", "", "def"], "input", 0, 1, null);
    ParseTree child = ParseTree("Child", true, ["abc", "", "def"], "input", 0, 1, null);
    p.children = [child, child];

    ParseTree q = p;
    assert(p == q, "Copy => Equal trees.");
    assert(softCompare(p,q), "Copy => Trees equal for softCompare.");

    q.name = "Another One";
    assert(p != q, "Name change => non-equal trees.");
    assert(softCompare(p,q), "Name change => Trees equal for softCompare.");
}


@safe unittest // 'fail' unit test
{

    ParseTree input = ParseTree("input", true, [], "This is the input string.", 0,0, null);
    ParseTree result = ParseTree.fail(input);
    assert(result.name == "fail");
    assert(!result.successful, "'fail' fails.");
    assert(result.matches is null, "'fail' makes no match.");
    assert(result.input == input.input, "'fail' does not change the input.");
    assert(result.end == input.end, "'fail' puts the index after the previous parse.");
    assert(result.children is null, "'fail' has no children.");

    result = ParseTree.fail("This is the input string.");
    assert(!result.successful, "'fail' fails.");
}


@safe unittest // 'eoi' unit test
{
    ParseTree input = ParseTree("input", true, [], "This is the input string.", 0,0, null);
    ParseTree result = ParseTree.eoi(input);
    assert(result.name == "eoi");
    assert(!result.successful, "'eoi' fails on non-null string.");
    assert(result.matches == ["end of input"], "'eoi' error message.");
    assert(result.input == input.input, "'eoi' does not change the input.");
    assert(result.end == input.end, "'eoi' puts the index after the previous parse.");
    assert(result.children is null, "'eoi' has no children.");

    input = ParseTree("input", true, [], "", 0,0, null);
    result = ParseTree.eoi(input);
    assert(result.successful, "'eoi' succeeds on strings of length 0.");
    result = ParseTree.eoi("");
    assert(result.successful, "'eoi' succeeds on strings of length 0.");
    result = ParseTree.eoi(null);
    assert(result.successful, "'eoi' succeeds on null strings");
}


@safe unittest // 'any' unit test
{
    ParseTree input = ParseTree("input", true, [], "This is the input string.", 0,0, null);
    ParseTree result = ParseTree.any(input);

    assert(result.name == "any");
    assert(result.successful, "'any' succeeds on non-null strings.");
    assert(result.matches  == ["T"], "'any' matches the first char in an input.");
    assert(result.input == input.input, "'any' does not change the input.");
    assert(result.end == input.end+1, "'any' advances the index by one position.");
    assert(result.children is null, "'any' has no children.");

    result = ParseTree.any("a");
    assert(result.successful, "'any' matches on strings of length one.");
    assert(result.matches == ["a"], "'any' matches the first char in an input.");
    assert(result.input == "a", "'any' does not change the input.");
    assert(result.end == 1, "'any' advances the index by one position.");
    assert(result.children is null, "'any' has no children.");

    input = ParseTree("input", true, [], "", 0,0, null);

    result = ParseTree.any(input);
    assert(!result.successful, "'any' fails on strings of length 0.");
    assert(result.matches == ["any char"], "'any' error message on strings of length 0.");
    assert(result.end == 0, "'any' does not advance the index.");

    result = ParseTree.any("");
    assert(!result.successful, "'any' fails on strings of length 0.");
    assert(result.matches == ["any char"], "'any' error message on strings of length 0.");
    assert(result.end == 0, "'any' does not advance the index.");

    result = ParseTree.any(null);
    assert(!result.successful, "'any' fails on null strings.");
    assert(result.matches == ["any char"], "'any' error message on strings of length 0.");
    assert(result.end == 0, "'any' does not advance the index.");
}


@safe unittest // word boundary
{
    ParseTree input = ParseTree("", false, [], "This is a word.");
    auto wb = [// "This"
        cast(size_t)(0):true, 1:false, 2:false, 3:false, 4: true,
        // "is"
        5: true, 6:false, 7: true,
        // "a"
        8: true, 9:true,
        // "word"
        10:true, 11:false, 12:false, 13:false, 14:true,
        // "."
        15:false
        ];

    foreach(size_t index; 0 .. input.input.length)
    {
        input.end = index;
        ParseTree result = wordBoundary(input);

        assert(result.name == "wordBoundary");
        assert(result.successful == wb[index]); // true, false, ...
        // for errors, there is an error message
        assert(result.successful && result.matches is null || !result.successful);
        assert(result.begin == input.end);
        assert(result.end == input.end);
        assert(result.children is null);
    }
}


@safe unittest // 'eps' unit test
{
    ParseTree input = ParseTree("input", true, [], "abcdef", 0,0, null);

    ParseTree result = ParseTree.eps(input);

    assert(result.name == "eps");
    assert(result.successful, "'eps' succeeds on non-null inputs.");
    assert(result.matches  == [""], "'eps' matches '' at the beginning.");
    assert(result.input == input.input, "'eps' does not change the input.");
    assert(result.end == input.end+0, "'eps' does not advance the index.");
    assert(result.children is null, "'eps' has no children.");

    input.input = "";

    result = ParseTree.eps(input);
    assert(result.name == "eps");
    assert(result.successful, "'eps' succeeds on empty strings.");
    assert(result.matches  == [""], "'eps' matches '' at the beginning, even on empty strings.");
    assert(result.input == input.input, "'eps' does not change the input.");
    assert(result.end == input.end+0, "'eps' does not advance the index.");
    assert(result.children is null, "'eps' has no children.");
}



template eoiT(ParseTree) {
    @safe:
/**
   Matches the end of input. Fails if there is any character left.
*/
    ParseTree eoiT(ParseTree p) {
        if (p.end == p.input.length)
            return ParseTree("eoi", true, [], p.input, p.end, p.end);
        else
            return ParseTree("eoi", false, ["end of input"], p.input, p.end, p.end);
    }

/// ditto
    ParseTree eoiT(string input)
        {
            return eoiT(ParseTree("", false, [], input));
        }


    string eoiT(GetName g) @safe
        {
            return "eoi";
        }
}


template epsT(ParseTree) {
/**
   eps matches the empty string (usually denoted by the Greek letter 'epsilon') and always succeeds.
   It's equivalent to literal!"" (for example, it creates a match of [""]: one match, the empty string).
*/
    ParseTree epsT(const ParseTree p) {
        return ParseTree("eps", true, [""], p.input, p.end, p.end);
    }

    ParseTree epsT(string input)
        {
            return epsT(ParseTree("",false,[], input));
        }

    string epsT(GetName g)
        {
            return "eps";
        }
}


template anyT(ParseTree) {
    /**
       Match any character. As long as there is at least a character left in the input, it succeeds.
       Conversely, it fails only if called at the end of the input.
    */
    ParseTree anyT(ParseTree p) {
        if (p.end < p.input.length)
            return ParseTree("any", true, [p.input[p.end..p.end+1]], p.input, p.end, p.end+1);
        else
            return ParseTree("any", false, ["any char"], p.input, p.end, p.end);
    }


    /// ditto
    ParseTree anyT(string input)
        {
            return anyT(ParseTree("", false, [], input));
        }


    string anyT(GetName g) @safe
        {
            return "any";
        }
}

template failT(ParseTree) {
    /**
       Basic rule, that always fail without consuming.
    */
    ParseTree failT(ParseTree p) @safe {
        return ParseTree("fail", false, [], p.input, p.end, p.end, null);
    }



    ParseTree failT(string input)
        {
            return failT(ParseTree("", false, [], input));
        }


    string failT(GetName g) @safe
        {
            return "fail";
        }
}




/**
   Represents a literal in a PEG, like "abc" or 'abc' (or even '').
   It succeeds if a prefix of the input is equal to its template parameter and fails otherwise.
*/
template literalT(ParseTree, string s)
{
    enum name = "literal!(\""~s~"\")";

    ParseTree literalT(ParseTree p)
        {
            enum lit = "\"" ~ s ~ "\"";

            if (p.end+s.length <= p.input.length && p.input[p.end..p.end+s.length] == s)
                return ParseTree(name, true, [s], p.input, p.end, p.end+s.length);
            else {
                import std.algorithm : commonPrefix;
                import std.utf : byCodeUnit;
                auto prefix = p.input[p.end..$].byCodeUnit.commonPrefix(s.byCodeUnit);
                return ParseTree(name, false, [lit], p.input, p.end, p.end, null, p.end + prefix.length);
            }
        }

    ParseTree literalT(string input)
        {
            return literalT!(ParseTree, s)(ParseTree("", false, [], input));
        }


    string literalT(GetName g)
        {
            return name;
        }

}

@safe unittest // 'literal' unit test
{

    ParseTree input = ParseTree("input", true, [], "abcdef", 0,0, null);

    alias a = ParseTree.literal!"a";
    alias abc = ParseTree.literal!"abc";
    alias empty = ParseTree.literal!"";

    ParseTree result = a(input);

    assert(result.name == `literal!("a")`, "Literal name test.");
    assert(result.successful, "'a' succeeds on inputs beginning with 'a'.");
    assert(result.matches  == ["a"], "'a' matches the 'a' at the beginning.");
    assert(result.input == input.input, "'a' does not change the input.");
    assert(result.end == input.end+1, "'a' advances the index by one position.");
    assert(result.children is null, "'a' has no children.");

    result = a("abcdef");

    assert(result.successful, "'a' succeeds on inputs beginning with 'a'.");
    assert(result.matches  == ["a"], "'a' matches the 'a' at the beginning.");
    assert(result.input == input.input, "'a' does not change the input.");
    assert(result.end == input.end+1, "'a' advances the index by one position.");
    assert(result.children is null, "'a' has no children.");

    result = abc(input);

    assert(result.name == `literal!("abc")`, "Literal name test.");
    assert(result.successful, "'abc' succeeds on inputs beginning with 'abc'.");
    assert(result.matches  == ["abc"], "'abc' matches 'abc' at the beginning.");
    assert(result.input == input.input, "'abc' does not change the input.");
    assert(result.end == input.end+3, "'abc' advances the index by 3 positions.");
    assert(result.children is null, "'abc' has no children.");

    result = abc("abcdef");

    assert(result.successful, "'abc' succeeds on inputs beginning with 'abc'.");
    assert(result.matches  == ["abc"], "'abc' matches 'abc' at the beginning.");
    assert(result.input == input.input, "'abc' does not change the input.");
    assert(result.end == input.end+3, "'abc' advances the index by 3 positions.");
    assert(result.children is null, "'abc' has no children.");

    result = empty(input);

    assert(result.name == `literal!("")`, "Literal name test.");
    assert(result.successful, "'' succeeds on non-null inputs.");
    assert(result.matches  == [""], "'' matches '' at the beginning.");
    assert(result.input == input.input, "'' does not change the input.");
    assert(result.end == input.end+0, "'' does not advance the index.");
    assert(result.children is null, "'' has no children.");

    result = empty("abcdef");

    assert(result.successful, "'' succeeds on non-null inputs.");
    assert(result.matches  == [""], "'' matches '' at the beginning.");
    assert(result.input == input.input, "'' does not change the input.");
    assert(result.end == input.end+0, "'' does not advance the index.");
    assert(result.children is null, "'' has no children.");

    input.input = "bcdef";

    result = a(input);

    assert(!result.successful, "'a' fails on inputs not beginning with 'a'.");
    assert(result.matches == ["\"a\""], "'a' makes no match on 'bcdef'.");
    assert(result.input == input.input, "'a' does not change the input.");
    assert(result.end == input.end, "'a' does not advances the index on 'bcdef'.");
    assert(result.children is null, "'a' has no children.");

    result = abc(input);

    assert(!result.successful, "'abc' fails on inputs not beginning with 'abc'.");
    assert(result.matches == ["\"abc\""], "'abc' does no match on 'bcdef'.");
    assert(result.input == input.input, "'abc' does not change the input.");
    assert(result.end == input.end, "'abc' does not advance the index on 'bcdef'.");
    assert(result.children is null, "'abc' has no children.");

    result = empty(input);

    assert(result.successful, "'' succeeds on non-null inputs.");
    assert(result.matches == [""], "'' matches '' at the beginning.");
    assert(result.input == input.input, "'' does not change the input.");
    assert(result.end == input.end+0, "'' does not advance the index.");
    assert(result.children is null, "'' has no children.");

    input.input = "";

    result = a(input);

    assert(!result.successful, "'a' fails on empty strings.");
    assert(result.matches == ["\"a\""], "'a' does not match ''.");
    assert(result.input == input.input, "'a' does not change the input.");
    assert(result.end == input.end, "'a' does not advance the index on 'bcdef'.");
    assert(result.children is null, "'a' has no children.");

    result = abc(input);

    assert(!result.successful, "'abc' fails on empty strings.");
    assert(result.matches == ["\"abc\""], "'abc' does not match ''.");
    assert(result.input == input.input, "'abc' does not change the input.");
    assert(result.end == input.end, "'abc' does not advance the index on 'bcdef'.");
    assert(result.children is null, "'abc' has no children.");

    result = empty(input);

    assert(result.successful, "'' succeeds on empty strings.");
    assert(result.matches  == [""], "'' matches '' at the beginning, even on empty strings.");
    assert(result.input == input.input, "'' does not change the input.");
    assert(result.end == input.end+0, "'' does not advance the index.");
    assert(result.children is null, "'' has no children.");
}

/**
   Represents a case insensitive literal in a PEG, like "abc"i or 'abc'i (or even ''i).
   It succeeds if a case insensitive comparison of a prefix of the input and its template
   parameter yields no difference and fails otherwise.
*/
template caseInsensitiveLiteralT(ParseTree, string s)
{
    enum name = "caseInsensitiveLiteral!(\""~s~"\")";

    ParseTree caseInsensitiveLiteralT(ParseTree p)
        {
            enum lit = "\"" ~ s ~ "\"";
            if (p.end+s.length <= p.input.length && icmp(p.input[p.end..p.end+s.length], s) == 0)
                return ParseTree(name, true, [s], p.input, p.end, p.end+s.length);
            else
                return ParseTree(name, false, [lit], p.input, p.end, p.end);
        }

    ParseTree caseInsensitiveLiteralT(string input)
        {
            return caseInsensitiveLiteralT!(ParseTree, s)(ParseTree("", false, [], input));
        }


    string caseInsensitiveLiteralT(GetName g)
        {
            return name;
        }

}

@safe unittest // 'caseInsensitiveLiteral' unit test
{
    ParseTree input = ParseTree("input", true, [], "AbCdEf", 0,0, null);

    alias ParseTree.caseInsensitiveLiteral!"a" a;
    alias ParseTree.caseInsensitiveLiteral!"aBC" abc;
    alias ParseTree.caseInsensitiveLiteral!"" empty;

    ParseTree result = a(input);

    assert(result.name == `caseInsensitiveLiteral!("a")`, "caseInsensitiveLiteral name test.");
    assert(result.successful, "'a' succeeds on inputs beginning with 'A'.");
    assert(result.matches == ["a"], "'a' matches the 'A' at the beginning.");
    assert(result.input == input.input, "'a' does not change the input.");
    assert(result.end == input.end+1, "'a' advances the index by one position.");
    assert(result.children is null, "'a' has no children.");

    result = a("AbCdEf");

    assert(result.successful, "'a' succeeds on inputs beginning with 'A'.");
    assert(result.matches == ["a"], "'a' matches the 'A' at the beginning.");
    assert(result.input == input.input, "'a' does not change the input.");
    assert(result.end == input.end+1, "'a' advances the index by one position.");
    assert(result.children is null, "'a' has no children.");

    result = abc(input);

    assert(result.name == `caseInsensitiveLiteral!("aBC")`, "caseInsensitiveLiteral name test.");
    assert(result.successful, "'aBC' succeeds on inputs beginning with 'AbC'.");
    assert(result.matches == ["aBC"], "'AbC' matches 'aBC' at the beginning.");
    assert(result.input == input.input, "'aBC' does not change the input.");
    assert(result.end == input.end+3, "'aBC' advances the index by 3 positions.");
    assert(result.children is null, "'aBC' has no children.");

    result = abc("AbCdEf");

    assert(result.successful, "'aBC' succeeds on inputs beginning with 'AbC'.");
    assert(result.matches == ["aBC"], "'AbC' matches 'aBC' at the beginning.");
    assert(result.input == input.input, "'aBC' does not change the input.");
    assert(result.end == input.end+3, "'aBC' advances the index by 3 positions.");
    assert(result.children is null, "'aBC' has no children.");

    result = empty(input);

    assert(result.name == `caseInsensitiveLiteral!("")`, "caseInsensitiveLiteral name test.");
    assert(result.successful, "'' succeeds on non-null inputs.");
    assert(result.matches  == [""], "'' matches '' at the beginning.");
    assert(result.input == input.input, "'' does not change the input.");
    assert(result.end == input.end+0, "'' does not advance the index.");
    assert(result.children is null, "'' has no children.");

    result = empty("AbCdEf");

    assert(result.successful, "'' succeeds on non-null inputs.");
    assert(result.matches  == [""], "'' matches '' at the beginning.");
    assert(result.input == input.input, "'' does not change the input.");
    assert(result.end == input.end+0, "'' does not advance the index.");
    assert(result.children is null, "'' has no children.");

    input.input = "bCdEf";

    result = a(input);

    assert(!result.successful, "'a' fails on inputs not beginning with 'a' or 'A'.");
    assert(result.matches == ["\"a\""], "'a' makes no match on 'bCdEf'.");
    assert(result.input == input.input, "'a' does not change the input.");
    assert(result.end == input.end, "'a' does not advances the index on 'bCdEf'.");
    assert(result.children is null, "'a' has no children.");

    result = abc(input);

    assert(!result.successful, "'aBC' fails on inputs beginning with 'bCdEf'.");
    assert(result.matches == ["\"aBC\""], "'aBC' does no match on 'bCdEf'.");
    assert(result.input == input.input, "'aBC' does not change the input.");
    assert(result.end == input.end, "'aBC' does not advance the index on 'bCdEf'.");
    assert(result.children is null, "'aBC' has no children.");

    result = empty(input);

    assert(result.successful, "'' succeeds on non-null inputs.");
    assert(result.matches == [""], "'' matches '' at the beginning.");
    assert(result.input == input.input, "'' does not change the input.");
    assert(result.end == input.end+0, "'' does not advance the index.");
    assert(result.children is null, "'' has no children.");

    input.input = "";

    result = a(input);

    assert(!result.successful, "'a' fails on empty strings.");
    assert(result.matches == ["\"a\""], "'a' does not match ''.");
    assert(result.input == input.input, "'a' does not change the input.");
    assert(result.end == input.end, "'a' does not advance the index on 'bCdEf'.");
    assert(result.children is null, "'a' has no children.");

    result = abc(input);

    assert(!result.successful, "'aBC' fails on empty strings.");
    assert(result.matches == ["\"aBC\""], "'aBC' does not match ''.");
    assert(result.input == input.input, "'aBC' does not change the input.");
    assert(result.end == input.end, "'aBC' does not advance the index on 'bCdEf'.");
    assert(result.children is null, "'aBC' has no children.");

    result = empty(input);

    assert(result.successful, "'' succeeds on empty strings.");
    assert(result.matches  == [""], "'' matches '' at the beginning, even on empty strings.");
    assert(result.input == input.input, "'' does not change the input.");
    assert(result.end == input.end+0, "'' does not advance the index.");
    assert(result.children is null, "'' has no children.");

    input.input = "ÄöÜæØå";
    result = ParseTree.caseInsensitiveLiteral!"äÖüÆøÅ"(input);

    assert(result.successful, "Unicode characters are matched case insensitively.");
}

/**
   Represents a range of chars, from begin to end, included. So charRange!('a','z') matches
   all English lowercase letters. If fails if the input is empty or does not begin with a character
   between begin and end.

   If begin == end, it will match one char (begin... or end).

   begin > end is non-legal.
*/
template charRangeT(ParseTree, dchar begin, dchar end) if (begin <= end)
{
    enum name = "charRange!('"~to!string(begin)~"','" ~ to!string(end) ~ "')";

    ParseTree charRangeT(ParseTree p)
        {
            enum longname = "a char between '"~to!string(begin)~"' and '"~to!string(end)~"'";
            if (p.end < p.input.length && p.input[p.end] >= begin && p.input[p.end] <= end)
                return ParseTree(name, true, [p.input[p.end..p.end+1]], p.input, p.end, p.end+1);
            else
                return ParseTree(name, false, [longname], p.input, p.end, p.end);
        }

    ParseTree charRangeT(string input)
        {
            return .charRangeT!(ParseTree, begin, end)(ParseTree("",false,[],input));
        }

    string charRangeT(GetName g)
        {
            return name;
        }
}

@safe unittest // 'charRange' unit test
{
    ParseTree input = ParseTree("input", true, [], "abcdef", 0,0, null);

    alias aa = ParseTree.charRange!('a','a');
    alias ab = ParseTree.charRange!('a','b');
    alias az = ParseTree.charRange!('a','z');
    alias allChars = ParseTree.charRange!(dchar.min,dchar.max);
    alias ASCII = ParseTree.charRange!('\U00000000','\U000000FF');

    static assert(!__traits(compiles, {alias charRange!('z','a') za;}));

    ParseTree result = aa(input);

    assert(result.name == "charRange!('a','a')", "charRange name test.");
    assert(result.successful, "'a-a' succeeds on inputs beginning with 'a'.");
    assert(result.matches  == ["a"], "'a-a' matches the 'a' at the beginning.");
    assert(result.input == input.input, "'a-a' does not change the input.");
    assert(result.end == input.end+1, "'a-a' advances the index by one position.");
    assert(result.children is null, "'a-a' has no children.");

    result = ab("abcdef");

    assert(result.name == "charRange!('a','b')", "charRange name test.");
    assert(result.successful, "'a-b' succeeds on inputs beginning with 'a'.");
    assert(result.matches  == ["a"], "'a-b' matches the 'a' at the beginning.");
    assert(result.input == input.input, "'a-b' does not change the input.");
    assert(result.end == input.end+1, "'a-b' advances the index by one position.");
    assert(result.children is null, "'a-b' has no children.");

    result = az(input);

    assert(result.name == "charRange!('a','z')", "charRange name test.");
    assert(result.successful, "'a-z' succeeds on inputs beginning with 'abc'.");
    assert(result.matches  == ["a"], "'a-z' matches 'a' at the beginning.");
    assert(result.input == input.input, "'a-z' does not change the input.");
    assert(result.end == input.end+1, "'a-z' advances the index by one position.");
    assert(result.children is null, "'a-z' has no children.");

    input.input = "bcdef";

    result = aa(input);

    assert(!result.successful, "'a-a' fails on inputs not beginning with 'a'.");
    assert(result.matches == ["a char between 'a' and 'a'"], "'a-a' makes no match on 'bcdef'.");
    assert(result.input == input.input, "'a-a' does not change the input.");
    assert(result.end == input.end, "'a-a' does not advances the index on 'bcdef'.");
    assert(result.children is null, "'a-a' has no children.");

    result = ab(input);

    assert(result.successful, "'a-b' succeeds on inputs beginning with 'b'.");
    assert(result.matches == ["b"], "'a-b' matches on 'bcdef'.");
    assert(result.input == input.input, "'a-b' does not change the input.");
    assert(result.end == input.end+1, "'a-b' advances the index by one position'.");
    assert(result.children is null, "'a-b' has no children.");

    result = az(input);

    assert(result.successful, "'a-z' succeeds on 'bcdef'.");
    assert(result.matches == ["b"], "'a-z' matches 'b' at the beginning of 'bcdef'.");
    assert(result.input == input.input, "'a-z' does not change the input.");
    assert(result.end == input.end+1, "'a-z' advances the index by one position.");
    assert(result.children is null, "'a-z' has no children.");

    input.input = "";

    result = aa(input);

    assert(!result.successful, "'a-a' fails on empty strings.");
    assert(result.matches == ["a char between 'a' and 'a'"], "'a-a' does not match ''.");
    assert(result.input == input.input, "'a-a' does not change the input.");
    assert(result.end == input.end, "'a-a' does not advance the index on ''.");
    assert(result.children is null, "'a-a' has no children.");

    result = ab(input);

    assert(!result.successful, "'a-b' fails on empty strings.");
    assert(result.matches == ["a char between 'a' and 'b'"], "'a-b' does not match ''.");
    assert(result.input == input.input, "'a-b' does not change the input.");
    assert(result.end == input.end, "'a-b' does not advance the index on ''.");
    assert(result.children is null, "'a-b' has no children.");

    result = az(input);

    assert(!result.successful, "'a-z' fails on empty strings.");
    assert(result.matches == ["a char between 'a' and 'z'"], "'a-z' does not match ''.");
    assert(result.input == input.input, "'a-z' does not change the input.");
    assert(result.end == input.end, "'a-z' does not advance the index on ''.");
    assert(result.children is null, "'a-z' has no children.");

    input.input = "123";

    result = aa(input);

    assert(!result.successful, "'a-a' fails on '123'.");
    assert(result.matches == ["a char between 'a' and 'a'"], "'a-a' does not match '123'.");
    assert(result.input == input.input, "'a-a' does not change the input.");
    assert(result.end == input.end, "'a-a' does not advance the index on '123'.");
    assert(result.children is null, "'a-a' has no children.");

    result = ab(input);

    assert(!result.successful, "'a-b' fails on '123'.");
    assert(result.matches == ["a char between 'a' and 'b'"], "'a-b' does not match '123'.");
    assert(result.input == input.input, "'a-b' does not change the input.");
    assert(result.end == input.end, "'a-b' does not advance the index on '123'.");
    assert(result.children is null, "'a-b' has no children.");

    result = az(input);

    assert(!result.successful, "'a-z' fails on '123'.");
    assert(result.matches == ["a char between 'a' and 'z'"], "'a-z' does not match '123'.");
    assert(result.input == input.input, "'a-z' does not change the input.");
    assert(result.end == input.end, "'a-z' does not advance the index on '123'.");
    assert(result.children is null, "'a-z' has no children.");


    foreach(dchar ch; 0..256*(128+64+16+8))
        assert(allChars(to!string(ch)).successful);

    assert(!allChars("").successful);
}

/**
   Basic operator: it matches if all its subrules (stored in the rules template parameter tuple) match
   the input successively. Its subrules parse trees are stored as its children and its matches field
   will contain all its subrules matches, in order.

   ----
   alias and!(literal!"abc", charRange!('a','z')) rule; // abc followed by any letter between a and z.
   ParseTree input = ParseTree("",false,[],"abcd"); // low-level plumbing,
   // the rules described here act on ParseTree's not strings.
   // It's equivalent to "abcd" as input
   auto result = rule(input);

   assert(result.successful); // OK, 'abc' followed by 'd'
   assert(result.matches == ["abc", "d"]); // stores the matches
   assert(result.children.length == 2); // two children, the result of "abc" on "abcd" and the result of [a-z] on "d"

   input.input = "abc"; // changing the input string;
   assert(!rule(input)).successful); // NOK, abc alone
   input.input = "ab";
   assert(!rule(input)).successful); // NOK, does not begin by abc
   ----

   If it fails, the last children will contain the failed node. That way, when printing, as sort of diagnostic is given:

   ----
   alias and!(literal!"abc", charRange!('a','z')) rule; // 'abc[a-z]', aka 'abc' followed by any letter between 'a' and 'z'.
   ParseTree input = ParseTree("",false,[],"abc1"); // equivalent to "abc1"

   auto failure = rule(input);
   writeln(failure);
   /+
   writes:
   and (failure)
   +-literal(abc) [0, 3]["abc"]
   +-charRange(a,z) failure at line 0, col 3, after "abc" a char between 'a' and 'z', but got "1"
   +/
   ----

   So we know the global 'and' failed, that the first sub-rule ('abc') succeeded on input[0..3] with "abc"
   and that the second subrule ('[a-z]') failed at position 3 (so, on '1').
*/
template andT(ParseTree, rules...) if (rules.length > 0)
{
    string ctfeGetNameAnd()
        {
            string name = "and!(";
            foreach(i,rule; rules)
                name ~= __traits(identifier, rule) // because using getName!(rule) causes an infinite loop during compilation
                    // for recursive rules
                    ~ (i < rules.length -1 ? ", " : "");
            name ~= ")";
            return name;
        }

    enum name = ctfeGetNameAnd();

    ParseTree andT(ParseTree p)
        {
            bool keepNode(ParseTree node)
            {
                return    node.name.startsWith("keep!(")
                    || (  !node.name.startsWith("discard!(")
                        //&& !node.name.startsWith("drop!(")
                        && (node.matches !is null
                            || node.failEnd >= node.end)
                        //&& node.begin != node.end
                        );
            }

            version (tracer)
            {
                incTraceLevel();
            }

            ParseTree result = ParseTree(name, false, [], p.input, p.end, p.end, []);

            foreach(i,r; rules)
            {
                version (tracer)
                {
                    if (shouldTrace(getName!(r)(), p))
                        trace(traceMsg(result, name, getName!(r)()));
                }
                ParseTree temp = r(result);
                result.end = temp.end;
                result.failEnd = max(result.failEnd, temp.failEnd);
                if (temp.successful)
                {
                    if (keepNode(temp))
                    {
                        result.matches ~= temp.matches;
                        if (temp.name.startsWith("drop!("))
                        {}
                        else if (temp.name.startsWith("propagate!("))
                            result.children ~= temp.children;
                        else
                            result.children ~= temp;
                    }
                }
                else
                {
                    auto firstLongestFailedMatch = result.children.firstLongestFailedMatch(temp.end);
                    if (firstLongestFailedMatch == -1) {
                        result.children ~= temp;// add the failed node, to indicate which failed
                        if (temp.matches.length > 0)
                            result.matches ~= temp.matches[$-1];
                    } else {
                        // don't add the failed node because a previous one already failed further back
                        result.children = result.children[0 .. firstLongestFailedMatch+1]; // discard any intermediate correct nodes
                        // This current 'and' rule has failed parsing and there is a successful child
                        // that had a longer failing match. We now want to revisit that child and modify it
                        // so that it is no longer successful and we want to move its failedChild into its children.
                        failedChildFixup(result.children[firstLongestFailedMatch], result.children[firstLongestFailedMatch].failEnd);
                    }
                    result.end = result.children.maxEnd();
                    result.failEnd = result.children.maxFailEnd();
                    version (tracer)
                    {
                        if (shouldTrace(getName!(r)(), p))
                            trace(traceResultMsg(result, getName!(r)()));
                        decTraceLevel();
                    }
                    return result; // and end the parsing attempt right there
                }
            }
            result.successful = true;
            version (tracer)
            {
                foreach(i, r; rules)
                    if (shouldTrace(getName!(r)(), p))
                    {
                        trace(traceResultMsg(result, name));
                        break;
                    }
                decTraceLevel();
            }
            return result;
        }

    ParseTree andT(string input)
        {
            return .andT!(ParseTree, rules)(ParseTree("",false,[],input));
        }

    string andT(GetName g)
        {
            return name;
        }

}

auto firstLongestFailedMatch(ParseTree)(ParseTree[] children, size_t threshold) if (isParseTree!ParseTree) {
    return children.countUntil!(c => c.failEnd > threshold);
}

auto maxFailEnd(ParseTree)(ParseTree[] children) if (isParseTree!ParseTree) {
    return children.map!(c => c.failEnd).maxElement;
}

auto maxEnd(ParseTree)(ParseTree[] children) if (isParseTree!ParseTree) {
    return children.map!(c => c.end).maxElement;
}

// A child ParseTree has kept track of an alternate ParseTree (in failedChild) that matches longer.
// whenever the 'and' rule fails we want to rewrite that child so that the failedChild is
// moved into its children, the successful is set to false, the end is set the its failEnd,
// the failEnd is reset, and all that info is propagated upwards the tree so intermediate
// nodes reflect the proper state.
bool failedChildFixup(ParseTree)(ref ParseTree p, size_t failEnd) if (isParseTree!ParseTree) {
    if (p.failedChild.length > 0)
    {
        p.children ~= p.failedChild[0];
        p.failedChild = [];
        p.successful = false;
        p.end = p.failEnd;
        p.failEnd = p.children.map!(c => c.failEnd).maxElement();
        return true;
    }
    else
    {
        bool result = false;
        foreach (ref c; p.children)
        {
            if (c.failEnd != failEnd)
                continue;
            if (failedChildFixup(c, failEnd))
            {
                p.end = c.end;
                p.successful = false;
                p.failEnd = p.children.map!(c => c.failEnd).maxElement();
                result = true;
            }
        }
        return result;
    }
}

@safe unittest // 'and' unit test
{
    mixin DefaultPatters!ParseTree;
    alias abc= ParseTree.literal!"abc";
    alias de = ParseTree.literal!"de";
    alias f = ParseTree.literal!"f";

    alias abcAnd = and!(abc);
    alias abcde = and!(abc,de);
    alias abcdef = and!(abc,de,f);
    alias withEps = and!(eps, abc, eps, de, eps, f, eps);
    //assert(getName!(abcAnd)() == `and!(literal!("abc"))`);
    //assert(getName!(abcde)()  == `and!(literal!("abc"), literal!("de"))`);
    //assert(getName!(abcdef)() == `and!(literal!("abc"), literal!("de"), literal!("f"))`);

    ParseTree input = ParseTree("",false,[], "abcdefghi");

    ParseTree result = abcAnd(input);

    assert(result.successful, "and!('abc') parses 'abcdefghi'");
    assert(result.matches == ["abc"], "and!('abc') matches 'abc' at the beginning of 'abcdefghi'");
    assert(result.end == input.end+3, "and!('abc') advances the index by 'abc' size (3).");
    assert(result.children == [abc(input)], "and!('abc') has one child: the one created by 'abc'.");

    result = abcde(input);

    assert(result.successful, "and!('abc','de') parses 'abcdefghi'");
    assert(result.matches == ["abc","de"],
        "and!('abc','de') matches 'abc' and 'de' at the beginning of 'abcdefghi'");
    assert(result.end == input.end+5, "and!('abc','de') advances the index by 3+2 positions.");
    assert(result.children == [abc(input), de(abc(input))],
        "and!('abc','de') has two children, created by 'abc' and 'de'.");

    result = abcdef(input);

    assert(result.successful, "and!('abc','de','f') parses 'abcdefghi'");
    assert(result.matches == ["abc","de","f"],
        "and!('abc','de','f') matches 'abcdef' at the beginning of 'abcdefghi'");
    assert(result.end == input.end+6, "and!('abc','de','f') advances the index by 3+2+1 positions.");
    assert(result.children == [abc(input), de(abc(input)), f(de(abc(input)))]
        , "and!('abc','de') has two children, created by 'abc' and 'de'.");

    result = withEps(input);

    assert(result.successful, "and!('','abc','','de','','f','') parses 'abcdefghi'");
    assert(result.matches == ["","abc","","de","","f",""],
        "and!('','abc','','de','','f','') matches 'abcdef' at the beginning of 'abcdefghi'");
    assert(result.end == input.end+6,
        "and!('','abc','','de','','f','') advances the index by 0+3+0+2+0+1+0 positions.");

    input.input = "bcdefghi";

    result = abcdef(input);

    assert(!result.successful, "'abc' 'de' 'f' fails on 'bcdefghi'");
    //assert(result.matches is null, "'abc' 'de' 'f' has no match on 'bcdefghi'");
    assert(result.end == input.end);
    assert(result.children == [abc(input)], "'abc' 'de' 'f' has one child (a failure) on 'bcdefghi'");

    input.input = "abc_efghi";

    result = abcdef(input);

    assert(!result.successful, "'abc' 'de' 'f' fails on 'abc_efghi'");
    //assert(result.matches == ["abc"], "Only the first match, from 'abc'.");
    assert(result.end == input.end+3, "Advances by 3 positions, due to 'abc'");
    assert(result.children == [abc(input), de(abc(input))]
        , "'abc' 'de' 'f' has two child on 'abc_efghi', the one from 'abc' (success) and the one from 'de' (failure).");
}

version (unittest) {
    static ParseTree getError(ParseTree)(ref ParseTree p) if (isParseTree!ParseTree) {
        if (p.children.length > 0)
            return getError(p.children[$-1]);
        return p;
    }
}

@safe unittest // 'and' unit test with zeroOrMore and longest failing match
{
    alias A = ParseTree.literal!"abc";
    alias B = ParseTree.literal!"def";
    alias C = ParseTree.literal!"ghi";

    alias Thing = ParseTree.and!(ParseTree.zeroOrMore!(ParseTree.and!(A,B)), C) Thing;

    ParseTree input = ParseTree("",false,[], "abc");
    ParseTree result = Thing(input);

    assert(!result.successful);
    assert(getError(result).matches[$-1] == "\"def\"", "and!(zeroOrMore!(and!(literal!\"abc\", literal!\"def\")), literal!\"ghi\") should expected def when input is \"abc\"");
    assert(result.matches == []);
}

@safe unittest // 'and' unit test with option and longest failing match
{

    alias A = ParseTree.literal!"abc";
    alias B = ParseTree.literal!"def";
    alias C = ParseTree.literal!"ghi";

    alias Thing = ParseTree.and!(ParseTree.option!(ParseTree.and!(A,B)), C);

    ParseTree input = ParseTree("",false,[], "abc");
    ParseTree result = Thing(input);

    assert(!result.successful);
    assert(getError(result).matches[$-1] == "\"def\"", "and!(option!(and!(literal!\"abc\", literal!\"def\")), literal!\"ghi\") should expected def when input is \"abc\"");
    assert(result.matches == []);
}

@safe unittest // 'and' unit test with oneOrMore and longest failing match
{

    alias ParseTree.literal!"abc" A;
    alias ParseTree.literal!"def" B;
    alias ParseTree.literal!"ghi" C;

    alias Thing = ParseTree.and!(ParseTree.oneOrMore!(ParseTree.and!(A,B)), C);

    ParseTree input = ParseTree("",false,[], "abcdefabc");
    ParseTree result = Thing(input);

    assert(!result.successful);
    assert(getError(result).matches[$-1] == "\"def\"", "and!(oneOrMore!(and!(literal!\"abc\", literal!\"def\")), literal!\"ghi\") should expected def when input is \"abcdefabc\"");
    assert(result.matches == ["abc", "def"]);
}

template wrapAroundT(ParseTree, alias before, alias target, alias after)
{
    ParseTree wrapAroundT(ParseTree p)
        {
            ParseTree temp = before(p);
            if (!temp.successful)
                return temp;

            ParseTree result = target(temp);
            if (!result.successful)
                return result;
            result.begin = temp.begin;

            temp = after(result);
            if (!temp.successful)
                return temp;

            result.end = temp.end;
            return result;
        }

    ParseTree wrapAroundT(string input)
        {
            return wrapAroundT!(ParseTree, before, target, after)(ParseTree("",false,[],input));
        }

    string wrapAroundT(GetName g)
        {
            return "wrapAround!(" ~ getName!(before)() ~
                ", " ~ getName!(target)() ~
                ", " ~ getName!(after)() ~ ")";
        }
}

/**
   Basic operator: it matches if one of its subrules (stored in the rules template parameter tuple) match
   the input. The subrules are tested in order, from rules[0] to rules[$-1].

   The matching subrule parse trees is stored as its only child and its matches field
   will contain all the subrule matches, in order.

   ----
   alias or!(literal!"abc", charRange!('a','z')) rule; // abc or, failing that, any letter between a and z.
   ParseTree input = ParseTree("",false,[],"defg"); // low-level plumbing, the rules described here act on ParseTree's not strings.
   // It's equivalent to "defg" as input
   auto result = rule(input);

   assert(result.successful); // OK
   assert(result.matches == ["d"]); // stores the (in this case) only match
   assert(result.children.length == 1); // one child, the result of "abc" or [a-z], depending on which rule succeeded.

   input.input = "abc"; // changing the input string;
   assert(rule(input)).successful); // Still OK
   input.input = "1abc";
   assert(!rule(input)).successful); // NOK, does not begin by abc nor by [a-z]
   ----

   If it fails, the last children will contain the failed node that matched furthest (longes match).
   That way, when printing, as sort of diagnostic is given:

   ----
   alias or!(literal!"abc", and!(literal!"ab", charRange!('0','9'))) rule; // 'abc' or 'ab[0-9]'
   ParseTree input = ParseTree("",false,[],"abd"); // equivalent to "abd"

   auto failure = rule(input);
   writeln(failure);
   /+
   or (failure)
   +-and (failure)
   +-literal(ab) [0, 2]["ab"]
   +-charRange(0,9) failure at line 0, col 2, after "ab" expected a char between '0' and '9', but got "d"
   +/
   ----

   So we know 'or' failed, that the 'and' sub-rule had the longest match, matching 'ab' and failing for [0-9] on index 2.
*/
template orT(ParseTree, rules...) if (rules.length > 0) {
    @safe {
        string ctfeGetNameOr()
        {
            string name = "or!(";
            foreach(i,rule; rules)
                name ~= getName!(rule)
                    ~ (i < rules.length -1 ? ", " : "");
            name ~= ")";
            return name;
        }

        enum name = ctfeGetNameOr();

        ParseTree orT(ParseTree p)
        {
            // error-management
            ParseTree longestFail = ParseTree(name, false, [], p.input, p.end, 0);
            string[] errorStrings;
            size_t errorStringChars;
            //string orErrorString;

            ParseTree[rules.length] results;
            string[rules.length] names;
            size_t[rules.length] failedLength;
            size_t maxFailedLength;

            version (tracer)
            {
                incTraceLevel();
            }

            // Real 'or' loop
            foreach(i,r; rules)
            {
                version (tracer)
                {
                    if (shouldTrace(getName!(r)(), p))
                        trace(traceMsg(p, name, getName!(r)()));
                }
                ParseTree temp = r(p);
                if (temp.successful)
                {
                    temp.children = [temp];
                    temp.name = name;
                    // if there is a child that failed but parsed more
                    if (longestFail.failEnd > temp.end) {
                        temp.failEnd = longestFail.failEnd;
                        temp.failedChild = [longestFail];
                    }
                    version (tracer)
                    {
                        if (shouldTrace(getName!(r)(), p))
                            trace(traceResultMsg(temp, getName!(r)()));
                        decTraceLevel();
                    }
                    return temp;
                }
                else
                {
                    version (tracer)
                    {
                        if (shouldTrace(getName!(r)(), p))
                            trace(traceResultMsg(temp, getName!(r)()));
                    }
                    enum errName = " (" ~ getName!(r)() ~")";
                    failedLength[i] = temp.end;
                    if (temp.end >= longestFail.end)
                    {
                        if (temp.end == longestFail.end)
                            errorStringChars += (temp.matches.length > 0 ? temp.matches[$-1].length : 0) + errName.length + 4;
                        else
                            errorStringChars = (temp.matches.length > 0 ? temp.matches[$-1].length : 0) + errName.length + 4;
                        maxFailedLength = temp.end;
                        longestFail = temp;
                        names[i] = errName;
                        results[i] = temp;

                    }
                    // Else, this error parsed less input than another one: we discard it.
                }
            }
            version (tracer)
            {
                decTraceLevel();
            }


            // All subrules failed, we will take the longest match as the result
            // If more than one node failed at the same (farthest) position, we concatenate their error messages


            char[] errString;// = new char[](errorStringChars);
            errString.length = errorStringChars;
            uint start = 0;
            foreach(i; 0..rules.length)
            {
                if (failedLength[i] == maxFailedLength && results[i].matches.length > 0)
                {
                    auto temp = results[i];
                    auto len = temp.matches[$-1].length;
                    auto nlen = names[i].length;
                    errString[start .. start+len] = temp.matches[$-1][];
                    errString[start+len .. start+len+names[i].length] = names[i][];
                    errString[start+len+nlen .. start+len+nlen+4] = " or ";
                    start += len + names[i].length + 4;
                }
            }
            string orErrorString = errString[0..$-4].idup;


            longestFail.matches = longestFail.matches.length == 0 ? [orErrorString] :
                longestFail.matches[0..$-1]  // discarding longestFail error message
                ~ [orErrorString];             // and replacing it by the new, concatenated one.
            auto children = ParseTree.getUpto(results, maxFailedLength);
            return ParseTree(name, false, longestFail.matches, p.input, p.end, longestFail.end, children, children.maxFailEnd);
        }

        ParseTree orT(string input)
        {
            return orT!(ParseTree,rules)(ParseTree("",false,[],input));
        }

        string orT(GetName g)
        {
            return name;
        }
    }
}

@safe unittest // 'or' unit test
{

    mixin DefaultPatters!ParseTree;
    alias charRange!('a','b') ab;
    alias charRange!('c','d') cd;

    alias or!(ab) abOr;
    alias or!(ab,cd) abOrcd;

    assert(getName!(ab)() == "charRange!('a','b')");
    assert(getName!(cd)() == "charRange!('c','d')");

    ParseTree input = ParseTree("",false,[], "abcdefghi");

    ParseTree result = abOr(input);

    assert(result.name == "or!(charRange!('a','b'))", "or name test.");
    assert(result.successful, "or!([a-b]) parses 'abcdefghi'");
    assert(result.matches == ["a"], "or!([a-b]) matches 'a' at the beginning of 'abcdefghi'");
    assert(result.end == input.end+1, "or!([a-b]) advances the index by 'a' size (1).");
    assert(result.children == [ab(input)], "or!([a-b]) has one child: the one created by '[a-b]'.");

    result = abOrcd(input);

    assert(result.name == "or!(charRange!('a','b'), charRange!('c','d'))", "or name test.");
    assert(result.successful, "or!([a-b],[c-d]) parses 'abcdefghi'");
    assert(result.matches == ["a"], "or!([a-b],[c-d]) matches 'a' at the beginning of 'abcdefghi'");
    assert(result.end == input.end+1, "or!([a-b],[c-d]) advances the index by 1 position.");

    assert(result.children == [ab(input)], "or!([a-b],[c-d]) has one child, created by [a-b].");

    input.input = "cdefghi";

    result = abOrcd(input);

    assert(result.name == "or!(charRange!('a','b'), charRange!('c','d'))", "or name test.");
    assert(result.successful, "or!([a-b],[c-d]) parses 'cdefghi'");
    assert(result.matches == ["c"], "or!([a-b],[c-d]) matches 'c' at the beginning of 'cdefghi'");
    assert(result.end == input.end+1, "or!([a-b],[c-d]) advances the index by 1 position.");

    assert(result.children == [cd(input)], "or!([a-b],[c-d]) has one child, created by [c-d].");

    input.input = "_abcdefghi";

    result = abOrcd(input);

    assert(!result.successful, "or!([a-b],[c-d]) fails on '_abcdefghi'");
    assert(result.end == input.end+0, "or!([a-b],[c-d]) does not advance the index.");
    assert(result.matches ==
        [ "a char between 'a' and 'b' (charRange!('a','b')) or a char between 'c' and 'd' (charRange!('c','d'))"]
        , "or!([a-b],[c-d]) error message. |" ~ result.matches[0]~ "|");

    input.input = "";

    result = abOrcd(input);

    assert(!result.successful, "or!([a-b],[c-d]) fails on and empty input");
    assert(result.end == input.end+0, "or!([a-b],[c-d]) does not advance the index.");
    assert(result.matches ==
        [ "a char between 'a' and 'b' (charRange!('a','b')) or a char between 'c' and 'd' (charRange!('c','d'))"]
        , "or!([a-b],[c-d]) error message.");
}

/**
   Basic operator: it matches if one of its subrules (stored in the rules template parameter tuple) match
   the input. All subrules are tested and the one producing the longest match is taken.

   The longest matching subrule's parse tree is stored as its only child and its matches field
   will contain all the subrule matches, in order.
*/
template longest_matchT(ParseTree, rules...) if (rules.length > 0)
{
    @safe {
        string ctfeGetNameOr()
        {
            string name = "longest_match!(";
            foreach(i,rule; rules)
                name ~= getName!(rule)
                    ~ (i < rules.length -1 ? ", " : "");
            name ~= ")";
            return name;
        }

        enum name = ctfeGetNameOr();

        ParseTree longest_matchT(ParseTree p)
        {
            // error-management
            ParseTree longest, longestFail = ParseTree(name, false, [], p.input, p.end, 0);
            string[] errorStrings;
            size_t errorStringChars;
            //string orErrorString;

            ParseTree[rules.length] results;
            string[rules.length] names;
            size_t[rules.length] failedLength;
            size_t maxFailedLength;

            version (tracer)
            {
                incTraceLevel();
            }

            // Real 'longest_match' loop
            foreach(i,r; rules)
            {
                version (tracer)
                {
                    if (shouldTrace(getName!(r)(), p))
                        trace(traceMsg(p, name, getName!(r)()));
                }
                ParseTree temp = r(p);
                version (tracer)
                {
                    if (shouldTrace(getName!(r)(), p))
                        trace(traceResultMsg(temp, getName!(r)()));
                }

                if (temp.successful)
                {
                    if (temp.end > longest.end)
                        longest = temp;
                    // Else, this rule parsed less input than another one: we discard it.
                }
                else
                {
                    enum errName = " (" ~ getName!(r)() ~")";
                    failedLength[i] = temp.end;
                    if (temp.end >= longestFail.end)
                    {
                        maxFailedLength = temp.end;
                        longestFail = temp;
                        names[i] = errName;
                        results[i] = temp;

                        if (temp.end == longestFail.end)
                            errorStringChars += (temp.matches.length > 0 ? temp.matches[$-1].length : 0) + errName.length + 4;
                        else
                            errorStringChars = (temp.matches.length > 0 ? temp.matches[$-1].length : 0) + errName.length + 4;
                    }
                    // Else, this error parsed less input than another one: we discard it.
                }
            }
            version (tracer)
            {
                decTraceLevel();
            }
            if (longest.successful)
            {
                longest.children = [longest];
                longest.name = name;
                return longest;
            }

            // All subrules failed, we will take the longest match as the result
            // If more than one node failed at the same (farthest) position, we concatenate their error messages

            char[] errString;// = new char[](errorStringChars);
            errString.length = errorStringChars;
            uint start = 0;
            foreach(i; 0..rules.length)
            {
                if (failedLength[i] == maxFailedLength && results[i].matches.length > 0)
                {
                    auto temp = results[i];
                    auto len = temp.matches[$-1].length;
                    auto nlen = names[i].length;
                    errString[start .. start+len] = temp.matches[$-1][];
                    errString[start+len .. start+len+names[i].length] = names[i][];
                    errString[start+len+nlen .. start+len+nlen+4] = " or ";
                    start += len + names[i].length + 4;
                }
            }
            (() @trusted {
                string orErrorString = cast(string)errString[0..$-4];

                longestFail.matches = longestFail.matches.length == 0 ? [orErrorString] :
                    longestFail.matches[0..$-1]  // discarding longestFail error message
                    ~ [orErrorString];             // and replacing it by the new, concatenated one.
            })();
            longestFail.name = name;
            longestFail.begin = p.end;
            return longestFail;
        }

        ParseTree longest_matchT(string input)
        {
            return orT!(ParseTree, rules)(ParseTree("",false,[],input));
        }

        string longest_matchT(GetName g)
        {
            return name;
        }
    }
}

@safe unittest // 'longest_match' unit test
{
    mixin DefaultPatters!ParseTree;

    alias ab = charRange!('a','b');
    alias cd = charRange!('c','d');

    alias abOr = longest_match!(ab);
    alias abOrcd = longest_match!(ab,cd);

    assert(getName!(ab)() == "charRange!('a','b')");
    assert(getName!(cd)() == "charRange!('c','d')");

    // These are the same tests as for 'or':

    ParseTree input = ParseTree("",false,[], "abcdefghi");

    ParseTree result = abOr(input);

    assert(result.name == "longest_match!(charRange!('a','b'))", "or name test.");
    assert(result.successful, "longest_match!([a-b]) parses 'abcdefghi'");
    assert(result.matches == ["a"], "longest_match!([a-b]) matches 'a' at the beginning of 'abcdefghi'");
    assert(result.end == input.end+1, "longest_match!([a-b]) advances the index by 'a' size (1).");
    assert(result.children == [ab(input)], "longest_match!([a-b]) has one child: the one created by '[a-b]'.");

    result = abOrcd(input);

    assert(result.name == "longest_match!(charRange!('a','b'), charRange!('c','d'))", "or name test.");
    assert(result.successful, "longest_match!([a-b],[c-d]) parses 'abcdefghi'");
    assert(result.matches == ["a"], "longest_match!([a-b],[c-d]) matches 'a' at the beginning of 'abcdefghi'");
    assert(result.end == input.end+1, "longest_match!([a-b],[c-d]) advances the index by 1 position.");

    assert(result.children == [ab(input)], "longest_match!([a-b],[c-d]) has one child, created by [a-b].");

    input.input = "cdefghi";

    result = abOrcd(input);

    assert(result.name == "longest_match!(charRange!('a','b'), charRange!('c','d'))", "or name test.");
    assert(result.successful, "longest_match!([a-b],[c-d]) parses 'cdefghi'");
    assert(result.matches == ["c"], "longest_match!([a-b],[c-d]) matches 'c' at the beginning of 'cdefghi'");
    assert(result.end == input.end+1, "longest_match!([a-b],[c-d]) advances the index by 1 position.");

    assert(result.children == [cd(input)], "longest_match!([a-b],[c-d]) has one child, created by [c-d].");

    input.input = "_abcdefghi";

    result = abOrcd(input);

    assert(!result.successful, "longest_match!([a-b],[c-d]) fails on '_abcdefghi'");
    assert(result.end == input.end+0, "longest_match!([a-b],[c-d]) does not advance the index.");
    assert(result.matches ==
        [ "a char between 'a' and 'b' (charRange!('a','b')) or a char between 'c' and 'd' (charRange!('c','d'))"]
        , "longest_match!([a-b],[c-d]) error message. |" ~ result.matches[0]~ "|");

    input.input = "";

    result = abOrcd(input);

    assert(!result.successful, "longest_match!([a-b],[c-d]) fails on and empty input");
    assert(result.end == input.end+0, "longest_match!([a-b],[c-d]) does not advance the index.");
    assert(result.matches ==
        [ "a char between 'a' and 'b' (charRange!('a','b')) or a char between 'c' and 'd' (charRange!('c','d'))"]
        , "longest_match!([a-b],[c-d]) error message.");

    // Now test longest match behaviour:

    input.input = "aaaccccb";
    result =            or!(oneOrMore!(literal!("a")), and!(oneOrMore!(literal!("a")), literal!("cc")))(input);
    assert(result.matches == ["a", "a", "a"], "or! takes the first matching rule.");
    result = longest_match!(oneOrMore!(literal!("a")), and!(oneOrMore!(literal!("a")), literal!("cc")))(input);
    assert(result.matches == ["a", "a", "a", "cc"], "longest_match! takes the longest matching rule.");
}


/**
   Compile-time switch trie from Brian Schott
*/
class Trie(V) : TrieNode!(V)
{
    /**
     * Adds the given value to the trie with the given key
     */
    void add(string key, V value) pure
    {
        TrieNode!(V) current = this;
        foreach(dchar keyPart; key)
        {
            if ((keyPart in current.children) is null)
            {
                auto node = new TrieNode!(V);
                current.children[keyPart] = node;
                current = node;
            }
            else
                current = current.children[keyPart];
        }
        current.value = value;
    }
}

class TrieNode(V)
{
    V value;
    TrieNode!(V)[dchar] children;
}

string printCaseStatements(V)(TrieNode!(V) node, string indentString)
{
    string s = "";
    string idnt = indentString;

    void incIndent() { idnt ~= "  "; }
    void decIndent() { idnt = idnt[2..$]; }

    void put(string k) { s ~= idnt ~ k; }
    void append(string k) { s ~= k;}

    foreach(dchar k, TrieNode!(V) v; node.children)
    {
        put("case '");
        switch(k)
        {
        case '\n': append("\\n"); break;
        case '\t': append("\\t"); break;
        case '\r': append("\\r"); break;
        case 92:   append("\\");  break;
        default:   append(to!string(k));
        }
        append("':\n");
        incIndent();

        put("temp.end++;\n");
        if (v.children.length > 0)
        {
            put("if (temp.end >= temp.input.length)\n");
            put("{\n");
            incIndent();

            if (node.children[k].value.length != 0)
                put("return ParseTree(name, true, [`" ~ node.children[k].value ~ "`], temp.input, p.end, temp.end)");
            else
                put("return ParseTree(name, false, [failString], p.input, p.end, p.end)");

            append(";\n");
            decIndent();

            put("}\n");
            put("switch (temp.input[temp.end])\n");
            put("{\n");

            incIndent();
            append(printCaseStatements(v, idnt));

            put("default:\n");
            incIndent();
            if (v.value.length != 0)
                put("return ParseTree(name, true, [`" ~ v.value ~ "`], temp.input, p.end, temp.end)");
            else
                put("return ParseTree(name, false, [failString], p.input, p.end, p.end)");
            append(";\n");
            decIndent();
            decIndent();
            put("}\n");
        }
        else
        {
            if (v.value.length != 0)
                put("return ParseTree(name, true, [`" ~ v.value ~ "`], temp.input, p.end, temp.end)");
            else
                put("return ParseTree(name, false, [failString], p.input, p.end, p.end)");
            append(";\n");
        }
    }
    return s;
}

string generateCaseTrie(string[] args ...)
{
    auto t = new Trie!(string);
    foreach(arg; args)
    {
        t.add(arg, arg);
    }
    return printCaseStatements(t, "");
}

/**
   or special case for literal list ("abstract"/"alias"/...)
*/
template keywordsT(ParseTree,kws...) if (kws.length > 0)
{
    string ctfeGetNameKeywords()
        {
            string name= "keywords!(";
            foreach(i,kw;kws)
                name ~= "\"" ~ kw ~ "\""~ (i < kws.length -1 ? ", " : "");
            name ~= ")";
            return name;
        }

    string ctfeConcatKeywords()
        {
            string s = "[";
            foreach(i, k; kws)
            {
                s ~= "\"" ~ k ~ "\"";
                if (i < kws.length - 1)
                    s ~= ", ";
            }
            return s ~= "]";
        }

    enum name = ctfeGetNameKeywords();
    enum failString = "one among " ~ ctfeConcatKeywords();

    ParseTree keywordsT(ParseTree p)
        {
            string keywordCode(string[] keywords)
            {
                string result;
                foreach(kw; keywords)
                    result ~= "if (p.end+"~to!string(kw.length) ~ " <= p.input.length "
                        ~" && p.input[p.end..p.end+"~to!string(kw.length)~"]==`"
                        ~kw~"`) return ParseTree(`"
                        ~name~"`,true,[`"~kw~"`],p.input,p.end,p.end+"
                        ~to!string(kw.length)~");\n";

                result ~= "return ParseTree(`"~name~"`,false,[`" ~ failString ~ "`],p.input,p.end,p.end);";

                return result;
            }

            static if (KEYWORDS == IFCHAIN)
            {
                mixin(keywordCode([kws]));
            }
            else static if (KEYWORDS == TRIE)
            {
                auto temp = p;
                if (p.end < p.input.length) // is this conditional required?
                {
                    switch(p.input[p.end])
                    {
                        mixin(generateCaseTrie([kws]));
                        mixin("default: return ParseTree(`"~name~"`,false,[`" ~ failString ~ "`],p.input,p.end,p.end);");
                    }
                }
                else
                {
                    mixin("return ParseTree(`"~name~"`,false,[`" ~ failString ~ "`],p.input,p.end,p.end);");
                }
            }
        }

    ParseTree keywordsT(string input)
        {
            return keywordsT!(ParseTree, kws)(ParseTree("",false,[],input));
        }

    string keywordsT(GetName g)
        {
            return name;
        }
}

@safe unittest
{

    alias kw = ParseTree.keywords!("abc","de","f");

    assert(getName!(kw)() == `keywords!("abc", "de", "f")`);

    ParseTree input = ParseTree("",false,[],"abcd");

    ParseTree result = kw(input);

    assert(result.name == `keywords!("abc", "de", "f")`, "keywords name test.");
    assert(result.successful, "keywords success on `abcd`");
    assert(result.matches == ["abc"], "keywords matches `abc` on `abcd`");
    assert(result.end == input.end+3, "keywords advances the index by 3 positions.");
    assert(result.children is null, "No children for `keywords`.");

    input.input = "def";

    result = kw(input);

    assert(result.successful, "keywords success on `def`");
    assert(result.matches == ["de"], "keywords matches `de` on `def`");
    assert(result.end == input.end+2, "keywords advances the index by 2 positions.");
    assert(result.children is null, "No children for `keywords`.");


    input.input = "ab_def";

    result = kw(input);

    assert(!result.successful, "keywords fails on `ab_def`.");
    assert(result.matches == [`one among ["abc", "de", "f"]`], "keywords error message." ~ result.matches[0]);
    assert(result.end == input.end, "keywords does not advance the index.");
    assert(result.children is null, "No children for `keywords`.");

    input.input = "";

    result = kw(input);

    assert(!result.successful, "keywords fails on an empty input.");
    assert(result.matches == [`one among ["abc", "de", "f"]`], "keywords error message.");
    assert(result.end == input.end, "keywords does not advance the index.");
    assert(result.children is null, "No children for `keywords`.");
}


/**
   Tries to match subrule 'r' zero or more times. It always succeeds, since if 'r' fails
   from the very beginning, it matched 'r' zero times...

   Its matches are those of its subrules (they might be different for each match) and its
   children are all the parse trees returned by the successive application of 'r'.

   ----
   alias zeroOrMore!(or!(literal!"abc", literal!"d")) rule; // in PEG-speak:  '("abc" / "d")*'
   ParseTree input = ParseTree("",false,[], "abcdabce");

   ParseTree result = rule(input);

   assert(result.successful);
   assert(result.matches == ["abc", "d", "abc"]);
   assert(result.end == 7); // matched "abcdabce"[0..7] => "abcdabc". "e" at the end is not part of the parse tree.
   assert(result.children.length == 3);
   writeln(result);
   /+
   writes:
   zeroOrMore  [0, 7]["abc", "d", "abc"]
   +-or  [0, 3]["abc"]
   |  +-literal(abc)  [0, 3]["abc"]
   +-or  [3, 4]["d"]
   |  +-literal(d)  [3, 4]["d"]
   +-or  [4, 7]["abc"]
   +-literal(abc)  [4, 7]["abc"]
   +/
   ----

   So we know the first child used the 'literal!"abc"' sub-rule and matched input[0..3].
   The second matched input[3..4] and the third input[4..7].

   ----
   input = ParseTree("",false,[], "efgh");
   result = rule(input);
   assert(result.successful); // succeed, even though all patterns failed.
   assert(result.children.length == 0);
   ----
*/
template zeroOrMoreT(ParseTree, alias r)
{
    enum name = "zeroOrMore!(" ~ getName!(r) ~ ")";

    ParseTree zeroOrMoreT(ParseTree p)
        {
            auto result = ParseTree(name, true, [], p.input, p.end, p.end);
            version (tracer)
            {
                incTraceLevel();
                if (shouldTrace(getName!(r)(), p))
                    trace(traceMsg(result, name, getName!(r)()));
            }
            auto temp = r(result);
            while(temp.successful
                && (temp.begin < temp.end // To avoid infinite loops on epsilon-matching rules
                    || temp.name.startsWith("discard!(")))
            {
                result.matches ~= temp.matches;
                result.children ~= temp;
                result.end = temp.end;
                result.failEnd = max(result.failEnd, temp.failEnd);
                version (tracer)
                {
                    if (shouldTrace(getName!(r)(), p))
                        trace(traceMsg(result, name, getName!(r)()));
                }
                temp = r(result);
            }
            auto maxFail = max(temp.failEnd, temp.end);
            if (maxFail > result.failEnd && maxFail > result.end) {
                result.failedChild = [temp];
                result.failEnd = maxFail;
            }
            result.successful = true;
            version (tracer)
            {
                if (shouldTrace(getName!(r)(), p))
                    trace(traceResultMsg(result, getName!(r)()));
                decTraceLevel();
            }
            return result;
        }

    ParseTree zeroOrMoreT(string input)
        {
            return zeroOrMoreT!(ParseTree, r)(ParseTree("",false,[],input));
        }

    string zeroOrMoreT(GetName g)
        {
            return name;
        }
}

@safe unittest // 'zeroOrMore' unit test
{
    mixin DefaultPatters!ParseTree;
    alias literal!"a" a;
    alias literal!"abc" abc;
    alias charRange!('a','z') az;

    alias zeroOrMore!(a) as;
    alias zeroOrMore!(abc) abcs;
    alias zeroOrMore!(az) azs;

    assert(getName!(as)() == `zeroOrMore!(literal!("a"))`);
    assert(getName!(abcs)() == `zeroOrMore!(literal!("abc"))`);
    assert(getName!(azs)() == `zeroOrMore!(charRange!('a','z'))`);

    assert(as("").successful);
    assert(as("a").successful);
    assert(as("aa").successful);
    assert(as("aaa").successful);
    assert(as("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa").successful);
    assert(as("b").successful);

    ParseTree result = as("aaa");

    assert(result.name == `zeroOrMore!(literal!("a"))`);
    assert(result.successful);
    assert(result.matches == ["a","a","a"]);
    assert(result.begin == 0);
    assert(result.end == 3);
    assert(result.children.length == 3);
    assert(result.children == [ a("aaa"), a(a("aaa")), a(a(a("aaa")))]);

    assert(abcs("").successful);
    assert(abcs("abc").successful);
    assert(abcs("abcabc").successful);
    assert(abcs("abcabcabc").successful);
    assert(abcs("abcabcabcabcabcabcabcabcabcabcabcabcabcabcabc").successful);
    assert(abcs("ab").successful);

    result = abcs("abcabcabc");

    assert(result.name == `zeroOrMore!(literal!("abc"))`);
    assert(result.successful);
    assert(result.matches == ["abc","abc","abc"]);
    assert(result.begin == 0);
    assert(result.end == 3*3);
    assert(result.children.length == 3);
    assert(result.children == [ abc("abcabcabc"), abc(abc("abcabcabc")), abc(abc(abc("abcabcabc")))]);

    assert(azs("").successful);
    assert(azs("a").successful);
    assert(azs("abc").successful);
    assert(azs("abcdefghijklmnoqrstuvwxyz").successful);
    assert(azs("abcdefghijklmnoqrstuvwxyz   1234567890").successful);

    result = azs("abc");

    assert(result.name == `zeroOrMore!(charRange!('a','z'))`);
    assert(result.successful);
    assert(result.matches == ["a","b","c"]);
    assert(result.begin == 0);
    assert(result.end == 3);
    assert(result.children.length == 3);
    assert(result.children == [ az("abc"), az(az("abc")), az(az(az("abc")))]);
}

/**
   Tries to match subrule 'r' one or more times. If 'r' fails
   from the very beginning, it fails and else succeeds.

   Its matches are those of its subrules (they might be different for each match) and its
   children are all the parse trees returned by the successive application of 'r'.

   ----
   alias oneOrMore!(or!(literal!"abc", literal!"d")) rule; // in PEG-speak:  '("abc" / "d")*'
   ParseTree input = ParseTree("",false,[], "abcdabce");

   ParseTree result = rule(input);

   assert(result.successful);
   assert(result.matches == ["abc", "d", "abc"]);
   assert(result.end == 7); // matched "abcdabce"[0..7] => "abcdabc". "e" at the end is not part of the parse tree.
   assert(result.children.length == 3);
   writeln(result);
   /+
   writes:
   oneOrMore  [0, 7]["abc", "d", "abc"]
   +-or  [0, 3]["abc"]
   |  +-literal(abc)  [0, 3]["abc"]
   +-or  [3, 4]["d"]
   |  +-literal(d)  [3, 4]["d"]
   +-or  [4, 7]["abc"]
   +-literal(abc)  [4, 7]["abc"]
   +/
   ----

   So we know the first child used the 'literal!"abc"' sub-rule and matched input[0..3].
   The second matched input[3..4] and the third input[4..7].

   ----
   input = ParseTree("",false,[], "efgh");
   result = rule(input);
   assert(!result.successful); // fails, since it failed on the first try.
   ----
*/
template oneOrMoreT(ParseTree, alias r)
{
    enum name = "oneOrMore!(" ~ getName!(r) ~ ")";

    ParseTree oneOrMoreT(ParseTree p)
        {
            auto result = ParseTree(name, false, [], p.input, p.end, p.end);
            version (tracer)
            {
                incTraceLevel();
                if (shouldTrace(getName!(r)(), p))
                    trace(traceMsg(result, name, getName!(r)()));
            }
            auto temp = r(result);

            if (!temp.successful)
            {
                result.matches = temp.matches;
                result.children = [temp];
                result.end = temp.end;
            }
            else
            {
                while(  temp.successful
                    && (temp.begin < temp.end // To avoid infinite loops on epsilon-matching rules
                        || temp.name.startsWith("discard!(")))
                {
                    result.matches ~= temp.matches;
                    result.children ~= temp;
                    result.end = temp.end;
                    result.failEnd = max(result.failEnd, temp.failEnd);
                    version (tracer)
                    {
                        if (shouldTrace(getName!(r)(), p))
                            trace(traceMsg(result, name, getName!(r)()));
                    }
                    temp = r(result);
                }
                auto maxFail = max(temp.failEnd, temp.end);
                if (maxFail > result.failEnd && maxFail > result.end) {
                    result.failedChild = [temp];
                    result.failEnd = maxFail;
                }
                result.successful = true;
            }
            version (tracer)
            {
                if (shouldTrace(getName!(r)(), p))
                    trace(traceResultMsg(result, getName!(r)()));
                decTraceLevel();
            }
            return result;
        }

    ParseTree oneOrMoreT(string input)
        {
            return oneOrMoreT!(ParseTree, r)(ParseTree("",false,[],input));
        }

    string oneOrMoreT(GetName g)
        {
            return name;
        }
}

@safe unittest // 'oneOrMore' unit test
{
    mixin DefaultPatters!(ParseTree, [q{literal}, q{charRange}, q{oneOrMore}]);
    alias a = literal!"a";
    alias abc = literal!"abc";
    alias az = charRange!('a','z');

    alias as = oneOrMore!(a);
    alias abcs = oneOrMore!(abc);
    alias azs = oneOrMore!(az);

    assert(getName!(as)() == `oneOrMore!(literal!("a"))`);
    assert(getName!(abcs)() == `oneOrMore!(literal!("abc"))`);
    assert(getName!(azs)() == `oneOrMore!(charRange!('a','z'))`);

    assert(!as("").successful);
    assert(as("a").successful);
    assert(as("aa").successful);
    assert(as("aaa").successful);
    assert(as("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa").successful);
    assert(!as("b").successful);

    ParseTree result = as("aaa");

    assert(result.name == `oneOrMore!(literal!("a"))`);
    assert(result.successful);
    assert(result.matches == ["a","a","a"]);
    assert(result.begin == 0);
    assert(result.end == 3);
    assert(result.children.length == 3);
    assert(result.children == [ a("aaa"), a(a("aaa")), a(a(a("aaa")))]);

    assert(!abcs("").successful);
    assert(abcs("abc").successful);
    assert(abcs("abcabc").successful);
    assert(abcs("abcabcabc").successful);
    assert(abcs("abcabcabcabcabcabcabcabcabcabcabcabcabcabcabc").successful);
    assert(!abcs("ab").successful);

    result = abcs("abcabcabc");

    assert(result.name == `oneOrMore!(literal!("abc"))`);
    assert(result.successful);
    assert(result.matches == ["abc","abc","abc"]);
    assert(result.begin == 0);
    assert(result.end == 3*3);
    assert(result.children.length == 3);
    assert(result.children == [ abc("abcabcabc"), abc(abc("abcabcabc")), abc(abc(abc("abcabcabc")))]);

    assert(!azs("").successful);
    assert(azs("a").successful);
    assert(azs("abc").successful);
    assert(azs("abcdefghijklmnoqrstuvwxyz").successful);
    assert(azs("abcdefghijklmnoqrstuvwxyz   1234567890").successful);
    assert(!azs(".").successful);

    result = azs("abc");

    assert(result.name == `oneOrMore!(charRange!('a','z'))`);
    assert(result.successful);
    assert(result.matches == ["a","b","c"]);
    assert(result.begin == 0);
    assert(result.end == 3);
    assert(result.children.length == 3);
    assert(result.children == [ az("abc"), az(az("abc")), az(az(az("abc")))]);
}

/**
   Given a subrule 'r', represents the expression 'r?'. It tries to match 'r' and if this matches
   successfully, it returns this match. If 'r' failed, 'r?' is still a success, but without any child nor match.

   ----
   alias option!(literal!"abc") rule; // Aka '"abc"?'
   ParseTree input = ParseTree("",false,[],"abcd");

   ParseTree result = rule(input);
   assert(result.successful);
   assert(result.matches == ["abc"]);
   assert(result.children.length == 1);
   assert(result.children[0] == literal!"abc"(input));
   ----
*/
template optionT(ParseTree, alias r)
{
    enum name = "option!(" ~ getName!(r) ~ ")";

    ParseTree optionT(ParseTree p)
        {
            version (tracer)
            {
                if (shouldTrace(getName!(r)(), p))
                    trace(traceMsg(p, name, getName!(r)()));
            }
            ParseTree result = r(p);
            if (result.successful)
                return ParseTree(name, true, result.matches, result.input, result.begin, result.end, [result], result.failEnd);
            else
                return ParseTree(name, true, [], p.input, p.end, p.end, null, max(result.end,result.failEnd), [result]);
        }

    ParseTree optionT(string input)
        {
            return optionT!(ParseTree, r)(ParseTree("",false,[],input));
        }

    string optionT(GetName g)
        {
            return name;
        }
}

@safe unittest // 'option' unit test
{
    mixin DefaultPatters!(ParseTree, [q{literal}, q{option}]);
    alias literal!"a" a;
    alias literal!"abc" abc;

    alias option!(a) a_;
    alias option!(abc) abc_;

    assert(getName!(a_)() == `option!(literal!("a"))`);
    assert(getName!(abc_)() == `option!(literal!("abc"))`);

    assert(a_("").successful);
    assert(a_("a").successful);
    assert(a_("aa").successful);
    assert(a_("b").successful);

    ParseTree result = a_("a");

    assert(result.name == `option!(literal!("a"))`);
    assert(result.successful);
    assert(result.matches == ["a"]);
    assert(result.begin == 0);
    assert(result.end == 1);
    assert(result.children.length == 1);
    assert(result.children == [ a("a")]);

    result = a_("");

    assert(result.name == `option!(literal!("a"))`);
    assert(result.successful);
    assert(result.matches is null);
    assert(result.begin == 0);
    assert(result.end == 0);
    assert(result.children.length == 0);


    assert(abc_("").successful);
    assert(abc_("abc").successful);
    assert(abc_("abcabc").successful);
    assert(abc_("ab").successful);

    result = abc_("abcdef");

    assert(result.name == `option!(literal!("abc"))`);
    assert(result.successful);
    assert(result.matches == ["abc"]);
    assert(result.begin == 0);
    assert(result.end == 3);
    assert(result.children.length == 1);
    assert(result.children == [ abc("abcdef")]);

    result = abc_("def");

    assert(result.name == `option!(literal!("abc"))`);
    assert(result.successful);
    assert(result.matches is null);
    assert(result.begin == 0);
    assert(result.end == 0);
    assert(result.children.length == 0);
}

/**
   Tries 'r' on the input. If it succeeds, the rule also succeeds, without consuming any input.
   If 'r' fails, then posLookahead!r also fails. Low-level implementation of '&r'.
*/
template posLookaheadT(ParseTree, alias r)
{
    enum name = "posLookahead!(" ~ getName!(r) ~ ")";

    ParseTree posLookaheadT(ParseTree p)
        {
            version (tracer)
            {
                if (shouldTrace(getName!(r)(), p))
                    trace(traceMsg(p, name, getName!(r)()));
            }
            ParseTree temp = r(p);
            if (temp.successful)
                return ParseTree(name, temp.successful, [], p.input, p.end, p.end);
            else
                return ParseTree(name, temp.successful, [temp.matches[$-1]], p.input, p.end, p.end);
        }

    ParseTree posLookaheadT(string input)
        {
            return posLookaheadT!(ParseTree, r)(ParseTree("",false,[],input));
        }

    string posLookaheadT(GetName g)
        {
            return name;
        }
}

@safe unittest // 'posLookahead' unit test
{
    mixin DefaultPatters!(ParseTree, [q{literal}, q{posLookahead}]);

    alias a = literal!"a";
    alias abc = literal!"abc";

    alias a_ = posLookahead!(a);
    alias abc_ = posLookahead!(abc);

    assert(getName!(a_)() == `posLookahead!(literal!("a"))`);
    assert(getName!(abc_)() == `posLookahead!(literal!("abc"))`);

    assert(!a_("").successful);
    assert(a_("a").successful);
    assert(a_("aa").successful);
    assert(!a_("b").successful);

    ParseTree result = a_("a");

    assert(result.name == `posLookahead!(literal!("a"))`);
    assert(result.successful);
    assert(result.matches is null);
    assert(result.begin == 0);
    assert(result.end == 0);
    assert(result.children.length == 0);

    result = a_("");

    assert(result.name == `posLookahead!(literal!("a"))`);
    assert(!result.successful);
    assert(result.matches == [`"a"`], "posLookahead error message.");
    assert(result.begin == 0);
    assert(result.end == 0);
    assert(result.children.length == 0);

    assert(!abc_("").successful);
    assert(abc_("abc").successful);
    assert(abc_("abcabc").successful);
    assert(!abc_("ab").successful);

    result = abc_("abcdef");

    assert(result.name == `posLookahead!(literal!("abc"))`);
    assert(result.successful);
    assert(result.matches is null);
    assert(result.begin == 0);
    assert(result.end == 0);
    assert(result.children.length == 0);

    result = abc_("def");

    assert(result.name == `posLookahead!(literal!("abc"))`);
    assert(!result.successful);
    assert(result.matches == [`"abc"`], "posLookahead error message.");
    assert(result.begin == 0);
    assert(result.end == 0);
    assert(result.children.length == 0);
}

/**
   Tries 'r' on the input. If it fails, the rule succeeds, without consuming any input.
   If 'r' succeeds, then negLookahead!r fails. Low-level implementation of '!r'.
*/
template negLookaheadT(ParseTree, alias r)
{
    enum name = "negLookahead!(" ~ getName!(r) ~ ")";

    ParseTree negLookaheadT(ParseTree p)
        {
            version (tracer)
            {
                if (shouldTrace(getName!(r)(), p))
                    trace(traceMsg(p, name, getName!(r)()));
            }

            ParseTree temp = r(p);
            if (temp.successful)
                return ParseTree(name, false, ["anything but \"" ~ p.input[temp.begin..temp.end] ~ "\""], p.input, p.end, p.end);
            else
                return ParseTree(name, true, [], p.input, p.end, p.end);
        }

    ParseTree negLookaheadT(string input)
        {
            return negLookaheadT!(ParseTree, r)(ParseTree("",false,[],input));
        }

    string negLookaheadT(GetName g)
        {
            return name;
        }
}

@safe unittest // 'negLookahead' unit test
{
    mixin DefaultPatters!(ParseTree, [q{literal}, q{negLookahead}]);

    alias a = literal!"a";
    alias abc = literal!"abc";

    alias a_ = negLookahead!(a);
    alias abc_ = negLookahead!(abc);

    assert(getName!(a_)() == `negLookahead!(literal!("a"))`);
    assert(getName!(abc_)() == `negLookahead!(literal!("abc"))`);

    assert(a_("").successful);
    assert(!a_("a").successful);
    assert(!a_("aa").successful);
    assert(a_("b").successful);

    ParseTree result = a_("a");

    assert(result.name == `negLookahead!(literal!("a"))`);
    assert(!result.successful);
    assert(result.matches == [`anything but "a"`]);
    assert(result.begin == 0);
    assert(result.end == 0);
    assert(result.children.length == 0);

    result = a_("");

    assert(result.name == `negLookahead!(literal!("a"))`);
    assert(result.successful);
    assert(result.matches is null);
    assert(result.begin == 0);
    assert(result.end == 0);
    assert(result.children.length == 0);

    assert(abc_("").successful);
    assert(!abc_("abc").successful);
    assert(!abc_("abcabc").successful);
    assert(abc_("ab").successful);

    result = abc_("abcdef");

    assert(result.name == `negLookahead!(literal!("abc"))`);
    assert(!result.successful);
    assert(result.matches == [`anything but "abc"`]);
    assert(result.begin == 0);
    assert(result.end == 0);
    assert(result.children.length == 0);

    result = abc_("def");

    assert(result.name == `negLookahead!(literal!("abc"))`);
    assert(result.successful);
    assert(result.matches is null);
    assert(result.begin == 0);
    assert(result.end == 0);
    assert(result.children.length == 0);
}

/**
   Internal helper template, to get a parse tree node with a name. For example, given:
   ----
   alias or!(literal!("abc"), charRange!('0','9')) myRule;
   ----

   myRule gives nodes named "or", since its the parent rule. If you want nodes to be named "myRule",
   use named. named just overwrites the original root node name, the children are left untouched.

   See_Also: defined.

   ----
   alias or!(literal!("abc"), charRange!('0','9')) rule;
   alias named!(rule, "myRule") myRule;

   auto input = "abc3";
   auto p1 = rule(input);
   auto p2 = myRule(input);

// They are both successful
assert(p1.successful && p2.successful);
assert(p1.matches == p2.matches);
// But the names are different
assert(p1.name == `or!(literal!("abc"), charRange!('0','9'))`);
assert(p2.name == `myRule`);
// Same children:
assert(p2.children == p1.children);

----
*/
template namedT(ParseTree, alias r, string name)
{
    ParseTree namedT(ParseTree p)
        {
            ParseTree result = r(p);
            result.name = name;
            return result;
        }

    ParseTree namedT(string input)
        {
            return namedT!(ParseTree, r, name)(ParseTree("",false,[],input));
        }

    string namedT(GetName g)
        {
            return name;
        }
}

@safe unittest // 'named' unit test
{
    mixin DefaultPatters!(ParseTree, [q{literal}, q{or}, q{named}, q{charRange}]);

    alias rule = or!(literal!("abc"), charRange!('0','9'));
    alias myRule = named!(rule, "myRule");

    assert(getName!(rule)() == `or!(literal!("abc"), charRange!('0','9'))`);
    assert(getName!(myRule)() == "myRule");

    // Equality on success (except for the name)
    ParseTree result = rule("abc0");
    ParseTree myResult = myRule("abc0");

    assert(myResult.successful == result.successful);
    assert(myResult.name == "myRule");
    assert(myResult.matches == result.matches);
    assert(myResult.begin == result.begin);
    assert(myResult.end == result.end);
    assert(myResult.children == result.children);

    // Equality on failure (except for the name)
    result = rule("_abc");
    myResult = myRule("_abc");

    assert(myResult.successful == result.successful);
    assert(myResult.name == "myRule");
    assert(myResult.matches == result.matches);
    assert(myResult.begin == result.begin);
    assert(myResult.end == result.end);
    assert(myResult.children == result.children);
}

/**
   Internal helper template, to get a parse tree node with a name, while keeping the original node (see also named).
   For example, given:
   ----
   alias or!(literal!("abc"), charRange!('0','9')) myRule;
   ----

   myRule gives nodes named "or", since its the parent rule. If you want nodes to be named "myRule",
   use defined. Contrary to named (see before), the original node is pushed as the child.

   See_Also: named.

   ----
   alias or!(literal!("abc"), charRange!('0','9')) rule;
   alias defined!(rule, "myRule") myRule;

   auto input = "abc3";
   auto p1 = rule(input);
   auto p2 = myRule(input);

// They are both successful
assert(p1.successful && p2.successful);
assert(p1.matches == p2.matches);
// But the names are different
assert(p1.name == `or!(literal!("abc"), charRange!('0','9'))`);
assert(p2.name == `myRule`);
// Here the original tree is not discarded:
assert(p2.children[0] == p1);
----
*/
template definedT(ParseTree, alias r, string name)
{
    ParseTree definedT(ParseTree p)
        {
            ParseTree result = r(p);
            result.children = [result];
            result.name = name;
            return result;
        }

    ParseTree definedT(string input)
        {
            return definedT!(ParseTree, r,name)(ParseTree("",false,[],input));
        }

    string definedT(GetName g)
        {
            return name;
        }
}

@safe unittest // 'defined' unit test
{
    mixin DefaultPatters!(ParseTree, [q{literal}, q{or}, q{named}, q{charRange}, q{defined}]);

    alias rule = or!(literal!("abc"), charRange!('0','9'));
    alias myRule = defined!(rule, "myRule");

    assert(getName!(rule)() == `or!(literal!("abc"), charRange!('0','9'))`);
    assert(getName!(myRule)() == "myRule");

    // Equality on success (except for the name)
    ParseTree result = rule("abc0");
    ParseTree myResult = myRule("abc0");

    assert(myResult.successful && result.successful);
    assert(myResult.name == "myRule");
    assert(myResult.matches == result.matches);
    assert(myResult.begin == result.begin);
    assert(myResult.end == result.end);
    assert(myResult.children[0] == result);

    // Equality on failure (except for the name)
    result = rule("_abc");
    myResult = myRule("_abc");

    assert(!myResult.successful && !result.successful);
    assert(myResult.name == "myRule");
    assert(myResult.matches == result.matches);
    assert(myResult.begin == result.begin);
    assert(myResult.end == result.end);
    assert(myResult.children[0] == result);
}

/**
   Low-level representation for the expression 'r {act}'. That is, it applies rule 'r'
   on the input and then calls 'act' on the resulting ParseTree.
*/
template actionT(ParseTree, alias r, alias act)
{
    ParseTree actionT(ParseTree p)
        {
            return act(r(p));
        }

    ParseTree actionT(string input)
        {
            return actionT!(ParseTree, r,act)(ParseTree("",false,[],input));
        }

    string actionT(GetName g)
        {
            enum name = "action!("~ getName!(r)() ~ ", " ~ __traits(identifier, act) ~ ")";
            return name;
        }
}

@safe unittest // 'action' unit test
{
    mixin DefaultPatters!(ParseTree, [q{literal}, q{action}]);

    ParseTree foo(ParseTree p)
    {
        p.matches ~= p.matches; // doubling matches
        return p;
    }
    alias literal!("abc") abc;

    alias action!(abc, foo) abcfoo;

    assert(getName!(abcfoo) == `action!(literal!("abc"), foo)`);

    ParseTree result = abcfoo("abc");
    ParseTree reference = abc("abc");

    assert(result.successful == reference.successful);
    assert(result.successful);
    assert(result.matches == reference.matches ~ reference.matches);
    assert(result.begin == reference.begin);
    assert(result.end == reference.end);
    assert(result.children == reference.children);

    // On failure
    result = abcfoo("_abc");
    reference = abc("_abc");

    assert(result.successful == reference.successful);
    assert(!result.successful);
    assert(result.matches == reference.matches ~ reference.matches);
    assert(result.begin == reference.begin);
    assert(result.end == reference.end);
    assert(result.children == reference.children);
}

/**
   Concatenates a ParseTree's matches as one match and discards its children. Equivalent to the expression '~r'.
*/
template fuseT(ParseTree, alias r)
{
    ParseTree fuseT(ParseTree p)
        {
            p = r(p);
            if(p.successful)
            {
                if (p.matches.length != 0)
                    p.matches = [std.array.join(p.matches)];

                p.children = null; // also discard children
            }
            return p;
        }

    ParseTree fuseT(string input)
        {
            return fuseT!(ParseTree, r)(ParseTree("",false,[],input));
        }

    string fuseT(GetName g)
        {
            enum name = "fuse!(" ~ getName!(r)() ~ ")";
            return name;
        }
}

@safe unittest // 'fuse' unit test
{
    mixin DefaultPatters!(ParseTree, [q{literal}, q{oneOrMore}, q{fuse}, q{discard}]);

    alias abcs = oneOrMore!(literal!("abc"));

    alias f = fuse!(abcs);

    assert(getName!(f) == `fuse!(oneOrMore!(literal!("abc")))`);

    ParseTree result = f("abcabcabc");
    ParseTree reference = abcs("abcabcabc");

    assert(result.successful == reference.successful);
    assert(result.successful);
    assert(reference.matches == ["abc", "abc", "abc"]);
    assert(result.matches == ["abcabcabc"]);
    assert(result.begin == reference.begin);
    assert(result.end == reference.end);
    assert(result.children is null);

    // On failure
    result = f("_abc");
    reference = abcs("_abc");

    assert(result.successful == reference.successful);
    assert(!result.successful);
    assert(result.matches == reference.matches);
    assert(result.begin == reference.begin);
    assert(result.end == reference.end);
    assert(result.children == reference.children);

    alias dabc = discard!(literal!("abc"));
    alias f2 = fuse!(dabc);

    result = f2("abcabc");
    reference = dabc("abcabc");

    assert(result.successful);
    assert(result.matches is null);
    assert(result.begin == reference.begin);
    assert(result.end == reference.end);
    assert(result.children == reference.children);
}

/**
   Calls 'r' on the input and then discards its children nodes.
*/
template discardChildrenT(ParseTree, alias r)
{
    ParseTree discardChildrenT(ParseTree p)
        {
            p = r(p);
            p.children = null;
            return p;
        }

    ParseTree discardChildrenT(string input)
        {
            return .discardChildrenT!(ParseTree, r)(ParseTree("",false,[],input));
        }

    string discardChildrenT(GetName g)
        {
            enum name = "discardChildren!(" ~ getName!(r)() ~ ")";
            return name;
        }
}

/**
   Calls 'r' on the input and then discards its matches.
*/
template discardMatchesT(ParseTree, alias r)
{
    ParseTree discardMatchesT(ParseTree p)
        {
            p = r(p);
            if (p.successful)
                p.matches = null;
            return p;
        }

    ParseTree discardMatchesT(string input)
        {
            return discardMatchesT!(ParseTree, r)(ParseTree("",false,[],input));
        }

    string discardMatchesT(GetName g)
        {
            enum name = "discardMatches!(" ~ getName!(r)() ~ ")";
            return name;
        }
}

/**
   Calls 'r' on the input and then discard everything 'r' returned: no children, no match and index
   put at the end of the match. It's the low-level engine behind ':r'.
*/
template discardT(ParseTree, alias r)
{
    ParseTree discardT(ParseTree p)
        {
            ParseTree result = r(p);
            result.name = "discard!(" ~ getName!(r)() ~ ")";
            //result.begin = result.end;
            result.children = null;
            if (result.successful)
                result.matches = null;//to keep error messages, if any

            return result;
        }

    ParseTree discardT(string input)
        {
            return discardT!(ParseTree, r)(ParseTree("",false,[],input));
        }

    string discardT(GetName g)
        {
            return "discard!(" ~ getName!(r)() ~ ")";
        }
}

@safe unittest // 'discard' unit test
{
    mixin DefaultPatters!(ParseTree, [q{literal}, q{oneOrMore}, q{discard}, q{and}]);

    alias abc = literal!"abc";
    alias abcs = oneOrMore!abc;
    alias dabc = discard!(literal!("abc"));
    alias dabcs = discard!(oneOrMore!(literal!("abc")));

    ParseTree reference = abc("abc");
    ParseTree result =dabc("abc");

    assert(result.successful == reference.successful);
    assert(result.successful);
    assert(result.name == `discard!(literal!("abc"))`);
    assert(result.matches is null);
    assert(result.begin == reference.begin);
    assert(result.end == reference.end);
    assert(result.children is null);

    reference = abcs("abcabcabc");
    result = dabcs("abcabcabc");

    assert(result.successful == reference.successful);
    assert(result.successful);
    assert(result.name == `discard!(oneOrMore!(literal!("abc")))`);
    assert(result.matches is null);
    assert(result.begin == reference.begin);
    assert(result.end == reference.end);
    assert(result.children is null);

    // On failure
    reference = abcs("");
    result = dabcs("");

    assert(result.successful == reference.successful);
    assert(!result.successful);
    assert(result.name == `discard!(oneOrMore!(literal!("abc")))`);
    assert(result.matches == [`"abc"`], "discard error message.");
    assert(result.begin == reference.begin);
    assert(result.end == reference.end);
    assert(result.children is null);

    // Action on 'and'
    alias discardMiddle = and!(abc,dabc,abc) discardMiddle;

    result = discardMiddle("abcabcabc");
    assert(result.successful);
    assert(result.matches == ["abc", "abc"]);
    assert(result.begin == 0);
    assert(result.end == 3*3);
    assert(result.children.length == 2);
    assert(result.children == [abc("abcabcabc"), abc(abc(abc("abcabcabc")))]);
}

/**
   Calls 'r' on the input and then discards everything 'r' did, except its matches (so that
   they propagate upwards). Equivalent to ';r'.
*/
template dropT(ParseTree, alias r)
{
    ParseTree dropT(ParseTree p)
        {
            ParseTree result = r(p);
            //result.begin = result.end;
            result.children = null;
            if (result.successful)
                result.name = "drop!(" ~ getName!(r)() ~ ")";
            return result;
        }

    ParseTree dropT(string input)
        {
            return dropT!(ParseTree, r)(ParseTree("",false,[],input));
        }

    string dropT(GetName g)
        {
            return "drop!(" ~ getName!(r)() ~ ")";
        }
}

@safe unittest // 'drop' unit test
{
    mixin DefaultPatters!(ParseTree, [q{literal}, q{charRange}, q{drop}, q{oneOrMore}, q{and}]);

    alias abc = literal!"abc";
    alias abcs = oneOrMore!abc;
    alias dabc = drop!(literal!("abc"));
    alias dabcs = drop!(oneOrMore!(literal!("abc")));

    ParseTree reference = abc("abc");
    ParseTree result =dabc("abc");

    assert(result.successful == reference.successful);
    assert(result.successful);
    assert(result.name == `drop!(literal!("abc"))`);
    assert(result.matches == reference.matches);
    assert(result.begin == reference.begin);
    assert(result.end == reference.end);
    assert(result.children is null);

    reference = abcs("abcabcabc");
    result = dabcs("abcabcabc");

    assert(result.successful == reference.successful);
    assert(result.successful);
    assert(result.name == `drop!(oneOrMore!(literal!("abc")))`);
    assert(result.matches == reference.matches);
    assert(result.begin == reference.begin);
    assert(result.end == reference.end);
    assert(result.children is null);

    // On failure
    reference = abcs("");
    result = dabcs("");

    assert(result.successful == reference.successful);
    assert(!result.successful);
    assert(result.name == reference.name);
    assert(result.matches == [`"abc"`], "'drop' error message.");
    assert(result.begin == reference.begin);
    assert(result.end == reference.end);
    assert(result.children is null);

    // Action on 'and'
    alias and!(abc,dabc,abc) discardMiddle;

    result = discardMiddle("abcabcabc");
    assert(result.successful);
    assert(result.matches == ["abc", "abc", "abc"], "3 matches.");
    assert(result.begin == 0);
    assert(result.end == 3*3);
    assert(result.children.length == 2, "but only 2 children.");
    assert(result.children == [abc("abcabcabc"), abc(abc(abc("abcabcabc")))]);
}

/**
   Makes r disappear in a sequence, letting its children take its place. It's equivalent
   to the '%' operator. Given A <- B %C D and C <- E F, a successful parse for A will
   generate a three with four children: B, E, F and D parse trees.
*/
template propagateT(ParseTree, alias r)
{
    ParseTree propagateT(ParseTree p)
        {
            ParseTree result = r(p);
            if (result.successful)
                result.name = "propagate!(" ~ getName!(r)() ~ ")";
            return result;
        }

    ParseTree propagateT(string input)
        {
            return propagateT!(ParseTree, r)(ParseTree("",false,[],input));
        }

    string propagateT(GetName g)
        {
            return "propagate!(" ~ getName!(r)() ~ ")";
        }
}

/**
   Makes 'r's result be kept when it would be discarded by the tree-decimation done by a grammar.
   Equivalent to '^r'.
*/
template keepT(ParseTree, alias r)
{
    ParseTree keepT(ParseTree p)
        {
            ParseTree result = r(p);
            if (result.successful)
            {
                result.children = [result];
                result.name = "keep!(" ~ getName!(r)() ~ ")";
            }
            return result;
        }

    ParseTree keepT(string input)
        {
            return keepT!(ParseTree, r)(ParseTree("",false,[],input));
        }

    string keepT(GetName g)
        {
            return "keep!(" ~ getName!(r)() ~ ")";
        }
}

@safe unittest // 'keep' unit test
{
    mixin DefaultPatters!(ParseTree, [q{literal}, q{and}, q{named}, q{keep}]);
    // Grammar mimicry
    static struct KeepTest
    {
        static bool isRule(string s)
            {
                if (s == "A" || s == "KA")
                    return true;
                else
                    return false;
            }

        mixin decimateTree!ParseTree;

        // Equivalent to A <- 'a' 'b'
        static ParseTree A(string s)
            {
                return decimateTree(named!(and!(literal!"a", literal!"b"), "A")(s));
            }

        // Here we use keep to protect 'b'
        // Equivalent to KA <- 'a' ^'b'
        static ParseTree KA(string s)
            {
                return decimateTree(named!(and!(literal!"a", keep!(literal!"b")), "KA")(s));
            }
    }

    ParseTree reference = KeepTest.A("abc");
    ParseTree result = KeepTest.KA("abc");

    assert(result.successful == reference.successful);
    assert(result.matches == reference.matches);
    assert(result.matches == ["a","b"]);
    assert(result.begin == reference.begin);
    assert(result.end == reference.end);
    assert(reference.children.length == 0);
    assert(result.children.length == 1);
    assert(result.children == [literal!("b")(literal!("a")("abc"))], "'b' node was kept.");
}

template AddSpaceT(ParseTree, alias sp)
{
    template AddSpaceT(alias r)
    {
        alias AddSpaceT=TypeTuple!(r, discardT!(ParseTree,sp));
    }
}

/**
   The engine formerly behind the '< ' Pegged rule: all sequence subelements of a rule are interspersed
   with a space-consuming rule, given as the first template parameter. It's not used by Pegged anymore
   but can be useful for low-level code. It might become deprecated, but it's not there yet.

   ----
   alias and!(literal!"abc", literal!"def") rule1; // "abc" "def", equivalent to "abcdef"
   alias spaceAnd!(oneOrMore!blank, literal!"abc", literal!"def") rule2; // "abc" "def", but with spaces in-between.

   string input1 = "abcdef";
   string input2 = "  abc

   def  "; // with spaces and end of line markers.

   assert(rule1(input1).successful); // OK
   assert(!rule1(input2).successful); // NOK, couldn't find "def" after "abc"

   assert(rule2(input1).successful); // OK
   assert(rule2(input2).successful); // Still OK
   assert(rule2(input2).matches == ["abc","def"]);// rule2 finds the literals among the spaces
   ----

   As you can see on the previous line, spaceAnd discards the matched spaces
   and returns matches only for the 'real' subrules.

   Note: by using a non-space rule as the first template argument,
   you can use spaceAnd as a generic 'find these patterns, possibly separated by this pattern' rule.

   For example, using digits as separators:
   ----
   alias spaceAnd!(digit, literal!"abc", litera!"def") rule3;

   ParseTree result = rule3("123abc45def67890");
   assert(rule3.successful);
   assert(rule3.matches == ["abc", "def"]);
   assert(rule3.children.length == 2);

   assert(rule3.begin == 0;)
   assert(rule3.end == "123abc45def67890".length);
   ----
*/

@safe unittest // 'spaceAnd' unit test
{
    mixin DefaultPatters!(ParseTree, [q{literal}, q{and}, q{oneOrMore}, q{spaceAnd}, q{blank}, q{digit}]);

    alias a = literal!"a";
    alias b = literal!"b";

    //Basic use
    alias ab = and!(a,b);
    alias a_b = spaceAnd!(oneOrMore!(blank), a, b);

    ParseTree reference = ab("ab");
    ParseTree result = a_b("ab");

    assert(reference.successful);
    assert(result.successful);
    assert(result.matches == reference.matches);
    assert(result.begin == reference.begin);
    assert(result.end == reference.end);
    assert(result.children == reference.children);

    reference = ab("   a  b  ");
    result = a_b(  "   a  b  ");

    assert(!reference.successful);
    assert(result.successful);
    assert(result.matches == ["a","b"]);
    assert(result.begin == 0);
    assert(result.end == "   a  b  ".length);
    assert(result.children.length == 2);

    reference = ab("ac");
    result = a_b("ac");

    assert(!reference.successful);
    assert(!result.successful);

    reference = ab("   a  c   ");
    result = a_b("   a  c   ");

    assert(!reference.successful);
    assert(!result.successful);

    // With another separator than spaces
    alias a0b = spaceAnd!(digit, a, b);

    assert(a0b("ab").successful);
    assert(!a0b("  a b  ").successful);

    result = a0b("012a34b567");

    assert(result.successful);
    assert(result.matches == ["a", "b"]);
    assert(result.begin == 0);
    assert(result.end == "012a34b567".length);
    assert(result.children.length == 2);
}

/// Mixin to simplify a parse tree inside a grammar
mixin template decimateTree(ParseTree)
{
    static ParseTree decimateTree(ParseTree p)
        {
            if(p.children.length == 0) return p;

            bool parseFailed = !p.successful;

            ParseTree[] filterChildren(ParseTree pt)
            {
                ParseTree[] result;
                foreach(child; pt.children)
                {
                    import std.algorithm : startsWith;

                    if (  (isRule(child.name) && (child.matches.length != 0 || parseFailed))
                        || (!child.successful && child.children.length == 0)
                        || (!child.successful && child.name.startsWith("or!") && child.children.length > 1)
                        || (!pt.successful && child.successful && child.children.length == 0 && child.failedChild.length > 0))
                    {
                        child.children = filterChildren(child);
                        result ~= child;
                    }
                    else if (child.name.startsWith("keep!(")) // 'keep' node are never discarded.
                        // They have only one child, the node to keep
                    {
                        result ~= child.children[0];
                    }
                    else // discard this node, but see if its children contain nodes to keep
                    {
                        result ~= filterChildren(child);
                    }
                }
                return result;
            }
            void filterFailedChildren(ref ParseTree pt)
            {
                foreach(ref child; pt.children)
                {
                    filterFailedChildren(child);
                    import std.algorithm : startsWith;

                    if (  (isRule(child.name) && (child.matches.length != 0 || parseFailed))
                        || (!child.successful && child.children.length == 0)
                        || (!child.successful && child.name.startsWith("or!") && child.children.length > 1)
                        || (!pt.successful && child.successful && child.children.length == 0 && child.failedChild.length > 0))
                    {
                    }
                    else if (child.name.startsWith("keep!(")) // 'keep' node are never discarded.
                        // They have only one child, the node to keep
                    {
                    }
                    else if (child.failedChild.length > 0)// discard this node, but see if its children contain nodes to keep
                    {
                        pt.failedChild ~= child.failedChild;
                        child.failedChild = [];
                    }
                }
                foreach(ref child; pt.failedChild)
                {
                    filterFailedChildren(child);
                    child.children = filterChildren(child);
                }
            }
            if (!p.successful)
                filterFailedChildren(p);
            p.children = filterChildren(p);
            return p;
        }
}

/**
   Discard one-child nodes and replace them with their children.
   Most grammar tend to produce long one-child/one-child branches,
   simplifyTree compacts these.
*/
ParseTree simplifyTree(ParseTree)(ParseTree p)
{
    foreach(ref child; p.children)
        child = simplifyTree(child);

    if (p.children.length != 1)
        return p;
    else // linear tree
        return p.children[0];
}

/**
   Returns: the number of nodes in a parse tree.
*/
size_t size(ParseTree)(ParseTree p)
{
    size_t result = 1;
    foreach(child; p.children)
        result += size(child);
    return result;
}

/**
   Generic ParseTree modifier:
   predicate must be callable with a ParseTree and return a boolean.
   modifier must be callable with a ParseTree and return a ParseTree.

   If predicate is true on input, modify calls modifier on input and return the result.
   If not, it continues with the children.
*/
ParseTree modify(ParseTree, alias predicate, alias modifier)(ParseTree input) if (isParseTree!ParseTree)
{
    foreach(ref child; input.children)
        child = modify!(ParseTree, predicate, modifier)(child);

    if (predicate(input))
        input = modifier(input);

    return input;
}

// mixin template ParseCollections(alias ParseTreeT=void) {
//     static if (is(ParseTreeT == void)) {
//         alias ParseTree = typeof(this);
//     }
//     else {
//         alias ParseTree = ParseTreeT;
//     }
//     mixin ParseCollectionsM;
// }

mixin template ParseCollectionsM() {
//    static assert(isParseTree!ParseTree, "ParseTreeT must be a isParseTree type");
    @safe:
    import pegged.peg;
    alias eoi = eoiT!ParseTree;

    alias eps = epsT!ParseTree;
    alias any = anyT!ParseTree;
    alias fail = failT!ParseTree;
    alias literal(string s) = literalT!(ParseTree, s);
    alias caseInsensitiveLiteral(string s) = caseInsensitiveLiteralT!(ParseTree, s);
    alias charRange(dchar begin, dchar end) = charRangeT!(ParseTree, begin, end);

    alias wrapAround(alias before, alias target, alias after) = wrapAroundT!(ParseTree, before, target, after);
    alias and(rules...) = andT!(ParseTree, rules);
    alias or(rules...) = orT!(ParseTree, rules);
    alias longest_match(rules...) = longest_matchT!(ParseTree, rules);
    alias keywords(kws...) = keywordsT!(ParseTree, kws);
    alias zeroOrMore(alias r) = zeroOrMoreT!(ParseTree, r);
    alias oneOrMore(alias r) = oneOrMoreT!(ParseTree, r);
    alias option(alias r) = optionT!(ParseTree, r);
    alias posLookahead(alias r) = posLookaheadT!(ParseTree, r);
    alias negLookahead(alias r) = negLookaheadT!(ParseTree, r);
    alias named(alias r, string name) = namedT!(ParseTree, r, name);
    alias defined(alias r, string name)= definedT!(ParseTree, r, name);
    alias action(alias r, alias act) = actionT!(ParseTree, r, act);
    alias fuse(alias r) = fuseT!(ParseTree, r);
    alias discardChildren(alias r) = discardChildrenT!(ParseTree, r);
    alias discardMatches(alias r) = discardMatchesT!(ParseTree, r);
    alias discard(alias r) = discardT!(ParseTree, r);
    alias drop(alias r) = dropT!(ParseTree, r);
    alias propagate(alias r) = propagateT!(ParseTree, r);
    alias keep(alias r) = keepT!(ParseTree, r);
    alias AddSpace(alias sp) = AddSpaceT!(ParseTree, sp);

// }

// mixin template DefaultParsePatterns() {
    import std.meta : staticMap;
    /* ****************** predefined rules ******************** */

    alias endOfLine = named!(or!(literal!("\r\n"), literal!("\n"), literal!("\r")), "endOfLine"); /// predefined end-of-line parser
    alias eol = endOfLine; /// helper alias.

    alias space = or!(literal!(" "), literal!("\t"), literal!("\v")); /// predefined space-recognizing parser (space or tabulation).
    alias tab = named!(literal!"\t", "tab"); /// A parser recognizing \t (tabulation)
    alias spaces = named!(fuse!(discardChildren!(oneOrMore!space)),
        "spaces"); /// aka '~space+'
    alias blank = or!(space, endOfLine); /// Any blank char (spaces or end of line).
    alias spacing = named!(discard!(zeroOrMore!blank),
        "spacing"); /// The basic space-management parser: discard zero or more blank spaces.

    alias digit = charRange!('0', '9'); /// Decimal digit: [0-9]
    alias digits = named!(fuse!(discardChildren!(oneOrMore!digit)), "digits"); /// [0-9]+

    alias hexDigit = or!(charRange!('0','9'), charRange!('a','f'), charRange!('A', 'F')); /// Hexadecimal digit: [0-9a-fA-F]

    alias alpha = charRange!('a', 'z'); /// [a-z]
    alias Alpha = charRange!('A', 'Z'); /// [A-Z]

    alias ident = and!(oneOrMore!(or!(alpha, Alpha, literal!("_"))), zeroOrMore!(or!(digit, alpha, Alpha, literal!("_"))));
    alias identifier = named!(fuse!(discardChildren!ident),
        "identifier"); /// [a-zA-Z_][a-zA-Z_0-9]*, the basic C-family identifier
    alias qualifiedIdentifier = named!(fuse!(discardChildren!(and!(identifier, zeroOrMore!(and!(literal!".", identifier))))),
        "qualifiedIdentifier"); /// qualified identifiers (ids separated by dots: abd.def.g).

    alias slash = named!(literal!"/", "slash"); /// A parser recognizing '/'
    alias backslash = named!(literal!"\\", "backslash"); /// A parser recognizing '\'
    alias quote = named!(literal!"'", "quote"); /// A parser recognizing ' (single quote)
    alias doublequote = named!(literal!"\"", "doublequote"); /// A parser recognizing " (double quote)
    alias backquote = named!(literal!"`", "backquote"); /// A parser recognizing $(BACKTICK) (backquote)
    /// A list of elem's separated by sep's. One element minimum.
    alias list(alias elem, alias sep) = named!(spaceAnd!(oneOrMore!blank, and!(elem, zeroOrMore!(spaceAnd!(discardMatches!(sep), elem)))), "list");

/// A list of elem's separated by sep's. The empty list (no elem, no sep) is OK.
    alias list0(alias elem, alias sep) = named!(spaceAnd!(oneOrMore!blank, option!(and!(elem, zeroOrMore!(spaceAnd!(discardMatches!(sep), elem))))), "list0");

    alias spaceAnd(alias sp, rules...) = and!(discard!(zeroOrMore!sp), staticMap!(AddSpace!(zeroOrMore!sp), rules));
}

enum defaultNames =[
    "eol",
    "eoi",
    "named",
    "blank",
    "quote",
    "doublequote",
    "backquote",
    "alpha",
    "Alpha",
    "spacing",
    "identifier",
    "ident",
    "backslash",
    "hexDigit",
    "endOfLine",
    "qualifiedIdentifier",
    "literal",
    "posLookahead",
    "negLookahead",
    "option",
    "defined",
    "eps",
    "literal",
    "zeroOrMore",
    "oneOrMore",
    "literal",
    "list",
    "and",
    "or",
    "fail",
    "fuse",
    "digits",
    "charRange",
    "discard",
    "longest_match",
    "spaceAnd",
    "space",
    "digit",
    ];

/**
   Change the namespace of the grammar pattern in the ParseTree to scope if the mixin.
   names is the list of the pattern-names inside the ParseTree
*/
mixin template DefaultPatters(ParseTree, string[] names = defaultNames) {
    private import std.format;
    static foreach(name; names) {
        mixin(format!q{alias %1$s = ParseTree.%1$s;}(name));
    }
}
