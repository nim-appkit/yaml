# nim-yaml

Lexer based Yaml parser for [Nim](http://nim-lang.org).

## Install

nim-yaml is best installed with [Nimble](http://github.com/nim-lang/nimble), Nims package manager.

```bash
nimble install yaml
```

## Parse a simple document

The parser returns the parsed yaml as *Value* objects, which are supplied by the [values](https://github.com/nim-appkit/values) package.

Parse a yaml document:

```nim
from yaml import nil

var myYaml = """
str: String
quotedString: "String \n String"
seq: [1, "a", false]
blockSeq:
  - A
  - B
mapping:
  str: Nested String
longText: >
  Text
  Text
  Text
"""

var data = yaml.parseYaml(myYaml)

# Accessing the data.

echo(data.str) => "String"
var str = data.str[string]

echo(data.mapping.str) => "Nested String"

echo(data.hasKey("xxx")) => false

echo(data.seq[2]) # => "false"
var isFalse = data.seq[2][bool]

echo(data.blockSeq.len()) # => 2

# Convert ValueSequence to actual seq[T].
# Only works if the sequence only contains items of one type!
var blockSeq = data.blockSeq.asSeq(string) 

var s1: string = blockSeq[0]
```

## Parsing multiple documents

```nim
from yaml import nil

var myYaml = """
a: A
id: 1
...
b: B
id: 2
"""

var data = yaml.parseYaml(myYaml)

for document in data:
  echo(document.id)
```

## Parsing a YAML file.

```nim
from yaml import nil
var data = yaml.parseYamlFile()
```

## Additional Information

### Changelog

See CHANGELOG.md.

### Versioning

This project follows [SemVer](semver.org).

### License.

This project is under the [MIT](https://opensource.org/licenses/MIT) license.
