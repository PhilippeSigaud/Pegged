/**
Grammar testing module for Pegged.

*/
module pegged.tester.grammartester;

import std.stdio;
import std.array;
import std.ascii : whitespace;
import std.range : retro;
import std.algorithm : max, splitter;
import std.format : format;
import std.string : stripRight, stripLeft, lineSplitter;

import pegged.tester.testerparser;
import pegged.grammar;

@safe class GrammarTester(grammar, string startSymbol)
{
	bool soft = false;

	private Appender!string errorTextStream;
	private int numberTests;
	private int numberErrors;
	private string latestDiff;

	@property int testCount()  { return numberTests; }
	@property int errorCount() { return numberErrors; }
	@property string errorText() { return errorTextStream.data; }
	@property string latestDiffText() { return latestDiff; }

	this()
	{
		reset();
	}

	void reset()
	{
		errorTextStream = appender!string();
		numberTests = 0;
		numberErrors = 0;
	}

	private void consumeResults(string file, size_t lineNo, bool pass, string diffText )
	{
		numberTests++;

		if ( !pass )
		{
			if ( !soft )
			{
				assert(pass, diffText);
			}
			else
			{
				numberErrors++;
				errorTextStream.put("\n");
				errorTextStream.put(        "---------------------------\n");
				errorTextStream.put(format("Assertion failed at %s(%s):\n",file,lineNo));
				errorTextStream.put(diffText);
			}
		}
	}

	private bool runTest(string file, size_t lineNo,
		string textToParse, string desiredTreeRepresentation, bool invert )
	{
		auto treeGot = grammar.decimateTree(mixin("grammar."~startSymbol~"(textToParse)"));
		auto treeChecker = TesterGrammar.decimateTree(TesterGrammar.Root(desiredTreeRepresentation));

		/+writefln("%s",treeGot);
		writefln("");
		writefln("%s",treeChecker);
		writefln("");+/

		if ( !treeGot.successful )
			consumeResults(file, lineNo, false,
				grammar.stringof ~ " failed to parse (left-hand-side).  Details:\n" ~ treeGot.toString());

		if ( !treeChecker.successful )
			consumeResults(file, lineNo, false,
				"Failed to parse test expectation (right-hand-side). Details:\n" ~ treeChecker.toString());

		if ( treeGot.successful && treeChecker.successful )
		{
			auto ctx = getDifferencer(treeGot, treeChecker);
			latestDiff = ctx.diff();

			bool pass;
			if ( invert )
				pass = (ctx.differences != 0);
			else
				pass = (ctx.differences == 0);

			consumeResults(file, lineNo, pass, latestDiff);
			return pass;
		}
		else
			return false;
	}

	bool assertSimilar(string file = __FILE__, size_t lineNo = __LINE__)
		( string textToParse, string desiredTreeRepresentation )
	{
		return runTest(file, lineNo, textToParse, desiredTreeRepresentation, false);
	}

	bool assertDifferent(string file = __FILE__, size_t lineNo = __LINE__)
		( string textToParse, string desiredTreeRepresentation )
	{
		return runTest(file, lineNo, textToParse, desiredTreeRepresentation, true);
	}

	static auto getDifferencer(T,P)( auto ref T treeRoot, auto ref P patternRoot ) @trusted
	{
		Differencer!(T,P) t;
		t.treeRoot = &treeRoot;
		t.patternRoot = &patternRoot;
		return t;
	}
}

@safe private struct Differencer(T,P)
{
	size_t level = 0;
	size_t differences = 0;
	const(T)* treeRoot;
	const(P)* patternRoot;
	size_t max1stColumnWidth = 0;
	Appender!(string[]) leftColumn;
	Appender!(char[])   centerLine;
	Appender!(string[]) rightColumn;

	alias T TParseTree;
	alias P PParseTree;

