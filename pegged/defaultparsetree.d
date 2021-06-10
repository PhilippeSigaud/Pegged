/**
   This module contaits functions and parameter for ParseTree data element
 */
module pegged.defaultparsetree;

import std.traits : isType, ReturnType, ForeachType, isCallable, Unqual;

private import pegged.peg : ParseCollectionsM;
private import pegged.dynamic.peg : DynamicPeg;
import pegged.parsetree : isParseTree, ParseTreeM;
/**
   The basic parse tree, as used throughout the project.
   You can define your own parse tree node, but respect the basic layout.
   Example:
   struct MyParseTree {
       mixin ParseTreeM;
       ... My own stuff
   }
*/

struct DefaultParseTree {
    mixin ParseTreeM;
    mixin ParseCollectionsM;
    alias DPEG=DynamicPeg!(ParseTree);
//    mixin DynamicParseCollectionsM;

}

//mixin DynmicParseCollectionM!(ParseTree);


static assert(isParseTree!DefaultParseTree);
