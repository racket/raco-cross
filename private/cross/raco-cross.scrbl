#lang scribble/manual
@(require (for-label racket/base)
          scribble/bnf)

@(define raco-scrbl '(lib "scribblings/raco/raco.scrbl"))
@(define raco-exe @seclink[#:doc raco-scrbl "exe"]{@exec{raco exe}})
@(define raco-dist @seclink[#:doc raco-scrbl "exe-dist"]{@exec{raco dist}})

@title{Cross-Compilation Driver: @exec{raco cross}}

The @exec{raco cross} command (implemented in the
@filepath{raco-cross} package) provides a convenient interface to
cross-compilation for Racket. It's especially handy generating
executables that run on platforms other than the one used to create
the executable.

For example,

@commandline{raco cross --target x86_64-linux exe example.rkt}

creates an executable named @filepath{example} that runs on x86_64
Linux. That is, it sets up a combination of distributions for the
current platform and for the @tt{x86_64-linux} platform, and it runs
@|raco-exe| as if from the local @tt{x86_64-linux} installation.

For that command to work, however, the @filepath{compiler-lib} package
must be installed in the @exec{raco cross} workspace for the
@tt{x86_64-linux} target. It's not there by default, because
@exec{raco cross} starts with a minimal Racket distribution, and
@|raco-exe| is provided by @filepath{compiler-lib}. So, @emph{before}
the above command, use this one:

@commandline{raco cross --target x86_64-linux pkg install compiler-lib}

The @filepath{example} executable generated above is not necessarily
portable by itself to other machines. As is generally the case with
@|raco-exe|, the executable need to be turned into a distribution with
@|raco-dist| (which is also supplied by the @filepath{compiler-lib}
package):

@commandline{raco cross --target x86_64-linux dist example-dist example}

The result directory @filepath{example-dist} is then ready to be
copied to a x86_64 Linux machine and run there.

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
       @url{https://snapshots.racket-lang.org}.}

 @item{Generates a cross-compiler plug-in from Racket sources for the
       CS variant of Racket. (No extra cross-compilation plugin is
       needed for BC.)}

 @item{Chains to @exec{racket} or @exec{raco} for a given version and
       virtual machine---running on the current machine, but in
       cross-compilation mode for a target that is potentially a
       different operating system and/or architecture.}

]

The version and CS/BC variant of Racket where @filepath{raco-cross} is
installed and run does not have to be related to the target version
and variant. The @exec{raco cross} command will download and install a
version and variant of Racket for the current machine as needed.

The Racket distributions that are downloaded and managed by @exec{raco
cross} are installed in a @deftech{workspace} directory. By default,
the workspace directory is @racket[(build-path (find-system-path
'addon-dir) "raco-cross" _vers)] where @racket[_vers] is the specified
version. The workspace directory is independent of the Racket
installation that is used to run @exec{raco cross}.

When building for a given target, often packages need to be installed
via @exec{raco cross} only for that target. In some cases, however,
compilation may require platform-specific native libraries, in which
case the packages must also be installed for the host platform via
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

 @item{@DFlag{version} @nonterm{vers} --- Selects the Racket version
       to use for the target machine.

       The default version is based on the Racket version used to run
       @exec{raco cross}, but if that version has a fourth
       @litchar{.}-separated component, then it is dropped, and a
       third component is dropped if it is @litchar{0}.

       The version @exec{current} might be useful with a snapshot
       download site, but only with a fresh workspace directory each
       time the snapshot site's @exec{current} build changes.}

 @item{@DFlag{version} @nonterm{vers} --- Selects the Racket
       virtual-machine implementation to use for the target machine,
       either @exec{cs} or @exec{bc}.

       The default matches the Racket implementation that is used to
       run @exec{raco cross}.

       Beware that only some combinations of platform and Racket
       implementation are available from installer sites.}

 @item{@DFlag{work-dir} @nonterm{dir} --- Uses @nonterm{dir} as the
       workspace directory.

       The default workspace directory depends on the target version
       @nonterm{vers}: @racket[(build-path (find-system-path
       'addon-dir) "raco-cross" @#,nonterm{vers})].}

  @item{@DFlag{installers} @nonterm{url} --- Specifies the site for
        downloading minimal Racket distributions.

        The installers URL is needed only when a target platform and
        virtual-machine implementation is specified for the first time
        for a given workspace. The name of the file to download is
        constructed based on the version, target machine, and
        virtual-machine implementation, and that file name is added to
        the end of @nonterm{url}.

        The default @nonterm{url} is @exec{https://mirror.racket-lang.org/installers/@nonterm{vers}/}.}

]
