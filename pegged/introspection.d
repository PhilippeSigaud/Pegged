/**
This module contains function to inspect a Pegged grammar.
*/
module pegged.introspection;

import std.algorithm : equal;
import std.typecons;

import pegged.parser;

/**
The different kinds of recursion for a rule.
'direct' means the rule name appears in its own definition. 'indirect' means the rule calls itself through another rule (the call chain can be long).
*/
enum Recursive { no, direct, indirect }

/**
Left-recursion diagnostic for a rule. A rule is left-recursive when its own name appears at the beginning of its definition or behind possibly-null-matching rules (see below for null matches).
For example A <- A 'a' is left-recursive, whereas A <- 'a' A is not. *But* A <- 'a'? A is left-recursive, since if the input does not begin
with 'a', then the parsing will continue by invoking A again, at the same position.

'direct' means the rule invokes itself in the first position of its definition (A <- A ...). 'hidden' means the rule names appears after a possibly-null other rule (A <- 'a'? A ...). 'indirect' means the rule calls itself trough another rule.
*/
enum LeftRecursive { no, direct, hidden, indirect }

/**
NullMatch.yes means a rule can succeed while consuming no input. For example e? or e*, for all expressions e.
Nullmatch.no means a rule will always consume at least a token while succeeding.
Nullmatch.indeterminate means the algorithm could not converge.
*/
enum NullMatch { no, yes, indeterminate }

/**
InfiniteLoop.yes means a rule can loop indefinitely while consuming nothing.
InfiniteLoop.no means a rule cannot loop indefinitely.
InfiniteLoop.indeterminate means the algorithm could not converge.
*/
enum InfiniteLoop { no, yes, indeterminate }

/**
Struct holding the introspection info on a rule.
*/
@safe struct RuleInfo
{
    Recursive recursion; /// Is the rule recursive?
    LeftRecursive leftRecursion; /// Is the rule left-recursive?
    NullMatch nullMatch; /// Can the rule succeed while consuming nothing?
    InfiniteLoop infiniteLoop; /// Can the rule loop indefinitely, while consuming nothing?
    string[] leftRecursiveCycle; /// The path of rules traversed before indirect left-recursion recurses.
}

/**
Struct holding the introspection info on a grammar.
*/
@safe struct GrammarInfo
{
    RuleInfo[string] ruleInfo;
    immutable(string[])[] leftRecursiveCycles;
}

@safe pure void appendCycleIfUnique(ref immutable(string[])[] cycles, const string[] cycle)
{
    bool exists()
    {
        import std.algorithm : countUntil;
        foreach (c; cycles)
        {
            if (c.length != cycle.length)
                continue;
            auto pos = countUntil(c, cycle[0]);
            if (pos < 0)
                continue;
            if (equal!equal(c[pos .. $] ~ c[0 .. pos], cycle))
                return true;
        }
        return false;
    }
    if (!exists())
        cycles ~= cycle.idup;
}

