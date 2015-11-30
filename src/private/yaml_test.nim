###############################################################################
##                                                                           ##
##                           nim-utils                                       ##
##                                                                           ##
##   (c) Christoph Herzog <chris@theduke.at> 2015                            ##
##                                                                           ##
##   This project is under the MIT license.                                  ##
##   Check LICENSE.txt for details.                                          ##
##                                                                           ##
###############################################################################

from os import nil

import alpha, omega
import values

include ../yaml

var yamlSingleMapping = "str: String"

var yamlTypedMap = """
str: String
strSingleQuote: 'String'
strDoubleQuote: "String"
boolTrue: true
boolFalse: false
numInt: 1
numFloat: 1.1
"""

var yamlInlined = """
sequence: [a, 1, [], [x], [y, 1], {}, {a: A}, {a: A, x: false}]
mapping: {s: str, i: 1, emptySeq: [], oneItemSeq: [1], multiItemSeq: [A, true], emtyMapping: {}, nestedMapping: {a: A}}
"""

var yamlNestedBlock = """
nested:
  s: str
  f: 1.1
  sequence: [1, "a"]
  mapping: {a: A}
"""

var yamlSequenceBlock = """
- A
- 1.1
- [1, false]
- {a: A}
"""

var yamlLiteralString = """
str: |
  A
   B
    C
  
  X
"""

var yamlWithComments = """
# Starting comment

# Another comment
map:
  str: String # Inline comment
  # Block inline comment
  i: 22
str: str
# Final comment.
"""

var yamlMultiDocs = """
---
str: A
id: 1
...
---
str: B
id: 2
...
str: C
id: 3
"""

var yamlAll = """
---
str: string
strSingleQuote: 'string'
strDoubleQuote: "string"
boolTrue: true
boolFalse: false
i: 1
f: 1.1

emptyInlineMapping: {}
oneItemInlineMapping: {str: string}
inlineMapping: {str: string, strSingleQuote: "string", strDoubleQuote: "string", boolTrue: true, boolFalse: false, i: 1, f: 1.1}
inlineMappingNestedSeq: {empty: [], oneItem: [1], multiItem: [string, 'string', "string", true, false, 1, 1.1]}
inlineMappingNestedMap: {empty: {}, oneItem: {str: string}, many: {str: string, strSingleQuote: "string", strDoubleQuote: "string", boolTrue: true, boolFalse: false, i: 1, f: 1.1}}

inlineEmptySeq: []
inlineOneItemSeq: [string]
inlineSequence: [string, 'string', "string", true, false, 1, 1.1]
inlineSeqNestedSeq: [[], [1], [string, 'string', "string", true, false, 1, 1.1]]
inlineSeqNestedMap: [{}, {str: string}, {str: string, strSingleQuote: "string", strDoubleQuote: "string", boolTrue: true, boolFalse: false, i: 1, f: 1.1}]

mapping:
  str: string
  strSingleQuote: 'string'
  strDoubleQuote: "string"
  boolTrue: true
  boolFalse: false
  i: 1
  f: 1.1

  emptyInlineMapping: {}
  oneItemInlineMapping: {str: string}
  inlineMapping: {str: string, strSingleQuote: "string", strDoubleQuote: "string", boolTrue: true, boolFalse: false, i: 1, f: 1.1}
  inlineMappingNestedSeq: {empty: [], oneItem: [1], multiItem: [string, 'string', "string", true, false, 1, 1.1]}
  inlineMappingNestedMap: {empty: {}, oneItem: {str: string}, many: {str: string, strSingleQuote: "string", strDoubleQuote: "string", boolTrue: true, boolFalse: false, i: 1, f: 1.1}}

  inlineEmptySeq: []
  inlineOneItemSeq: [string]
  inlineSequence: [string, 'string', "string", true, false, 1, 1.1]
  inlineSeqNestedSeq: [[], [1], [string, 'string', "string", true, false, 1, 1.1]]
  inlineSeqNestedMap: [{}, {str: string}, {str: string, strSingleQuote: "string", strDoubleQuote: "string", boolTrue: true, boolFalse: false, i: 1, f: 1.1}]

sequence:
  - string
  - 'string'
  - "string"
  - true
  - false
  - 1
  - 1.1
  - []
  - [string]
  - [string, 'string', "string", true, false, 1, 1.1]
  - [[], [1], [string, 'string', "string", true, false, 1, 1.1]]
  - [{}, {str: string}, {str: string, strSingleQuote: "string", strDoubleQuote: "string", boolTrue: true, boolFalse: false, i: 1, f: 1.1}]
  - {}
  - {str: string}
  - {str: string, strSingleQuote: "string", strDoubleQuote: "string", boolTrue: true, boolFalse: false, i: 1, f: 1.1}
  - {empty: [], oneItem: [1], multiItem: [string, 'string', "string", true, false, 1, 1.1]}
  - {empty: {}, oneItem: {str: string}, many: {str: string, strSingleQuote: "string", strDoubleQuote: "string", boolTrue: true, boolFalse: false, i: 1, f: 1.1}}
...
"""

