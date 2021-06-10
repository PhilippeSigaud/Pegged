/++
This module was automatically generated from the following grammar:


# This is the PEG extended grammar used by Pegged
Pegged:

# Syntactic rules:
Grammar      <- Spacing GrammarName Definition+ :eoi
Definition   <- LhsName Arrow Expression
Expression   <- FirstExpression / LongestExpression
FirstExpression   <- :OR? Sequence (:OR Sequence)+
LongestExpression <- :(OR / LONGEST_OR)? Sequence (:LONGEST_OR Sequence)*
Sequence     <- Prefix+
Prefix       <- (POS / NEG / FUSE / DISCARD / KEEP / DROP / PROPAGATE)* Suffix
Suffix       <- Primary (OPTION / ZEROORMORE / ONEORMORE / Action)*
Primary      <- !(LhsName Arrow)
                ( RhsName
                / :OPEN Expression :CLOSE
                / Literal
                / CILiteral
                / CharClass
                / ANY)
# Lexical syntax
Identifier   <- identifier
GrammarName  <- Identifier ParamList? Spacing :':' Spacing
LhsName      <- Identifier ParamList? Spacing
RhsName      <- Identifier ArgList? (NAMESEP Identifier ArgList?)* Spacing         # NAMESEP is *not* discarded
ParamList    <- :OPEN Param (:SEPARATOR Param)*  :CLOSE
Param        <- DefaultParam / SingleParam
DefaultParam <- Identifier Spacing :ASSIGN Expression
SingleParam  <- Identifier Spacing
ArgList      <- :OPEN Expression (:SEPARATOR Expression)* :CLOSE

Literal      <- quote       ~(!quote Char)*       quote       !'i' Spacing
              / doublequote ~(!doublequote Char)* doublequote !'i' Spacing
CILiteral    <- quote       ~(!quote Char)*       quote       :'i' Spacing
              / doublequote ~(!doublequote Char)* doublequote :'i' Spacing
CharClass    <- :'[' (!']' CharRange)* :']' Spacing
CharRange    <- Char '-' Char / Char

# Terminals
Char         <~ backslash ( quote
                          / doublequote
                          / backquote
                          / backslash
                          / '-'
                          / '['
                          / ']'
                          / [nrt]
                          / [0-2][0-7][0-7]
                          / [0-7][0-7]?
                          / 'x' hexDigit hexDigit
                          / 'u' hexDigit hexDigit hexDigit hexDigit
                          / 'U' hexDigit hexDigit hexDigit hexDigit hexDigit hexDigit hexDigit hexDigit
                          )
              / . # or anything else

Arrow        <- LEFTARROW / FUSEARROW / DISCARDARROW / KEEPARROW / DROPARROW / PROPAGATEARROW / ACTIONARROW / SPACEARROW
LEFTARROW    <- '<-' Spacing
FUSEARROW    <- '<~' Spacing
DISCARDARROW <- '<:' Spacing
KEEPARROW    <- '<^' Spacing
DROPARROW    <- '<;' Spacing
PROPAGATEARROW <- '<%' Spacing
SPACEARROW   <- '<' Spacing
ACTIONARROW  <- '<' Action Spacing

OR           <- '/' Spacing
LONGEST_OR   <- '|' Spacing

POS          <- '&' Spacing
NEG          <- '!' Spacing
FUSE         <- '~' Spacing
DISCARD      <- ':' Spacing
KEEP         <- '^' Spacing
DROP         <- ';' Spacing
PROPAGATE    <- '%' Spacing

OPTION       <- '?' Spacing
ZEROORMORE   <- '*' Spacing
ONEORMORE    <- '+' Spacing
ACTIONOPEN   <- '{' Spacing
ACTIONCLOSE  <- '}' Spacing
SEPARATOR    <- ',' Spacing
ASSIGN       <- '=' Spacing
NAMESEP      <- '.'   # No Spacing
OPEN         <- '(' Spacing
CLOSE        <- ')' Spacing
ANY          <- '.' Spacing
Spacing      <: (blank / Comment)*
Comment      <- '#' (!eol .)* :eol
Space        <- spacing / "\\t" / "\\n" / "\\r"

# Action Rule
Action      <- :ACTIONOPEN Spacing ((Lambda / qualifiedIdentifier)
(:SEPARATOR (Lambda / qualifiedIdentifier))*) Spacing :ACTIONCLOSE
Lambda      <~ (!(ACTIONCLOSE/SEPARATOR) (LambdaItems / NestedList('{',LambdaItems,'}') / .))*

LambdaItems <- ~DComment / ~DString / ~DParamList
DString     <- WYSString / DBQString / TKNString / DLMString

WYSString   <- 'r' doublequote (!doublequote .)* doublequote /
               backquote (!backquote .)* backquote

DBQString   <- doublequote (!doublequote Char)* doublequote

TKNString   <- (&'q{' ('q' NestedList('{',DString,'}')))

DLMString   <- ('q' doublequote) ( (&'{' NestedList('{',DString,'}'))
                                 / (&'[' NestedList('[',DString,']'))
                                 / (&'(' NestedList('(',DString,')'))
                                 / (&'<' NestedList('<',DString,'>'))
                                 ) doublequote

DComment             <- DLineComment / DBlockComment / DNestingBlockComment

DLineComment         <- "//" (!endOfLine .)* endOfLine
DBlockComment        <- "/*" (!"*/" .)* "*/"
DNestingBlockComment <- NestedList("/+","+/")

DParamList <- NestedList('(',')')

# Linear nested lists with and without special items
NestedList(L,Items,R)   <- ^L ( !(L/R/Items) . )* ( Items
                                                  / NestedList(L,Items,R)
                                                  / ( !(L/R/Items) . )*
                                                  )* ( !(L/R/Items) . )* ^R

NestedList(L,R) <- ^L ( !(L/R) . )* (NestedList(L,R) / ( !(L/R) . )*)* ( !(L/R) . )* ^R


+/
module pegged.parser;

public import pegged.defaultparsetree;
public import pegged.peg;
import std.algorithm: startsWith;
import std.functional: toDelegate;

import pegged.defaultparsetree : DefaultParseTree;
@safe struct GenericPegged(ParseTree)
{
//    static if (is(ParseTree == DefaultParseTree)) {
        alias PEG=ParseTree;
//    }

    import std.functional : toDelegate;
    import pegged.dynamic.grammar;
    static import pegged.peg;
    mixin DefaultPatters!ParseTree;
    //alias PEG=PeggedT!ParseTree;

    @safe struct Pegged
    {
        enum name = "Pegged";
        static ParseTree.Dynamic[string] before;
        static ParseTree.Dynamic[string] after;
        static ParseTree.Dynamic[string] rules;
    static this() @trusted
    {
        rules["Grammar"] = toDelegate(&Grammar);
        rules["Definition"] = toDelegate(&Definition);
        rules["Expression"] = toDelegate(&Expression);
        rules["FirstExpression"] = toDelegate(&FirstExpression);
        rules["LongestExpression"] = toDelegate(&LongestExpression);
        rules["Sequence"] = toDelegate(&Sequence);
        rules["Prefix"] = toDelegate(&Prefix);
        rules["Suffix"] = toDelegate(&Suffix);
        rules["Primary"] = toDelegate(&Primary);
        rules["Identifier"] = toDelegate(&Identifier);
        rules["GrammarName"] = toDelegate(&GrammarName);
        rules["LhsName"] = toDelegate(&LhsName);
        rules["RhsName"] = toDelegate(&RhsName);
        rules["ParamList"] = toDelegate(&ParamList);
        rules["Param"] = toDelegate(&Param);
        rules["DefaultParam"] = toDelegate(&DefaultParam);
        rules["SingleParam"] = toDelegate(&SingleParam);
        rules["ArgList"] = toDelegate(&ArgList);
        rules["Literal"] = toDelegate(&Literal);
        rules["CILiteral"] = toDelegate(&CILiteral);
        rules["CharClass"] = toDelegate(&CharClass);
        rules["CharRange"] = toDelegate(&CharRange);
        rules["Char"] = toDelegate(&Char);
        rules["Arrow"] = toDelegate(&Arrow);
        rules["LEFTARROW"] = toDelegate(&LEFTARROW);
        rules["FUSEARROW"] = toDelegate(&FUSEARROW);
        rules["DISCARDARROW"] = toDelegate(&DISCARDARROW);
        rules["KEEPARROW"] = toDelegate(&KEEPARROW);
        rules["DROPARROW"] = toDelegate(&DROPARROW);
        rules["PROPAGATEARROW"] = toDelegate(&PROPAGATEARROW);
        rules["SPACEARROW"] = toDelegate(&SPACEARROW);
        rules["ACTIONARROW"] = toDelegate(&ACTIONARROW);
        rules["OR"] = toDelegate(&OR);
        rules["LONGEST_OR"] = toDelegate(&LONGEST_OR);
        rules["POS"] = toDelegate(&POS);
        rules["NEG"] = toDelegate(&NEG);
        rules["FUSE"] = toDelegate(&FUSE);
        rules["DISCARD"] = toDelegate(&DISCARD);
        rules["KEEP"] = toDelegate(&KEEP);
        rules["DROP"] = toDelegate(&DROP);
        rules["PROPAGATE"] = toDelegate(&PROPAGATE);
        rules["OPTION"] = toDelegate(&OPTION);
        rules["ZEROORMORE"] = toDelegate(&ZEROORMORE);
        rules["ONEORMORE"] = toDelegate(&ONEORMORE);
        rules["ACTIONOPEN"] = toDelegate(&ACTIONOPEN);
        rules["ACTIONCLOSE"] = toDelegate(&ACTIONCLOSE);
        rules["SEPARATOR"] = toDelegate(&SEPARATOR);
        rules["ASSIGN"] = toDelegate(&ASSIGN);
        rules["NAMESEP"] = toDelegate(&NAMESEP);
        rules["OPEN"] = toDelegate(&OPEN);
        rules["CLOSE"] = toDelegate(&CLOSE);
        rules["ANY"] = toDelegate(&ANY);
        rules["Spacing"] = toDelegate(&Spacing);
    }

