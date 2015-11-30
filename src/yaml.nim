###############################################################################
##                                                                           ##
##                                 nim-yaml                                  ##
##                                                                           ##
##   (c) Christoph Herzog <chris@theduke.at> 2015                            ##
##                                                                           ##
##   This project is under the MIT license.                                  ##
##   Check LICENSE.txt for details.                                          ##
##                                                                           ##
###############################################################################

from strutils import format, contains, repeat, strip

import values

import utils/parser


type YamlParseError = object of Exception
  line: int

proc newYamlParseError(msg: string, line: int): ref YamlParseError =
  result = newException(YamlParseError, msg)
  result.line = line

type 
  YamlIndicator = enum
    yiTag               = '!'
    yiDoubleQuote       = '"'
    yiComment           = '#'
    yiDirective         = '%'
    yiAnchor            = '&'
    yiSingleQuote       = '\''
    yiAlias             = '*'
    yiEntryEnd          = ','
    yiSequenceEntry     = '-'
    yiMapper            = ':'
    yiFolded             = '>'
    yiMappingKey        = '?'
    yiReserverAt        = '@'
    yiSequenceStart     = '['
    yiSequenceEnd       = ']'
    yiReserverdBacktick = '`'
    yiMappingStart      = '{'
    yiLiteral           = '|'
    yiMappingEnd        = '}'

  YamlWordKind = enum
    ywkIndicator
    ywkIndent
    ywkString
    ywkLineEnd
    ywkDocumentStart
    ywkDocumentEnd

  YamlWord = object
    line: int
    case kind*: YamlWordKind  
    of ywkIndicator:
      indicator: YamlIndicator
    of ywkIndent:
      indent: int
    of ywkString:
      str: string
      quoted: bool
    of ywkLineEnd:
      nil
    of ywkDocumentStart:
      nil
    of ywkDocumentEnd:
      nil

  YamlParser = ref object of Parser
    words: seq[YamlWord]

    currentWord: int

const IndicatorChars = {'-', '?', ':', ',', '[', ']', '{', '}', '#', '&', '*', '!', '|', '>', '%', '@', '`'}

proc `==`(i: YamlIndicator, c: char): bool =
  char(i) == c

proc curWord(p: YamlParser): YamlWord = 
  p.words[p.currentWord]

proc hasNextWord(p: YamlParser): bool =
  p.currentWord < p.words.len()

proc wordEndReached(p: YamlParser): bool =
  p.currentWord > high(p.words)

proc nextWord(p: YamlParser): YamlWord=
  p.words[p.currentWord + 1]

proc shiftWord(p: YamlParser): YamlWord =
  result = p.curWord()
  p.currentWord += 1

proc lexWord(p: YamlParser) =
  # Check for indent.
  var lineStart = p.words.len() == 0 or p.words[high(p.words)].kind == ywkLineEnd

  # Check for newline.
  if p.skipNewLine() > 0:
    # if the line is empty, ignore it.
    if lineStart:
      # Empty line, so ignore it and don't add a new lineend.
      discard
    else:
      # Not an empty line, so add line break.
      p.words.add(YamlWord(kind: ywkLineEnd, line: p.line()))
    return

  var count = p.skip(' ')
  if count > 0:
    if lineStart:
      # Check for any tabs coming next, which would be illegal.
      if p.cur() == '\t':
        raise newYamlParseError("Invalid tab indent at beginning of line " & p.line().`$`, p.line())

      if p.continuesWithNewline():
        # Empty line, so ignore it!
        return
      # Something other than newline follows after the indent, so add the indent.
      p.words.add(YamlWord(kind: ywkIndent, indent: count, line: p.line()))
    return
  else:
    # Spaces in the middle of a line, which we can ignore.
    discard

  # Handle tabs.
  if p.cur() == '\t':
    if lineStart:
      # Tab at the beginning of the line, which is illegal.
      raise newYamlParseError("Invalid tab indent at beginning of line " & p.line().`$`, p.line())
    else:
      # Ignore tabs not at the beginning of a line.
      return

  # Check for document start.
  if p.skip("---", mustSkip = false) > 0:
    p.words.add(YamlWord(kind: ywkDocumentStart, line: p.line()))
    return

  # Check for document end.
  if p.skip("...", mustSkip = false) > 0:
    p.words.add(YamlWord(kind: ywkDocumentEnd, line: p.line()))
    return

  # Check for indicators.
  if p.cur() in IndicatorChars:
    p.words.add(YamlWord(
      kind: ywkIndicator, 
      indicator: YamlIndicator(int(p.cur())),
      line: p.line()
    ))
    discard p.shift()
    return

  # Check for Json schema types.

  # Check for quoted strings.
  if p.cur() == '\'':
    # Shift out the first ' char.
    discard p.shift()
    var token = p.parseTokenUntil('\'')
    p.words.add(YamlWord(
      kind: ywkString, 
      str: token, 
      line: p.line(),
      quoted: true
    ))
    # Shift out the ' char.
    discard p.shift()
    return

  if p.cur() == '"':
    # Shift out the first " char.
    discard p.shift()
    var token = p.parseTokenUntil('"')
    p.words.add(YamlWord(
      kind: ywkString, 
      str: token, 
      line: p.line(),
      quoted: true
    ))
    # Shift out the first " char.
    discard p.shift()
    return

  # Parse any unquoted string.
  var token = p.parseTokenUntil({'\r', '\x0A'} + IndicatorChars)
  if token != "":
    p.words.add(YamlWord(kind: ywkString, str: token, line: p.line()))

  #raise newYamlParseError("Invalid yaml syntax at line " & p.line().`$`, p.line())

