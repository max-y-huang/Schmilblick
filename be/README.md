# Schmilblick Back-end

## Python API Instructions

Add the following line(s) to `.env`:

```
PYTHON_PORT=<python_port>
```

Run the following command:

```sh
# --debug: run the app in debug mode
./python/main.py [--debug]
```

Send a POST request to the following endpoint with the appropriate arguments:

```
http://localhost:<python_port>/compile-mxl
```

| Argument | Type | Description                            |
| -------- | ---- | -------------------------------------- |
| `file`   | File | The compressed MusicXML file to parse. |

### Output

#### On success:

```json
// status: 2XX
{
  "parts": {
    "<part_id>": {
      "name": "<part_name>",
      "notes": [
        {
          "time": <seconds>,
          "duration": <seconds>,
          "pitch": <midi_pitch>
        },
        ...
      ]
    },
    ...
  }
}
```

#### On failure:

```json
// status: 4XX
{
  "message": "<error_message>"
}
```

## Node API Instructions

Add the following line(s) to `.env`:

```
NODE_PORT=<node_port>
```

TODO: Add more instructions here.

## MXL Compiler CLI Instructions

Run the following command:

```sh
# --preview: immediately open the generated MIDI file
# --file <score_path>: path to the compressed MusicXML file to parse
./python/compile-mxl-cli.py [--preview] --file <score_path>
```

### Output

The output will be the following files:

- `./out/<score_name>/<part>.json`: the parsed data corresponding to the part `<part>`.
- `./out/<score_name>/<part>.mid`: a MIDI file corresponding to `./out/<score_name>/<part>.json`.

## Appendix

Sample data can be found [here](https://drive.google.com/drive/folders/19GXoGG40P6MN9dCoI2gPH88HKLXORbpS?usp=drive_link).
