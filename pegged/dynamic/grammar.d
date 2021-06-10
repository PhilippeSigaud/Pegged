/**
Dynamic grammars:
    - no CT parsing (this one will stay)
    - no memoization (could be added)
    - slightly less handy parameterized rules (could be better)
    - no semantic actions (drat, this one is the worse)
    - no calling from other grammars?

Advantages:
    - fully runtime configurable: change rules, add rules, delete rules.
*/
module pegged.dynamic.grammar;

import std.algorithm : startsWith;
import std.array;
import std.stdio;

import pegged.parser;
import pegged.dynamic.peg;

private import pegged.parsetree : isParseTree;

struct ParameterizedRule(ParseTree)
{
    size_t numArgs;
    alias Dynamic=ParseTree.Dynamic;
    alias DynamicModifier = Dynamic delegate(Dynamic[]);
    DynamicModifier code;

//    @disbale this();
    this(const size_t num, DynamicModifier code) {
        numArgs = num;
        this.code=code;
    }
    Dynamic opCall(D...)(D rules)
    {
        Dynamic[] args;
        foreach(i,rule; rules)
        {
            static if (is(typeof(rule) == Dynamic))
                args ~= rule;
            else
                args ~= rule(); // Dynamic delegate()
        }

        if(rules.length == numArgs)
        {
            switch(numArgs)
            {
                case 1:
                    return code([args[0]]);
                case 2:
                    return code([args[0], args[1]]);
                case 3:
                    return code([args[0], args[1], args[2]]);
                case 4:
                    return code([args[0], args[1], args[2], args[3]]);
                case 5:
                    return code([args[0], args[1], args[2], args[3], args[4]]);
                case 6:
                    return code([args[0], args[1], args[2], args[3], args[4], args[5]]);
                default:
                    throw new Exception("Unimplemented parameterized rule with more than 6 arguments.");
            }
        }
        else
            throw new Exception( "ParameterizedRule called with "
                               ~ to!string(rules.length)
                               ~ " args. Waited for "
                               ~ to!string(numArgs) ~ ".");
        return code(args);
    }
}

struct DynamicGrammar(ParseTree)
{
    alias DPEG=ParseTree.DPEG;
    string grammarName;
    string startingRule;
    alias Dynamic = ParseTree.Dynamic;
    Dynamic[string] rules;
    ParameterizedRule!ParseTree[string] paramRules;

