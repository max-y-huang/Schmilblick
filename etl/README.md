# Schmilblick MXL Compiler

## How to Run

Run the following command _from the repository root folder_ with the [appropriate flags](#argument-table):

```
./etl/compile_mxl.py
```

The output will be:

- `/out/<SCORE>/<PART>.json`: the parsed data corresponding to the part `<PART>`.
- `/out/<SCORE>/<PART>.mid`: a MIDI file corresponding to `/out/<SCORE>/<PART>.json`.

## Appendix

Sample data can be found [here](https://drive.google.com/drive/folders/19GXoGG40P6MN9dCoI2gPH88HKLXORbpS?usp=drive_link).

### Argument Table

| Flag            | Optional? | Description                                |
| --------------- | --------- | ------------------------------------------ |
| `--score SCORE` | False     | The input file `/in/<SCORE>.mxl` to parse. |
| `--preview`     | True      | Option to open the parsed data as MIDI.    |