proc lex(p: YamlParser) =
  while not p.endReached():
    p.lexWord()
  # Lexing is done.
  # Add a final line end, if the file did not end with a newline.
  if p.words.len() > 0 and (p.words[high(p.words)].kind != ywkLineEnd):
    p.words.add(YamlWord(kind: ywkLineEnd, line: p.line())) 

proc parseString(p: YamlParser): ValueRef =
  if p.curWord().kind != ywkString:
    raise newYamlParseError("Expected string", p.curWord().line)
  var w = p.shiftWord()

  # Parse a string into a value.
  # This checks for JSON types bool, int, float, nil.

  if w.quoted:
    # Quoted string, so don't check for json types.
    return toValueRef(w.str)

  var stripped = strutils.strip(w.str)

  # Check for nil, true and false, which are just simple string comparisons.
  if stripped == "null":
    return ValueRef(kind: valNil)
  elif stripped == "true":
    return toValueRef(true)
  elif stripped == "false":
    return toValueRef(false)

  # Check for float.
  if stripped.contains("."):
    try:
      return toValueRef(strutils.parseFloat(stripped))
    except ValueError:
      discard

  # Check for int.
  try:
    return toValueRef(strutils.parseInt(stripped))
  except ValueError:
    discard

  # String is not of any json type, so it must be a plain string.
  return toValueRef(w.str)

# parseExpression forward declaration.
proc parseExpression(p: YamlParser, indent: int): ValueRef

proc parseSequence(p: YamlParser): ValueRef =
  var w = p.shiftWord()
  if w.kind != ywkIndicator or w.indicator != yiSequenceStart:
    raise newYamlParseError("Expected [", p.line)
  if p.curWord().kind == ywkLineEnd:
    raise newYamlParseError("Invalid unclosed sequence at line " & w.line.`$`, w.line)
  if p.curWord().kind == ywkIndicator and p.curWord().indicator == yiSequenceEnd:
    # Empty sequence.
    # No parsing neccessary.
    var s: seq[Value] = @[]
    # Shift out the ].
    discard p.shiftWord()
    return toValueRef(s)
  
  var s = newValueSeq()

  while true:
    var line = p.curWord().line

    # We verified that the line does not end yet and that the sequence does not end, 
    # so an expression must come next.
    s.add(p.parseExpression(-1))


    # Next must come either a , separator or ].
    var w = p.shiftWord()
    if w.kind != ywkIndicator or w.indicator notin {yiEntryEnd, yiSequenceEnd}:
      raise newYamlParseError("Invalid character or line end at line $1: expected ',' or ']'".format(w.line), w.line)
    if w.indicator == yiSequenceEnd:
      # Sequence ended, we are done.
      break
    elif w.indicator == yiEntryEnd:
      # Verify that something follows.
      if p.curWord().kind == ywkLineEnd:
        raise newYamlParseError("Invalid unclosed sequence at line " & w.line.`$`, w.line)

    # Still got items left, so keep parsing.

  return s

proc parseMapping(p: YamlParser): Map =
  var w = p.shiftWord()
  if w.kind != ywkIndicator or w.indicator != yiMappingStart:
    raise newYamlParseError("Expected {", w.line)
  if p.curWord().kind == ywkLineEnd:
    raise newYamlParseError("Invalid unclosed mapping at line " & w.line.`$`, w.line)
  if p.curWord().kind == ywkIndicator and p.curWord().indicator == yiMappingEnd:
    # Empty mapping.
    # No parsing neccessary.
    # Shift out the }.
    discard p.shiftWord()
    return newValueMap()
  
  var map = newValueMap()

  while true:
    var w = p.shiftWord()

    # We verified that the line does not end yet and that the mapping does not end, 
    # so a key-value pair must come next.
    if w.kind != ywkString or p.curWord().kind != ywkIndicator or p.curWord().indicator != yiMapper:
      raise newYamlParseError("Invalid mapping at line $1: expected key/value pair".format(w.line), w.line)

    # Valid mapping follows.
    var key = strutils.strip(w.str)
    # Shift out the : indicator.
    discard p.shiftWord()
    var value = p.parseExpression(-1)

    map[key] = value

    # Next must come either a , separator or }.
    w = p.shiftWord()
    if w.kind != ywkIndicator or w.indicator notin {yiEntryEnd, yiMappingEnd}:
      raise newYamlParseError("Invalid character or line end at line $1: expected ',' or '}'".format(w.line), w.line)
    if w.indicator == yiMappingEnd:
      # Mapping ended, we are done.
      break
    elif w.indicator == yiEntryEnd:
      # Verify that something follows.
      if p.curWord().kind == ywkLineEnd:
        raise newYamlParseError("Invalid unclosed mapping at line " & w.line.`$`, w.line)

    # Still got items left, so keep parsing.

  return map