/**
Returns for all grammar rules:

- the recursion type (no recursion, direct or indirect recursion).
- the left-recursion type (no left-recursion, direct left-recursion, hidden, or indirect)
- the null-match for a grammar's rules: whether the rule can succeed while consuming nothing.
- the possibility of an infinite loop (if 'e' can null-match, then 'e*' can enter an infinite loop).

This kind of potential problem can be detected statically and should be transmitted to the grammar designer.
*/
GrammarInfo grammarInfo(ParseTree)(ParseTree p) pure @safe
{
    if (p.name == "Pegged")
        return grammarInfo(p.children[0]);
    assert(p.name == "Pegged.Grammar");

    GrammarInfo result;
    ParseTree[string] rules;

    /**
    Returns the call graph of a grammar: the list of rules directly called by each rule of the grammar.
    The graph is represented as a bool[string][string] associative array, the string holding
    the rules names. graph["ruleName"] contains all rules called by ruleName, as a set (a bool[string] AA).

    graph.keys thus gives the grammar's rules names.

    If a rule calls itself, its own name will appear in the called set. If a rule calls an external rule, it will
    also appear in the call graph when the rule has a name: hence, calls to predefined rules like 'identifier' or
    'digit' will appear, but not a call to '[0-9]+', considered here as an anonymous rule.
    */
    bool[string][string] callGraph(ParseTree p) @safe
    {
        bool[string] findIdentifiers(ParseTree p) @trusted
        {
            bool[string] idList;
            if (p.name == "Pegged.Identifier")
                idList[p.matches[0]] = true;
            else {
                foreach(child; p.children)
                    foreach(name; findIdentifiers(child).keys)
                        idList[name] = true;
            }
            return idList;
        }

        bool[string][string] graph;

        foreach(definition; p.children)
            if (definition.name == "Pegged.Definition")
            {
                auto ids = findIdentifiers(definition.children[2]);
                graph[definition.matches[0]] = ids;
                foreach(id, _; ids) // getting possible external calls
                    if (id !in graph)
                        graph[id] = (bool[string]).init;
            }

        return graph;
    }

    /**
    The transitive closure of a call graph.
    It will propagate the calls to find all rules called by a given rule,
    directly (already in the call graph) or indirectly (through another rule).
    */
    bool[string][string] closure(bool[string][string] graph) @trusted
    {
        bool[string][string] path;
        foreach(rule, children; graph) // deep-dupping, to avoid children aliasing
            path[rule] = children.dup;

        bool changed = true;

        while(changed)
        {
            changed = false;
            foreach(rule1; graph.keys)
                foreach(rule2; graph.keys)
                    if (rule2 in path[rule1])
                        foreach(rule3; graph.keys)
                            if (rule3 in path[rule2] && rule3 !in path[rule1])
                            {
                                path[rule1][rule3] = true;
                                changed = true;
                            }
        }

        return path;
    }

    Recursive[string] recursions(bool[string][string] graph) @safe
    {
        bool[string][string] path = closure(graph);

        Recursive[string] result;
        foreach(rule, children; path)
        {
            result[rule] = Recursive.no;
            if (rule in children)
            {
                if (rule in graph[rule])
                    result[rule] = Recursive.direct;
                else
                    result[rule] = Recursive.indirect;
            }
        }

        return result;
    }

    NullMatch nullMatching(ParseTree p) @safe
    {
        switch (p.name)
        {
            case "Pegged.Expression":
                return nullMatching(p.children[0]);
            case "Pegged.FirstExpression",
                 "Pegged.LongestExpression": // choice expressions null-match whenever one of their components can null-match
                foreach(seq; p.children)
                    if (nullMatching(seq) == NullMatch.yes)
                        return NullMatch.yes;
                foreach(seq; p.children)
                    if (nullMatching(seq) == NullMatch.indeterminate)
                        return NullMatch.indeterminate;
                return NullMatch.no;
            case "Pegged.Sequence": // sequence expressions can null-match when all their components can null-match
                foreach(pref; p.children)
                    if (nullMatching(pref) == NullMatch.no)
                        return NullMatch.no;
                foreach(pref; p.children)
                    if (nullMatching(pref) == NullMatch.indeterminate)
                        return NullMatch.indeterminate;
                return NullMatch.yes;
            case "Pegged.Prefix":
                foreach(pref; p.children[0..$-1])
                    if (pref.name == "Pegged.POS" || pref.name == "Pegged.NEG")
                        return NullMatch.yes;
                return nullMatching(p.children[$-1]);
            case "Pegged.Suffix":
                foreach(suff; p.children[1..$])
                    if (suff.name == "Pegged.ZEROORMORE" || suff.name == "Pegged.OPTION")
                        return NullMatch.yes;
                return nullMatching(p.children[0]);
            case "Pegged.Primary":
                return nullMatching(p.children[0]);
            case "Pegged.RhsName":
                if (p.matches[0] in result.ruleInfo)
                    if (result.ruleInfo[p.matches[0]].nullMatch != NullMatch.indeterminate)
                        return result.ruleInfo[p.matches[0]].nullMatch;
                return nullMatching(p.children[0]);
            case "Pegged.Identifier":
                if (p.matches[0] == "eps" ||
                    p.matches[0] == "eoi")
                    return NullMatch.yes;
                return NullMatch.indeterminate;
            case "Pegged.Literal":
                if (p.matches[0].length == 0) // Empty literal, '' or ""
                    return NullMatch.yes;
                else
                    return NullMatch.no;
            case "Pegged.CharClass":
            case "Pegged.ANY":
                return NullMatch.no;
            case "eps":
            case "eoi":
                return NullMatch.yes;
            default:
                return NullMatch.indeterminate;
        }
    }

    InfiniteLoop infiniteLooping(ParseTree p)
    {
        switch (p.name)
        {
            case "Pegged.Expression": // choice expressions loop whenever one of their components can loop
            case "Pegged.Sequence": // sequence expressions can loop when one of their components can loop
                foreach(seq; p.children)
                {
                    auto nm = infiniteLooping(seq);
                    if (nm == InfiniteLoop.yes)
                        return InfiniteLoop.yes;
                    if (nm == InfiniteLoop.indeterminate)
                        return InfiniteLoop.indeterminate;
                }
                return InfiniteLoop.no;
            case "Pegged.Prefix":
                return infiniteLooping(p.children[$-1]);
            case "Pegged.Suffix":
                foreach(pref; p.children[1..$])
                    if ((  pref.name == "Pegged.ZEROORMORE" || pref.name == "Pegged.ONEORMORE")
                        && p.matches[0] in result.ruleInfo
                        && result.ruleInfo[p.matches[0]].nullMatch == NullMatch.yes)
                        return InfiniteLoop.yes;
                return infiniteLooping(p.children[0]);
            case "Pegged.Primary":
                return infiniteLooping(p.children[0]);
            case "Pegged.RhsName":
                if (p.matches[0] in result.ruleInfo)
                    return result.ruleInfo[p.matches[0]].infiniteLoop;
                else
                    return infiniteLooping(p.children[0]);
            case "Pegged.Literal":
            case "Pegged.CharClass":
            case "Pegged.ANY":
            case "eps":
            case "eoi":
                return InfiniteLoop.no;
            default:
                return InfiniteLoop.indeterminate;
        }
    }

    LeftRecursive leftRecursion(ParseTree p, ref string[] cycle)
    {
        import std.algorithm.searching: countUntil;
        switch (p.name)
        {
            case "Pegged.Expression":
                return leftRecursion(p.children[0], cycle);
            case "Pegged.FirstExpression",
                 "Pegged.LongestExpression": // Choices are left-recursive if any choice is left-recursive
                // Because memoized left-recursion handling needs to know about all left-recursive cycles,
                // we consider all choices, not just one.
                auto any_lr = LeftRecursive.no;
                size_t current = cycle.length;
                foreach(seq; p.children)
                {
                    cycle = cycle[0..current];
                    auto lr = leftRecursion(seq, cycle);
                    if (lr != LeftRecursive.no && any_lr == LeftRecursive.no)
                        any_lr = lr;
                }
                cycle = cycle[0..current];
                return any_lr;
            case "Pegged.Sequence": // Sequences are left-recursive when the leftmost member is left-recursive
                                    // or behind null-matching members
                size_t current = cycle.length;
                foreach(i, seq; p.children)
                {
                    auto lr = leftRecursion(seq, cycle);
                    if (lr == LeftRecursive.direct)
                        return (i == 0 ? LeftRecursive.direct : LeftRecursive.hidden);
                    if (lr == LeftRecursive.hidden || lr == LeftRecursive.indirect)
                        return lr;
                    if (nullMatching(seq) == NullMatch.yes)
                        continue;
                    else
                    {
                        cycle = cycle[0..current];
                        return LeftRecursive.no;
                    }
                }
                cycle = cycle[0..current];
                return LeftRecursive.no; // found only null-matching rules!
            case "Pegged.Prefix":
                return leftRecursion(p.children[$-1], cycle);
            case "Pegged.Suffix":
            case "Pegged.Primary":
                return leftRecursion(p.children[0], cycle);
            case "Pegged.RhsName":
                auto dejavu = cycle.countUntil(p.matches[0]);
                if (dejavu >= 0)
                {
                    if (cycle.length == 1)
                    {
                        result.leftRecursiveCycles.appendCycleIfUnique(cycle);
                        return LeftRecursive.direct;
                    }
                    // Strictly spoken, the rules before dejavu are not actively left-recursive, but since they
                    // can call into a left-recursive cycle, they would still left-recurse if left-recursion
                    // wasn't handled.
                    result.leftRecursiveCycles.appendCycleIfUnique(cycle[dejavu..$]);
                    return LeftRecursive.indirect;
                }
                size_t current = cycle.length;
                cycle ~= p.matches[0];
                if ((p.matches[0] in rules) && (leftRecursion(rules[p.matches[0]], cycle) != LeftRecursive.no))
                    return LeftRecursive.indirect;
                cycle = cycle[0..current];
                return LeftRecursive.no;
            default:
                return LeftRecursive.no;
        }
    }

    // Initialize rules and result.
    foreach(definition; p.children)
        if (definition.name == "Pegged.Definition")
        {
            rules[definition.matches[0]] = definition.children[2];
            result.ruleInfo[definition.matches[0]] = RuleInfo(Recursive.no, LeftRecursive.no,
                                                              NullMatch.indeterminate, InfiniteLoop.indeterminate);
        }

    // Detect recursions.
    foreach(rule, recursionType; recursions(callGraph(p)))
        if (rule in result.ruleInfo) // external rules are in recursions, but not in result
            result.ruleInfo[rule].recursion = recursionType;

    // Detect left-recursions.
    foreach(name, tree; rules)
        if (result.ruleInfo[name].recursion != Recursive.no)
        {
            result.ruleInfo[name].leftRecursiveCycle ~= name;
            result.ruleInfo[name].leftRecursion = leftRecursion(tree, result.ruleInfo[name].leftRecursiveCycle);
        }

    // Detect null matches.
    bool changed = true;
    while(changed) // while something new happened, the process is not over
    {
        changed = false;
        foreach(name, tree; rules)
            if (result.ruleInfo[name].nullMatch == NullMatch.indeterminate) // not done yet
            {
                result.ruleInfo[name].nullMatch = nullMatching(tree); // try to find if it's null-matching
                if (result.ruleInfo[name].nullMatch != NullMatch.indeterminate)
                    changed = true;
            }
    }

    // Detect infinite loops.
    changed = true;
    while(changed) // while something new happened, the process is not over
    {
        changed = false;
        foreach(name, tree; rules)
            if (result.ruleInfo[name].infiniteLoop == InfiniteLoop.indeterminate) // not done yet
            {
                result.ruleInfo[name].infiniteLoop = infiniteLooping(tree); // try to find if it's looping
                if (result.ruleInfo[name].infiniteLoop != InfiniteLoop.indeterminate)
                    changed = true;
            }
    }

    return result;
}

