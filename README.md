Prettify OpenStack Logs
=======================

This script takes OpenStack logs and adds coloring,
skips raw messages, and more, in order to make reading
DEBUG level logs a bit easier.

Invocation
----------

```bash
$ ./os_log_prettify [/path/to/file.log] [OPTIONS]
```

If a file is not specified, STDIN is used.  "Streaming" pipes, such as from `tail -f`, are supported (in this case, outputting to `less` is not used).

### Options ###

* `--maxlines=n` reads the first `n` lines from the from the input, and then exits
* `--taillines=n` reads the last `n` lines from the given file, and must be used with a filename
* `--hideraw` (default) / `--nohideraw` hides (or shows, with the 'no' prefix) messages with a 'source' of '*.messaging.io.raw'
* `--skipsource=regex` can be added one or more times to add regular expressions against which to match the 'source' of the message.  Matched 'sources' will have their messages hidden
* `--stripu` (default) / `--nostipu` strips the 'u' (or does not) the 'u' prefix off of the front of unicode strings in the message body
* `--highlightcontent` (default) / `--nohightlightcontent` makes the 'content=' key in the message body bold in appropriate messages
* `--follow` uses tail to keep the file open, continuing to read as updates come in.  This may be used with `--taillines`, and must be used with a file
