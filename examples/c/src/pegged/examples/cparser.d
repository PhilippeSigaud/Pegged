module pegged.examples.cparser;

import pegged.grammar;

@safe struct C
{
    enum names = [`TranslationUnit`:true, `ExternalDeclaration`:true, `FunctionDefinition`:true, `PrimaryExpression`:true,
    `PostfixExpression`:true, `ArgumentExpressionList`:true, `UnaryExpression`:true, `IncrementExpression`:true, `PlusPlus`:true,
    `DecrementExpression`:true, `UnaryOperator`:true, `CastExpression`:true, `MultiplicativeExpression`:true, `AdditiveExpression`:true,
    `ShiftExpression`:true, `RelationalExpression`:true, `EqualityExpression`:true, `ANDExpression`:true, `ExclusiveORExpression`:true,
    `InclusiveORExpression`:true, `LogicalANDExpression`:true, `LogicalORExpression`:true, `ConditionalExpression`:true, `AssignmentExpression`:true,
    `AssignmentOperator`:true, `Expression`:true, `ConstantExpression`:true, `Declaration`:true, `DeclarationSpecifiers`:true, `InitDeclaratorList`:true,
    `InitDeclarator`:true, `StorageClassSpecifier`:true, `TypeSpecifier`:true, `StructOrUnionSpecifier`:true, `StructDeclarationList`:true,
    `StructDeclaration`:true, `SpecifierQualifierList`:true, `StructDeclaratorList`:true, `StructDeclarator`:true, `EnumSpecifier`:true,
    `EnumeratorList`:true, `Enumerator`:true, `EnumerationConstant`:true, `TypeQualifier`:true, `Declarator`:true, `DirectDeclarator`:true,
    `Pointer`:true, `TypeQualifierList`:true, `ParameterTypeList`:true, `ParameterList`:true, `ParameterDeclaration`:true, `IdentifierList`:true,
    `TypeName`:true, `AbstractDeclarator`:true, `DirectAbstractDeclarator`:true, `TypedefName`:true, `Initializer`:true, `InitializerList`:true,
    `Statement`:true, `LabeledStatement`:true, `CompoundStatement`:true, `DeclarationList`:true, `StatementList`:true, `ExpressionStatement`:true,
    `IfStatement`:true, `SwitchStatement`:true, `IterationStatement`:true, `WhileStatement`:true, `DoStatement`:true, `ForStatement`:true,
    `GotoStatement`:true, `ContinueStatement`:true, `BreakStatement`:true, `ReturnStatement`:true, `Return`:true, `Identifier`:true,
    `Keyword`:true, `Spacing`:true, `Comment`:true, `StringLiteral`:true, `DQChar`:true, `EscapeSequence`:true, `CharLiteral`:true, `IntegerLiteral`:true,
    `Integer`:true, `IntegerSuffix`:true, `FloatLiteral`:true, `Sign`:true];

    import pegged.defaultparsetree : ParseTree = DefaultParseTree;
    mixin decimateTree!ParseTree;
    mixin DefaultPatters!ParseTree;

    static ParseTree TranslationUnit(ParseTree p)
    {
        return named!(and!(ExternalDeclaration, zeroOrMore!(and!(discard!(Spacing), ExternalDeclaration))), "TranslationUnit")(p);
    }

    static ParseTree ExternalDeclaration(ParseTree p)
    {
        return named!(or!(spaceAnd!(Spacing, FunctionDefinition), spaceAnd!(Spacing, Declaration)), "ExternalDeclaration")(p);
    }