/**
Returns for all grammar rules:

- the recursion type (no recursion, direct or indirect recursion).
- the left-recursion type (no left-recursion, direct left-recursion, hidden, or indirect)
- the null-match for a grammar's rules: whether the rule can succeed while consuming nothing.
- the possibility of an infinite loop (if 'e' can null-match, then 'e*' can enter an infinite loop).

This kind of potential problem can be detected statically and should be transmitted to the grammar designer.
*/
@safe pure RuleInfo[string] ruleInfo(ParseTree)(ParseTree p)
{
    return grammarInfo(p).ruleInfo;
}

/** ditto */
@safe RuleInfo[string] ruleInfo(string grammar)
{
    return ruleInfo(Pegged(grammar).children[0]);
}

@safe unittest
{
    auto info = ruleInfo(`
        Test:
            A <- A 'a'
    `);
    assert(info["A"].leftRecursion == LeftRecursive.direct);

    info = ruleInfo(`
        Test:
            A <- B? A 'a'
            B <- 'b'
    `);
    assert(info["A"].leftRecursion == LeftRecursive.hidden);

    info = ruleInfo(`
        Test:
            A <- B 'a'
            B <- A
    `);
    assert(info["A"].leftRecursion == LeftRecursive.indirect);
}

// Test against infinite recursion in detection of indirect left-recursion.
@safe unittest
{
    auto info = ruleInfo(`
        Test:
            A <- B / C 'a'
            B <- A
            C <- A
    `);
    assert(info["A"].leftRecursion == LeftRecursive.indirect);
}