proc parseLiteralString(p: YamlParser, indent: int): ValueRef =
  var w = p.shiftWord()
  if w.kind != ywkIndicator or w.indicator != yiLiteral:
    raise newYamlParseError("Expected |", w.line)

  # Newline must come next.
  w = p.shiftWord()
  if w.kind != ywkLineEnd:
    raise newYamlParseError("Expected a newline after literal string indicator | at line " & w.line.`$`, w.line)

  if p.curWord().kind != ywkIndent or p.curWord().indent < indent:
    raise newYamlParseError("Literal string started with | must be followed by a (more) indented line (line $1)".format(w.line), w.line)
  var indent = p.curWord().indent

  var str = ""
  while not p.wordEndReached():
    # Each line must start with an indent.
    if p.curWord().kind != ywkIndent or p.curWord().indent < indent:
      # Not indented, or indented less, so stop.
      break

    # Shift the indent.
    var lineIndent = p.shiftWord().indent

    # Leading spaces are preserved.
    str &= " ".repeat(lineIndent - indent)

    var w = p.shiftWord()

    # Folded string consists of only ywkString and ywkLineEnd pairs.
    if w.kind == ywkLineEnd:
      # Newlines are preserved
      str &= "\n"
    else:
      if w.kind != ywkString or p.curWord().kind != ywkLineEnd:
        raise newYamlParseError("Invalid token $1 in line $2 inside literal string, only strings are allowed".format(w.kind.`$`, w.line.`$`), w.line)
      str &= w.str & "\n"      
      # Shift out the newline.
      discard p.shiftWord()

  # We need to keep the last newline for block parser.
  p.currentWord.dec()

  # Strip trailing newlines, and add a final newline.
  return toValueRef(strip(str, leading=false) & "\n")

proc parseFoldedString(p: YamlParser, indent: int): ValueRef =
  var w = p.shiftWord()
  if w.kind != ywkIndicator or w.indicator != yiFolded:
    raise newYamlParseError("Expected >", w.line)

  # Newline must come next.
  w = p.shiftWord()
  if w.kind != ywkLineEnd:
    raise newYamlParseError("Expected a newline after folded string indicator > at line " & w.line.`$`, w.line)

  if p.curWord().kind != ywkIndent or p.curWord().indent < indent:
    raise newYamlParseError("Folded string started with > must be followed by a (more) indented line (at line $1)".format(w.line), w.line)
  var indent = p.curWord().indent

  var str = ""
  while not p.wordEndReached():
    # Each line must start with an indent.
    if p.curWord().kind != ywkIndent or p.curWord().indent < indent:
      # Not indented, or indented less, so stop.
      break

    # Discard the indent.
    discard p.shiftWord()

    var w = p.shiftWord()

    # Folded string consists of only ywkString and ywkLineEnd pairs.
    if w.kind == ywkLineEnd:
      # Newlines are replaced with spaces, unless it's a double newline.
      if str.len() > 0 and str[high(str)] != ' ':
        str &= " "
    else:
      if w.kind != ywkString or p.curWord().kind != ywkLineEnd:
        raise newYamlParseError("Invalid token $1 in line $2 inside folded string, only strings are allowed".format(w.kind.`$`, w.line.`$`), w.line)
      str &= w.str & " "      
      # Shift out the newline.
      discard p.shiftWord()

  # We need to keep the last newline for block parser.
  p.currentWord.dec()

  # Clean the string by stripping leading/trailing spaces and newlines.
  # Add a final newline.
  result = toValueRef(strip(str) & "\n")

proc parseExpression(p: YamlParser, indent: int): ValueRef =
  var w = p.curWord()
  if w.kind == ywkString:
    # String.
    return p.parseString()

  if indent != -1 and w.kind == ywkIndicator:
      if w.indicator == yiFolded:
        return p.parseFoldedString(indent)
      elif w.indicator == yiLiteral:
        return p.parseLiteralString(indent)

  if w.indicator == yiSequenceStart:
    return p.parseSequence()

  if w.indicator == yiMappingStart:
    return p.parseMapping()

  # If code reaches this point, we have something invalid.
  raise newYamlParseError("Invalid token at line $1: expression expected".format(w.line), w.line)

