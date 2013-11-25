require 'formula'

class Octave < Formula
  homepage 'http://www.gnu.org/software/octave/index.html'
  url 'http://ftpmirror.gnu.org/octave/octave-3.6.4.tar.bz2'
  mirror 'http://ftp.gnu.org/gnu/octave/octave-3.6.4.tar.bz2'
  sha1 '3cc9366b6dbbd336eaf90fe70ad16e63705d82c4'

  option 'without-fltk', 'Compile without fltk (disables native graphics)'
  option 'test', 'Run tests before installing'

  depends_on :fortran

  depends_on 'pkg-config' => :build
  depends_on 'gnu-sed' => :build
  depends_on 'texinfo' => :build     # OS X's makeinfo won't work for this

  depends_on :x11
  depends_on 'fftw'
  # When building 64-bit binaries on Snow Leopard, there are naming issues with
  # the dot product functions in the BLAS library provided by Apple's
  # Accelerate framework. See the following thread for the gory details:
  #
  #   http://www.macresearch.org/lapackblas-fortran-106
  #
  # We can work around the issues using dotwrp.
  depends_on 'dotwrp' if MacOS.version == :snow_leopard and MacOS.prefer_64_bit?
  # octave refuses to work with BSD readline, so it's either this or --disable-readline
  depends_on 'readline'
  depends_on 'curl' if MacOS.version == :leopard # Leopard's libcurl is too old

  # additional features
  depends_on 'suite-sparse'
  # The API was changed in glpk-4.49
  depends_on 'glpk448'
  depends_on 'graphicsmagick' => :recommended
  depends_on 'hdf5'
  depends_on 'pcre'
  depends_on 'qhull'
  depends_on 'qrupdate'

  if build.include? 'without-fltk'
    # required for plotting if we don't have native graphics
    depends_on 'gnuplot'
  else
    depends_on 'fltk'
  end

  # The fix for std::unordered_map requires regenerating
  # configure. Remove once the fix is in next release.
  depends_on :autoconf => :build
  depends_on :automake => :build
  depends_on :libtool => :build

  def patches
    # MacPorts patches
    macports = [
                 "https://svn.macports.org/repository/macports/trunk/dports/math/octave-devel/files/patch-configure.diff",
                 "https://svn.macports.org/repository/macports/trunk/dports/math/octave-devel/files/patch-liboctave-eigs-base.cc.diff",
                 "https://svn.macports.org/repository/macports/trunk/dports/math/octave-devel/files/patch-liboctave-regexp.h.diff",
               ]
    if MacOS.version >= :lion
      macports.push("https://svn.macports.org/repository/macports/trunk/dports/math/octave-devel/files/patch-src-display.cc.diff")
    end
    patch = { :p0 => macports,
              :p1 => [
              "http://hg.savannah.gnu.org/hgweb/octave/raw-rev/26b2983a8acd",
              DATA
              ],
            }

    #patch = { :p0 => [
              ## 1) fix std::unordered map
              ##"https://svn.macports.org/repository/macports/trunk/dports/math/octave-devel/files/patch-configure.diff",
              ## 2) static keywords a problem with clang 3.0 or later
              ## From https://mailman.cae.wisc.edu/pipermail/octave-maintainers/2012-June/028505.html
              #"https://svn.macports.org/repository/macports/trunk/dports/math/octave-devel/files/patch-liboctave-eigs-base.cc.diff",
              ## 3) fix type declaration from struct to class
              #"https://svn.macports.org/repository/macports/trunk/dports/math/octave-devel/files/patch-liboctave-regexp.h.diff",
              #],
              #:p1 => [
              ## Pull upstream patch to fix configure script on std::unordered_map detection.
              #"http://hg.savannah.gnu.org/hgweb/octave/raw-rev/26b2983a8acd",
              ## Force scripts/mk-pkg-add to use gsed
              ## Unknown as to why it forgets the SED='/usr/local/bin/gsed'
              #DATA
              #]
            #}

    ## 10.7+ requires an extra patch; this patch will break the
    ## build on 10.6 and prior, so apply it only under 10.7.
    #if MacOS.version >= :lion
      #patch[:p0] << "https://svn.macports.org/repository/macports/trunk/dports/math/octave-devel/files/patch-src-display.cc.diff"
    #end
  end

  def blas_flags
    flags = []
    flags << "-ldotwrp" if MacOS.version == :snow_leopard and MacOS.prefer_64_bit?
    # Cant use `-framework Accelerate` because `mkoctfile`, the tool used to
    # compile extension packages, can't parse `-framework` flags.
    flags << "-Wl,-framework,Accelerate"
    flags.join(" ")
  end

  def install
    ENV.m64 if MacOS.prefer_64_bit?
    ENV.append_to_cflags "-D_REENTRANT"

    args = [
      "--disable-dependency-tracking",
      "--prefix=#{prefix}",
      "--with-blas=#{blas_flags}",
      "--with-x",
      "--enable-docs=no",
      # SuiteSparse-4.x.x fix, see http://savannah.gnu.org/bugs/?37031
      "--with-umfpack=-lumfpack -lsuitesparseconfig",
      # Use the keg-only glpk-4.48
      "--with-glpk=glpk",
      "--with-glpk-includedir=#{HOMEBREW_PREFIX}/opt/glpk448/include",
      "--with-glpk-libdir=#{HOMEBREW_PREFIX}/opt/glpk448/lib",
    ]
    args << "--without-framework-carbon" if MacOS.version >= :lion
    # avoid spurious 'invalid assignment to cs-list' erorrs on 32 bit installs:
    args << 'CXXFLAGS=-O0' unless MacOS.prefer_64_bit?

    # Taken from MacPorts
    if build.include? 'without-fltk'
      args << "--without-opengl"
    else
      args << "--with-opengl"
    end

    # Use the keg-only readline and llvm from Homebrew
    args << "LDFLAGS=-L#{HOMEBREW_PREFIX}/opt/readline/lib -L#{HOMEBREW_PREFIX}/opt/llvm/lib"
    args << "CPPFLAGS=-I#{HOMEBREW_PREFIX}/opt/readline/include -I#{HOMEBREW_PREFIX}/opt/llvm/include"

    # Find llvm-config executable
    args << "LLVM_CONFIG=#{HOMEBREW_PREFIX}/Cellar/llvm/3.3/bin"

    # Find gs executable
    # From http://octave.1599824.n4.nabble.com/MXE-Octave-Cannot-find-Ghostscript-td4655045.html
    args << "GS=#{HOMEBREW_PREFIX}/bin"

    # From MacPorts:
    # In 10.8+, the LANG environment variable needs to be set to
    # "C" otherwise /usr/bin/sed fails with an error.  Ideally,
    # octave's build system would honor the environment variable
    # ${SED} throughout; reality is that it does not, so this
    # addition is required because /usr/bin/sed will be used.
    args << "LANG=C"

    # The fix for std::unordered_map requires regenerating
    # configure. Remove once the fix is in next release.
    system "autoreconf", "-ivf"

    system "./configure", *args
    system "env LANG=C make"
    system "make check 2>&1 | tee make-check.log" if build.include? 'test'
    system "make install"

    prefix.install ["test/fntests.log", "make-check.log"] if build.include? 'test'
  end

  def caveats
    native_caveats = <<-EOS.undent
      Octave supports "native" plotting using OpenGL and FLTK. You can activate
      it for all future figures using the Octave command

          graphics_toolkit ("fltk")

      or for a specific figure handle h using

          graphics_toolkit (h, "fltk")

      Otherwise, gnuplot is still used by default, if available.
    EOS

    gnuplot_caveats = <<-EOS.undent
      When plotting with gnuplot, you should set "GNUTERM=x11" before running octave;
      if you are using Aquaterm, use "GNUTERM=aqua".
    EOS

    glpk_caveats = <<-EOS.undent

      GLPK functionality has been disabled due to API incompatibility.
    EOS

    s = glpk_caveats
    s = gnuplot_caveats + s
    s = native_caveats + s unless build.include? 'without-fltk'
  end
end

__END__
diff --git a/scripts/mk-pkg-add b/scripts/mk-pkg-add
index 383bf1d..ed36c44 100755
--- a/scripts/mk-pkg-add
+++ b/scripts/mk-pkg-add
@@ -32,6 +32,6 @@ do
   if [ "$arg" = "--" ]; then
     prefix=""
   else
-    sed -n 's/^[#%][#%]* *PKG_ADD: *//p' "$prefix$arg"
+    gsed -n 's/^[#%][#%]* *PKG_ADD: *//p' "$prefix$arg"
   fi
 done