	private string diff()
	{
		level = 0;
		differences = 0;
		max1stColumnWidth = 0;

		leftColumn  = appender!(string[])();
		centerLine  = appender!(char[])();
		rightColumn = appender!(string[])();

		printColumns("  Nodes Found",'|',"  Nodes Expected");
		printColumns("",             '|',"");

		diffNode(treeRoot,patternRoot);

		string[] lcolumn = leftColumn.data;
		char[]   center  = centerLine.data;
		string[] rcolumn = rightColumn.data;
		auto diffText = appender!string();
		for ( size_t i = 0; i < lcolumn.length; i++ )
			diffText.put(format("\n%-*s  %c  %s", max1stColumnWidth,
				lcolumn[i], center[i], rcolumn[i]).stripRight());
		diffText.put("\n");

		return diffText.data;
	}

	private void diffNode( const(T*) node, const(P*) pattern ) @trusted
	{
		assert(pattern);
		switch ( pattern.name )
		{
		case "TesterGrammar.Root":
			diffNode(node, &pattern.children[0]);
			break;

		case "TesterGrammar.Node":

			lineDiff(node,pattern);

			// These will track which node children we have visited.
			size_t cursor = 0;
			bool[] visited = [];
			if ( node ) visited = new bool[node.children.length];
			foreach ( ref flag; visited ) flag = false;

			// This will handle nodes that we expect to find as
			//   children of this one.  If these nodes don't exist,
			//   then we throw out angry diff lines about them.
			string uniformBranchType = null;
			foreach ( branch; pattern.children )
			{
				// Enforce uniform branch types.
				if ( uniformBranchType == null )
					uniformBranchType = branch.name;
				else if ( branch.name != uniformBranchType )
					throw new Exception(
						"It is forbidden to have both unordered and "~
						"ordered branches from the same node.");

				// Note that we don't dereference the node's children:
				//   the pattern child will be a Branch statement and
				//   it will do the dereference for us.
				diffBranch(node, &branch, visited, cursor);
			}

			// This will handle nodes that the pattern doesn't expect
			//   to find, but that we find anyways.  Anything here
			//   deserves a nice angry diff line about the extra node.
			level++;
			if ( node ) foreach( i, childNode; node.children )
			{
				// TODO: rescanning the visit array this is probably slow.
				if ( visited[i] )
					continue;

				traverseUnexpected(&node.children[i]);
				visited[i] = true;
			}
			level--;

			break;

		default: assert(0, "Unexpected element in pattern: "~pattern.name);
		}
	}

	private void traverseUnexpected( const(T*) node ) @trusted
	{
		assert(node);
		lineDiff(node, null);
		level++;
		foreach( child; node.children )
			traverseUnexpected(&child);
		level--;
	}

	private void diffBranch( const(T*) node, const(P*) pattern, bool[] visited, ref size_t cursor ) @trusted
	{
		assert(pattern);
		switch ( pattern.name )
		{

		case "TesterGrammar.OrderedBranch":

			level++;
			if ( node ) foreach ( patternChild; pattern.children )
			{
				if ( cursor >= node.children.length )
				{
					diffNode(null, &patternChild);
				}
				else
				{
					diffNode(&node.children[cursor], &patternChild);
					visited[cursor] = true;
					cursor++;
				}
			}
			level--;

			break;

		case "TesterGrammar.UnorderedBranch":

			level++;
			if ( node ) foreach ( i, patternChild; pattern.children )
			{
				size_t foundIndex = size_t.max;

				// Cheap hack for now: 0(n^2) scan-in-scan.
				//
				// Ideally the parser will generate hints for locating
				//   submatches:
				//     GrammarName.childLocationHint(
				//       GrammarName.ruleId!(RuleName),
				//       GrammarName.ruleId!(ChildRuleName));
				// Think about it... it should be possible to compile
				//   this into integer table lookups, thus allowing us
				//   to do what a compiler does with an AST: vtable
				//   lookups followed by offset indexing to typed
				//   fields which are sometimes (typed) arrays.
				// At that point things stay nice and dynamic while
				//   being just as performant as oldschool methods.
				//
				foreach ( j, nodeChild; node.children )
				{
					// TODO: rescanning the visit array this is probably slow.
					if ( visited[j] )
						continue;

					if ( checkIdentifierMatch( &nodeChild, &patternChild ) )
					{
						foundIndex = j;
						break;
					}
				}

				if ( foundIndex == size_t.max )
					diffNode(null, &patternChild);
				else
				{
					diffNode(&node.children[foundIndex], &patternChild);
					visited[foundIndex] = true;
				}
			}
			level--;

			break;

		default: assert(0, "Unexpected element in pattern: "~pattern.name);
		}
	}

