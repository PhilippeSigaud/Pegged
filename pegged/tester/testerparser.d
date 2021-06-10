/++
This module was automatically generated from the following grammar:


TesterGrammar:

Root < Node eoi

Node <
    / :'^' identifier
    / identifier (%Branch)*

Branch <
    / OrderedBranch
    / UnorderedBranch

OrderedBranch <
    / :'->' :'{' Node+ :'}'
    / :'->' Node

UnorderedBranch <
    / :'~>' :'{' Node+ :'}'
    / :'~>' Node

Spacing <: (blank / Comment)*

Comment <-
    / '//' (!eol .)* (eol)
    / '/*' (!'*/' .)* '*/'
    / NestedComment

NestedComment <- '/+' (!NestedCommentEnd . / NestedComment) NestedCommentEnd

# This is needed to make the /+ +/ nest when the grammar is placed into a D # nested comment ;$(RPAREN)
NestedCommentEnd <- '+/'


+/
module pegged.tester.testerparser;

public import pegged.peg;
private import pegged.parsetree;
@safe struct GenericTesterGrammar(ParseTree)
{
    alias PEG=ParseTree;
    mixin DefaultPatters!ParseTree;
    //alias PEG=PeggedT!ParseTree;
//    mixin DefaultParsePatterns!PEG;

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
    mixin decimateTree!ParseTree;
    static ParseTree Root(ParseTree p)
    {
         return PEG.named!(PEG.and!(PEG.wrapAround!(Spacing, Node, Spacing), PEG.wrapAround!(Spacing, PEG.eoi, Spacing)), "TesterGrammar.Root")(p);
    }
    static ParseTree Root(string s)
    {
        return PEG.named!(PEG.and!(PEG.wrapAround!(Spacing, Node, Spacing), PEG.wrapAround!(Spacing, PEG.eoi, Spacing)), "TesterGrammar.Root")(ParseTree("", false,[], s));
    }
    static string Root(GetName g)
    {
        return "TesterGrammar.Root";
    }

    static ParseTree Node(ParseTree p)
    {
         return PEG.named!(PEG.or!(PEG.and!(PEG.discard!(PEG.wrapAround!(Spacing, PEG.literal!("^"), Spacing)), PEG.wrapAround!(Spacing, identifier, Spacing)), PEG.and!(PEG.wrapAround!(Spacing, identifier, Spacing), PEG.zeroOrMore!(PEG.wrapAround!(Spacing, PEG.propagate!(PEG.wrapAround!(Spacing, Branch, Spacing)), Spacing)))), "TesterGrammar.Node")(p);
    }
    static ParseTree Node(string s)
    {
        return PEG.named!(PEG.or!(PEG.and!(PEG.discard!(PEG.wrapAround!(Spacing, PEG.literal!("^"), Spacing)), PEG.wrapAround!(Spacing, identifier, Spacing)), PEG.and!(PEG.wrapAround!(Spacing, identifier, Spacing), PEG.zeroOrMore!(PEG.wrapAround!(Spacing, PEG.propagate!(PEG.wrapAround!(Spacing, Branch, Spacing)), Spacing)))), "TesterGrammar.Node")(ParseTree("", false,[], s));
    }
    static string Node(GetName g)
    {
        return "TesterGrammar.Node";
    }

    static ParseTree Branch(ParseTree p)
    {
         return PEG.named!(PEG.or!(PEG.wrapAround!(Spacing, OrderedBranch, Spacing), PEG.wrapAround!(Spacing, UnorderedBranch, Spacing)), "TesterGrammar.Branch")(p);
    }
    static ParseTree Branch(string s)
    {
        return PEG.named!(PEG.or!(PEG.wrapAround!(Spacing, OrderedBranch, Spacing), PEG.wrapAround!(Spacing, UnorderedBranch, Spacing)), "TesterGrammar.Branch")(ParseTree("", false,[], s));
    }
    static string Branch(GetName g)
    {
        return "TesterGrammar.Branch";
    }

    static ParseTree OrderedBranch(ParseTree p)
    {
         return PEG.named!(PEG.or!(PEG.and!(PEG.discard!(PEG.wrapAround!(Spacing, PEG.literal!("->"), Spacing)), PEG.discard!(PEG.wrapAround!(Spacing, PEG.literal!("{"), Spacing)), PEG.oneOrMore!(PEG.wrapAround!(Spacing, Node, Spacing)), PEG.discard!(PEG.wrapAround!(Spacing, PEG.literal!("}"), Spacing))), PEG.and!(PEG.discard!(PEG.wrapAround!(Spacing, PEG.literal!("->"), Spacing)), PEG.wrapAround!(Spacing, Node, Spacing))), "TesterGrammar.OrderedBranch")(p);
    }
    static ParseTree OrderedBranch(string s)
    {
        return PEG.named!(PEG.or!(PEG.and!(PEG.discard!(PEG.wrapAround!(Spacing, PEG.literal!("->"), Spacing)), PEG.discard!(PEG.wrapAround!(Spacing, PEG.literal!("{"), Spacing)), PEG.oneOrMore!(PEG.wrapAround!(Spacing, Node, Spacing)), PEG.discard!(PEG.wrapAround!(Spacing, PEG.literal!("}"), Spacing))), PEG.and!(PEG.discard!(PEG.wrapAround!(Spacing, PEG.literal!("->"), Spacing)), PEG.wrapAround!(Spacing, Node, Spacing))), "TesterGrammar.OrderedBranch")(ParseTree("", false,[], s));
    }
    static string OrderedBranch(GetName g)
    {
        return "TesterGrammar.OrderedBranch";
    }