    ParseTree decimateTree(ParseTree p)
    {
        if(p.children.length == 0) return p;

        ParseTree[] filterChildren(ParseTree pt)
        {
            ParseTree[] result;
            foreach(child; pt.children)
            {
                if (  (child.name.startsWith(grammarName) && child.matches.length != 0)
                   || !child.successful && child.children.length == 0)
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
        p.children = filterChildren(p);
        return p;
    }

    ParseTree opCall(ParseTree p)
    {
        return decimateTree(rules[startingRule](p));
        /+
        result.children = [result];
        result.name = grammarName;
        return result;
        +/
    }

    ParseTree opCall(string input)
    {
        return decimateTree(rules[startingRule](ParseTree(``, false, [], input, 0, 0)));
        /+
        result.children = [result];
        result.name = grammarName;
        return result;
        +/
    }

    void opIndexAssign(D)(D code, string s)
    {
        rules[s]= DPEG.named(code, grammarName ~ "." ~ s);
    }

    Dynamic opIndex(string s)
    {
        return rules[s];
    }
}

// Helper to insert 'Spacing' before and after Primaries
ParseTree spaceArrow(ParseTree)(ParseTree input) if (isParseTree!ParseTree)
{
    ParseTree wrapInSpaces(ParseTree p)
    {
        ParseTree spacer =
        ParseTree("Pegged.Prefix", true, null, null, 0,0, [
            ParseTree("Pegged.Suffix", true, null, null, 0, 0, [
                ParseTree("Pegged.Primary", true, null, null, 0, 0, [
                    ParseTree("Pegged.RhsName", true, null, null, 0,0, [
                        ParseTree("Pegged.Identifier", true, ["Spacing"])
                    ])
                ])
            ])
        ]);
        ParseTree result = ParseTree("Pegged.WrapAround", true, p.matches, p.input, p.begin, p.end, p.children);
        result.children = spacer ~ result.children ~ spacer;
        return result;
    }
    import pegged.peg : modify;
    return modify!(ParseTree, p => p.name == "Pegged.Primary",
                    wrapInSpaces)(input);
}

ParseTree.Dynamic makeRule(ParseTree)(string def, Dynamic[string] context) if(isParseTree!ParseTree)
{
    ParseTree p = Pegged.decimateTree(Pegged.Definition(def));
    return makeRule(p, context);
}



ParseTree.Dynamic makeRule(ParseTree)(ParseTree def, ParseTree.Dynamic[string] context) if (isParseTree!ParseTree)
{
    alias DPEG=ParseTree.DPEG;
    ParseTree.Dynamic code;

    ParseTree.Dynamic getDyn(string name)
    {
        if (name in context)
            return context[name];
        else
            throw new Exception("Unknown name: " ~ name);
    }

    ParseTree.Dynamic ruleFromTree(ParseTree p)
    {
        //writeln("rfT: ", p.name, " ", p.matches);
        //Dynamic result;
        switch(p.name)
        {
            case "Pegged.Expression":
                //if (p.children.length > 1) // OR expression
                //{
                    ParseTree.Dynamic[] children;
                    foreach(seq; p.children)
                        children ~= ruleFromTree(seq);
                    return distribute!(ParseTree, DPEG.or)(children);
                //}
                //else // One child -> just a sequence, no need for a or!( , )
                //{
                //    return ruleFromTree(p.children[0]);
                //}
                //break;
            case "Pegged.Sequence":
                //if (p.children.length > 1) // real sequence
                //{
                    ParseTree.Dynamic[] children;
                    foreach(seq; p.children)
                        children ~= ruleFromTree(seq);
                    return distribute!(ParseTree, DPEG.and)(children);
                /+}
                else // One child -> just a Suffix, no need for a and!( , )
                {
                    return ruleFromTree(p.children[0]);
                }
                +/
            case "Pegged.Prefix":
                ParseTree temp;
                foreach_reverse(i,child; p.children[0..$-1]) // transforming a list into a linear tree
                {
                    temp  = p.children[$-1];
                    p.children[$-1] = child;
                    p.children[$-1].children = [temp];
                }
                return ruleFromTree(p.children[$-1]);
            case "Pegged.Suffix":
                foreach(child; p.children[1..$])
                {
                    ParseTree temp = p.children[0];
                    p.children[0] = child;
                    p.children[0].children = [temp];
                }
                return ruleFromTree(p.children[0]);
            case "Pegged.Primary":
                return ruleFromTree(p.children[0]);
            case "Pegged.RhsName":
                return ruleFromTree(p.children[0]);
            case "Pegged.Identifier":
                //writeln("Identifier: ", p.matches[0], " ");//, getDyn(p.matches[0])()(ParseTree()).name);
                return getDyn(p.matches[0]);
            case "Pegged.Literal":
                //writeln("Literal: ", p.matches);
                if(p.matches.length == 3) // standard case
                    return DPEG.literal(p.matches[1]);
                else // only two children -> empty literal
                    return DPEG.eps();
            case "Pegged.CharClass":
                if (p.children.length > 1)
                {
                    ParseTree.Dynamic[] children;
                    foreach(seq; p.children)
                        children ~= ruleFromTree(seq);
                    return distribute!(ParseTree, DPEG.or)(children);
                }
                else // One child -> just a sequence, no need for a or!( , )
                {
                    return ruleFromTree(p.children[0]);
                }
                //break;
            case "Pegged.CharRange":
                /// Make the generation at the Char level: directly what is needed, be it `` or "" or whatever
                if (p.children.length > 1) // a-b range
                {
                    return DPEG.charRange(p.matches[0].front, p.matches[2].front);
                }
                else // lone char
                {
                    //result = "pegged.peg.literal!(";
                    string ch = p.matches[0];
                    switch (ch)
                    {
                        case "\\[":
                        case "\\]":
                        case "\\-":
                            return DPEG.literal(ch[0..1]);
                        case "\\\'":
                            return DPEG.literal("\'");
                        case "\\`":
                            return DPEG.literal("`");
                        case "\\":
                        case "\\\\":
                            return DPEG.literal("\\");
                        case "\"":
                        case "\\\"":
                            return DPEG.literal("\"");
                        case "\n":
                        case "\r":
                        case "\t":
                            return DPEG.literal(ch);
                        default:
                            return DPEG.literal(ch);
                    }
                }
            case "Pegged.Char":
                string ch = p.matches[0];
                switch (ch)
                {
                    case "\\[":
                    case "\\]":
                    case "\\-":

                    case "\\\'":
                    case "\\\"":
                    case "\\`":
                    case "\\\\":
                        return DPEG.literal(ch[1..$]);
                    case "\n":
                    case "\r":
                    case "\t":
                        return DPEG.literal(ch);
                    default:
                        return DPEG.literal(ch);
                }
                //break;
            case "Pegged.POS":
                return DPEG.posLookahead(ruleFromTree(p.children[0]));
            case "Pegged.NEG":
                return DPEG.negLookahead(ruleFromTree(p.children[0]));
            case "Pegged.FUSE":
                return DPEG.fuse(ruleFromTree(p.children[0]));
            case "Pegged.DISCARD":
                return DPEG.discard(ruleFromTree(p.children[0]));
            case "Pegged.KEEP":
                return DPEG.keep(ruleFromTree(p.children[0]));
            case "Pegged.DROP":
                return DPEG.drop(ruleFromTree(p.children[0]));
            case "Pegged.PROPAGATE":
                return DPEG.propagate(ruleFromTree(p.children[0]));
            case "Pegged.OPTION":
                return DPEG.option(ruleFromTree(p.children[0]));
            case "Pegged.ZEROORMORE":
                return DPEG.zeroOrMore(ruleFromTree(p.children[0]));
            case "Pegged.ONEORMORE":
                return DPEG.oneOrMore(ruleFromTree(p.children[0]));
            case "Pegged.Action":
                ParseTree.Dynamic result = ruleFromTree(p.children[0]);
                foreach(act; p.matches[1..$])
                    result = DPEG.action(result, getDyn(act));
                return result;
            case "Pegged.ANY":
                return DPEG.any();
            case "Pegged.WrapAround":
                return DPEG.wrapAround( ruleFromTree(p.children[0])
                                        , ruleFromTree(p.children[1])
                                        , ruleFromTree(p.children[2]));
            default:
                throw new Exception("Bad tree: " ~ p.toString());
        }
    }

    switch(def.children[1].children[0].name)
    {
        case "Pegged.LEFTARROW":
            code = ruleFromTree(def.children[2]);
            break;
        case "Pegged.FUSEARROW":
            code = DPEG.fuse(ruleFromTree(def.children[2]));
            break;
        case "Pegged.DISCARDARROW":
            code = DPEG.discard(ruleFromTree(def.children[2]));
            break;
        case "Pegged.KEEPARROW":
            code = DPEG.keep(ruleFromTree(def.children[2]));
            break;
        case "Pegged.DROPARROW":
            code = DPEG.drop(ruleFromTree(def.children[2]));
            break;
        case "Pegged.PROPAGATEARROW":
            code = DPEG.propagate(ruleFromTree(def.children[2]));
            break;
        case "Pegged.SPACEARROW":
            ParseTree modified = spaceArrow(def.children[2]);
            code = ruleFromTree(modified);
            break;
        case "Pegged.ACTIONARROW":
            ParseTree.Dynamic actionResult = ruleFromTree(def.children[2]);
            foreach(act; def.children[1].matches[1..$])
                actionResult = DPEG.action(actionResult, getDyn(act));
            code = actionResult;
            break;
        default:
            throw new Exception("Unknow arrow: " ~ def.children[1].children[0].name);
            //break;
    }

    return DPEG.named(code, def.matches[0]);
}

DynamicGrammar!ParseTree grammar(ParseTree)(string definition, ParseTree.Dynamic[string] context = null) if(isParseTree!ParseTree)
{
    alias DPEG=ParseTree.DPEG;
    //writeln("Entering dyn gram");
    ParseTree defAsParseTree = GenericPegged!(ParseTree).Pegged(definition);
    //writeln(defAsParseTree);
    if (!defAsParseTree.successful)
    {
        // To work around a strange bug with ParseTree printing at compile time
        throw new Exception("Bad grammar input: " ~ defAsParseTree.toString(""));
    }

    DynamicGrammar!ParseTree gram;
    foreach(name, rule; context)
    {
        gram.rules[name] = rule;
    }

    ParseTree p = defAsParseTree.children[0];

    string grammarName = p.children[0].matches[0];
    string shortGrammarName = p.children[0].matches[0];
    gram.grammarName = shortGrammarName;

    // Predefined spacing
    gram.rules["Spacing"] = DPEG.discard(DPEG.zeroOrMore(DPEG.or(DPEG.literal(" "), DPEG.literal("\t"), DPEG.literal("\n"), DPEG.literal("\r"))));

    ParseTree[] definitions = p.children[1 .. $];

    foreach(i,def; definitions)
    {
        gram[def.matches[0]] = DPEG.fail();
    }

    foreach(i,def; definitions)
    {
        string shortName = def.matches[0];

        if (i == 0)
            gram.startingRule = shortName;
        // prepending the global grammar name, to get a qualified-name rule 'Gram.Rule'
        def.matches[0] = shortGrammarName ~ "." ~ def.matches[0];
        gram.rules[shortName] = makeRule!ParseTree(def, gram.rules);
    }

    return gram;
}

ParseTree.Dynamic distribute(ParseTree, alias fun)(ParseTree.Dynamic[] args) if(isParseTree!ParseTree)
{
    //mixin(makeSwitch(40));
    switch(args.length)
    {
        case 1:
            return fun(args[0]);
        case 2:
            return fun(args[0], args[1]);
        case 3:
            return fun(args[0], args[1], args[2]);
        case 4:
            return fun(args[0], args[1], args[2], args[3]);
        case 5:
            return fun(args[0], args[1], args[2], args[3], args[4]);
        case 6:
            return fun(args[0], args[1], args[2], args[3], args[4], args[5]);
        default:
            return fun(fun(args[0], args[1], args[2], args[3], args[4], args[5]), distribute!(ParseTree, fun)(args[6..$]));
    }
}