	private bool checkIdentifierMatch(const(T*) node, const(P*) pattern)
	{
		if ( !node || !pattern )
			return false;

		auto splitNode    = retro(splitter(node.name,'.'));
		auto splitPattern = retro(splitter(pattern.matches[0],'.'));

		while ( true )
		{
			auto nodePathElem = splitNode.front;
			auto patternPathElem = splitPattern.front;
			splitNode.popFront();
			splitPattern.popFront();

			if ( nodePathElem != patternPathElem )
				return false;

			if ( splitNode.empty || splitPattern.empty )
				break;
		}

		return true;
	}

	private void lineDiff(const(T*) node, const(P*) expected)
	{
		if ( !checkIdentifierMatch( node, expected ) )
		{
			differences++;
			printNodes(node, expected, true);
		}
		else
			printNodes(node, expected, false);
	}

	private string getNodeTxt(const(T*) node)
	{
		string nodeTxt = "";
		if ( node )
			nodeTxt = node.name;
		return replicate("  ",level) ~ nodeTxt;
	}

	private string getPatternTxt(const(P*) pattern)
	{

		string patternTxt = "";
		if ( pattern )
			patternTxt = pattern.matches[0];
		return replicate("  ",level) ~ patternTxt;
	}

	private void printNodes(const(T*) node, const(P*) pattern, bool different)
	{
		auto nodeTxt    = getNodeTxt(node);
		auto patternTxt = getPatternTxt(pattern);

		char diffLine = '=';
		if ( !node && pattern )
			diffLine = '>';
		else if ( node && !pattern )
			diffLine = '<';
		else if ( different )
			diffLine = '|';

		printColumns( nodeTxt, diffLine, patternTxt );
	}

	private void printColumns( string ltext, char center, string rtext )
	{
		max1stColumnWidth = max(max1stColumnWidth, ltext.length);
		leftColumn.put(ltext);
		centerLine.put(center);
		rightColumn.put(rtext);
	}
}