    static ParseTree UnorderedBranch(ParseTree p)
    {
         return PEG.named!(PEG.or!(PEG.and!(PEG.discard!(PEG.wrapAround!(Spacing, PEG.literal!("~>"), Spacing)), PEG.discard!(PEG.wrapAround!(Spacing, PEG.literal!("{"), Spacing)), PEG.oneOrMore!(PEG.wrapAround!(Spacing, Node, Spacing)), PEG.discard!(PEG.wrapAround!(Spacing, PEG.literal!("}"), Spacing))), PEG.and!(PEG.discard!(PEG.wrapAround!(Spacing, PEG.literal!("~>"), Spacing)), PEG.wrapAround!(Spacing, Node, Spacing))), "TesterGrammar.UnorderedBranch")(p);
    }
    static ParseTree UnorderedBranch(string s)
    {
        return PEG.named!(PEG.or!(PEG.and!(PEG.discard!(PEG.wrapAround!(Spacing, PEG.literal!("~>"), Spacing)), PEG.discard!(PEG.wrapAround!(Spacing, PEG.literal!("{"), Spacing)), PEG.oneOrMore!(PEG.wrapAround!(Spacing, Node, Spacing)), PEG.discard!(PEG.wrapAround!(Spacing, PEG.literal!("}"), Spacing))), PEG.and!(PEG.discard!(PEG.wrapAround!(Spacing, PEG.literal!("~>"), Spacing)), PEG.wrapAround!(Spacing, Node, Spacing))), "TesterGrammar.UnorderedBranch")(ParseTree("", false,[], s));
    }
    static string UnorderedBranch(GetName g)
    {
        return "TesterGrammar.UnorderedBranch";
    }

    static ParseTree Spacing(ParseTree p)
    {
         return PEG.named!(PEG.discard!(PEG.zeroOrMore!(PEG.or!(blank, Comment))), "TesterGrammar.Spacing")(p);
    }
    static ParseTree Spacing(string s)
    {
        return PEG.named!(PEG.discard!(PEG.zeroOrMore!(PEG.or!(blank, Comment))), "TesterGrammar.Spacing")(ParseTree("", false,[], s));
    }
    static string Spacing(GetName g)
    {
        return "TesterGrammar.Spacing";
    }

    static ParseTree Comment(ParseTree p)
    {
         return PEG.named!(PEG.or!(PEG.and!(PEG.literal!("//"), PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(eol), PEG.any)), eol), PEG.and!(PEG.literal!("/*"), PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(PEG.literal!("*/")), PEG.any)), PEG.literal!("*/")), NestedComment), "TesterGrammar.Comment")(p);
    }
    static ParseTree Comment(string s)
    {
        return PEG.named!(PEG.or!(PEG.and!(PEG.literal!("//"), PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(eol), PEG.any)), eol), PEG.and!(PEG.literal!("/*"), PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(PEG.literal!("*/")), PEG.any)), PEG.literal!("*/")), NestedComment), "TesterGrammar.Comment")(ParseTree("", false,[], s));
    }
    static string Comment(GetName g)
    {
        return "TesterGrammar.Comment";
    }

    static ParseTree NestedComment(ParseTree p)
    {
         return PEG.named!(PEG.and!(PEG.literal!("/+"), PEG.or!(PEG.and!(PEG.negLookahead!(NestedCommentEnd), PEG.any), NestedComment), NestedCommentEnd), "TesterGrammar.NestedComment")(p);
    }
    static ParseTree NestedComment(string s)
    {
        return PEG.named!(PEG.and!(PEG.literal!("/+"), PEG.or!(PEG.and!(PEG.negLookahead!(NestedCommentEnd), PEG.any), NestedComment), NestedCommentEnd), "TesterGrammar.NestedComment")(ParseTree("", false,[], s));
    }
    static string NestedComment(GetName g)
    {
        return "TesterGrammar.NestedComment";
    }

    static ParseTree NestedCommentEnd(ParseTree p)
    {
         return PEG.named!(PEG.literal!("+/"), "TesterGrammar.NestedCommentEnd")(p);
    }
    static ParseTree NestedCommentEnd(string s)
    {
        return PEG.named!(PEG.literal!("+/"), "TesterGrammar.NestedCommentEnd")(ParseTree("", false,[], s));
    }
    static string NestedCommentEnd(GetName g)
    {
        return "TesterGrammar.NestedCommentEnd";
    }

    static ParseTree opCall(ParseTree p)
    {
        ParseTree result = decimateTree(Root(p));
        result.children = [result];
        result.name = "TesterGrammar";
        return result;
    }

    static ParseTree opCall(string input)
    {
        return TesterGrammar(ParseTree(``, false, [], input, 0, 0));
}
    static string opCall(GetName g)
    {
        return "TesterGrammar";
    }

    }
}

import pegged.defaultparsetree : DefaultParseTree;
alias GenericTesterGrammar!(DefaultParseTree).TesterGrammar TesterGrammar;
