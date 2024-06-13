# Schmilblick MXL Compiler

## API Instructions

Add the following to the environment variables file `./.env`:

```
PORT=<PORT>
```

Run the following command with the [appropriate arguments](#api-argument-table):

```
./app.py
```

Send a POST request to the following endpoint with the [appropriate arguments](#compile-mxl-argument-table):

```
http//0.0.0.0:<PORT>/compile-mxl
```

TODO: add responses.

## CLI Script Instructions

Run the following command with the [appropriate arguments](#cli-argument-table):

```
./cli.py
```

The output files will be:

- `./out/<SCORE>/<PART>.json`: the parsed data corresponding to the part `<PART>`.
- `./out/<SCORE>/<PART>.mid`: a MIDI file corresponding to `./out/<SCORE>/<PART>.json`.

## Appendix

Sample data can be found [here](https://drive.google.com/drive/folders/19GXoGG40P6MN9dCoI2gPH88HKLXORbpS?usp=drive_link).

### API Argument Table

| Flag      | Optional? | Description                |
| --------- | --------- | -------------------------- |
| `--debug` | True      | Run the app in debug mode. |

### CLI Argument Table

| Flag            | Optional? | Description                                 |
| --------------- | --------- | ------------------------------------------- |
| `--score SCORE` | False     | The input file `./in/<SCORE>.mxl` to parse. |
| `--preview`     | True      | Option to open the parsed data as MIDI.     |

### `/compile-mxl` Argument Table

| Argument | Type | Description                            |
| -------- | ---- | -------------------------------------- |
| `file`   | File | The compressed MusicXML file to parse. |
