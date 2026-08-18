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

Preview in a browser:

```bash
open http://localhost:9292/preview/bash/test/2
```

## Access token

Set `ACCESS_TOKEN` to require authenticated access for both script and preview routes.

You can pass the token either as a bearer token header or as a `token` query parameter.

```bash
ACCESS_TOKEN=preview-token ruby server.rb
curl --oauth2-bearer <token> http://localhost:9292/bash/test/2
curl "http://localhost:9292/preview/bash/test/2?token=<token>"
```

## Edit & preview in a browser

Open the interactive editor for any snippet (source on the left, live preview on the right):

```bash
open http://localhost:9292/edit/bash/test
# with authentication:
open "http://localhost:9292/edit/bash/test?token=<token>"
```

Toggle the optional-part checkboxes to see the rendered output change live.

## .netrc generator

Generate a ready-to-paste `.netrc` entry for quick auth setup:

```bash
curl "http://localhost:9292/.netrc?token=<token>&host=localhost:9292&login=token"
# >> machine localhost:9292
# >> login token
# >> password <token>
```

Append it to `~/.netrc`:

```bash
curl "http://localhost:9292/.netrc?token=<token>&host=localhost:9292" >> ~/.netrc
```

| Query param | Default | Description |
|---|---|---|
| `token` | — | your access token (required when `ACCESS_TOKEN` is set) |
| `host` | `localhost` | hostname to embed in the `machine` line |
| `login` | `token` | login name to embed in the `login` line |



```bash
ruby -Itest test/snippetion_test.rb
```
