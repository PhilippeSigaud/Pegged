module pegged.dynamic.peg;

import std.algorithm : startsWith;
import std.array: join;
import std.conv: to;

import std.stdio;

import pegged.peg;


private import pegged.parsetree : isParseTree;
// private alias ParseTree=DefaultParseTree;
// alias ParseTree delegate(ParseTree) Dynamic;

@safe struct DynamicPeg(ParseTree) {
    static {
        string getName(D)(D rule)
        {
            return callDynamic(rule, ParseTree()).name;
        }

        ParseTree callDynamic(D)(D d, string s)
        {
            static if (is(typeof(d) : ParseTree delegate(ParseTree)) || is(typeof(d) : ParseTree function(ParseTree)))
                return d(ParseTree("",false,[], s));
            else static if (is(typeof(d) : ParseTree delegate(ParseTree) delegate()) || is(typeof(d) : ParseTree function(ParseTree) delegate()))
                return d()(ParseTree("",false,[], s));
            else static if (is(typeof(d) : ParseTree delegate(string)) || is(typeof(d) : ParseTree function(string)))
                return d(s);
            else static if (is(typeof(d) : ParseTree delegate(string) delegate()) || is(typeof(d) : ParseTree function(string) delegate()))
                return d()(s);
            else
                assert(false, "Bad callDynamic, with type " ~ D.stringof);
        }

        ParseTree callDynamic(D)(D d, ParseTree p)
        {
            static if (is(typeof(d) : ParseTree delegate(ParseTree)) || is(typeof(d) : ParseTree function(ParseTree)))
                return d(p);
            else static if (is(typeof(d) : ParseTree delegate(ParseTree) delegate()) || is(typeof(d) : ParseTree function(ParseTree) delegate()))
                return d()(p);
            else static if (is(typeof(d) : ParseTree delegate(string)) || is(typeof(d) : ParseTree function(string)))
                return d(p.input[p.end..$]);
            else static if (is(typeof(d) : ParseTree delegate(string) delegate()) || is(typeof(d) : ParseTree function(string) delegate()))
                return d()(p.input[p.end..$]);
            else
                static assert(false, "Bad callDynamic, with type " ~ D.stringof);
        }

        ParseTree.Dynamic fail()
        {
            return (ParseTree p)
            {
                return ParseTree("fail", false, ["fail"], p.input, p.end, p.end);
            };
        }

        ParseTree.Dynamic eoi()
        {
            return (ParseTree p)
            {
                if (p.end == p.input.length)
                    return ParseTree("eoi", true, [], p.input, p.end, p.end);
                else
                    return ParseTree("eoi", false, ["end of input"], p.input, p.end, p.end);
            };
        }

        ParseTree.Dynamic eps()
        {
            return (ParseTree p)
            {
                return ParseTree("eps", true, [""], p.input, p.end, p.end);
            };
        }

        ParseTree.Dynamic any()
        {
            return(ParseTree p)
            {
                if (p.end < p.input.length)
                    return ParseTree("any", true, [p.input[p.end..p.end+1]], p.input, p.end, p.end+1);
                else
                    return ParseTree("any", false, ["any char"], p.input, p.end, p.end);
            };
        }

        ParseTree.Dynamic literal(string s)
        {
            return (ParseTree p)
            {
                if (p.end+s.length <= p.input.length && p.input[p.end..p.end+s.length] == s)
                    return ParseTree("literal!(\"" ~ s ~ "\")", true, [s], p.input, p.end, p.end+s.length);
                else
                    return ParseTree("literal!(\"" ~ s ~ "\")", false, [`"` ~ s ~ `"`], p.input, p.end, p.end);

            };
        }

        ParseTree.Dynamic charRange(dchar begin, dchar end)
        {
            return (ParseTree p)
            {
                string longName = "a char between '"~to!string(begin)~"' and '"~to!string(end)~"'";
                if (p.end < p.input.length && p.input[p.end] >= begin && p.input[p.end] <= end)
                    return ParseTree("charRange!(" ~ to!string(begin) ~ ", " ~ to!string(end) ~ ")", true, [p.input[p.end..p.end+1]], p.input, p.end, p.end+1);
                else
                    return ParseTree("charRange!(" ~ to!string(begin) ~ ", " ~ to!string(end) ~ ")", false, [longName], p.input, p.end, p.end);
            };

        }

        ParseTree.Dynamic wrapAround(B, M, A)(B before, M middle, A after)
        {
            return(ParseTree p)
            {
                ParseTree temp = callDynamic(before,p);
                if (!temp.successful)
                    return temp;

                ParseTree result = callDynamic(middle,temp);
                if (!result.successful)
                    return result;
                result.begin = temp.begin;

                temp = callDynamic(after,result);
                if (!temp.successful)
                    return temp;

                result.end = temp.end;
                return result;
            };
        }

        ParseTree.Dynamic zeroOrMore(D)(D d)
        {
            return (ParseTree p)
            {
                string name = "zeroOrMore!(" ~ getName(d) ~ ")";
                ParseTree result = ParseTree(name, true, [], p.input, p.end, p.end);
                ParseTree temp = callDynamic(d,result);
                while(temp.successful
                    && (temp.begin < temp.end // To avoid infinite loops on epsilon-matching rules
                        || temp.name.startsWith("discard!(")))
                {
                    result.matches ~= temp.matches;
                    result.children ~= temp;
                    result.end = temp.end;
                    temp = callDynamic(d, result);
                }
                result.successful = true;
                return result;
            };
        }

        ParseTree.Dynamic oneOrMore(D)(D d)
        {
            return(ParseTree p)
            {
                string name = "oneOrMore!(" ~ getName(d) ~ ")";
                ParseTree result = ParseTree(name, false, [], p.input, p.end, p.end);
                ParseTree temp = callDynamic(d, result);

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
                        temp = callDynamic(d, result);
                    }
                    result.successful = true;
                }
                return result;
            };
        }

        ParseTree.Dynamic option(D)(D d)
        {
            return (ParseTree p)
            {
                string name = "option!(" ~ getName(d) ~ ")";
                ParseTree result = callDynamic(d, p);
                if (result.successful)
                    return ParseTree(name, true, result.matches, result.input, result.begin, result.end, [result]);
                else
                    return ParseTree(name, true, [], p.input, p.end, p.end, null);
            };
        }

        ParseTree.Dynamic and(T...)(T rules) if (T.length)
        {
            return (ParseTree p)
            {
                bool keepNode(ParseTree node)
                {
                    return    node.name.startsWith("keep!(")
                        || (  !node.name.startsWith("discard!(")
                            //&& !node.name.startsWith("drop!(")
                            && node.matches !is null
                            //&& node.begin != node.end
                            );
                }


                string name = "and!(" ~ ")";

                ParseTree result = ParseTree(name, false, [], p.input, p.end, p.end, []);

                foreach(i,r; rules)
                {
                    ParseTree temp = callDynamic(r, result);

                    result.end = temp.end;
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
                        result.children ~= temp;// add the failed node, to indicate which failed
                        if (temp.matches.length > 0)
                            result.matches ~= temp.matches[$-1];
                        return result; // and end the parsing attempt right there
                    }
                }
                result.successful = true;
                return result;
            };
        }

        ParseTree.Dynamic or(T...)(T rules)
        {
            return (ParseTree p) @safe
            {
                // error-management
                ParseTree longestFail = ParseTree("or", false, [], p.input, p.end, 0);
                string[] errorStrings;
                size_t errorStringChars;
                //string orErrorString;

                ParseTree[rules.length] results;
                string[rules.length] names;
                size_t[rules.length] failedLength;
                size_t maxFailedLength;

                // Real 'or' loop
                foreach(i,r; rules)
                {
                    ParseTree temp = callDynamic(r, p);
                    if (temp.successful)
                    {
                        temp.children = [temp];
                        temp.name = "or";
                        return temp;
                    }
                    else
                    {
                        enum errName = " (" ~")";
                        failedLength[i] = temp.end;
                        if (temp.end >= longestFail.end)
                        {
                            maxFailedLength = temp.end;
                            longestFail = temp;
                            names[i] = errName;
                            results[i] = temp;

                            if (temp.end == longestFail.end)
                                errorStringChars += temp.matches[$-1].length + errName.length + 4;
                            else
                                errorStringChars = temp.matches[$-1].length + errName.length + 4;
                        }
                        // Else, this error parsed less input than another one: we discard it.
                    }
                }


                // All subrules failed, we will take the longest match as the result
                // If more than one node failed at the same (farthest) position, we concatenate their error messages


                char[] errString;// = new char[](errorStringChars);
                errString.length = errorStringChars;
                uint start = 0;
                foreach(i; 0..rules.length)
                {
                    if (failedLength[i] == maxFailedLength)
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
                    longestFail.matches = longestFail.matches[0..$-1]  // discarding longestFail error message
                        ~ [orErrorString];             // and replacing it by the new, concatenated one.
                })();
                longestFail.name = "or";
                longestFail.begin = p.end;
                return longestFail;
            };
        }

        ParseTree.Dynamic posLookahead(D)(D d)
        {
            return (ParseTree p)
            {
                string name = "posLookahead!(" ~ getName(d) ~ ")";
                ParseTree temp = callDynamic(d,p);
                if (temp.successful)
                    return ParseTree(name, temp.successful, [], p.input, p.end, p.end);
                else
                    return ParseTree(name, temp.successful, [temp.matches[$-1]], p.input, p.end, p.end);
            };
        }

        ParseTree.Dynamic negLookahead(D)(D d)
        {
            return (ParseTree p)
            {
                string name = "negLookahead!(" ~ getName(d) ~ ")";
                ParseTree temp = callDynamic(d,p);
                if (temp.successful)
                    return ParseTree(name, false, ["anything but \"" ~ p.input[temp.begin..temp.end] ~ "\""], p.input, p.end, p.end);
                else
                    return ParseTree(name, true, [], p.input, p.end, p.end);
            };
        }

        ParseTree.Dynamic named(D)(D d, string name)
        {
            return (ParseTree p)
            {
                ParseTree result = callDynamic(d,p);
                result.name = name;
                return result;
            };
        }

        ParseTree.Dynamic action(D, A)(D d, A act)
        {
            return (ParseTree p)
            {
                return callDynamic(act, callDynamic(d,p));
            };
        }

        ParseTree.Dynamic fuse(D)(D d)
        {
            return(ParseTree p)
            {
                p = callDynamic(d,p);
                if (p.successful)
                {
                    if (p.matches.length != 0)
                        p.matches = [join(p.matches)];

                    p.children = null; // also discard children
                }
                return p;
            };
        }

        ParseTree.Dynamic discardChildren(D)(D d)
        {
            return (ParseTree p)
            {
                p = callDynamic(d,p);
                p.children = null;
                return p;
            };
        }

        ParseTree.Dynamic discardMatches(D)(D d)
        {
            return (ParseTree p)
            {
                p = callDynamic(d,p);
                if (p.successful)
                    p.matches = null;
                return p;
            };
        }

        static ParseTree.Dynamic discard(D)(D d)
        {
            return (ParseTree p)
            {
                ParseTree result = callDynamic(d,p);
                result.name = "discard!(" ~ getName(d) ~ ")";
                //result.begin = result.end;
                result.children = null;
                if (result.successful)
                    result.matches = null;//to keep error messages, if any

                return result;
            };
        }

        ParseTree.Dynamic drop(D)(D d)
        {
            return (ParseTree p)
            {
                ParseTree result = callDynamic(d,p);
                result.children = null;
                if (result.successful)
                    result.name = "drop!(" ~ getName(d) ~ ")";
                return result;
            };
        }

        ParseTree.Dynamic propagate(D)(D d)
        {
            return (ParseTree p)
            {
                ParseTree result = callDynamic(d,p);
                if (result.successful)
                    result.name = "propagate!(" ~ getName(d) ~ ")";
                return result;
            };
        }

        ParseTree.Dynamic keep(D)(D d)
        {
            return (ParseTree p)
            {
                ParseTree result = callDynamic(d,p);
                if (result.successful)
                {
                    result.children = [result];
                    result.name = "keep!(" ~ getName(d) ~ ")";
                }
                return result;
            };
        }
    }
}
