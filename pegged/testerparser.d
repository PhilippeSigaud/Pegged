/++
This module was automatically generated from the following grammar:

 
TesterGrammar:

Root < Node eoi

Node <
	/ :'/' identifier
	/ identifier (%Branch)*

Branch <
	/ OrderedBranch
	/ UnorderedBranch

OrderedBranch <
	/ :'->' Node
	/ :'[' Node+ :']'

UnorderedBranch <
	/ :'~>' Node
	/ :'{' Node+ :'}'

Spacing <- blank / Comment

Comment <- 
	/ '//' (!eol .)* (eol)
	/ '/*' (!'*/' .)* '*/'
	/ NestedComment

NestedComment <- '/+' (!NestedCommentEnd . / NestedComment) NestedCommentEnd

# This is needed to make the /+ +/ nest when the grammar is placed into a D nested comment ;)
NestedCommentEnd <- '+/'



+/
module pegged.testerparser;

public import pegged.peg;
struct GenericTesterGrammar(TParseTree)
{
    struct TesterGrammar
    {
    enum name = "TesterGrammar";
    static bool isRule(string s)
    {
        switch(s)
        {
            case "TesterGrammar.Root":
            case "TesterGrammar.Node":
            case "TesterGrammar.Branch":
            case "TesterGrammar.OrderedBranch":
            case "TesterGrammar.UnorderedBranch":
            case "TesterGrammar.Spacing":
            case "TesterGrammar.Comment":
            case "TesterGrammar.NestedComment":
            case "TesterGrammar.NestedCommentEnd":
                return true;
            default:
                return false;
        }
    }
    mixin decimateTree;
    static TParseTree Root(TParseTree p)
    {
        return pegged.peg.named!(pegged.peg.and!(pegged.peg.wrapAround!(pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)), Node, pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing))), pegged.peg.wrapAround!(pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)), eoi, pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)))), name ~ `.`~ `Root`)(p);
    }

    static TParseTree Root(string s)
    {
        return pegged.peg.named!(pegged.peg.and!(pegged.peg.wrapAround!(pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)), Node, pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing))), pegged.peg.wrapAround!(pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)), eoi, pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)))), name ~ `.`~ `Root`)(TParseTree("", false,[], s));
    }

    static string Root(GetName g)
    {
        return name ~ `.`~ `Root`;
    }

    static TParseTree Node(TParseTree p)
    {
        return pegged.peg.named!(pegged.peg.or!(pegged.peg.and!(pegged.peg.discard!(pegged.peg.wrapAround!(pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)), pegged.peg.literal!(`/`), pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)))), pegged.peg.wrapAround!(pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)), identifier, pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)))), pegged.peg.and!(pegged.peg.wrapAround!(pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)), identifier, pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing))), pegged.peg.zeroOrMore!(pegged.peg.wrapAround!(pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)), pegged.peg.propagate!(pegged.peg.wrapAround!(pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)), Branch, pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)))), pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)))))), name ~ `.`~ `Node`)(p);
    }

    static TParseTree Node(string s)
    {
        return pegged.peg.named!(pegged.peg.or!(pegged.peg.and!(pegged.peg.discard!(pegged.peg.wrapAround!(pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)), pegged.peg.literal!(`/`), pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)))), pegged.peg.wrapAround!(pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)), identifier, pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)))), pegged.peg.and!(pegged.peg.wrapAround!(pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)), identifier, pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing))), pegged.peg.zeroOrMore!(pegged.peg.wrapAround!(pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)), pegged.peg.propagate!(pegged.peg.wrapAround!(pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)), Branch, pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)))), pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)))))), name ~ `.`~ `Node`)(TParseTree("", false,[], s));
    }

    static string Node(GetName g)
    {
        return name ~ `.`~ `Node`;
    }

    static TParseTree Branch(TParseTree p)
    {
        return pegged.peg.named!(pegged.peg.or!(pegged.peg.wrapAround!(pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)), OrderedBranch, pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing))), pegged.peg.wrapAround!(pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)), UnorderedBranch, pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)))), name ~ `.`~ `Branch`)(p);
    }

    static TParseTree Branch(string s)
    {
        return pegged.peg.named!(pegged.peg.or!(pegged.peg.wrapAround!(pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)), OrderedBranch, pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing))), pegged.peg.wrapAround!(pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)), UnorderedBranch, pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)))), name ~ `.`~ `Branch`)(TParseTree("", false,[], s));
    }

    static string Branch(GetName g)
    {
        return name ~ `.`~ `Branch`;
    }

    static TParseTree OrderedBranch(TParseTree p)
    {
        return pegged.peg.named!(pegged.peg.or!(pegged.peg.and!(pegged.peg.discard!(pegged.peg.wrapAround!(pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)), pegged.peg.literal!(`->`), pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)))), pegged.peg.wrapAround!(pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)), Node, pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)))), pegged.peg.and!(pegged.peg.discard!(pegged.peg.wrapAround!(pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)), pegged.peg.literal!(`[`), pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)))), pegged.peg.oneOrMore!(pegged.peg.wrapAround!(pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)), Node, pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)))), pegged.peg.discard!(pegged.peg.wrapAround!(pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)), pegged.peg.literal!(`]`), pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)))))), name ~ `.`~ `OrderedBranch`)(p);
    }

    static TParseTree OrderedBranch(string s)
    {
        return pegged.peg.named!(pegged.peg.or!(pegged.peg.and!(pegged.peg.discard!(pegged.peg.wrapAround!(pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)), pegged.peg.literal!(`->`), pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)))), pegged.peg.wrapAround!(pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)), Node, pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)))), pegged.peg.and!(pegged.peg.discard!(pegged.peg.wrapAround!(pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)), pegged.peg.literal!(`[`), pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)))), pegged.peg.oneOrMore!(pegged.peg.wrapAround!(pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)), Node, pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)))), pegged.peg.discard!(pegged.peg.wrapAround!(pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)), pegged.peg.literal!(`]`), pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)))))), name ~ `.`~ `OrderedBranch`)(TParseTree("", false,[], s));
    }

    static string OrderedBranch(GetName g)
    {
        return name ~ `.`~ `OrderedBranch`;
    }

    static TParseTree UnorderedBranch(TParseTree p)
    {
        return pegged.peg.named!(pegged.peg.or!(pegged.peg.and!(pegged.peg.discard!(pegged.peg.wrapAround!(pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)), pegged.peg.literal!(`~>`), pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)))), pegged.peg.wrapAround!(pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)), Node, pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)))), pegged.peg.and!(pegged.peg.discard!(pegged.peg.wrapAround!(pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)), pegged.peg.literal!(`{`), pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)))), pegged.peg.oneOrMore!(pegged.peg.wrapAround!(pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)), Node, pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)))), pegged.peg.discard!(pegged.peg.wrapAround!(pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)), pegged.peg.literal!(`}`), pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)))))), name ~ `.`~ `UnorderedBranch`)(p);
    }

    static TParseTree UnorderedBranch(string s)
    {
        return pegged.peg.named!(pegged.peg.or!(pegged.peg.and!(pegged.peg.discard!(pegged.peg.wrapAround!(pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)), pegged.peg.literal!(`~>`), pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)))), pegged.peg.wrapAround!(pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)), Node, pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)))), pegged.peg.and!(pegged.peg.discard!(pegged.peg.wrapAround!(pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)), pegged.peg.literal!(`{`), pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)))), pegged.peg.oneOrMore!(pegged.peg.wrapAround!(pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)), Node, pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)))), pegged.peg.discard!(pegged.peg.wrapAround!(pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)), pegged.peg.literal!(`}`), pegged.peg.discard!(pegged.peg.zeroOrMore!(Spacing)))))), name ~ `.`~ `UnorderedBranch`)(TParseTree("", false,[], s));
    }

    static string UnorderedBranch(GetName g)
    {
        return name ~ `.`~ `UnorderedBranch`;
    }

    static TParseTree Spacing(TParseTree p)
    {
        return pegged.peg.named!(pegged.peg.or!(blank, Comment), name ~ `.`~ `Spacing`)(p);
    }

    static TParseTree Spacing(string s)
    {
        return pegged.peg.named!(pegged.peg.or!(blank, Comment), name ~ `.`~ `Spacing`)(TParseTree("", false,[], s));
    }

    static string Spacing(GetName g)
    {
        return name ~ `.`~ `Spacing`;
    }

    static TParseTree Comment(TParseTree p)
    {
        return pegged.peg.named!(pegged.peg.or!(pegged.peg.and!(pegged.peg.literal!(`//`), pegged.peg.zeroOrMore!(pegged.peg.and!(pegged.peg.negLookahead!(eol), pegged.peg.any)), eol), pegged.peg.and!(pegged.peg.literal!(`/*`), pegged.peg.zeroOrMore!(pegged.peg.and!(pegged.peg.negLookahead!(pegged.peg.literal!(`*/`)), pegged.peg.any)), pegged.peg.literal!(`*/`)), NestedComment), name ~ `.`~ `Comment`)(p);
    }

    static TParseTree Comment(string s)
    {
        return pegged.peg.named!(pegged.peg.or!(pegged.peg.and!(pegged.peg.literal!(`//`), pegged.peg.zeroOrMore!(pegged.peg.and!(pegged.peg.negLookahead!(eol), pegged.peg.any)), eol), pegged.peg.and!(pegged.peg.literal!(`/*`), pegged.peg.zeroOrMore!(pegged.peg.and!(pegged.peg.negLookahead!(pegged.peg.literal!(`*/`)), pegged.peg.any)), pegged.peg.literal!(`*/`)), NestedComment), name ~ `.`~ `Comment`)(TParseTree("", false,[], s));
    }

    static string Comment(GetName g)
    {
        return name ~ `.`~ `Comment`;
    }

    static TParseTree NestedComment(TParseTree p)
    {
        return pegged.peg.named!(pegged.peg.and!(pegged.peg.literal!(`/+`), pegged.peg.or!(pegged.peg.and!(pegged.peg.negLookahead!(NestedCommentEnd), pegged.peg.any), NestedComment), NestedCommentEnd), name ~ `.`~ `NestedComment`)(p);
    }

    static TParseTree NestedComment(string s)
    {
        return pegged.peg.named!(pegged.peg.and!(pegged.peg.literal!(`/+`), pegged.peg.or!(pegged.peg.and!(pegged.peg.negLookahead!(NestedCommentEnd), pegged.peg.any), NestedComment), NestedCommentEnd), name ~ `.`~ `NestedComment`)(TParseTree("", false,[], s));
    }

    static string NestedComment(GetName g)
    {
        return name ~ `.`~ `NestedComment`;
    }

    static TParseTree NestedCommentEnd(TParseTree p)
    {
        return pegged.peg.named!(pegged.peg.literal!(`+/`), name ~ `.`~ `NestedCommentEnd`)(p);
    }

    static TParseTree NestedCommentEnd(string s)
    {
        return pegged.peg.named!(pegged.peg.literal!(`+/`), name ~ `.`~ `NestedCommentEnd`)(TParseTree("", false,[], s));
    }

    static string NestedCommentEnd(GetName g)
    {
        return name ~ `.`~ `NestedCommentEnd`;
    }

    static TParseTree opCall(TParseTree p)
    {
        TParseTree result = decimateTree(Root(p));
        result.children = [result];
        result.name = "TesterGrammar";
        return result;
    }

    static TParseTree opCall(string input)
    {
        return TesterGrammar(TParseTree(``, false, [], input, 0, 0));
    }
    static string opCall(GetName g)
    {
        return "TesterGrammar";
    }

    }
}

alias GenericTesterGrammar!(ParseTree).TesterGrammar TesterGrammar;

