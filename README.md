# Schmilblick

### `/etl/parse_mxl.py`

**Input (Sample data [here](https://drive.google.com/drive/folders/19GXoGG40P6MN9dCoI2gPH88HKLXORbpS?usp=drive_link)):**

- `/in/<TEST_CASE>/score.mxl`: a compressed MusicXML file.

**Output:**

- `/out/<TEST_CASE>/notes.json`: a list of note information containing pitch, start, and duration data.
- (optional) `/out/<TEST_CASE>/preview.midi`: a MIDI file built from `/out/<TEST_CASE>/notes.json`.
