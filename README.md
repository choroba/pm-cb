pm-cb is Copyright (C) 2017-2020, E. Choroba

PerlMonks ChatterBox Client
==

DESCRIPTION
--

There are two executable programs, `pm-cb` and `pm-cb-g`. The former
doesn't implement a full chat client (you can't use it to post to the
ChatterBox) and is no longer supported. The latter is a graphical
client to PerlMonks' ChatterBox written in Perl and Tk.

Pull requests welcome!

PREQUISITES
--
Install required modules using
```
cpanm --installdeps .
```

If your `perl` has been compiled with thread support:

```
perl -MConfig -E 'say "Threads supported" if $Config{useithreads}'
```
you can simply start the program with

```
perl pm-cb-g

```
If threads are not supported, either compile a new perl with threads enabled,
e.g.

```
perlbrew install perl-5.30.0 --as=5.30.0-threads -Dusethreads
perlbrew use 5.30.0-threads
```
or run the program using `MCE::Hobo` with
```
perl pm-cb-g --mce_hobo
```
or with `MCE::Child`
```
perl pm-cb-g --mce_child
```


LICENSE INFORMATION
--

This code is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.30 (see [the Perl Artistic
License](https://perldoc.pl/perlartistic) and [the GNU General Public
License, version 1](https://perldoc.pl/perlgpl)).