Suite "YamlParser":

  Describe "Lexer":
    discard

  Describe "Parser":

    Describe("String parsing"):

      It "Should parse a single quoted string":
        var p = newParser("' hallo '")
        p.lex()
        p.parseString().should equal toValue(" hallo ")

      It "Should parse a double quoted string":
        var p = newParser("\" hallo \"")
        p.lex()
        p.parseString().should equal toValue(" hallo ")

      It "Should parse a plain string":
        var p = newParser("la li lu")
        p.lex()
        p.parseString().should equal toValue("la li lu")

      It "Should parse a 'null' string":
        var p = newParser("null")
        p.lex()
        p.parseString().kind.should be valNil

      It "Should parse a 'true' string":
        var p = newParser("true")
        p.lex()
        p.parseString().should equal toValue(true)

      It "Should parse a 'false' string":
        var p = newParser("false")
        p.lex()
        p.parseString().should equal toValue(false)

      It "Should parse a float string":
        var p = newParser("11.145")
        p.lex()
        p.parseString().should equal toValue(11.145)

      It "Should parse an integer string":
        var p = newParser("1234")
        p.lex()
        p.parseString().should equal toValue(1234)

      It "Should parse a literal string block":
        var p = newParser("|\n a\n  b\n   c\n x")
        p.lex()
        p.parseLiteralString(0).should equal toValue("a\n b\n  c\nx\n") 

      It "Should parse a folded string block":
        var p = newParser(">\n a\n b\n\n c\n")
        p.lex()
        p.parseFoldedString(0).should equal toValue("a b c\n") 
        

    Describe "Inline sequence parsing":
      It "Should parse an empty inline sequence":
        var p = newParser("[]")
        p.lex()
        var seqVal = newValueSeq()
        p.parseSequence().should equal seqVal

      It "Should parse an inline sequence with one item":
        var p = newParser("[1]")
        p.lex()
        var seqVal = newValueSeq(1)
        p.parseSequence().should equal seqVal

      It "Should parse an inline sequence with multiple items":
        var p = newParser("[a, b, 22, 1.345, false]")
        p.lex()
        var seqVal = newValueSeq("a", "b", 22, 1.345, false)
        p.parseSequence().should equal seqVal

      It "Should parse a nested inline sequence":
        var p = newParser("[a, [1, false], []]")
        p.lex()
        var seqVal = newValueSeq("a", newValueSeq(1, false), newValueSeq())
        p.parseSequence().should equal seqVal

      It "Should parse a complex inline sequence with mappings":
        var p = newParser("[a, 1, [], [x], [y, 1], {}, {a: A}, {a: A, x: false}]")
        p.lex()
        var seqVal = newValueSeq(
          "a",
          1,
          newValueSeq(),
          newValueSeq("x"),
          newValueSeq("y", 1),
          @%(),
          @%(a: "A"),
          @%(a: "A", x: false)
        )
        p.parseSequence().should equal seqVal


    Describe "Inline mapping parsing":
      It "Should parse an empty inline mapping":
        var p = newParser("{}")
        p.lex()
        var map = @%()
        assert p.parseMapping() == map

      It "Should parse an inline mapping with one item":
        var p = newParser("{a: 1}")
        p.lex()
        var map = @%(a: 1)
        assert p.parseMapping() == map

      It "Should parse an inline mapping with multiple items":
        var p = newParser("{s: str, i: 1, f: 1.1, b: true}")
        p.lex()
        var map = @%(
          s: "str",
          i: 1,
          f: 1.1,
          b: true
        )
        assert p.parseMapping() == map

      It "Should parse a nested inline mapping":
        var p = newParser("{a: str, b: {b1: 1, b2: true}, c: {}}")
        p.lex()
        var map = @%(
          a: "str",
          b: @%(b1: 1, b2: true),
          c: @%()
        )
        assert p.parseMapping() == map

    Describe "Yaml parsing":

      It "Should parse simple one-line yaml":
        var data = parseYaml(yamlSingleMapping)
        var map = @%(str: "String")
        assert data == map

      It "Should parse yaml with typed mapping":
        var data = parseYaml(yamlTypedMap)
        var map = @%(
          str: "String",
          strSingleQuote: "String",
          strDoubleQuote: "String",
          boolTrue: true,
          boolFalse: false,
          numInt: 1,
          numFloat: 1.1
        )
        assert data == map

      It "Should parse yaml with inline sequence/mapping":
        var data = parseYaml(yamlInlined)
        var map = @%(
          sequence: newValueSeq(
            "a", 1, 
            newValueSeq(), 
            newValueSeq("x"), 
            newValueSeq("y", 1),
            @%(),
            @%(a: "A"),
            @%(a: "A", x: false)
          ),
          mapping: (
            s: "str",
            i: 1,
            emptySeq: newValueSeq(),
            oneItemSeq: newValueSeq(1),
            multiItemSeq: newValueSeq("A", true),
            emtyMapping: @%(),
            nestedMapping: @%(a: "A")
          )
        )
        assert data == map

      It "Should parse a nested block":
        var data = parseYaml(yamlNestedBlock)
        var map = @%(
          nested: (
            s: "str",
            f: 1.1,
            sequence: newValueSeq(1, "a"),
            mapping: @%(a: "A")
          )
        )

        assert data == map

      It "Should parse a sequence block":
        var data = parseYaml(yamlSequenceBlock)
        data.isSeq().should beTrue()
        data.should equal newValueSeq("A", 1.1, newValueSeq(1, false), @%(a: "A"))

      It "Should parse a flow literal string":
        var data = parseYaml(yamlLiteralString)
        data.should haveKey "str"
        data.str.should equal toValue("A\n B\n  C\nX\n")

      It "Should parse doc with comments":
        var data = parseYaml(yamlWithComments)
        data.should haveLen 2
        #data.len().should equal 2
        #data.str.should equal "str"
        #var map = @%(str: "String", i: 22)
        #assert data.map == map

      It "Should parse multiple documents":
        var data = parseYaml(yamlMultiDocs)
        data.isSeq().should beTrue()
        data.len().should equal 3
        assert data[0] == @%(str: "A", id: 1)
        assert data[1] == @%(str: "B", id: 2)
        assert data[2] == @%(str: "C", id: 3)

      It "Should parse a really complex yaml document":
        var data = parseYaml(yamlAll)

      It "Should parse a yaml file":
        var path = os.joinPath(os.getTempDir(), "nim_yaml_test_1.yaml")
        writeFile(path, yamlTypedMap)

        var data = parseYamlFile(path)
        data.numFloat.should equal 1.1

when isMainModule:
  omega.run() 