// Test against compile-time infinite recursion.
@safe unittest // Mutual left-recursion
{
    enum ct = ruleInfo(`
      Left:
        A <- L
        L <- P
        P <- P / L
    `);
    static assert(ct["A"].leftRecursion == LeftRecursive.no);
    static assert(ct["L"].leftRecursion == LeftRecursive.indirect);
    static assert(ct["P"].leftRecursion == LeftRecursive.direct);

    auto rt = ruleInfo(`
        Left:
          A <- L
          L <- P
          P <- P / L
    `);
    assert(rt["A"].leftRecursion == LeftRecursive.no);
    assert(rt["L"].leftRecursion == LeftRecursive.indirect);
    assert(rt["P"].leftRecursion == LeftRecursive.direct);
}

@safe unittest // Intersecting cycles of left-recursion
{
    enum ct = ruleInfo(`
      Left:
        C <- A
        A <- B* C
        B <- A
    `);
    static assert(ct["C"].leftRecursion == LeftRecursive.indirect);
    static assert(ct["A"].leftRecursion == LeftRecursive.indirect);
    static assert(ct["B"].leftRecursion == LeftRecursive.indirect);
    auto rt = ruleInfo(`
      Left:
        C <- A
        A <- B* C
        B <- A
    `);
    assert(rt["C"].leftRecursion == LeftRecursive.indirect);
    assert(rt["A"].leftRecursion == LeftRecursive.indirect);
    assert(rt["B"].leftRecursion == LeftRecursive.indirect);
}

