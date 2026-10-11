# Exercise demonstrations and local media

Six built-in exercises have an optional two-position photo guide and locally
bundled technique instructions: bench press, squat, deadlift, overhead press,
bicep curl (barbell reference variant), and push-ups. The reference variant is
labelled explicitly. These photos show positions, not a continuous movement or
a live form check. Download runs only after the user taps the button; downloaded
photos are available offline. Photos/instructions are from Free Exercise DB,
pinned at f00c92c7dcf1216a928a52c3706c7ce8e2f71ed5 (Unlicense).

Edit an exercise to add or remove up to four JPG/PNG photos, GIF animations, or
MP4 videos. Each image is limited to 12 MB and 16 megapixels; photos are resized
to at most 1600 pixels on the long edge and re-encoded as PNG without EXIF.
GIF animations preserve their bytes. Videos are limited to 30 MB and 60 seconds;
Android validates duration and plays them in a native viewer with seek controls,
a mute toggle, and a close button. Playback pauses when the app goes into the
background. Other platforms support photos/GIFs and explain the video limitation.
No custom file is uploaded or automatically sent to the AI coach.

Media appears in exercise details and in the workout's Demonstration sheet.
Files are copied into the app-private documents directory with SHA-256 filenames.
The original external path and filename are not stored. Hashing, byte comparison,
and backup encoding/validation run in worker isolates so large files do not block
the editor or backup UI. A restore repairs corrupt existing files atomically. Removed/cancelled editor
attachments and deleted custom exercise attachments are cleaned up when no other
exercise references the same content. Failed saves keep the old exercise intact.

Backups containing media use JSON format version 2 with base64 file payloads
(deduplicated by hash) and a combined 80 MB media limit. Validation checks all
references, hashes, sizes, and file signatures before database merging starts.
References are relative filenames and resolve in the destination's private media
directory. Import retains the existing merge behavior: an existing local exercise
or override wins over the imported copy. Older version-1 and legacy backups still
import, and backups without media remain version 1. Older RepForge builds cannot
restore format-2 backups. Photos and videos increase backup size and may contain
personal information; the user explicitly controls exporting/sharing the file.

SQLite schema 7 adds nullable `exercises.media_json`; version-6 rows default to
no media. Hive fallback supports the same exercise JSON and built-in overrides.
Native video playback and gallery/lock-screen lifecycle behavior should be checked
on a physical Android device before release.
