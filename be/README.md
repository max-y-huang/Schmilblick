# Schmilblick Back-end

## Setup

### Requirements

- Python 3.10 (e.g. with [pyenv](https://github.com/pyenv/pyenv))
- [Pipenv](https://pipenv.pypa.io/en/latest/)
- [Node.js](https://nodejs.org/en) (TODO: add version)

In `/be`, run the following commands:

```sh
pipenv install
npm install
```

Add the following line(s) to `.env`:

```
PYTHON_PORT=<python_port>
NODE_PORT=<node_port>
```

## Testing

Run the following commands _in parallel_:

```sh
pipenv run dev
```

```sh
npm run dev
```

The Python and Node APIs will run on ports `<python_port>` and `<node_port>` respectively (from [Setup](#setup)).

## Endpoints

### `/compile-mxl` (Python)

| Argument | Type | Description                            |
| -------- | ---- | -------------------------------------- |
| `file`   | File | The compressed MusicXML file to parse. |

#### Example Output(s)

```jsonc
// status: 2XX
{
  "parts": {
    // keys are part IDs
    "P1": {
      "name": "Piano",
      "notes": [
        {
          "time": 0, // in seconds
          "duration": 0.4, // in seconds
          "pitch": 65, // in MIDI pitch
          "measure": 0 // zero-indexed
        }
      ],
      "page_table": [0, 0, 1, 1, 2] // maps measures to pages (both are zero-indexed)
    }
  }
}
```

```jsonc
// status: 4XX
{
  "message": <error message>
}
```

## Miscellaneous

### MXL Compiler CLI

Run the following command:

```sh
# --preview: immediately open the generated MIDI file
# --file <score_path>: path to the compressed MusicXML file to parse
./python/compile-mxl-cli.py [--preview] --file <score_path>
```

The output will be the following files:

- `./out/<score_name>/<part>.json`: the parsed data corresponding to the part `<part>`.
- `./out/<score_name>/<part>.mid`: a MIDI file corresponding to `./out/<score_name>/<part>.json`.

## Appendix

Sample data can be found [here](https://drive.google.com/drive/folders/19GXoGG40P6MN9dCoI2gPH88HKLXORbpS?usp=drive_link).
