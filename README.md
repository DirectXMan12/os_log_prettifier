Prettify OpenStack Logs
=======================

This script takes OpenStack logs and adds coloring,
skips raw messages, and more, in order to make reading
DEBUG level logs a bit easier.

Invocation
----------

```bash
$ ./os_log_prettify [/path/to/file1.log] [/path/to/file2.log] ... [OPTIONS]
```

If files are specified, the contents are concatenated in the output.  Otherwise, STDIN is used.  Currently "streaming" to STDIN will not work.  When not used in a pipe, the contents will be output through `less`, if possible.

### Options ###

* `--maxlines=n` reads the first `n` lines from the from the input (treated as one big file)
* `--taillines=n` reads the last `n` lines from *each* file in the input (must use files, not STDIN -- uses the `tail` program)
* `--hideraw` (default) / `--nohideraw` hides (or shows, with the 'no' prefix) messages with a 'source' of '*.messaging.io.raw'
* `--skipsource=regex` can be added one or more times to add regular expressions against which to match the 'source' of the message.  Matched 'sources' will have their messages hidden
* `--stripu` (default) / `--nostipu` strips the 'u' (or does not) the 'u' prefix off of the front of unicode strings in the message body
* `--highlightcontent` (default) / `--nohightlightcontent` makes the 'content=' key in the message body bold in appropriate messages