@safe unittest // Null-matching
{
    enum ct = ruleInfo(`
      NM:
        NMM <- NML eoi
        NML <- 'x'?
    `);
    static assert(ct["NML"].nullMatch == NullMatch.yes);
    static assert(ct["NMM"].nullMatch == NullMatch.yes);
    auto rt = ruleInfo(`
      NM:
        NMM <- NML eoi
        NML <- 'x'?
    `);
    assert(rt["NML"].nullMatch == NullMatch.yes);
    assert(rt["NMM"].nullMatch == NullMatch.yes);
}

@safe unittest // Not null-matching
{
    enum ct = ruleInfo(`
      Left:
        M <- L eoi
        L <- P '.x' / 'x'
        P <- P '(n)' / L
    `);
    static assert(ct["M"].nullMatch == NullMatch.no);
    static assert(ct["L"].nullMatch == NullMatch.no);
    static assert(ct["P"].nullMatch == NullMatch.no);
    auto rt = ruleInfo(`
      Left:
        M <- L eoi
        L <- P '.x' / 'x'
        P <- P '(n)' / L
    `);
    assert(rt["M"].nullMatch == NullMatch.no);
    assert(rt["L"].nullMatch == NullMatch.no);
    assert(rt["P"].nullMatch == NullMatch.no);
}

@safe unittest // Left-recursive null-matching
{
    enum ct = ruleInfo(`
      Left:
        M <- L eoi
        L <- P? '.x'? / 'x'
        P <- P '(n)' / L
    `);
    static assert(ct["M"].nullMatch == NullMatch.yes);
    static assert(ct["L"].nullMatch == NullMatch.yes);
    static assert(ct["P"].nullMatch == NullMatch.yes);
    auto rt = ruleInfo(`
      Left:
        M <- L eoi
        L <- P? '.x'? / 'x'
        P <- P '(n)' / L
    `);
    assert(rt["M"].nullMatch == NullMatch.yes);
    assert(rt["L"].nullMatch == NullMatch.yes);
    assert(rt["P"].nullMatch == NullMatch.yes);
}


/**
Act on rules parse tree as produced by pegged.parser.
Replace every occurence of child in parent by child's parse tree
*/
ParseTree replaceInto(ParseTree)(ParseTree parent, ParseTree child)
{
    if (parent.name == "Pegged.RhsName" && parent.matches[0] == child.matches[0])
        return ParseTree("Pegged.Named", true, child.matches[0..1], "",0,0,
                       [child.children[2],
                        ParseTree("Pegged.Identifier", true, child.matches[0..1])]);
    else
        foreach(ref branch; parent.children)
            branch = replaceInto(branch, child);
    return parent;
}
