# snippetion

Small Ruby service for composing script snippets from required and optional parts.

## Project layout

Projects live under `projects/<group>/<project>.snippet`.

Each snippet file is made of fenced parts:

````text
```header must
#!/bin/bash
```

```feature_a opt
echo A
```
````

- `must` parts are always included
- `opt` parts are controlled by the choice value in the URL
- optional parts are mapped to bits from least-significant to most-significant in file order
- choice tokens use lowercase base-36 characters: `0-9` and `a-z`

Example:

- `1` => binary `001` => select the first optional part
- `2` => binary `010` => select the second optional part
- `7` => binary `111` => select all optional parts

## Run

```bash
ruby server.rb
```

Then request:

```bash
curl http://localhost:9292/bash/test/2
```

## Test

```bash
ruby -Itest test/snippetion_test.rb
```