    static ParseTree FunctionDefinition(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, option!(DeclarationSpecifiers), Declarator, option!(DeclarationList), CompoundStatement), "FunctionDefinition")(p);
    }

    static ParseTree PrimaryExpression(ParseTree p)
    {
        return named!(or!(spaceAnd!(Spacing, Identifier), spaceAnd!(Spacing, CharLiteral), spaceAnd!(Spacing, StringLiteral), spaceAnd!(Spacing, FloatLiteral), spaceAnd!(Spacing, IntegerLiteral), spaceAnd!(Spacing, literal!("("), Expression, literal!(")"))), "PrimaryExpression")(p);
    }

    static ParseTree PostfixExpression(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, PrimaryExpression, zeroOrMore!(or!(spaceAnd!(Spacing, literal!("["), Expression, literal!("]")), spaceAnd!(Spacing, literal!("("), literal!(")")), spaceAnd!(Spacing, literal!("("), ArgumentExpressionList, literal!(")")), spaceAnd!(Spacing, literal!("."), Identifier), spaceAnd!(Spacing, literal!("->"), Identifier), spaceAnd!(Spacing, literal!("++")), spaceAnd!(Spacing, literal!("--"))))), "PostfixExpression")(p);
    }

    static ParseTree ArgumentExpressionList(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, AssignmentExpression, zeroOrMore!(spaceAnd!(Spacing, literal!(","), AssignmentExpression))), "ArgumentExpressionList")(p);
    }

    static ParseTree UnaryExpression(ParseTree p)
    {
        return named!(or!(spaceAnd!(Spacing, PostfixExpression), spaceAnd!(Spacing, IncrementExpression), spaceAnd!(Spacing, DecrementExpression), spaceAnd!(Spacing, UnaryOperator, CastExpression), spaceAnd!(Spacing, literal!("sizeof"), UnaryExpression), spaceAnd!(Spacing, literal!("sizeof"), literal!("("), TypeName, literal!(")"))), "UnaryExpression")(p);
    }

    static ParseTree IncrementExpression(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, PlusPlus, UnaryExpression), "IncrementExpression")(p);
    }

    static ParseTree PlusPlus(ParseTree p)
    {
        return named!(and!(literal!("++")), "PlusPlus")(p);
    }

    static ParseTree DecrementExpression(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, literal!("--"), UnaryExpression), "DecrementExpression")(p);
    }

    static ParseTree UnaryOperator(ParseTree p)
    {
        return named!(and!(or!(literal!("-"), literal!("&"), literal!("*"), literal!("+"), literal!("~"), literal!("!"))), "UnaryOperator")(p);
    }

    static ParseTree CastExpression(ParseTree p)
    {
        return named!(or!(spaceAnd!(Spacing, UnaryExpression), spaceAnd!(Spacing, literal!("("), TypeName, literal!(")"), CastExpression)), "CastExpression")(p);
    }

    static ParseTree MultiplicativeExpression(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, CastExpression, zeroOrMore!(spaceAnd!(Spacing, or!(literal!("*"), literal!("%"), literal!("/")), MultiplicativeExpression))), "MultiplicativeExpression")(p);
    }

    static ParseTree AdditiveExpression(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, MultiplicativeExpression, zeroOrMore!(spaceAnd!(Spacing, or!(literal!("-"), literal!("+")), AdditiveExpression))), "AdditiveExpression")(p);
    }

    static ParseTree ShiftExpression(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, AdditiveExpression, zeroOrMore!(spaceAnd!(Spacing, or!(spaceAnd!(Spacing, literal!("<<")), spaceAnd!(Spacing, literal!(">>"))), ShiftExpression))), "ShiftExpression")(p);
    }

    static ParseTree RelationalExpression(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, ShiftExpression, zeroOrMore!(spaceAnd!(Spacing, or!(spaceAnd!(Spacing, literal!("<=")), spaceAnd!(Spacing, literal!(">=")), spaceAnd!(Spacing, literal!("<")), spaceAnd!(Spacing, literal!(">"))), RelationalExpression))), "RelationalExpression")(p);
    }

    static ParseTree EqualityExpression(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, RelationalExpression, zeroOrMore!(spaceAnd!(Spacing, or!(spaceAnd!(Spacing, literal!("==")), spaceAnd!(Spacing, literal!("!="))), EqualityExpression))), "EqualityExpression")(p);
    }

    static ParseTree ANDExpression(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, EqualityExpression, zeroOrMore!(spaceAnd!(Spacing, literal!("&"), ANDExpression))), "ANDExpression")(p);
    }

    static ParseTree ExclusiveORExpression(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, ANDExpression, zeroOrMore!(spaceAnd!(Spacing, literal!("^"), ExclusiveORExpression))), "ExclusiveORExpression")(p);
    }

    static ParseTree InclusiveORExpression(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, ExclusiveORExpression, zeroOrMore!(spaceAnd!(Spacing, literal!("|"), InclusiveORExpression))), "InclusiveORExpression")(p);
    }

    static ParseTree LogicalANDExpression(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, InclusiveORExpression, zeroOrMore!(spaceAnd!(Spacing, literal!("&&"), LogicalANDExpression))), "LogicalANDExpression")(p);
    }

    static ParseTree LogicalORExpression(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, LogicalANDExpression, zeroOrMore!(spaceAnd!(Spacing, literal!("||"), LogicalORExpression))), "LogicalORExpression")(p);
    }

    static ParseTree ConditionalExpression(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, LogicalORExpression, option!(spaceAnd!(Spacing, literal!("?"), Expression, literal!(":"), ConditionalExpression))), "ConditionalExpression")(p);
    }

    static ParseTree AssignmentExpression(ParseTree p)
    {
        return named!(or!(spaceAnd!(Spacing, UnaryExpression, AssignmentOperator, AssignmentExpression), spaceAnd!(Spacing, ConditionalExpression)), "AssignmentExpression")(p);
    }

    static ParseTree AssignmentOperator(ParseTree p)
    {
        return named!(or!(and!(literal!("=")), and!(literal!("*=")), and!(literal!("/=")), and!(literal!("%=")), and!(literal!("+=")), and!(literal!("-=")), and!(literal!("<<=")), and!(literal!(">>=")), and!(literal!("&=")), and!(literal!("^=")), and!(literal!("|="))), "AssignmentOperator")(p);
    }

    static ParseTree Expression(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, AssignmentExpression, zeroOrMore!(spaceAnd!(Spacing, literal!(","), AssignmentExpression))), "Expression")(p);
    }

    static ParseTree ConstantExpression(ParseTree p)
    {
        return named!(and!(ConditionalExpression), "ConstantExpression")(p);
    }

    static ParseTree Declaration(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, DeclarationSpecifiers, option!(InitDeclaratorList), literal!(";")), "Declaration")(p);
    }

    static ParseTree DeclarationSpecifiers(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, or!(spaceAnd!(Spacing, StorageClassSpecifier), spaceAnd!(Spacing, TypeSpecifier), spaceAnd!(Spacing, TypeQualifier)), option!(DeclarationSpecifiers)), "DeclarationSpecifiers")(p);
    }

    static ParseTree InitDeclaratorList(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, InitDeclarator, zeroOrMore!(spaceAnd!(Spacing, literal!(","), InitDeclarator))), "InitDeclaratorList")(p);
    }

    static ParseTree InitDeclarator(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, Declarator, option!(spaceAnd!(Spacing, literal!("="), Initializer))), "InitDeclarator")(p);
    }

    static ParseTree StorageClassSpecifier(ParseTree p)
    {
        return named!(or!(and!(literal!("typedef")), and!(literal!("extern")), and!(literal!("static")), and!(literal!("auto")), and!(literal!("register"))), "StorageClassSpecifier")(p);
    }

    static ParseTree TypeSpecifier(ParseTree p)
    {
        return named!(or!(and!(literal!("void")), and!(literal!("char")), and!(literal!("short")), and!(literal!("int")), and!(literal!("long")), and!(literal!("float")), and!(literal!("double")), and!(literal!("signed")), and!(literal!("unsigned")), and!(StructOrUnionSpecifier), and!(EnumSpecifier)), "TypeSpecifier")(p);
    }

    static ParseTree StructOrUnionSpecifier(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, or!(spaceAnd!(Spacing, literal!("struct")), spaceAnd!(Spacing, literal!("union"))), or!(spaceAnd!(Spacing, Identifier, option!(spaceAnd!(Spacing, literal!("{"), StructDeclarationList, literal!("}")))), spaceAnd!(Spacing, literal!("{"), StructDeclarationList, literal!("}")))), "StructOrUnionSpecifier")(p);
    }

    static ParseTree StructDeclarationList(ParseTree p)
    {
        return named!(and!(StructDeclaration, zeroOrMore!(and!(discard!(Spacing), StructDeclaration))), "StructDeclarationList")(p);
    }

    static ParseTree StructDeclaration(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, SpecifierQualifierList, StructDeclaratorList, literal!(";")), "StructDeclaration")(p);
    }

    static ParseTree SpecifierQualifierList(ParseTree p)
    {
        return named!(and!(or!(and!(TypeQualifier), and!(TypeSpecifier)), zeroOrMore!(and!(discard!(Spacing), or!(and!(TypeQualifier), and!(TypeSpecifier))))), "SpecifierQualifierList")(p);
    }

    static ParseTree StructDeclaratorList(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, StructDeclarator, zeroOrMore!(spaceAnd!(Spacing, literal!(","), StructDeclarator))), "StructDeclaratorList")(p);
    }

    static ParseTree StructDeclarator(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, or!(spaceAnd!(Spacing, Declarator, option!(ConstantExpression)), spaceAnd!(Spacing, ConstantExpression))), "StructDeclarator")(p);
    }

    static ParseTree EnumSpecifier(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, literal!("enum"), or!(spaceAnd!(Spacing, Identifier, option!(spaceAnd!(Spacing, literal!("{"), EnumeratorList, literal!("}")))), spaceAnd!(Spacing, literal!("{"), EnumeratorList, literal!("}")))), "EnumSpecifier")(p);
    }

    static ParseTree EnumeratorList(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, Enumerator, zeroOrMore!(spaceAnd!(Spacing, literal!(","), Enumerator))), "EnumeratorList")(p);
    }

    static ParseTree Enumerator(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, EnumerationConstant, option!(spaceAnd!(Spacing, literal!("="), ConstantExpression))), "Enumerator")(p);
    }

    static ParseTree EnumerationConstant(ParseTree p)
    {
        return named!(and!(Identifier), "EnumerationConstant")(p);
    }

    static ParseTree TypeQualifier(ParseTree p)
    {
        return named!(or!(and!(literal!("const")), and!(literal!("volatile"))), "TypeQualifier")(p);
    }

    static ParseTree Declarator(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, option!(Pointer), DirectDeclarator), "Declarator")(p);
    }

    static ParseTree DirectDeclarator(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, or!(spaceAnd!(Spacing, Identifier), spaceAnd!(Spacing, literal!("("), Declarator, literal!(")"))), zeroOrMore!(or!(spaceAnd!(Spacing, literal!("["), literal!("]")), spaceAnd!(Spacing, literal!("["), ConstantExpression, literal!("]")), spaceAnd!(Spacing, literal!("("), literal!(")")), spaceAnd!(Spacing, literal!("("), ParameterTypeList, literal!(")")), spaceAnd!(Spacing, literal!("("), IdentifierList, literal!(")"))))), "DirectDeclarator")(p);
    }

    static ParseTree Pointer(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, zeroOrMore!(spaceAnd!(Spacing, literal!("*"), zeroOrMore!(TypeQualifier)))), "Pointer")(p);
    }

    static ParseTree TypeQualifierList(ParseTree p)
    {
        return named!(and!(TypeQualifier, zeroOrMore!(and!(discard!(Spacing), TypeQualifier))), "TypeQualifierList")(p);
    }

    static ParseTree ParameterTypeList(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, ParameterList, option!(spaceAnd!(Spacing, literal!(","), literal!("...")))), "ParameterTypeList")(p);
    }

    static ParseTree ParameterList(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, ParameterDeclaration, zeroOrMore!(spaceAnd!(Spacing, literal!(","), ParameterDeclaration))), "ParameterList")(p);
    }

    static ParseTree ParameterDeclaration(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, DeclarationSpecifiers, option!(or!(spaceAnd!(Spacing, Declarator), spaceAnd!(Spacing, AbstractDeclarator)))), "ParameterDeclaration")(p);
    }

    static ParseTree IdentifierList(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, Identifier, zeroOrMore!(spaceAnd!(Spacing, literal!(","), Identifier))), "IdentifierList")(p);
    }

    static ParseTree TypeName(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, SpecifierQualifierList, option!(AbstractDeclarator)), "TypeName")(p);
    }

    static ParseTree AbstractDeclarator(ParseTree p)
    {
        return named!(or!(spaceAnd!(Spacing, Pointer, DirectAbstractDeclarator), spaceAnd!(Spacing, DirectAbstractDeclarator), spaceAnd!(Spacing, Pointer)), "AbstractDeclarator")(p);
    }

    static ParseTree DirectAbstractDeclarator(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, or!(spaceAnd!(Spacing, literal!("("), AbstractDeclarator, literal!(")")), spaceAnd!(Spacing, literal!("["), literal!("]")), spaceAnd!(Spacing, literal!("["), ConstantExpression, literal!("]")), spaceAnd!(Spacing, literal!("("), literal!(")")), spaceAnd!(Spacing, literal!("("), ParameterTypeList, literal!(")"))), zeroOrMore!(or!(spaceAnd!(Spacing, literal!("["), literal!("]")), spaceAnd!(Spacing, literal!("["), ConstantExpression, literal!("]")), spaceAnd!(Spacing, literal!("("), literal!(")")), spaceAnd!(Spacing, literal!("("), ParameterTypeList, literal!(")"))))), "DirectAbstractDeclarator")(p);
    }

    static ParseTree TypedefName(ParseTree p)
    {
        return named!(and!(Identifier), "TypedefName")(p);
    }

    static ParseTree Initializer(ParseTree p)
    {
        return named!(or!(spaceAnd!(Spacing, AssignmentExpression), spaceAnd!(Spacing, literal!("{"), InitializerList, option!(literal!(",")), literal!("}"))), "Initializer")(p);
    }

    static ParseTree InitializerList(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, Initializer, zeroOrMore!(spaceAnd!(Spacing, literal!(","), Initializer))), "InitializerList")(p);
    }

    static ParseTree Statement(ParseTree p)
    {
        return named!(or!(spaceAnd!(Spacing, LabeledStatement), spaceAnd!(Spacing, CompoundStatement), spaceAnd!(Spacing, ExpressionStatement), spaceAnd!(Spacing, IfStatement), spaceAnd!(Spacing, SwitchStatement), spaceAnd!(Spacing, IterationStatement), spaceAnd!(Spacing, GotoStatement), spaceAnd!(Spacing, ContinueStatement), spaceAnd!(Spacing, BreakStatement), spaceAnd!(Spacing, ReturnStatement)), "Statement")(p);
    }

    static ParseTree LabeledStatement(ParseTree p)
    {
        return named!(or!(spaceAnd!(Spacing, Identifier, literal!(":"), Statement), spaceAnd!(Spacing, literal!("case"), ConstantExpression, literal!(":"), Statement), spaceAnd!(Spacing, literal!("default"), literal!(":"), Statement)), "LabeledStatement")(p);
    }

    static ParseTree CompoundStatement(ParseTree p)
    {
        return named!(or!(spaceAnd!(Spacing, literal!("{"), literal!("}")), spaceAnd!(Spacing, literal!("{"), DeclarationList, literal!("}")), spaceAnd!(Spacing, literal!("{"), StatementList, literal!("}")), spaceAnd!(Spacing, literal!("{"), DeclarationList, StatementList, literal!("}"))), "CompoundStatement")(p);
    }

    static ParseTree DeclarationList(ParseTree p)
    {
        return named!(and!(Declaration, zeroOrMore!(and!(discard!(Spacing), Declaration))), "DeclarationList")(p);
    }

    static ParseTree StatementList(ParseTree p)
    {
        return named!(and!(Statement, zeroOrMore!(and!(discard!(Spacing), Statement))), "StatementList")(p);
    }

    static ParseTree ExpressionStatement(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, option!(Expression), literal!(";")), "ExpressionStatement")(p);
    }

    static ParseTree IfStatement(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, literal!("if"), literal!("("), Expression, literal!(")"), Statement, option!(spaceAnd!(Spacing, literal!("else"), Statement))), "IfStatement")(p);
    }

    static ParseTree SwitchStatement(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, literal!("switch"), literal!("("), Expression, literal!(")"), Statement), "SwitchStatement")(p);
    }

    static ParseTree IterationStatement(ParseTree p)
    {
        return named!(or!(spaceAnd!(Spacing, WhileStatement), spaceAnd!(Spacing, DoStatement), spaceAnd!(Spacing, ForStatement)), "IterationStatement")(p);
    }

    static ParseTree WhileStatement(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, literal!("while"), literal!("("), Expression, literal!(")"), Statement), "WhileStatement")(p);
    }

    static ParseTree DoStatement(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, literal!("do"), Statement, literal!("while"), literal!("("), Expression, literal!(")"), literal!(";")), "DoStatement")(p);
    }

    static ParseTree ForStatement(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, literal!("for"), literal!("("), option!(Expression), literal!(";"), option!(Expression), literal!(";"), option!(Expression), literal!(")"), Statement), "ForStatement")(p);
    }

    static ParseTree GotoStatement(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, literal!("goto"), Identifier, literal!(";")), "GotoStatement")(p);
    }

    static ParseTree ContinueStatement(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, literal!("continue"), literal!(";")), "ContinueStatement")(p);
    }

    static ParseTree BreakStatement(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, literal!("break"), literal!(";")), "BreakStatement")(p);
    }

    static ParseTree ReturnStatement(ParseTree p)
    {
        return named!(spaceAnd!(Spacing, Return, option!(Expression), discard!(literal!(";"))), "ReturnStatement")(p);
    }

    static ParseTree Return(ParseTree p)
    {
        return named!(and!(literal!("return")), "Return")(p);
    }

    static ParseTree Identifier(ParseTree p)
    {
        return named!(fuse!(and!(negLookahead!(Keyword), or!(charRange!('a', 'z'), charRange!('A', 'Z'), literal!("_")), zeroOrMore!(or!(charRange!('a', 'z'), charRange!('A', 'Z'), charRange!('0', '9'), literal!("_"))))), "Identifier")(p);
    }

    static ParseTree Keyword(ParseTree p)
    {
        return named!(or!(and!(literal!("auto")), and!(literal!("break")), and!(literal!("case")), and!(literal!("char")), and!(literal!("const")), and!(literal!("continue")), and!(literal!("default")), and!(literal!("double")), and!(literal!("do")), and!(literal!("else")), and!(literal!("enum")), and!(literal!("extern")), and!(literal!("float")), and!(literal!("for")), and!(literal!("goto")), and!(literal!("if")), and!(literal!("inline")), and!(literal!("int")), and!(literal!("long")), and!(literal!("register")), and!(literal!("restrict")), and!(literal!("return")), and!(literal!("short")), and!(literal!("signed")), and!(literal!("sizeof")), and!(literal!("static")), and!(literal!("struct")), and!(literal!("switch")), and!(literal!("typedef")), and!(literal!("union")), and!(literal!("unsigned")), and!(literal!("void")), and!(literal!("volatile")), and!(literal!("while")), and!(literal!("_Bool")), and!(literal!("_Complex")), and!(literal!("_Imaginary"))), "Keyword")(p);
    }

    static ParseTree Spacing(ParseTree p)
    {
        return named!(fuse!(and!(zeroOrMore!(or!(and!(space), and!(blank), and!(endOfLine), and!(Comment))))), "Spacing")(p);
    }

    static ParseTree Comment(ParseTree p)
    {
        return named!(fuse!(and!(literal!("//"), zeroOrMore!(and!(negLookahead!(endOfLine), fparse.any)), endOfLine)), "Comment")(p);
    }

    static ParseTree StringLiteral(ParseTree p)
    {
        return named!(fuse!(and!(doublequote, zeroOrMore!(and!(DQChar)), doublequote)), "StringLiteral")(p);
    }

    static ParseTree DQChar(ParseTree p)
    {
        return named!(or!(and!(EscapeSequence), and!(negLookahead!(doublequote), fparse.any)), "DQChar")(p);
    }

    static ParseTree EscapeSequence(ParseTree p)
    {
        return named!(fuse!(and!(backslash, or!(and!(quote), and!(doublequote), and!(backslash), and!(or!(literal!("a"), literal!("b"), literal!("f"), literal!("n"), literal!("r"), literal!("t"), literal!("v")))))), "EscapeSequence")(p);
    }

    static ParseTree CharLiteral(ParseTree p)
    {
        return named!(fuse!(and!(quote, and!(negLookahead!(quote), or!(and!(EscapeSequence), and!(fparse.any))), quote)), "CharLiteral")(p);
    }

    static ParseTree IntegerLiteral(ParseTree p)
    {
        return named!(fuse!(and!(option!(Sign), Integer, option!(IntegerSuffix))), "IntegerLiteral")(p);
    }

    static ParseTree Integer(ParseTree p)
    {
        return named!(fuse!(and!(oneOrMore!(digit))), "Integer")(p);
    }

    static ParseTree IntegerSuffix(ParseTree p)
    {
        return named!(or!(and!(literal!("Lu")), and!(literal!("LU")), and!(literal!("uL")), and!(literal!("UL")), and!(literal!("L")), and!(literal!("u")), and!(literal!("U"))), "IntegerSuffix")(p);
    }

    static ParseTree FloatLiteral(ParseTree p)
    {
        return named!(fuse!(and!(option!(Sign), Integer, literal!("."), option!(Integer), option!(and!(or!(and!(literal!("e")), and!(literal!("E"))), option!(Sign), Integer)))), "FloatLiteral")(p);
    }

    static ParseTree Sign(ParseTree p)
    {
        return named!(or!(and!(literal!("-")), and!(literal!("+"))), "Sign")(p);
    }

    static ParseTree opCall(ParseTree p)
    {
        ParseTree result = decimateTree(TranslationUnit(p));
        result.children = [result];
        result.name = "C";
        return result;
    }

    static ParseTree opCall(string input)
    {
        return C(ParseTree(``, false, [], input, 0, 0));
    }
}