    template hooked(alias r, string name)
    {
        @safe {
        static ParseTree hooked(ParseTree p)
        {
            ParseTree result;

            if (name in before)
            {
                result = before[name](p);
                if (result.successful)
                    return result;
            }

            result = r(p);
            if (result.successful || name !in after)
                return result;

            result = after[name](p);
            return result;
        }

        static ParseTree hooked(string input)
        {
            return hooked!(r, name)(ParseTree("",false,[],input));
        }
        }
    }

    static void addRuleBefore(string parentRule, string ruleSyntax)
    {
        // enum name is the current grammar name
        auto dg = pegged.dynamic.grammar.grammar!ParseTree(name ~ ": " ~ ruleSyntax, rules);
        foreach(ruleName,rule; dg.rules)
            if (ruleName != "Spacing") // Keep the local Spacing rule, do not overwrite it
                rules[ruleName] = rule;
        before[parentRule] = rules[dg.startingRule];
    }

    static void addRuleAfter(string parentRule, string ruleSyntax)
    {
        // enum name is the current grammar named
        auto dg = pegged.dynamic.grammar.grammar!ParseTree(name ~ ": " ~ ruleSyntax, rules);
        foreach(ruleName,rule; dg.rules)
        {
            if (ruleName != "Spacing")
                rules[ruleName] = rule;
        }
        after[parentRule] = rules[dg.startingRule];
    }

    static bool isRule(string s)
    {
        import std.algorithm : startsWith;
        return s.startsWith("Pegged.");
    }
    mixin decimateTree!ParseTree;