@safe unittest
{
	string normalizeStr(string str)
	{
		import std.array : join;
		return cast(string) str.stripLeft.lineSplitter.join('\n');
	}

	auto tester = new GrammarTester!(TesterGrammar, "Root");
	tester.soft = true;

	tester.assertSimilar(`foo`, `Root->Node`);
	tester.assertDifferent(`foo`, `Root`);

	tester.assertSimilar(`foo->bar`, `Root->Node->OrderedBranch->Node`);
	tester.assertDifferent(`foo->bar`, `Root->Node`);

	assert(normalizeStr(tester.latestDiff) ==
normalizeStr(`
  Nodes Found                    |    Nodes Expected
                                 |
TesterGrammar.Root               =  Root
  TesterGrammar.Node             =    Node
    TesterGrammar.OrderedBranch  <
      TesterGrammar.Node         <
`));

	tester.assertSimilar(`foo->{bar}`, `Root->Node->OrderedBranch->Node`);
	tester.assertDifferent(`foo->{bar}`, `Root->Node->UnorderedBranch->Node`);

	tester.assertSimilar(`foo~>{bar}`, `Root->Node->UnorderedBranch->Node`);

	tester.assertSimilar(`foo~>bar`, `Root->Node->UnorderedBranch->Node`);

	tester.assertSimilar(`foo->bar->baz`,
		`Root->Node
			->OrderedBranch->Node
				->OrderedBranch->Node
		`);

	tester.assertSimilar(`foo~>bar~>baz`,
		`Root->Node
			->UnorderedBranch->Node
				->UnorderedBranch->Node
		`);

	tester.assertSimilar(`foo->^bar->baz`,
		`Root->Node->
		{
			OrderedBranch->Node
			OrderedBranch->Node
		}
		`);

	tester.assertSimilar(`foo->{^bar}->baz`,
		`Root->Node->
		{
			OrderedBranch->Node
			OrderedBranch->Node
		}
		`);

	tester.assertSimilar(`foo~>^bar~>baz`,
		`Root->Node->
		{
			UnorderedBranch->Node
			UnorderedBranch->Node
		}
		`);

	tester.assertSimilar(`foo~>{^bar}~>baz`,
		`Root->Node->
		{
			UnorderedBranch->Node
			UnorderedBranch->Node
		}
		`);

	tester.assertSimilar(`
		FOO~>
		{
			Bar->baz
		}
		`,`
		/* FOO */   Root->Node
		/* Bar */       ->UnorderedBranch->Node
		/* baz */           ->OrderedBranch->Node
		`);

	tester.assertSimilar(`
		FOO~>
		{
			x->^y->^z
			u
			v
			Bar->baz
		}
		`,`
		/* FOO */   Root->Node->
		/*     */       UnorderedBranch->
		/*     */       {
		/* x   */           Node~>
		/*     */           {
		/*  y  */               OrderedBranch->Node
		/*   z */               OrderedBranch->Node
		/*     */           }
		/* u   */           Node
		/* v   */           Node
		/* Bar */           Node->OrderedBranch
		/* baz */               ->Node
		/*     */       }
		`);

	tester.assertDifferent(`
		FOO~>
		{
			x->^y->^z
			u
			v
			Bar->baz
		}
		`,`
		/* FOO */   Root->Node->
		/*     */       UnorderedBranch->
		/*     */       {
		/* x   */           Node->OrderedBranch~>
		/*     */           { // There should actually be two ordered branches.
		/*   y */               Node
		/*bug:z*/               Node
		/*bug:z*/               Node
		/*     */           }
		/*     */       }
		`);

	assert(normalizeStr(tester.latestDiff) ==
normalizeStr(`
  Nodes Found                        |    Nodes Expected
                                     |
TesterGrammar.Root                   =  Root
  TesterGrammar.Node                 =    Node
    TesterGrammar.UnorderedBranch    =      UnorderedBranch
      TesterGrammar.Node             =        Node
        TesterGrammar.OrderedBranch  =          OrderedBranch
          TesterGrammar.Node         =            Node
                                     >            Node
                                     >            Node
        TesterGrammar.OrderedBranch  <
          TesterGrammar.Node         <
      TesterGrammar.Node             <
      TesterGrammar.Node             <
      TesterGrammar.Node             <
        TesterGrammar.OrderedBranch  <
          TesterGrammar.Node         <
`));

	assert(tester.testCount > 0);
	assert(tester.errorCount == 0);
	assert(tester.errorText == "");


	tester = new GrammarTester!(TesterGrammar, "Root");
	tester.soft = true;

	tester.assertSimilar(`
		FOO
		{
			x->^y->^z
			u
			v
			Bar->baz
		}
		`,`
		/* FOO */   Root->Node->
		/*     */       UnorderedBranch->
		/*     */       {
		/* x   */           Node->OrderedBranch~>
		/*     */           { // There should actually be two ordered branches.
		/*   y */               Node
		/*not z*/               Node
		/*not z*/               Node
		/*     */           }
		/*     */       }
		`);

	assert(tester.testCount == 1);
	assert(tester.errorCount == 1);
	assert(tester.errorText.length > 0);
}

@safe unittest
{
    mixin(grammar(`
    Arithmetic:
        Term     < Factor (Add / Sub)*
        Add      < "+" Factor
        Sub      < "-" Factor
        Factor   < Primary (Mul / Div)*
        Mul      < "*" Primary
        Div      < "/" Primary
        Primary  < Parens / Neg / Number / Variable
        Parens   < :"(" Term :")"
        Neg      < "-" Primary
        Number   < ~([0-9]+)
        Variable <- identifier
    `));

	auto arithmeticTester = new GrammarTester!(Arithmetic, "Term");

	arithmeticTester.assertSimilar(`1 + 3`,
		`
		Term->
		{
			Factor->Primary->Number
			Add->
				Factor->Primary->Number
		}
		`);

	arithmeticTester.assertSimilar(`1*2 + 3/4`,
		`
		Term->
		{
			Factor->
			{
				Primary->Number
				Mul~>
				Primary->Number
			}
			Add->
			Factor->
			{
				Primary->Number
				Div~>
				Primary->Number
			}
		}
		`);
}

/+ For reference:

+/
