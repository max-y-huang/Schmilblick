# Schmilblick

### `/etl/parse_mxl.py`

**Input (Sample data [here](https://drive.google.com/drive/folders/19GXoGG40P6MN9dCoI2gPH88HKLXORbpS?usp=drive_link)):**

- `/in/<SCORE>.mxl`: a compressed MusicXML file.

**Output:**

- `/out/<SCORE>/<PART>.json`: a list of note information containing pitch, start time, and duration data.
- (optional) `/out/<SCORE>/<PART>.midi`: a MIDI file built from `/out/<SCORE>/<PART>.json`.