    static ParseTree Grammar(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(Spacing, GrammarName, PEG.oneOrMore!(Definition), PEG.discard!(eoi)), "Pegged.Grammar")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(Spacing, GrammarName, PEG.oneOrMore!(Definition), PEG.discard!(eoi)), "Pegged.Grammar"), "Grammar")(p);
        }
    }
    static ParseTree Grammar(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(Spacing, GrammarName, PEG.oneOrMore!(Definition), PEG.discard!(eoi)), "Pegged.Grammar")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(Spacing, GrammarName, PEG.oneOrMore!(Definition), PEG.discard!(eoi)), "Pegged.Grammar"), "Grammar")(ParseTree("", false,[], s));
        }
    }
    static string Grammar(GetName g)
    {
        return "Pegged.Grammar";
    }

    static ParseTree Definition(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(LhsName, Arrow, Expression), "Pegged.Definition")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(LhsName, Arrow, Expression), "Pegged.Definition"), "Definition")(p);
        }
    }
    static ParseTree Definition(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(LhsName, Arrow, Expression), "Pegged.Definition")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(LhsName, Arrow, Expression), "Pegged.Definition"), "Definition")(ParseTree("", false,[], s));
        }
    }
    static string Definition(GetName g)
    {
        return "Pegged.Definition";
    }

    static ParseTree Expression(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.or!(FirstExpression, LongestExpression), "Pegged.Expression")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.or!(FirstExpression, LongestExpression), "Pegged.Expression"), "Expression")(p);
        }
    }
    static ParseTree Expression(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.or!(FirstExpression, LongestExpression), "Pegged.Expression")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.or!(FirstExpression, LongestExpression), "Pegged.Expression"), "Expression")(ParseTree("", false,[], s));
        }
    }
    static string Expression(GetName g)
    {
        return "Pegged.Expression";
    }

    static ParseTree FirstExpression(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(PEG.discard!(PEG.option!(OR)), Sequence, PEG.oneOrMore!(PEG.and!(PEG.discard!(OR), Sequence))), "Pegged.FirstExpression")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(PEG.discard!(PEG.option!(OR)), Sequence, PEG.oneOrMore!(PEG.and!(PEG.discard!(OR), Sequence))), "Pegged.FirstExpression"), "FirstExpression")(p);
        }
    }
    static ParseTree FirstExpression(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(PEG.discard!(PEG.option!(OR)), Sequence, PEG.oneOrMore!(PEG.and!(PEG.discard!(OR), Sequence))), "Pegged.FirstExpression")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(PEG.discard!(PEG.option!(OR)), Sequence, PEG.oneOrMore!(PEG.and!(PEG.discard!(OR), Sequence))), "Pegged.FirstExpression"), "FirstExpression")(ParseTree("", false,[], s));
        }
    }
    static string FirstExpression(GetName g)
    {
        return "Pegged.FirstExpression";
    }

    static ParseTree LongestExpression(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(PEG.discard!(PEG.option!(PEG.or!(OR, LONGEST_OR))), Sequence, PEG.zeroOrMore!(PEG.and!(PEG.discard!(LONGEST_OR), Sequence))), "Pegged.LongestExpression")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(PEG.discard!(PEG.option!(PEG.or!(OR, LONGEST_OR))), Sequence, PEG.zeroOrMore!(PEG.and!(PEG.discard!(LONGEST_OR), Sequence))), "Pegged.LongestExpression"), "LongestExpression")(p);
        }
    }
    static ParseTree LongestExpression(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(PEG.discard!(PEG.option!(PEG.or!(OR, LONGEST_OR))), Sequence, PEG.zeroOrMore!(PEG.and!(PEG.discard!(LONGEST_OR), Sequence))), "Pegged.LongestExpression")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(PEG.discard!(PEG.option!(PEG.or!(OR, LONGEST_OR))), Sequence, PEG.zeroOrMore!(PEG.and!(PEG.discard!(LONGEST_OR), Sequence))), "Pegged.LongestExpression"), "LongestExpression")(ParseTree("", false,[], s));
        }
    }
    static string LongestExpression(GetName g)
    {
        return "Pegged.LongestExpression";
    }

    static ParseTree Sequence(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.oneOrMore!(Prefix), "Pegged.Sequence")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.oneOrMore!(Prefix), "Pegged.Sequence"), "Sequence")(p);
        }
    }
    static ParseTree Sequence(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.oneOrMore!(Prefix), "Pegged.Sequence")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.oneOrMore!(Prefix), "Pegged.Sequence"), "Sequence")(ParseTree("", false,[], s));
        }
    }
    static string Sequence(GetName g)
    {
        return "Pegged.Sequence";
    }

    static ParseTree Prefix(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(PEG.zeroOrMore!(PEG.or!(POS, NEG, FUSE, DISCARD, KEEP, DROP, PROPAGATE)), Suffix), "Pegged.Prefix")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(PEG.zeroOrMore!(PEG.or!(POS, NEG, FUSE, DISCARD, KEEP, DROP, PROPAGATE)), Suffix), "Pegged.Prefix"), "Prefix")(p);
        }
    }
    static ParseTree Prefix(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(PEG.zeroOrMore!(PEG.or!(POS, NEG, FUSE, DISCARD, KEEP, DROP, PROPAGATE)), Suffix), "Pegged.Prefix")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(PEG.zeroOrMore!(PEG.or!(POS, NEG, FUSE, DISCARD, KEEP, DROP, PROPAGATE)), Suffix), "Pegged.Prefix"), "Prefix")(ParseTree("", false,[], s));
        }
    }
    static string Prefix(GetName g)
    {
        return "Pegged.Prefix";
    }

    static ParseTree Suffix(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(Primary, PEG.zeroOrMore!(PEG.or!(OPTION, ZEROORMORE, ONEORMORE, Action))), "Pegged.Suffix")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(Primary, PEG.zeroOrMore!(PEG.or!(OPTION, ZEROORMORE, ONEORMORE, Action))), "Pegged.Suffix"), "Suffix")(p);
        }
    }
    static ParseTree Suffix(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(Primary, PEG.zeroOrMore!(PEG.or!(OPTION, ZEROORMORE, ONEORMORE, Action))), "Pegged.Suffix")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(Primary, PEG.zeroOrMore!(PEG.or!(OPTION, ZEROORMORE, ONEORMORE, Action))), "Pegged.Suffix"), "Suffix")(ParseTree("", false,[], s));
        }
    }
    static string Suffix(GetName g)
    {
        return "Pegged.Suffix";
    }

    static ParseTree Primary(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(PEG.negLookahead!(PEG.and!(LhsName, Arrow)), PEG.or!(RhsName, PEG.and!(PEG.discard!(OPEN), Expression, PEG.discard!(CLOSE)), Literal, CILiteral, CharClass, ANY)), "Pegged.Primary")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(PEG.negLookahead!(PEG.and!(LhsName, Arrow)), PEG.or!(RhsName, PEG.and!(PEG.discard!(OPEN), Expression, PEG.discard!(CLOSE)), Literal, CILiteral, CharClass, ANY)), "Pegged.Primary"), "Primary")(p);
        }
    }
    static ParseTree Primary(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(PEG.negLookahead!(PEG.and!(LhsName, Arrow)), PEG.or!(RhsName, PEG.and!(PEG.discard!(OPEN), Expression, PEG.discard!(CLOSE)), Literal, CILiteral, CharClass, ANY)), "Pegged.Primary")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(PEG.negLookahead!(PEG.and!(LhsName, Arrow)), PEG.or!(RhsName, PEG.and!(PEG.discard!(OPEN), Expression, PEG.discard!(CLOSE)), Literal, CILiteral, CharClass, ANY)), "Pegged.Primary"), "Primary")(ParseTree("", false,[], s));
        }
    }
    static string Primary(GetName g)
    {
        return "Pegged.Primary";
    }

    static ParseTree Identifier(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(identifier, "Pegged.Identifier")(p);
        }
        else
        {
            return hooked!(PEG.defined!(identifier, "Pegged.Identifier"), "Identifier")(p);
        }
    }
    static ParseTree Identifier(string s)
    {
        if(__ctfe)
            return         PEG.defined!(identifier, "Pegged.Identifier")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(identifier, "Pegged.Identifier"), "Identifier")(ParseTree("", false,[], s));
        }
    }
    static string Identifier(GetName g)
    {
        return "Pegged.Identifier";
    }

    static ParseTree GrammarName(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(Identifier, PEG.option!(ParamList), Spacing, PEG.discard!(PEG.literal!(":")), Spacing), "Pegged.GrammarName")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(Identifier, PEG.option!(ParamList), Spacing, PEG.discard!(PEG.literal!(":")), Spacing), "Pegged.GrammarName"), "GrammarName")(p);
        }
    }
    static ParseTree GrammarName(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(Identifier, PEG.option!(ParamList), Spacing, PEG.discard!(PEG.literal!(":")), Spacing), "Pegged.GrammarName")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(Identifier, PEG.option!(ParamList), Spacing, PEG.discard!(PEG.literal!(":")), Spacing), "Pegged.GrammarName"), "GrammarName")(ParseTree("", false,[], s));
        }
    }
    static string GrammarName(GetName g)
    {
        return "Pegged.GrammarName";
    }

    static ParseTree LhsName(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(Identifier, PEG.option!(ParamList), Spacing), "Pegged.LhsName")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(Identifier, PEG.option!(ParamList), Spacing), "Pegged.LhsName"), "LhsName")(p);
        }
    }
    static ParseTree LhsName(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(Identifier, PEG.option!(ParamList), Spacing), "Pegged.LhsName")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(Identifier, PEG.option!(ParamList), Spacing), "Pegged.LhsName"), "LhsName")(ParseTree("", false,[], s));
        }
    }
    static string LhsName(GetName g)
    {
        return "Pegged.LhsName";
    }

    static ParseTree RhsName(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(Identifier, PEG.option!(ArgList), PEG.zeroOrMore!(PEG.and!(NAMESEP, Identifier, PEG.option!(ArgList))), Spacing), "Pegged.RhsName")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(Identifier, PEG.option!(ArgList), PEG.zeroOrMore!(PEG.and!(NAMESEP, Identifier, PEG.option!(ArgList))), Spacing), "Pegged.RhsName"), "RhsName")(p);
        }
    }
    static ParseTree RhsName(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(Identifier, PEG.option!(ArgList), PEG.zeroOrMore!(PEG.and!(NAMESEP, Identifier, PEG.option!(ArgList))), Spacing), "Pegged.RhsName")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(Identifier, PEG.option!(ArgList), PEG.zeroOrMore!(PEG.and!(NAMESEP, Identifier, PEG.option!(ArgList))), Spacing), "Pegged.RhsName"), "RhsName")(ParseTree("", false,[], s));
        }
    }
    static string RhsName(GetName g)
    {
        return "Pegged.RhsName";
    }

    static ParseTree ParamList(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(PEG.discard!(OPEN), Param, PEG.zeroOrMore!(PEG.and!(PEG.discard!(SEPARATOR), Param)), PEG.discard!(CLOSE)), "Pegged.ParamList")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(PEG.discard!(OPEN), Param, PEG.zeroOrMore!(PEG.and!(PEG.discard!(SEPARATOR), Param)), PEG.discard!(CLOSE)), "Pegged.ParamList"), "ParamList")(p);
        }
    }
    static ParseTree ParamList(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(PEG.discard!(OPEN), Param, PEG.zeroOrMore!(PEG.and!(PEG.discard!(SEPARATOR), Param)), PEG.discard!(CLOSE)), "Pegged.ParamList")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(PEG.discard!(OPEN), Param, PEG.zeroOrMore!(PEG.and!(PEG.discard!(SEPARATOR), Param)), PEG.discard!(CLOSE)), "Pegged.ParamList"), "ParamList")(ParseTree("", false,[], s));
        }
    }
    static string ParamList(GetName g)
    {
        return "Pegged.ParamList";
    }

    static ParseTree Param(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.or!(DefaultParam, SingleParam), "Pegged.Param")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.or!(DefaultParam, SingleParam), "Pegged.Param"), "Param")(p);
        }
    }
    static ParseTree Param(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.or!(DefaultParam, SingleParam), "Pegged.Param")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.or!(DefaultParam, SingleParam), "Pegged.Param"), "Param")(ParseTree("", false,[], s));
        }
    }
    static string Param(GetName g)
    {
        return "Pegged.Param";
    }

    static ParseTree DefaultParam(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(Identifier, Spacing, PEG.discard!(ASSIGN), Expression), "Pegged.DefaultParam")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(Identifier, Spacing, PEG.discard!(ASSIGN), Expression), "Pegged.DefaultParam"), "DefaultParam")(p);
        }
    }
    static ParseTree DefaultParam(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(Identifier, Spacing, PEG.discard!(ASSIGN), Expression), "Pegged.DefaultParam")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(Identifier, Spacing, PEG.discard!(ASSIGN), Expression), "Pegged.DefaultParam"), "DefaultParam")(ParseTree("", false,[], s));
        }
    }
    static string DefaultParam(GetName g)
    {
        return "Pegged.DefaultParam";
    }

    static ParseTree SingleParam(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(Identifier, Spacing), "Pegged.SingleParam")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(Identifier, Spacing), "Pegged.SingleParam"), "SingleParam")(p);
        }
    }
    static ParseTree SingleParam(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(Identifier, Spacing), "Pegged.SingleParam")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(Identifier, Spacing), "Pegged.SingleParam"), "SingleParam")(ParseTree("", false,[], s));
        }
    }
    static string SingleParam(GetName g)
    {
        return "Pegged.SingleParam";
    }

    static ParseTree ArgList(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(PEG.discard!(OPEN), Expression, PEG.zeroOrMore!(PEG.and!(PEG.discard!(SEPARATOR), Expression)), PEG.discard!(CLOSE)), "Pegged.ArgList")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(PEG.discard!(OPEN), Expression, PEG.zeroOrMore!(PEG.and!(PEG.discard!(SEPARATOR), Expression)), PEG.discard!(CLOSE)), "Pegged.ArgList"), "ArgList")(p);
        }
    }
    static ParseTree ArgList(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(PEG.discard!(OPEN), Expression, PEG.zeroOrMore!(PEG.and!(PEG.discard!(SEPARATOR), Expression)), PEG.discard!(CLOSE)), "Pegged.ArgList")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(PEG.discard!(OPEN), Expression, PEG.zeroOrMore!(PEG.and!(PEG.discard!(SEPARATOR), Expression)), PEG.discard!(CLOSE)), "Pegged.ArgList"), "ArgList")(ParseTree("", false,[], s));
        }
    }
    static string ArgList(GetName g)
    {
        return "Pegged.ArgList";
    }

    static ParseTree Literal(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.or!(PEG.and!(quote, PEG.fuse!(PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(quote), Char))), quote, PEG.negLookahead!(PEG.literal!("i")), Spacing), PEG.and!(doublequote, PEG.fuse!(PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(doublequote), Char))), doublequote, PEG.negLookahead!(PEG.literal!("i")), Spacing)), "Pegged.Literal")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.or!(PEG.and!(quote, PEG.fuse!(PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(quote), Char))), quote, PEG.negLookahead!(PEG.literal!("i")), Spacing), PEG.and!(doublequote, PEG.fuse!(PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(doublequote), Char))), doublequote, PEG.negLookahead!(PEG.literal!("i")), Spacing)), "Pegged.Literal"), "Literal")(p);
        }
    }
    static ParseTree Literal(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.or!(PEG.and!(quote, PEG.fuse!(PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(quote), Char))), quote, PEG.negLookahead!(PEG.literal!("i")), Spacing), PEG.and!(doublequote, PEG.fuse!(PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(doublequote), Char))), doublequote, PEG.negLookahead!(PEG.literal!("i")), Spacing)), "Pegged.Literal")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.or!(PEG.and!(quote, PEG.fuse!(PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(quote), Char))), quote, PEG.negLookahead!(PEG.literal!("i")), Spacing), PEG.and!(doublequote, PEG.fuse!(PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(doublequote), Char))), doublequote, PEG.negLookahead!(PEG.literal!("i")), Spacing)), "Pegged.Literal"), "Literal")(ParseTree("", false,[], s));
        }
    }
    static string Literal(GetName g)
    {
        return "Pegged.Literal";
    }

    static ParseTree CILiteral(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.or!(PEG.and!(quote, PEG.fuse!(PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(quote), Char))), quote, PEG.discard!(PEG.literal!("i")), Spacing), PEG.and!(doublequote, PEG.fuse!(PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(doublequote), Char))), doublequote, PEG.discard!(PEG.literal!("i")), Spacing)), "Pegged.CILiteral")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.or!(PEG.and!(quote, PEG.fuse!(PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(quote), Char))), quote, PEG.discard!(PEG.literal!("i")), Spacing), PEG.and!(doublequote, PEG.fuse!(PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(doublequote), Char))), doublequote, PEG.discard!(PEG.literal!("i")), Spacing)), "Pegged.CILiteral"), "CILiteral")(p);
        }
    }
    static ParseTree CILiteral(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.or!(PEG.and!(quote, PEG.fuse!(PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(quote), Char))), quote, PEG.discard!(PEG.literal!("i")), Spacing), PEG.and!(doublequote, PEG.fuse!(PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(doublequote), Char))), doublequote, PEG.discard!(PEG.literal!("i")), Spacing)), "Pegged.CILiteral")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.or!(PEG.and!(quote, PEG.fuse!(PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(quote), Char))), quote, PEG.discard!(PEG.literal!("i")), Spacing), PEG.and!(doublequote, PEG.fuse!(PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(doublequote), Char))), doublequote, PEG.discard!(PEG.literal!("i")), Spacing)), "Pegged.CILiteral"), "CILiteral")(ParseTree("", false,[], s));
        }
    }
    static string CILiteral(GetName g)
    {
        return "Pegged.CILiteral";
    }

    static ParseTree CharClass(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(PEG.discard!(PEG.literal!("[")), PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(PEG.literal!("]")), CharRange)), PEG.discard!(PEG.literal!("]")), Spacing), "Pegged.CharClass")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(PEG.discard!(PEG.literal!("[")), PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(PEG.literal!("]")), CharRange)), PEG.discard!(PEG.literal!("]")), Spacing), "Pegged.CharClass"), "CharClass")(p);
        }
    }
    static ParseTree CharClass(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(PEG.discard!(PEG.literal!("[")), PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(PEG.literal!("]")), CharRange)), PEG.discard!(PEG.literal!("]")), Spacing), "Pegged.CharClass")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(PEG.discard!(PEG.literal!("[")), PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(PEG.literal!("]")), CharRange)), PEG.discard!(PEG.literal!("]")), Spacing), "Pegged.CharClass"), "CharClass")(ParseTree("", false,[], s));
        }
    }
    static string CharClass(GetName g)
    {
        return "Pegged.CharClass";
    }

    static ParseTree CharRange(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.or!(PEG.and!(Char, PEG.literal!("-"), Char), Char), "Pegged.CharRange")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.or!(PEG.and!(Char, PEG.literal!("-"), Char), Char), "Pegged.CharRange"), "CharRange")(p);
        }
    }
    static ParseTree CharRange(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.or!(PEG.and!(Char, PEG.literal!("-"), Char), Char), "Pegged.CharRange")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.or!(PEG.and!(Char, PEG.literal!("-"), Char), Char), "Pegged.CharRange"), "CharRange")(ParseTree("", false,[], s));
        }
    }
    static string CharRange(GetName g)
    {
        return "Pegged.CharRange";
    }

    static ParseTree Char(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.fuse!(PEG.or!(PEG.and!(backslash, PEG.or!(quote, doublequote, backquote, backslash, PEG.literal!("-"), PEG.literal!("["), PEG.literal!("]"), PEG.or!(PEG.literal!("n"), PEG.literal!("r"), PEG.literal!("t")), PEG.and!(PEG.charRange!('0', '2'), PEG.charRange!('0', '7'), PEG.charRange!('0', '7')), PEG.and!(PEG.charRange!('0', '7'), PEG.option!(PEG.charRange!('0', '7'))), PEG.and!(PEG.literal!("x"), hexDigit, hexDigit), PEG.and!(PEG.literal!("u"), hexDigit, hexDigit, hexDigit, hexDigit), PEG.and!(PEG.literal!("U"), hexDigit, hexDigit, hexDigit, hexDigit, hexDigit, hexDigit, hexDigit, hexDigit))), PEG.any)), "Pegged.Char")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.fuse!(PEG.or!(PEG.and!(backslash, PEG.or!(quote, doublequote, backquote, backslash, PEG.literal!("-"), PEG.literal!("["), PEG.literal!("]"), PEG.or!(PEG.literal!("n"), PEG.literal!("r"), PEG.literal!("t")), PEG.and!(PEG.charRange!('0', '2'), PEG.charRange!('0', '7'), PEG.charRange!('0', '7')), PEG.and!(PEG.charRange!('0', '7'), PEG.option!(PEG.charRange!('0', '7'))), PEG.and!(PEG.literal!("x"), hexDigit, hexDigit), PEG.and!(PEG.literal!("u"), hexDigit, hexDigit, hexDigit, hexDigit), PEG.and!(PEG.literal!("U"), hexDigit, hexDigit, hexDigit, hexDigit, hexDigit, hexDigit, hexDigit, hexDigit))), PEG.any)), "Pegged.Char"), "Char")(p);
        }
    }
    static ParseTree Char(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.fuse!(PEG.or!(PEG.and!(backslash, PEG.or!(quote, doublequote, backquote, backslash, PEG.literal!("-"), PEG.literal!("["), PEG.literal!("]"), PEG.or!(PEG.literal!("n"), PEG.literal!("r"), PEG.literal!("t")), PEG.and!(PEG.charRange!('0', '2'), PEG.charRange!('0', '7'), PEG.charRange!('0', '7')), PEG.and!(PEG.charRange!('0', '7'), PEG.option!(PEG.charRange!('0', '7'))), PEG.and!(PEG.literal!("x"), hexDigit, hexDigit), PEG.and!(PEG.literal!("u"), hexDigit, hexDigit, hexDigit, hexDigit), PEG.and!(PEG.literal!("U"), hexDigit, hexDigit, hexDigit, hexDigit, hexDigit, hexDigit, hexDigit, hexDigit))), PEG.any)), "Pegged.Char")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.fuse!(PEG.or!(PEG.and!(backslash, PEG.or!(quote, doublequote, backquote, backslash, PEG.literal!("-"), PEG.literal!("["), PEG.literal!("]"), PEG.or!(PEG.literal!("n"), PEG.literal!("r"), PEG.literal!("t")), PEG.and!(PEG.charRange!('0', '2'), PEG.charRange!('0', '7'), PEG.charRange!('0', '7')), PEG.and!(PEG.charRange!('0', '7'), PEG.option!(PEG.charRange!('0', '7'))), PEG.and!(PEG.literal!("x"), hexDigit, hexDigit), PEG.and!(PEG.literal!("u"), hexDigit, hexDigit, hexDigit, hexDigit), PEG.and!(PEG.literal!("U"), hexDigit, hexDigit, hexDigit, hexDigit, hexDigit, hexDigit, hexDigit, hexDigit))), PEG.any)), "Pegged.Char"), "Char")(ParseTree("", false,[], s));
        }
    }
    static string Char(GetName g)
    {
        return "Pegged.Char";
    }

    static ParseTree Arrow(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.or!(LEFTARROW, FUSEARROW, DISCARDARROW, KEEPARROW, DROPARROW, PROPAGATEARROW, ACTIONARROW, SPACEARROW), "Pegged.Arrow")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.or!(LEFTARROW, FUSEARROW, DISCARDARROW, KEEPARROW, DROPARROW, PROPAGATEARROW, ACTIONARROW, SPACEARROW), "Pegged.Arrow"), "Arrow")(p);
        }
    }
    static ParseTree Arrow(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.or!(LEFTARROW, FUSEARROW, DISCARDARROW, KEEPARROW, DROPARROW, PROPAGATEARROW, ACTIONARROW, SPACEARROW), "Pegged.Arrow")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.or!(LEFTARROW, FUSEARROW, DISCARDARROW, KEEPARROW, DROPARROW, PROPAGATEARROW, ACTIONARROW, SPACEARROW), "Pegged.Arrow"), "Arrow")(ParseTree("", false,[], s));
        }
    }
    static string Arrow(GetName g)
    {
        return "Pegged.Arrow";
    }

    static ParseTree LEFTARROW(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(PEG.literal!("<-"), Spacing), "Pegged.LEFTARROW")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("<-"), Spacing), "Pegged.LEFTARROW"), "LEFTARROW")(p);
        }
    }
    static ParseTree LEFTARROW(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(PEG.literal!("<-"), Spacing), "Pegged.LEFTARROW")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("<-"), Spacing), "Pegged.LEFTARROW"), "LEFTARROW")(ParseTree("", false,[], s));
        }
    }
    static string LEFTARROW(GetName g)
    {
        return "Pegged.LEFTARROW";
    }

    static ParseTree FUSEARROW(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(PEG.literal!("<~"), Spacing), "Pegged.FUSEARROW")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("<~"), Spacing), "Pegged.FUSEARROW"), "FUSEARROW")(p);
        }
    }
    static ParseTree FUSEARROW(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(PEG.literal!("<~"), Spacing), "Pegged.FUSEARROW")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("<~"), Spacing), "Pegged.FUSEARROW"), "FUSEARROW")(ParseTree("", false,[], s));
        }
    }
    static string FUSEARROW(GetName g)
    {
        return "Pegged.FUSEARROW";
    }

    static ParseTree DISCARDARROW(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(PEG.literal!("<:"), Spacing), "Pegged.DISCARDARROW")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("<:"), Spacing), "Pegged.DISCARDARROW"), "DISCARDARROW")(p);
        }
    }
    static ParseTree DISCARDARROW(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(PEG.literal!("<:"), Spacing), "Pegged.DISCARDARROW")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("<:"), Spacing), "Pegged.DISCARDARROW"), "DISCARDARROW")(ParseTree("", false,[], s));
        }
    }
    static string DISCARDARROW(GetName g)
    {
        return "Pegged.DISCARDARROW";
    }

    static ParseTree KEEPARROW(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(PEG.literal!("<^"), Spacing), "Pegged.KEEPARROW")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("<^"), Spacing), "Pegged.KEEPARROW"), "KEEPARROW")(p);
        }
    }
    static ParseTree KEEPARROW(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(PEG.literal!("<^"), Spacing), "Pegged.KEEPARROW")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("<^"), Spacing), "Pegged.KEEPARROW"), "KEEPARROW")(ParseTree("", false,[], s));
        }
    }
    static string KEEPARROW(GetName g)
    {
        return "Pegged.KEEPARROW";
    }

    static ParseTree DROPARROW(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(PEG.literal!("<;"), Spacing), "Pegged.DROPARROW")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("<;"), Spacing), "Pegged.DROPARROW"), "DROPARROW")(p);
        }
    }
    static ParseTree DROPARROW(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(PEG.literal!("<;"), Spacing), "Pegged.DROPARROW")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("<;"), Spacing), "Pegged.DROPARROW"), "DROPARROW")(ParseTree("", false,[], s));
        }
    }
    static string DROPARROW(GetName g)
    {
        return "Pegged.DROPARROW";
    }

    static ParseTree PROPAGATEARROW(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(PEG.literal!("<%"), Spacing), "Pegged.PROPAGATEARROW")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("<%"), Spacing), "Pegged.PROPAGATEARROW"), "PROPAGATEARROW")(p);
        }
    }
    static ParseTree PROPAGATEARROW(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(PEG.literal!("<%"), Spacing), "Pegged.PROPAGATEARROW")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("<%"), Spacing), "Pegged.PROPAGATEARROW"), "PROPAGATEARROW")(ParseTree("", false,[], s));
        }
    }
    static string PROPAGATEARROW(GetName g)
    {
        return "Pegged.PROPAGATEARROW";
    }

    static ParseTree SPACEARROW(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(PEG.literal!("<"), Spacing), "Pegged.SPACEARROW")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("<"), Spacing), "Pegged.SPACEARROW"), "SPACEARROW")(p);
        }
    }
    static ParseTree SPACEARROW(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(PEG.literal!("<"), Spacing), "Pegged.SPACEARROW")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("<"), Spacing), "Pegged.SPACEARROW"), "SPACEARROW")(ParseTree("", false,[], s));
        }
    }
    static string SPACEARROW(GetName g)
    {
        return "Pegged.SPACEARROW";
    }

    static ParseTree ACTIONARROW(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(PEG.literal!("<"), Action, Spacing), "Pegged.ACTIONARROW")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("<"), Action, Spacing), "Pegged.ACTIONARROW"), "ACTIONARROW")(p);
        }
    }
    static ParseTree ACTIONARROW(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(PEG.literal!("<"), Action, Spacing), "Pegged.ACTIONARROW")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("<"), Action, Spacing), "Pegged.ACTIONARROW"), "ACTIONARROW")(ParseTree("", false,[], s));
        }
    }
    static string ACTIONARROW(GetName g)
    {
        return "Pegged.ACTIONARROW";
    }

    static ParseTree OR(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(PEG.literal!("/"), Spacing), "Pegged.OR")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("/"), Spacing), "Pegged.OR"), "OR")(p);
        }
    }
    static ParseTree OR(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(PEG.literal!("/"), Spacing), "Pegged.OR")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("/"), Spacing), "Pegged.OR"), "OR")(ParseTree("", false,[], s));
        }
    }
    static string OR(GetName g)
    {
        return "Pegged.OR";
    }

    static ParseTree LONGEST_OR(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(PEG.literal!("|"), Spacing), "Pegged.LONGEST_OR")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("|"), Spacing), "Pegged.LONGEST_OR"), "LONGEST_OR")(p);
        }
    }
    static ParseTree LONGEST_OR(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(PEG.literal!("|"), Spacing), "Pegged.LONGEST_OR")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("|"), Spacing), "Pegged.LONGEST_OR"), "LONGEST_OR")(ParseTree("", false,[], s));
        }
    }
    static string LONGEST_OR(GetName g)
    {
        return "Pegged.LONGEST_OR";
    }

    static ParseTree POS(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(PEG.literal!("&"), Spacing), "Pegged.POS")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("&"), Spacing), "Pegged.POS"), "POS")(p);
        }
    }
    static ParseTree POS(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(PEG.literal!("&"), Spacing), "Pegged.POS")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("&"), Spacing), "Pegged.POS"), "POS")(ParseTree("", false,[], s));
        }
    }
    static string POS(GetName g)
    {
        return "Pegged.POS";
    }

    static ParseTree NEG(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(PEG.literal!("!"), Spacing), "Pegged.NEG")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("!"), Spacing), "Pegged.NEG"), "NEG")(p);
        }
    }
    static ParseTree NEG(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(PEG.literal!("!"), Spacing), "Pegged.NEG")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("!"), Spacing), "Pegged.NEG"), "NEG")(ParseTree("", false,[], s));
        }
    }
    static string NEG(GetName g)
    {
        return "Pegged.NEG";
    }

    static ParseTree FUSE(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(PEG.literal!("~"), Spacing), "Pegged.FUSE")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("~"), Spacing), "Pegged.FUSE"), "FUSE")(p);
        }
    }
    static ParseTree FUSE(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(PEG.literal!("~"), Spacing), "Pegged.FUSE")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("~"), Spacing), "Pegged.FUSE"), "FUSE")(ParseTree("", false,[], s));
        }
    }
    static string FUSE(GetName g)
    {
        return "Pegged.FUSE";
    }

    static ParseTree DISCARD(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(PEG.literal!(":"), Spacing), "Pegged.DISCARD")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!(":"), Spacing), "Pegged.DISCARD"), "DISCARD")(p);
        }
    }
    static ParseTree DISCARD(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(PEG.literal!(":"), Spacing), "Pegged.DISCARD")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!(":"), Spacing), "Pegged.DISCARD"), "DISCARD")(ParseTree("", false,[], s));
        }
    }
    static string DISCARD(GetName g)
    {
        return "Pegged.DISCARD";
    }

    static ParseTree KEEP(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(PEG.literal!("^"), Spacing), "Pegged.KEEP")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("^"), Spacing), "Pegged.KEEP"), "KEEP")(p);
        }
    }
    static ParseTree KEEP(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(PEG.literal!("^"), Spacing), "Pegged.KEEP")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("^"), Spacing), "Pegged.KEEP"), "KEEP")(ParseTree("", false,[], s));
        }
    }
    static string KEEP(GetName g)
    {
        return "Pegged.KEEP";
    }

    static ParseTree DROP(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(PEG.literal!(";"), Spacing), "Pegged.DROP")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!(";"), Spacing), "Pegged.DROP"), "DROP")(p);
        }
    }
    static ParseTree DROP(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(PEG.literal!(";"), Spacing), "Pegged.DROP")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!(";"), Spacing), "Pegged.DROP"), "DROP")(ParseTree("", false,[], s));
        }
    }
    static string DROP(GetName g)
    {
        return "Pegged.DROP";
    }

    static ParseTree PROPAGATE(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(PEG.literal!("%"), Spacing), "Pegged.PROPAGATE")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("%"), Spacing), "Pegged.PROPAGATE"), "PROPAGATE")(p);
        }
    }
    static ParseTree PROPAGATE(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(PEG.literal!("%"), Spacing), "Pegged.PROPAGATE")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("%"), Spacing), "Pegged.PROPAGATE"), "PROPAGATE")(ParseTree("", false,[], s));
        }
    }
    static string PROPAGATE(GetName g)
    {
        return "Pegged.PROPAGATE";
    }

    static ParseTree OPTION(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(PEG.literal!("?"), Spacing), "Pegged.OPTION")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("?"), Spacing), "Pegged.OPTION"), "OPTION")(p);
        }
    }
    static ParseTree OPTION(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(PEG.literal!("?"), Spacing), "Pegged.OPTION")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("?"), Spacing), "Pegged.OPTION"), "OPTION")(ParseTree("", false,[], s));
        }
    }
    static string OPTION(GetName g)
    {
        return "Pegged.OPTION";
    }

    static ParseTree ZEROORMORE(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(PEG.literal!("*"), Spacing), "Pegged.ZEROORMORE")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("*"), Spacing), "Pegged.ZEROORMORE"), "ZEROORMORE")(p);
        }
    }
    static ParseTree ZEROORMORE(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(PEG.literal!("*"), Spacing), "Pegged.ZEROORMORE")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("*"), Spacing), "Pegged.ZEROORMORE"), "ZEROORMORE")(ParseTree("", false,[], s));
        }
    }
    static string ZEROORMORE(GetName g)
    {
        return "Pegged.ZEROORMORE";
    }

    static ParseTree ONEORMORE(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(PEG.literal!("+"), Spacing), "Pegged.ONEORMORE")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("+"), Spacing), "Pegged.ONEORMORE"), "ONEORMORE")(p);
        }
    }
    static ParseTree ONEORMORE(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(PEG.literal!("+"), Spacing), "Pegged.ONEORMORE")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("+"), Spacing), "Pegged.ONEORMORE"), "ONEORMORE")(ParseTree("", false,[], s));
        }
    }
    static string ONEORMORE(GetName g)
    {
        return "Pegged.ONEORMORE";
    }

    static ParseTree ACTIONOPEN(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(PEG.literal!("{"), Spacing), "Pegged.ACTIONOPEN")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("{"), Spacing), "Pegged.ACTIONOPEN"), "ACTIONOPEN")(p);
        }
    }
    static ParseTree ACTIONOPEN(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(PEG.literal!("{"), Spacing), "Pegged.ACTIONOPEN")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("{"), Spacing), "Pegged.ACTIONOPEN"), "ACTIONOPEN")(ParseTree("", false,[], s));
        }
    }
    static string ACTIONOPEN(GetName g)
    {
        return "Pegged.ACTIONOPEN";
    }

    static ParseTree ACTIONCLOSE(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(PEG.literal!("}"), Spacing), "Pegged.ACTIONCLOSE")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("}"), Spacing), "Pegged.ACTIONCLOSE"), "ACTIONCLOSE")(p);
        }
    }
    static ParseTree ACTIONCLOSE(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(PEG.literal!("}"), Spacing), "Pegged.ACTIONCLOSE")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("}"), Spacing), "Pegged.ACTIONCLOSE"), "ACTIONCLOSE")(ParseTree("", false,[], s));
        }
    }
    static string ACTIONCLOSE(GetName g)
    {
        return "Pegged.ACTIONCLOSE";
    }

    static ParseTree SEPARATOR(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(PEG.literal!(","), Spacing), "Pegged.SEPARATOR")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!(","), Spacing), "Pegged.SEPARATOR"), "SEPARATOR")(p);
        }
    }
    static ParseTree SEPARATOR(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(PEG.literal!(","), Spacing), "Pegged.SEPARATOR")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!(","), Spacing), "Pegged.SEPARATOR"), "SEPARATOR")(ParseTree("", false,[], s));
        }
    }
    static string SEPARATOR(GetName g)
    {
        return "Pegged.SEPARATOR";
    }

    static ParseTree ASSIGN(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(PEG.literal!("="), Spacing), "Pegged.ASSIGN")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("="), Spacing), "Pegged.ASSIGN"), "ASSIGN")(p);
        }
    }
    static ParseTree ASSIGN(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(PEG.literal!("="), Spacing), "Pegged.ASSIGN")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("="), Spacing), "Pegged.ASSIGN"), "ASSIGN")(ParseTree("", false,[], s));
        }
    }
    static string ASSIGN(GetName g)
    {
        return "Pegged.ASSIGN";
    }

    static ParseTree NAMESEP(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.literal!("."), "Pegged.NAMESEP")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.literal!("."), "Pegged.NAMESEP"), "NAMESEP")(p);
        }
    }
    static ParseTree NAMESEP(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.literal!("."), "Pegged.NAMESEP")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.literal!("."), "Pegged.NAMESEP"), "NAMESEP")(ParseTree("", false,[], s));
        }
    }
    static string NAMESEP(GetName g)
    {
        return "Pegged.NAMESEP";
    }

    static ParseTree OPEN(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(PEG.literal!("("), Spacing), "Pegged.OPEN")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("("), Spacing), "Pegged.OPEN"), "OPEN")(p);
        }
    }
    static ParseTree OPEN(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(PEG.literal!("("), Spacing), "Pegged.OPEN")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("("), Spacing), "Pegged.OPEN"), "OPEN")(ParseTree("", false,[], s));
        }
    }
    static string OPEN(GetName g)
    {
        return "Pegged.OPEN";
    }

    static ParseTree CLOSE(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(PEG.literal!(")"), Spacing), "Pegged.CLOSE")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!(")"), Spacing), "Pegged.CLOSE"), "CLOSE")(p);
        }
    }
    static ParseTree CLOSE(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(PEG.literal!(")"), Spacing), "Pegged.CLOSE")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!(")"), Spacing), "Pegged.CLOSE"), "CLOSE")(ParseTree("", false,[], s));
        }
    }
    static string CLOSE(GetName g)
    {
        return "Pegged.CLOSE";
    }

    static ParseTree ANY(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(PEG.literal!("."), Spacing), "Pegged.ANY")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("."), Spacing), "Pegged.ANY"), "ANY")(p);
        }
    }
    static ParseTree ANY(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(PEG.literal!("."), Spacing), "Pegged.ANY")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("."), Spacing), "Pegged.ANY"), "ANY")(ParseTree("", false,[], s));
        }
    }
    static string ANY(GetName g)
    {
        return "Pegged.ANY";
    }

    static ParseTree Spacing(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.discard!(PEG.zeroOrMore!(PEG.or!(blank, Comment))), "Pegged.Spacing")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.discard!(PEG.zeroOrMore!(PEG.or!(blank, Comment))), "Pegged.Spacing"), "Spacing")(p);
        }
    }
    static ParseTree Spacing(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.discard!(PEG.zeroOrMore!(PEG.or!(blank, Comment))), "Pegged.Spacing")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.discard!(PEG.zeroOrMore!(PEG.or!(blank, Comment))), "Pegged.Spacing"), "Spacing")(ParseTree("", false,[], s));
        }
    }
    static string Spacing(GetName g)
    {
        return "Pegged.Spacing";
    }

    static ParseTree Comment(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(PEG.literal!("#"), PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(eol), PEG.any)), PEG.discard!(eol)), "Pegged.Comment")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("#"), PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(eol), PEG.any)), PEG.discard!(eol)), "Pegged.Comment"), "Comment")(p);
        }
    }
    static ParseTree Comment(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(PEG.literal!("#"), PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(eol), PEG.any)), PEG.discard!(eol)), "Pegged.Comment")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("#"), PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(eol), PEG.any)), PEG.discard!(eol)), "Pegged.Comment"), "Comment")(ParseTree("", false,[], s));
        }
    }
    static string Comment(GetName g)
    {
        return "Pegged.Comment";
    }

    static ParseTree Space(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.or!(spacing, PEG.literal!("\\t"), PEG.literal!("\\n"), PEG.literal!("\\r")), "Pegged.Space")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.or!(spacing, PEG.literal!("\\t"), PEG.literal!("\\n"), PEG.literal!("\\r")), "Pegged.Space"), "Space")(p);
        }
    }
    static ParseTree Space(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.or!(spacing, PEG.literal!("\\t"), PEG.literal!("\\n"), PEG.literal!("\\r")), "Pegged.Space")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.or!(spacing, PEG.literal!("\\t"), PEG.literal!("\\n"), PEG.literal!("\\r")), "Pegged.Space"), "Space")(ParseTree("", false,[], s));
        }
    }
    static string Space(GetName g)
    {
        return "Pegged.Space";
    }

    static ParseTree Action(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(PEG.discard!(ACTIONOPEN), Spacing, PEG.and!(PEG.or!(Lambda, qualifiedIdentifier), PEG.zeroOrMore!(PEG.and!(PEG.discard!(SEPARATOR), PEG.or!(Lambda, qualifiedIdentifier)))), Spacing, PEG.discard!(ACTIONCLOSE)), "Pegged.Action")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(PEG.discard!(ACTIONOPEN), Spacing, PEG.and!(PEG.or!(Lambda, qualifiedIdentifier), PEG.zeroOrMore!(PEG.and!(PEG.discard!(SEPARATOR), PEG.or!(Lambda, qualifiedIdentifier)))), Spacing, PEG.discard!(ACTIONCLOSE)), "Pegged.Action"), "Action")(p);
        }
    }
    static ParseTree Action(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(PEG.discard!(ACTIONOPEN), Spacing, PEG.and!(PEG.or!(Lambda, qualifiedIdentifier), PEG.zeroOrMore!(PEG.and!(PEG.discard!(SEPARATOR), PEG.or!(Lambda, qualifiedIdentifier)))), Spacing, PEG.discard!(ACTIONCLOSE)), "Pegged.Action")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(PEG.discard!(ACTIONOPEN), Spacing, PEG.and!(PEG.or!(Lambda, qualifiedIdentifier), PEG.zeroOrMore!(PEG.and!(PEG.discard!(SEPARATOR), PEG.or!(Lambda, qualifiedIdentifier)))), Spacing, PEG.discard!(ACTIONCLOSE)), "Pegged.Action"), "Action")(ParseTree("", false,[], s));
        }
    }
    static string Action(GetName g)
    {
        return "Pegged.Action";
    }

    static ParseTree Lambda(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.fuse!(PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(PEG.or!(ACTIONCLOSE, SEPARATOR)), PEG.or!(LambdaItems, NestedList!(PEG.literal!("{"), LambdaItems, PEG.literal!("}")), PEG.any)))), "Pegged.Lambda")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.fuse!(PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(PEG.or!(ACTIONCLOSE, SEPARATOR)), PEG.or!(LambdaItems, NestedList!(PEG.literal!("{"), LambdaItems, PEG.literal!("}")), PEG.any)))), "Pegged.Lambda"), "Lambda")(p);
        }
    }
    static ParseTree Lambda(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.fuse!(PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(PEG.or!(ACTIONCLOSE, SEPARATOR)), PEG.or!(LambdaItems, NestedList!(PEG.literal!("{"), LambdaItems, PEG.literal!("}")), PEG.any)))), "Pegged.Lambda")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.fuse!(PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(PEG.or!(ACTIONCLOSE, SEPARATOR)), PEG.or!(LambdaItems, NestedList!(PEG.literal!("{"), LambdaItems, PEG.literal!("}")), PEG.any)))), "Pegged.Lambda"), "Lambda")(ParseTree("", false,[], s));
        }
    }
    static string Lambda(GetName g)
    {
        return "Pegged.Lambda";
    }

    static ParseTree LambdaItems(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.or!(PEG.fuse!(DComment), PEG.fuse!(DString), PEG.fuse!(DParamList)), "Pegged.LambdaItems")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.or!(PEG.fuse!(DComment), PEG.fuse!(DString), PEG.fuse!(DParamList)), "Pegged.LambdaItems"), "LambdaItems")(p);
        }
    }
    static ParseTree LambdaItems(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.or!(PEG.fuse!(DComment), PEG.fuse!(DString), PEG.fuse!(DParamList)), "Pegged.LambdaItems")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.or!(PEG.fuse!(DComment), PEG.fuse!(DString), PEG.fuse!(DParamList)), "Pegged.LambdaItems"), "LambdaItems")(ParseTree("", false,[], s));
        }
    }
    static string LambdaItems(GetName g)
    {
        return "Pegged.LambdaItems";
    }

    static ParseTree DString(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.or!(WYSString, DBQString, TKNString, DLMString), "Pegged.DString")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.or!(WYSString, DBQString, TKNString, DLMString), "Pegged.DString"), "DString")(p);
        }
    }
    static ParseTree DString(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.or!(WYSString, DBQString, TKNString, DLMString), "Pegged.DString")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.or!(WYSString, DBQString, TKNString, DLMString), "Pegged.DString"), "DString")(ParseTree("", false,[], s));
        }
    }
    static string DString(GetName g)
    {
        return "Pegged.DString";
    }

    static ParseTree WYSString(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.or!(PEG.and!(PEG.literal!("r"), doublequote, PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(doublequote), PEG.any)), doublequote), PEG.and!(backquote, PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(backquote), PEG.any)), backquote)), "Pegged.WYSString")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.or!(PEG.and!(PEG.literal!("r"), doublequote, PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(doublequote), PEG.any)), doublequote), PEG.and!(backquote, PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(backquote), PEG.any)), backquote)), "Pegged.WYSString"), "WYSString")(p);
        }
    }
    static ParseTree WYSString(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.or!(PEG.and!(PEG.literal!("r"), doublequote, PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(doublequote), PEG.any)), doublequote), PEG.and!(backquote, PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(backquote), PEG.any)), backquote)), "Pegged.WYSString")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.or!(PEG.and!(PEG.literal!("r"), doublequote, PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(doublequote), PEG.any)), doublequote), PEG.and!(backquote, PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(backquote), PEG.any)), backquote)), "Pegged.WYSString"), "WYSString")(ParseTree("", false,[], s));
        }
    }
    static string WYSString(GetName g)
    {
        return "Pegged.WYSString";
    }

    static ParseTree DBQString(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(doublequote, PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(doublequote), Char)), doublequote), "Pegged.DBQString")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(doublequote, PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(doublequote), Char)), doublequote), "Pegged.DBQString"), "DBQString")(p);
        }
    }
    static ParseTree DBQString(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(doublequote, PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(doublequote), Char)), doublequote), "Pegged.DBQString")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(doublequote, PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(doublequote), Char)), doublequote), "Pegged.DBQString"), "DBQString")(ParseTree("", false,[], s));
        }
    }
    static string DBQString(GetName g)
    {
        return "Pegged.DBQString";
    }

    static ParseTree TKNString(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(PEG.posLookahead!(PEG.literal!("q{")), PEG.and!(PEG.literal!("q"), NestedList!(PEG.literal!("{"), DString, PEG.literal!("}")))), "Pegged.TKNString")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(PEG.posLookahead!(PEG.literal!("q{")), PEG.and!(PEG.literal!("q"), NestedList!(PEG.literal!("{"), DString, PEG.literal!("}")))), "Pegged.TKNString"), "TKNString")(p);
        }
    }
    static ParseTree TKNString(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(PEG.posLookahead!(PEG.literal!("q{")), PEG.and!(PEG.literal!("q"), NestedList!(PEG.literal!("{"), DString, PEG.literal!("}")))), "Pegged.TKNString")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(PEG.posLookahead!(PEG.literal!("q{")), PEG.and!(PEG.literal!("q"), NestedList!(PEG.literal!("{"), DString, PEG.literal!("}")))), "Pegged.TKNString"), "TKNString")(ParseTree("", false,[], s));
        }
    }
    static string TKNString(GetName g)
    {
        return "Pegged.TKNString";
    }

    static ParseTree DLMString(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(PEG.and!(PEG.literal!("q"), doublequote), PEG.or!(PEG.and!(PEG.posLookahead!(PEG.literal!("{")), NestedList!(PEG.literal!("{"), DString, PEG.literal!("}"))), PEG.and!(PEG.posLookahead!(PEG.literal!("[")), NestedList!(PEG.literal!("["), DString, PEG.literal!("]"))), PEG.and!(PEG.posLookahead!(PEG.literal!("(")), NestedList!(PEG.literal!("("), DString, PEG.literal!(")"))), PEG.and!(PEG.posLookahead!(PEG.literal!("<")), NestedList!(PEG.literal!("<"), DString, PEG.literal!(">")))), doublequote), "Pegged.DLMString")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(PEG.and!(PEG.literal!("q"), doublequote), PEG.or!(PEG.and!(PEG.posLookahead!(PEG.literal!("{")), NestedList!(PEG.literal!("{"), DString, PEG.literal!("}"))), PEG.and!(PEG.posLookahead!(PEG.literal!("[")), NestedList!(PEG.literal!("["), DString, PEG.literal!("]"))), PEG.and!(PEG.posLookahead!(PEG.literal!("(")), NestedList!(PEG.literal!("("), DString, PEG.literal!(")"))), PEG.and!(PEG.posLookahead!(PEG.literal!("<")), NestedList!(PEG.literal!("<"), DString, PEG.literal!(">")))), doublequote), "Pegged.DLMString"), "DLMString")(p);
        }
    }
    static ParseTree DLMString(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(PEG.and!(PEG.literal!("q"), doublequote), PEG.or!(PEG.and!(PEG.posLookahead!(PEG.literal!("{")), NestedList!(PEG.literal!("{"), DString, PEG.literal!("}"))), PEG.and!(PEG.posLookahead!(PEG.literal!("[")), NestedList!(PEG.literal!("["), DString, PEG.literal!("]"))), PEG.and!(PEG.posLookahead!(PEG.literal!("(")), NestedList!(PEG.literal!("("), DString, PEG.literal!(")"))), PEG.and!(PEG.posLookahead!(PEG.literal!("<")), NestedList!(PEG.literal!("<"), DString, PEG.literal!(">")))), doublequote), "Pegged.DLMString")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(PEG.and!(PEG.literal!("q"), doublequote), PEG.or!(PEG.and!(PEG.posLookahead!(PEG.literal!("{")), NestedList!(PEG.literal!("{"), DString, PEG.literal!("}"))), PEG.and!(PEG.posLookahead!(PEG.literal!("[")), NestedList!(PEG.literal!("["), DString, PEG.literal!("]"))), PEG.and!(PEG.posLookahead!(PEG.literal!("(")), NestedList!(PEG.literal!("("), DString, PEG.literal!(")"))), PEG.and!(PEG.posLookahead!(PEG.literal!("<")), NestedList!(PEG.literal!("<"), DString, PEG.literal!(">")))), doublequote), "Pegged.DLMString"), "DLMString")(ParseTree("", false,[], s));
        }
    }
    static string DLMString(GetName g)
    {
        return "Pegged.DLMString";
    }

    static ParseTree DComment(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.or!(DLineComment, DBlockComment, DNestingBlockComment), "Pegged.DComment")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.or!(DLineComment, DBlockComment, DNestingBlockComment), "Pegged.DComment"), "DComment")(p);
        }
    }
    static ParseTree DComment(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.or!(DLineComment, DBlockComment, DNestingBlockComment), "Pegged.DComment")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.or!(DLineComment, DBlockComment, DNestingBlockComment), "Pegged.DComment"), "DComment")(ParseTree("", false,[], s));
        }
    }
    static string DComment(GetName g)
    {
        return "Pegged.DComment";
    }

    static ParseTree DLineComment(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(PEG.literal!("//"), PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(endOfLine), PEG.any)), endOfLine), "Pegged.DLineComment")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("//"), PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(endOfLine), PEG.any)), endOfLine), "Pegged.DLineComment"), "DLineComment")(p);
        }
    }
    static ParseTree DLineComment(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(PEG.literal!("//"), PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(endOfLine), PEG.any)), endOfLine), "Pegged.DLineComment")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("//"), PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(endOfLine), PEG.any)), endOfLine), "Pegged.DLineComment"), "DLineComment")(ParseTree("", false,[], s));
        }
    }
    static string DLineComment(GetName g)
    {
        return "Pegged.DLineComment";
    }

    static ParseTree DBlockComment(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(PEG.literal!("/*"), PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(PEG.literal!("*/")), PEG.any)), PEG.literal!("*/")), "Pegged.DBlockComment")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("/*"), PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(PEG.literal!("*/")), PEG.any)), PEG.literal!("*/")), "Pegged.DBlockComment"), "DBlockComment")(p);
        }
    }
    static ParseTree DBlockComment(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(PEG.literal!("/*"), PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(PEG.literal!("*/")), PEG.any)), PEG.literal!("*/")), "Pegged.DBlockComment")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(PEG.literal!("/*"), PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(PEG.literal!("*/")), PEG.any)), PEG.literal!("*/")), "Pegged.DBlockComment"), "DBlockComment")(ParseTree("", false,[], s));
        }
    }
    static string DBlockComment(GetName g)
    {
        return "Pegged.DBlockComment";
    }

    static ParseTree DNestingBlockComment(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(NestedList!(PEG.literal!("/+"), PEG.literal!("+/")), "Pegged.DNestingBlockComment")(p);
        }
        else
        {
            return hooked!(PEG.defined!(NestedList!(PEG.literal!("/+"), PEG.literal!("+/")), "Pegged.DNestingBlockComment"), "DNestingBlockComment")(p);
        }
    }
    static ParseTree DNestingBlockComment(string s)
    {
        if(__ctfe)
            return         PEG.defined!(NestedList!(PEG.literal!("/+"), PEG.literal!("+/")), "Pegged.DNestingBlockComment")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(NestedList!(PEG.literal!("/+"), PEG.literal!("+/")), "Pegged.DNestingBlockComment"), "DNestingBlockComment")(ParseTree("", false,[], s));
        }
    }
    static string DNestingBlockComment(GetName g)
    {
        return "Pegged.DNestingBlockComment";
    }

    static ParseTree DParamList(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(NestedList!(PEG.literal!("("), PEG.literal!(")")), "Pegged.DParamList")(p);
        }
        else
        {
            return hooked!(PEG.defined!(NestedList!(PEG.literal!("("), PEG.literal!(")")), "Pegged.DParamList"), "DParamList")(p);
        }
    }
    static ParseTree DParamList(string s)
    {
        if(__ctfe)
            return         PEG.defined!(NestedList!(PEG.literal!("("), PEG.literal!(")")), "Pegged.DParamList")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(NestedList!(PEG.literal!("("), PEG.literal!(")")), "Pegged.DParamList"), "DParamList")(ParseTree("", false,[], s));
        }
    }
    static string DParamList(GetName g)
    {
        return "Pegged.DParamList";
    }

    template NestedList(alias L, alias Items, alias R)
    {
    static ParseTree NestedList(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(PEG.keep!(L), PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(PEG.or!(L, R, Items)), PEG.any)), PEG.zeroOrMore!(PEG.or!(Items, NestedList!(L, Items, R), PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(PEG.or!(L, R, Items)), PEG.any)))), PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(PEG.or!(L, R, Items)), PEG.any)), PEG.keep!(R)), "Pegged.NestedList!(" ~ pegged.peg.getName!(L)() ~ ", " ~ pegged.peg.getName!(Items)() ~ ", " ~ pegged.peg.getName!(R) ~ ")")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(PEG.keep!(L), PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(PEG.or!(L, R, Items)), PEG.any)), PEG.zeroOrMore!(PEG.or!(Items, NestedList!(L, Items, R), PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(PEG.or!(L, R, Items)), PEG.any)))), PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(PEG.or!(L, R, Items)), PEG.any)), PEG.keep!(R)), "Pegged.NestedList!(" ~ pegged.peg.getName!(L)() ~ ", " ~ pegged.peg.getName!(Items)() ~ ", " ~ pegged.peg.getName!(R) ~ ")"), "NestedList_3")(p);
        }
    }
    static ParseTree NestedList(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(PEG.keep!(L), PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(PEG.or!(L, R, Items)), PEG.any)), PEG.zeroOrMore!(PEG.or!(Items, NestedList!(L, Items, R), PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(PEG.or!(L, R, Items)), PEG.any)))), PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(PEG.or!(L, R, Items)), PEG.any)), PEG.keep!(R)), "Pegged.NestedList!(" ~ pegged.peg.getName!(L)() ~ ", " ~ pegged.peg.getName!(Items)() ~ ", " ~ pegged.peg.getName!(R) ~ ")")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(PEG.keep!(L), PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(PEG.or!(L, R, Items)), PEG.any)), PEG.zeroOrMore!(PEG.or!(Items, NestedList!(L, Items, R), PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(PEG.or!(L, R, Items)), PEG.any)))), PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(PEG.or!(L, R, Items)), PEG.any)), PEG.keep!(R)), "Pegged.NestedList!(" ~ pegged.peg.getName!(L)() ~ ", " ~ pegged.peg.getName!(Items)() ~ ", " ~ pegged.peg.getName!(R) ~ ")"), "NestedList_3")(ParseTree("", false,[], s));
        }
    }
    static string NestedList(GetName g)
    {
        return "Pegged.NestedList!(" ~ pegged.peg.getName!(L)() ~ ", " ~ pegged.peg.getName!(Items)() ~ ", " ~ pegged.peg.getName!(R) ~ ")";
    }

    }
    template NestedList(alias L, alias R)
    {
    static ParseTree NestedList(ParseTree p)
    {
        if(__ctfe)
        {
            return         PEG.defined!(PEG.and!(PEG.keep!(L), PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(PEG.or!(L, R)), PEG.any)), PEG.zeroOrMore!(PEG.or!(NestedList!(L, R), PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(PEG.or!(L, R)), PEG.any)))), PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(PEG.or!(L, R)), PEG.any)), PEG.keep!(R)), "Pegged.NestedList!(" ~ pegged.peg.getName!(L)() ~ ", " ~ pegged.peg.getName!(R) ~ ")")(p);
        }
        else
        {
            return hooked!(PEG.defined!(PEG.and!(PEG.keep!(L), PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(PEG.or!(L, R)), PEG.any)), PEG.zeroOrMore!(PEG.or!(NestedList!(L, R), PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(PEG.or!(L, R)), PEG.any)))), PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(PEG.or!(L, R)), PEG.any)), PEG.keep!(R)), "Pegged.NestedList!(" ~ pegged.peg.getName!(L)() ~ ", " ~ pegged.peg.getName!(R) ~ ")"), "NestedList_2")(p);
        }
    }
    static ParseTree NestedList(string s)
    {
        if(__ctfe)
            return         PEG.defined!(PEG.and!(PEG.keep!(L), PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(PEG.or!(L, R)), PEG.any)), PEG.zeroOrMore!(PEG.or!(NestedList!(L, R), PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(PEG.or!(L, R)), PEG.any)))), PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(PEG.or!(L, R)), PEG.any)), PEG.keep!(R)), "Pegged.NestedList!(" ~ pegged.peg.getName!(L)() ~ ", " ~ pegged.peg.getName!(R) ~ ")")(ParseTree("", false,[], s));
        else
        {
            forgetMemo();
            return hooked!(PEG.defined!(PEG.and!(PEG.keep!(L), PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(PEG.or!(L, R)), PEG.any)), PEG.zeroOrMore!(PEG.or!(NestedList!(L, R), PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(PEG.or!(L, R)), PEG.any)))), PEG.zeroOrMore!(PEG.and!(PEG.negLookahead!(PEG.or!(L, R)), PEG.any)), PEG.keep!(R)), "Pegged.NestedList!(" ~ pegged.peg.getName!(L)() ~ ", " ~ pegged.peg.getName!(R) ~ ")"), "NestedList_2")(ParseTree("", false,[], s));
        }
    }
    static string NestedList(GetName g)
    {
        return "Pegged.NestedList!(" ~ pegged.peg.getName!(L)() ~ ", " ~ pegged.peg.getName!(R) ~ ")";
    }

    }
    static ParseTree opCall(ParseTree p)
    {
        ParseTree result = decimateTree(Grammar(p));
        result.children = [result];
        result.name = "Pegged";
        return result;
    }

    static ParseTree opCall(string input)
    {
        forgetMemo();
        return Pegged(ParseTree(``, false, [], input, 0, 0));
    }
    static string opCall(GetName g)
    {
        return "Pegged";
    }


    static void forgetMemo()
    {
    }
    }
}

alias GenericPegged!(DefaultParseTree).Pegged Pegged;

