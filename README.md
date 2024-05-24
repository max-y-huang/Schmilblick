# Schmilblick

### `parse_mxl.py`

**Input:**

- `/in/score.xml`: an uncompressed MusicXML file.

**Output:**

- `/out/notes.json`: a list of note information containing pitch, start, and duration data.
- (optional) `/out/preview.midi`: a MIDI file built from `/out/notes.json`.
