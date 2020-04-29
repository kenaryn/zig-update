zig-update
==========

## Rationale
While looking for the newest version, it may be cumbersome and divert you from your primary
objective shall you need the cutting-edge branch of your favorite programming language. Thereby, downloading, copying, configuring and saving old_settings is time-consuming and error-prone.

zig-update was conceived to supply a easy-to-use and quick method to install and/or update the Zig
compiler from the official source.


## Dependencies
Zig-update is self-sufficient and does not require any dependencies other than the
[Z shell](https://zsh.sourceforge.net) (also known as Zsh. Note that it is henceforth the default
shell installed on Mac OS distributions since October 2019).

Zig-update will download the last tarball (*i.e.* pre-built binaries) from the official website
[ziglang](https://ziglang.org) and run all necessary operations in order to set up an immediately
fully functional working environment with Zig (which is as you may recall both a compiler
and a programming language).


## Who will benefit from it?
At the moment, zig-update is only available for x86_64-linux target.


## Road map
### 0.0.5:
* Revert changes in case of installation's failure by stashing old binary.

### 0.0.4:
* Improve detection with PATH environment variable instead of checking out the run-control file.

### 0.0.3:
* Add standard error outputs redirection for logging purpose.
* Make the script system-wide executable.

### 0.0.2:
* Detect and adapt to voidLinux distributions.
* Support freeBSD distribution to target a broader audience.


## Notes
zig-update is entirely written in Zsh 5.7.1.

## License
The project is under the 3-Clause BSD License.