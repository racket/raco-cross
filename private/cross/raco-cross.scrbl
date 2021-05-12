#lang scribble/manual
@(require (for-label racket/base)
          scribble/bnf)

@(define raco-scrbl '(lib "scribblings/raco/raco.scrbl"))
@(define raco-exe @seclink[#:doc raco-scrbl "exe"]{@exec{raco exe}})
@(define raco-dist @seclink[#:doc raco-scrbl "exe-dist"]{@exec{raco dist}})

@title{Cross-Compilation and Multi-Version Manager: @exec{raco cross}}

The @exec{raco cross} command (implemented in the
@filepath{raco-cross} package) provides a convenient interface to
cross-compilation for Racket. It's especially handy generating
executables that run on platforms other than the one used to create
the executable.

For example,
<
@commandline{raco cross --target x86_64-linux exe example.rkt}

creates an executable named @filepath{example} that runs on x86_64
Linux. That is, it sets up a combination of distributions for the
current platform and for the @tt{x86_64-linux} platform, and it runs
@|raco-exe| as if from the local @tt{x86_64-linux} installation.

@margin-note{For Racket CS, cross-building executables works for
             version 8.1.0.6 and later. For Racket BC, cross-build
             executables works for 7.0 and later. The specific
             platforms available as cross-compilation targets depends
             on the set of distributions that are available from an
             installer site.}

The generated @filepath{example} executable is not necessarily
portable by itself to other machines. As is generally the case with
@|raco-exe|, the executable needs to be turned into a distribution with
@|raco-dist| (which is also supplied by the @filepath{compiler-lib}
package):

@commandline{raco cross --target x86_64-linux dist example-dist example}

The result directory @filepath{example-dist} is then ready to be
copied to a x86_64 Linux machine and run there.

Since @exec{raco cross} depends on facilities for managing Racket
implementations for different versions and platforms, it can also act
as a launcher for a selected native implementation of Racket. For
example,

@commandline{raco cross --version 7.8 racket}

installs and runs a minimal installation of Racket version 7.8 for the
current platform (assuming that the combination of version, platform,
and virtual machine is available).

Use the @DFlag{native} flag to create an installation for a platform
other than the current machine's default, but where the current
machine can run executables directly. For example, on Windows where
@exec{raco} runs a 64-bit Racket build,

@commandline{raco cross --native --platform i383-win32 --vm bc racket}

installs and runs a 32-bit build of Racket BC for Windows and runs it
directly.

@; ----------------------------------------
@section{Platforms, Versions, and Workspaces for @exec{raco cross}}

The @exec{raco cross} command takes care of the following tasks:

@itemlist[

 @item{Downloads minimal Racket installations as needed for a given
       combination of operating system, architecture, Racket virtual
       machine (CS versus BC), and version.

       By default, @exec{raco cross} downloads from the main Racket
       mirror for release distributions, but you can point @exec{raco
       cross} to other sites (such as one of the snapshot sites at
       @url{https://snapshot.racket-lang.org}) using
       @DFlag{installers}.}

 @item{Configures the minimal Racket installation to install new
       packages in @exec{installation} scope by default.}

 @item{Installs the @filepath{compiler-lib} package so that @exec{raco
       exe} is available, unless @DFlag{skip-pkg} is specified to keep
       the installation minimal.}

 @item{Generates a cross-compiler plug-in from Racket sources for the
       CS variant of Racket. (No extra cross-compilation plugin is
       needed for BC or for native installations.)}

 @item{Chains to @exec{racket} or @exec{raco} for the target version
       and virtual machine---running a native executable, but
       potentially in cross-compilation mode for a target that is a
       different operating system and/or architecture.}

]

The version and CS/BC variant of Racket where @filepath{raco-cross} is
installed and run doesn't need to be related to the target version and
variant. The @exec{raco cross} command will download and install a
version and variant of Racket for the current machine as needed.

The Racket distributions that are downloaded and managed by @exec{raco
cross} are installed in a @deftech{workspace} directory. By default,
the workspace directory is @racket[(build-path (find-system-path
'addon-dir) "raco-cross" _vers)] where @racket[_vers] is the specified
version. The workspace directory is independent of the Racket
installation that is used to run @exec{raco cross}.

When building for a given target, often packages need to be installed
via @exec{raco cross} only for that target. In some cases, however,
compilation may require platform-specific native libraries, and
the packages must also be installed for the host platform via
@exec{raco cross} (with no @DFlag{target} flag). For example, if
compiling a module requires rendering images at compile time, then
@;
@commandline{raco cross pkg install draw-lib}
@;
most likely will be needed to install the packages for the current
machine, as well as
@;
@commandline{raco cross --target @nonterm{target} pkg install draw-lib}
@;
to install for the @nonterm{target} platform.

@; ----------------------------------------
@section{Running @exec{raco cross}}

The general form to run @exec{raco cross} is
@;
@commandline{raco cross @nonterm{option} @elem{...} @nonterm{command} @nonterm{arg} @elem{...}}
@;
which is analogous to running
@;
@commandline{raco @nonterm{command} @nonterm{arg} @elem{...}}
@;
but with a cross-compilation mode selected by the @nonterm{option}s.
As a special case, @nonterm{command} can be @exec{racket}, which is
analogous to running just @exec{racket} instead of @exec{raco racket}.
Finally, you can omit the @nonterm{command} and @nonterm{arg}s,
in which case @exec{raco cross} just downloads and prepares the
workspace's distribution for the target platform.

The following @nonterm{options} are recognized:

@itemlist[

 @item{@DFlag{target} @nonterm{platform} --- Selects the target
       platform. The @nonterm{platform} can have any of the following
       forms:

        @itemlist[

          @item{The concatenation of the string form of the symbols
                returned by @racket[(system-type 'arch)] and @racket[(system-type 'os)]
                on the target platform, with a @racket["-"] in between.
                Some common alternative spellings of the @racket[(system-type 'arch)]
                and @racket[(system-type 'os)] results are also recognized.

                Examples: @exec{i386-win32}, @exec{aarch64-macosx}, @exec{ppc-linux}}

          @item{The string form of the path returned on the target platform by
                @racket[(system-library-subpath #f)].

                These are mostly the same as the previous case, but also include
                @exec{win32\i386} and @exec{win32\x86_64}.}

          @item{The string form of the symbol that is the default
                value of @racket[current-compile-target-machine] for
                the CS implementation of Racket on the target platform.

                Examples: @exec{ti3nt}, @exec{tarm64osx}, @exec{ppc32le}}

        ]}

 @item{@DFlag{vm} @nonterm{variant} --- Selects the Racket version to
       use for the target machine.

       The default version is based on the Racket version used to run
       @exec{raco cross}, but if that version has a fourth
       @litchar{.}-separated component, then it is dropped, and a
       third component is dropped if it is @litchar{0}.

       The version @exec{current} might be useful with a snapshot
       download site, but only with a fresh workspace directory each
       time the snapshot site's @exec{current} build changes.}

 @item{@DFlag{native} --- Specifies that the target platform runs
       natively on the current machine, so cross-compilation mode is
       not needed.

       Native mode is inferred when the target platform is the same as
       the platform for @exec{raco}. Otherwise, the @DFlag{native}
       setting is recorded when the distribution for the target
       platform, version, and virtual machine is installed into the
       workspace, so it needs to use specified only the first time the
       target is selected.}

 @item{@DFlag{version} @nonterm{vers} --- Selects the Racket
       virtual-machine implementation to use for the target machine,
       either @exec{cs} or @exec{bc}.

       The default matches the Racket implementation that is used to
       run @exec{raco cross}.

       Beware that only some combinations of platform and Racket
       implementation are available from installer sites.}

 @item{@DFlag{workspace} @nonterm{dir} --- Uses @nonterm{dir} as the
       workspace directory.

       The default workspace directory depends on the target version
       @nonterm{vers}: @racket[(build-path (find-system-path
       'addon-dir) "raco-cross" @#,nonterm{vers})].}

  @item{@DFlag{installers} @nonterm{url} --- Specifies the site for
        downloading minimal Racket distributions. Note that @nonterm{url}
        normally should end with @litchar{/}, since the distribution file
        name will be combined as relative reference.

        The installers URL is needed only when a combination of a
        target platform, virtual-machine implementation, and version
        is specified for the first time for a given workspace. The
        name of the file to download is constructed based on the
        version, target machine, and virtual-machine implementation,
        and that file name is added to the end of @nonterm{url}, but
        the file name can be overridden through @DFlag{archive}.

        The default @nonterm{url} is @exec{https://mirror.racket-lang.org/installers/@nonterm{vers}/}.}

  @item{@DFlag{archive} @nonterm{filename} --- Overrides the archive
        to use when downloading for the target platform.}

  @item{@DFlag{skip-pkgs} --- Disables installation of the
        @filepath{compiler-lib} package when installing a new
        distribution.

        The @filepath{compiler-lib} package is installed by default so
        that @exec{raco cross @elem{....} exe @elem{...}} and
        @exec{raco cross @elem{....} dist @elem{...}} will work for
        the installed target.}

  @item{@Flag{j} @nonterm{n} or @DFlag{jobs} @nonterm{n} --- Uses
        @nonterm{n} parallel jobs for setup actions when installing a
        new distribution, including the initial package install if
        @DFlag{skip-pkgs} is not specified.}

  @item{@DFlag{remove} --- Removes any existing installation in the
        workspace for the target platform, virtual machine, and
        version.

        When @DFlag{remove} is specified, no @nonterm{command} can be
        given.}

]
