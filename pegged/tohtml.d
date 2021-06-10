module pegged.tohtml;

import std.stdio;
import std.conv, std.string;
import std.algorithm.searching;
import pegged.peg;
import pegged.parsetree : isParseTree;

enum Expand
{
    no, ifMatch, ifNotMatch
}

/**
 * Writes a parse tree to a html file.
 *
 * Params:
 *      e = Defines if the tree is expanded.
 *      Details = Defines the details, as a list of strings, that are expanded
 *          when e is equal to `Expand.ifMatch`, and not expanded when e is equal to
 *          `Expand.ifNotMatch`. When no details are passed, each node is expanded.
 *      p = The ParseTree to represent.
 *      file = The file where to write the tree.
 */
void toHTML(ParseTree, Expand e = Expand.no, Details...)(const ref ParseTree p,
    File file) if (isParseTree!ParseTree)
{
    file.write(`
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Pegged produced parse tree</title>
<style>
code {
    position: relative;
    font-family: monospace;
    white-space: pre;
}
code.failure {
    color: red;
}
/* hide tooltip */
code span {
    display: none;
}
/* show and style tooltip */
code:hover span {
    /* show tooltip */
    display: block;
    /* position relative to container div.tooltip */
    position: absolute;
    top: -1.6em;
    left: -0.6em;
    background: #ffffff;
    padding: 0.5em;
    color: #000000;
    border: 0.1em solid #b7ddf2;
    border-radius: 0.5em;
    white-space: nowrap;
    z-index: 1;
}
details {
    margin-left:25px;
    white-space: nowrap;
}
details.leaf summary::-webkit-details-marker {
    opacity: 0;
}
</style>
</head>
<body>
    `);

    void treeToHTML(const ref ParseTree p)
    {
        file.write("<details");
        static if (e != Expand.no)
        {
            static if (!Details.length)
            {
                file.write(" open");
            }
            else
            {
                static if (e == Expand.ifMatch)
                {
                    foreach(detail; Details)
                        if (indexOf(p.name, detail) > -1L)
                    {
                        file.write(" open");
                        break;
                    }
                }
                else
                {
                    bool w;
                    foreach(detail; Details)
                        if (indexOf(p.name, detail) > -1L)
                    {
                        w = true;
                        break;
                    }
                    if (!w)
                        file.write(" open");
                }
            }
        }

        if (p.children.length == 0)
            file.write(` class="leaf"`);
        file.write("><summary>", p.name, " ", to!string([p.begin, p.end]));

        if (p.children.length == 0 && !p.successful)
        {   // Failure leaf.
            Position pos = position(p);
            auto left = pos.index < 10 ? p.input[0 .. pos.index] : p.input[pos.index-10 .. pos.index];
            auto right = pos.index + 10 < p.input.length ? p.input[pos.index .. pos.index + 10] : p.input[pos.index .. $];
            file.write(" failure at line ", to!string(pos.line), ", col ", to!string(pos.col), ", ");
            if (left.length > 0)
                file.write("after <code>", left.stringified, "</code> ");
            file.write("expected <code>");
            if (p.matches.length > 0)
                file.write(p.matches[$-1].stringified);
            else
                file.write("NO MATCH");
            file.write(`</code>, but got <code class="failure">`, right.stringified, "</code>\n");
        }
        else
        {
            file.write(" <code");
            if (!p.successful)
                file.write(` class="failure"`);
            auto firstNewLine = p.input[p.begin .. p.end].countUntil('\n');
            auto firstLine = p.input[p.begin .. firstNewLine >= 0 ? p.begin + firstNewLine : p.end];
            if (firstLine.length > 0)
                file.write(">", firstLine, "<span><pre>", p.input[p.begin .. p.end], "</pre></span></code>");
            else // Insert the return-symbol so the mouse has something to hover over.
                file.write(">&#x23ce;<span><pre>&#x23ce;", p.input[p.begin .. p.end], "</pre></span></code>");
        }

        file.write("</summary>\n");
        foreach (child; p.children)
            treeToHTML(child);
        file.write("</details>\n");
    }

    treeToHTML(p);

    file.write(`
</body>
</html>
    `);
}

/**
 * Writes a parse tree to a html file.
 *
 * Params:
 *      e = Defines if the tree is expanded.
 *      Details = Defines the details, as a list of strings, that are expanded
 *          when e is equal to `Expand.yes`, and not exapnded when e is equal to
 *          `Expand.invert`. When no details are passed, each node is expanded.
 *      p = The ParseTree to represent.
 *      filename = The name of file where tree is written.
 */
void toHTML(ParseTree, Expand e = Expand.no, Details...)(const ref ParseTree p,
    string filename) if(isParseTree!ParseTree)
{
    if (filename.endsWith(".html", ".htm") == 0)
        filename ~= ".html";
    toHTML!(ParseTree, e, Details)(p, File(filename, "w"));
}