proc parseBlock(p: YamlParser, indent: int = 0): ValueRef =
  var data = newValueMap()
  var seqData: seq[ValueRef]

  while not p.wordEndReached():
    # Parse a line in the block.

    var lineIndent = 0

    var w = p.curWord() # Note: not shifting yet!

    if w.kind != ywkIndent and indent > 0:
      # End of block.
      break

    if w.kind == ywkIndent:
      # Indented line. check if the line is for the current block.
      if w.indent < indent:
        # End of block.
        break
      elif w.indent > indent:
        # Invalid, too large indent.
        raise newYamlParseError("Invalid indendation at line $1: expected $2 spaces".format(w.line, indent), w.line)
      else:
        # Line is indented for the current block, so process it.
        # Need to shift indent now.
        discard p.shiftWord()
    
    w = p.shiftWord()
      
    # Line belonging to the block, so process it.

    # Check for document start.
    if w.kind in {ywkDocumentStart, ywkDocumentEnd}:
      # Check that token is not indented.
      if indent > 0:
        raise newYamlParseError("Invalid --- or ... at line $1: Must not be indented".format(w.line), w.line) 
      # End of document!
      # If a newline follows, shift it out.
      if p.curWord().kind == ywkLineEnd:
        discard p.shiftWord()

      break

    # Check for SEQUENCE block.
    if seqData == nil and w.kind == ywkIndicator and w.indicator == yiSequenceEntry:
      # Start of a sequence!

      # Check that no mappings have been found yet.
      if data.len() > 0:
        raise newYamlParseError("Invalid sequence start '-' at line $1: Can't combine mapping and block sequence".format(w.line), w.line)
      seqData = @[]

    if seqData != nil:
      # Sequence block!

      if w.kind != ywkIndicator or w.indicator != yiSequenceEntry:
        raise newYamlParseError("Invalid token in line $1: expected sequence start '-' but got $2 (currently in sequence block)".format(w.line, w.kind), w.line)

      # Skip the sequenceEntry
      seqData.add(p.parseExpression(-1))

      w = p.shiftWord()
      if w.kind != ywkLineEnd:
        raise newYamlParseError("Invalid trailing expression at line $1: newline expected".format(w.line), w.line)

      # Ready to parse the next line.
      continue

    # Not a sequence block !

    if w.kind == ywkString:
      # String at first position, so it must be a mapping.
      var key = w.str
      w = p.shiftWord()
      if not (w.kind == ywkIndicator and w.indicator == yiMapper):
        raise newYamlParseError("Invalid string at beginning of line $1: must be followed by ':'".format(w.line) , w.line)


      if p.curWord().kind == ywkLineEnd:
        # Start of a nested mapping.
        # Verify that there is a next line.
        if not p.hasNextWord():
          raise newYamlParseError("Invalid EOF, nested block expected at line " & w.line.`$`, w.line)
        # Verify that next line is indented properly.
        if p.nextWord().kind != ywkIndent or p.nextWord().indent <= indent:
          raise newYamlParseError("Invalid indentation at line $1: must be > $2".format(w.line, indent), w.line)

        # Shift out the newline.
        discard p.shiftWord()
        
        # Block with proper indentation follows, so parse it.
        data[key] = p.parseBlock(p.curWord().indent)
        continue

      else:
        # Not a nested block, so parse the remainder of the line for an expression.
        data[key] = p.parseExpression(indent)
        # After an expression, a line break must come next.
        # Verify this.
        w = p.shiftWord()
        if w.kind != ywkLineEnd:
          raise newYamlParseError("Invalid trailing expression at line $1: newline expected".format(w.line), w.line)
        # Ready to parse the next line.
        continue

  if seqData != nil:
    result = toValueRef(seqData)
  else:
    result = toValueRef(data)


proc parseDocument(p: YamlParser): ValueRef =
  while p.curWord().kind == ywkLineEnd:
    discard p.shiftWord()
  if p.curWord().kind == ywkDocumentStart:
    # Ignore the document start indicator.
    discard p.shiftWord()
  
  p.parseBlock()

proc parseAll(p: YamlParser): ValueRef =
  result = newValueSeq()
  while not p.wordEndReached:
    result.add(p.parseDocument())

proc newParser(str: string): YamlParser =
  result = YamlParser(words: @[])
  result.init(str)

proc parseYaml*(str: string): ValueRef =
  var p = YamlParser(words: @[])
  p.init(str)
  p.lex()

  result = p.parseAll()
  if result.len() == 1:
    result = result[0]

proc parseYamlFile*(path: string): ValueRef =
  parseYaml(readFile(path))
