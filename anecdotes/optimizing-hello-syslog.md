# Optimizing Hello, Syslog!

This is a brief reconstruction of the process of optimizing the size of the `acap-logging` library crate.
I created the library to document, and make it easy to adopt, my recommendation for how to set up logging in an ACAP app.

I noticed that `acap-logging` introduced an outrageous overhead; something like 1M on a conservatively optimized
binary (`hello-world` is 362.4KiB):

```console
cargo bloat -n=5 --crates --profile=conservative -p hello-syslog--naive
 File  .text     Size Crate
25.2%  36.3% 418.7KiB std
17.7%  25.5% 294.1KiB regex_automata
 9.7%  13.9% 160.6KiB aho_corasick
 9.5%  13.7% 157.7KiB regex_syntax
 3.2%   4.6%  53.2KiB time
 4.7%   6.7%  77.2KiB And 12 more crates. Use -n N to show more.
69.6% 100.0%   1.1MiB .text section size, the file size is 1.6MiB
```

I knew that regex was a notoriously heavy dependency, and I was surprised to learn that I depended on it.
This is one of several optional features that I don't think the library needs, so disabling them by default was an easy fix [^disable-default-features-for-env-logger].
This shaved roughly 1M off the binary size:

```console
$ cargo bloat --crates --profile=conservative -p hello-syslog--features
 File  .text     Size Crate
49.5%  74.7% 271.3KiB std
 9.7%  14.6%  53.1KiB time
 2.1%   3.2%  11.8KiB hello_syslog__features
 1.8%   2.8%  10.1KiB env_logger
 1.2%   1.9%   6.8KiB syslog
 2.7%   4.1%  14.9KiB And 6 more crates. Use -n N to show more.
66.2% 100.0% 363.1KiB .text section size, the file size is 548.5KiB
```

Since this represented most (85%) of the overhead, I was happy.
For a while.

Recently I started looking closer at methods for reducing the size of rust binaries and thought that paying 200K for
logging, on top of the already high cost of any Rust binary, seemed a bit steep.
I looked again at the above output from `cargo-bloat`;
reducing the usage of `std` seemed tricky, and though `time` looks suspiciously large it was a transient dependency and it was not obvious what drove its size.
So I took aim at `env_logger` instead.
This is a direct dependency that is not needed in a production binary, so making it optional was easy.

Unfortunately this did not move the needle on the size of `time`.
`cargo tree` reveals that this is required only by `syslog`:

```console
$ cargo tree -i -p time
time v0.3.41
├── syslog v6.1.1
│   └── acap-logging v0.1.0
│       └── hello-syslog--features v0.1.0
```

I didn't find a way to remove this dependency using features.
So I tried to correlate the output from `cargo-bloat` without the `--crates` option with the `syslog` source code to see if I could use its API in a way that would reduce the size.
The most notorious thing I found was that a single call to the `time` API that in theory could have been constant:

```rust
time::format_description::parse("[month repr:short] [day] [hour]:[minute]:[second]").unwrap();
```

Replacing the implementation of this function with a `todo!()` shaved 40K off the total binary size!
I found no way of not using it, but I think this illustrates the point that the large size of Rust binaries is not only a technical problem, but also a culture problem;
The standard library is optimized for ergonomics and speed, and much of the ecosystem shares these priorities.

All that was left to do was replace the dependency entirely.
Luckily I found `libsyslog`, which means I don't have to write my own logging implementation on top of `libc`.

After making `env_logger` optional and replacing `syslog` [^make-env-logger-optional-and-remove-syslog] the price of `acap-logging` integration is now 20K:

```console
$ cargo bloat -n=5 --crates --profile=conservative -p hello-syslog--crates --no-default-features
 File  .text     Size Crate
64.3%  96.0% 242.9KiB std
 1.2%   1.8%   4.6KiB libsyslog
 1.1%   1.7%   4.3KiB [Unknown]
 1.1%   1.6%   4.0KiB hello_syslog__crates
 0.4%   0.7%   1.7KiB memchr
 0.1%   0.2%     574B And 2 more crates. Use -n N to show more.
67.0% 100.0% 253.1KiB .text section size, the file size is 377.8KiB
```

Along the way I also learned that `log` supports statically eliminating logs at low severities, theoretically improving both
speed and footprint.

[^disable-default-features-for-env-logger]: https://github.com/AxisCommunications/acap-rs/commit/46daf9febba4b8e500c8453506f204740350126e
[^make-env-logger-optional-and-remove-syslog]: https://github.com/AxisCommunications/acap-rs/commit/ac2cb60a7c826c78911996d85f1641672ff8d230
