/**
   This module contaits functions and parameter for ParseTree data element
*/
module pegged.parsetree;

import std.traits : isType, ReturnType, ForeachType, isCallable, Unqual;
/**
   Returns:
   Gets the lvalue of M where M can be a function/data as type of data
*/
template Returns(alias M) {
    static if (isType!M) {
        alias U = M;
    }
    else {
        alias U = typeof(M);
    }
    static if (isCallable!U) {
        alias Returns = Unqual!(ReturnType!U);
    }
    else {
        alias Returns = Unqual!(U);
    }
}

/**
   Returns
   true if T is a value ParseTree type
*/
enum isParseTree(T) =
    is(Returns!(T.name) == string) &&
    is(Returns!(T.successful) == bool)  &&
    is(Returns!(T.input) == string)  &&
    is(Returns!(T.begin) == size_t)  &&
    is(Returns!(T.end) == size_t) &&
    is(Returns!(T.failEnd) == size_t) &&
    is(ForeachType!(Returns!(T.matches)) == string)  &&
    is(ForeachType!(Returns!(T.children)) == T)  &&
    is(ForeachType!(Returns!(T.failedChild)) == T);


/**
   Contains the basic data and function for a ParseTree data element
*/
mixin template ParseTreeM() {
    import pegged.peg;
    import std.functional : toDelegate;
    import std.conv : to;
    import std.algorithm.iteration : map;
    import std.array : array;

    alias ParseTree = typeof(this);
    @safe {

        alias Dynamic = ParseTree delegate(ParseTree) @safe;
        string name; /// The node name
        bool successful; /// Indicates whether a parsing was successful or not
        string[] matches; /// The matched input's parts. Some expressions match at more than one place, hence matches is an array.

        string input; /// The input string that generated the parse tree. Stored here for the parse tree to be passed to other expressions, as input.
        size_t begin, end; /// Indices for the matched part from the very beginning of the first match to the last char of the last match.

        ParseTree[] children; /// The sub-trees created by sub-rules parsing.

        size_t failEnd; // The furthest this tree could match the input (including !successful rules).
        ParseTree[] failedChild; /// The !successful child that could still be partially parsed.

        /**
           Basic toString for easy pretty-printing.
        */
        string toString(string tabs = "") const
        {
            string result = name;

            string childrenString;
            bool allChildrenSuccessful = true;

            foreach(i,child; children)
            {
                childrenString ~= tabs ~ " +-" ~ child.toString(tabs ~ ((i < children.length -1 ) ? " | " : "   "));
                if (!child.successful) {
                    allChildrenSuccessful = false;
                }
            }
            result ~= this.toStringThisNode(allChildrenSuccessful);
            return result ~ childrenString;
        }

        static ParseTree[] getUpto(ParseTree[] children, size_t minFailedLength) {
            import std.algorithm : filter, max;
            ParseTree[] arr;
            foreach(a; children.filter!(r => max(r.end, r.failEnd) >= minFailedLength)) {
                arr~=a;
            }
            return arr;
//        return children.filter!(r => max(r.end, r.failEnd) >= minFailedLength).array();
        }


        /**
         * Basic toString of only this node, without the children
         */
        private string toStringThisNode(bool allChildrenSuccessful) const
        {
            if (successful) {
                return to!string([begin, end]) ~ to!string(matches) ~ "\n";
            } else { // some failure info is needed
                if (allChildrenSuccessful) { // no one calculated the position yet
                    return " " ~ this.failMsg ~ "\n";
                } else {
                    return " (failure)\n";
                }
            }
        }

        /**
         * Default fail message formating function
         */
        static string defaultFormatFailMsg(Position pos, string left, string right, const ParseTree pt)
        {
            return "Failure at line " ~ to!string(pos.line) ~ ", col " ~ to!string(pos.col) ~ ", "
                ~ (left.length > 0 ? "after " ~ left.stringified ~ " " : "")
                ~ "expected " ~ (pt.matches.length > 0 ? pt.matches[$ - 1].stringified : "NO MATCH")
                ~ `, but got ` ~ right.stringified;
        };


        /**
         * Generates a generic error when a node fails
         *
         * @param successMsg String returned when there isn't an error
         * @param formatFailMsg Formating delegate function that generates the error message.
         */
        string failMsg(string delegate(Position, string, string, const ParseTree) @safe formatFailMsg = toDelegate(&defaultFormatFailMsg),
            string successMsg = "Sucess") const @property
        {
            foreach(i, child; children) {
                if (!child.successful) {
                    return child.failMsg(formatFailMsg, successMsg);
                }
            }

            if (!successful) {
                Position pos = position(this);
                string left, right;

                if (pos.index < 10) {
                    left = input[0 .. pos.index];
                } else {
                    left = input[pos.index - 10 .. pos.index];
                }
                if (pos.index + 10 < input.length) {
                    right = input[pos.index .. pos.index + 10];
                } else {
                    right = input[pos.index .. $];
                }
                return formatFailMsg(pos, left, right, this);
            }

            return successMsg;
        }

        ParseTree dup() const @property
        {
            ParseTree result;
            result.name = name;
            result.successful = successful;
            result.matches = matches.dup;
            result.input = input;
            result.begin = begin;
            result.end = end;
            result.failEnd = failEnd;
            result.failedChild = map!(p => p.dup)(failedChild).array();
            result.children = map!(p => p.dup)(children).array();
            return result;
        }

        @trusted immutable(ParseTree) idup() const @property
        {
            return cast(immutable)dup();
        }

        // Override opIndex operators
        ref ParseTree opIndex(size_t index) {
            return children[index];
        }

        ref ParseTree[] opIndex() return {
            return children;
        }

        size_t opDollar(size_t pos)() const
        {
            return children.length;
        }

        ParseTree[] opSlice(size_t i, size_t j) {
            return children[i..j];
        }
    }
}
