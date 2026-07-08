%global mpich5_version 5.0.1

Name:           mpich5
Version:        %{mpich5_version}
Release:        1
Summary:        MPICH 5.x — MPI-4.1 implementation (OFI/libfabric backend)
License:        MIT
URL:            https://www.mpich.org
Source0:        mpich-%{version}.tar.gz

BuildRequires:  gcc
BuildRequires:  gcc-c++
BuildRequires:  gcc-fortran
BuildRequires:  python3
BuildRequires:  hwloc-devel
BuildRequires:  libnuma-devel
BuildRequires:  libfabric-devel

Requires:       libfabric

%description
MPICH is a high-performance and widely portable implementation of the
MPI standard (MPI-4.1). This build uses the OFI (libfabric) network
layer with the ch4 device for Slingshot support.

%package devel
Summary:        Development files for MPICH 5.x
Requires:       %{name} = %{version}-%{release}
Requires:       gcc-fortran

%description devel
Headers, modules, and compiler wrappers for building MPI applications
with MPICH 5.x.

%prep
%setup -q -n mpich-%{version}

%build
%configure \
  --prefix=%{_prefix} \
  --libdir=%{_libdir}/mpich5 \
  --includedir=%{_includedir}/mpich5 \
  --bindir=%{_libdir}/mpich5/bin \
  --mandir=%{_mandir}/mpich5 \
  --docdir=%{_datadir}/doc/mpich5 \
  --with-device=ch4:ofi \
  --with-libfabric \
  --enable-shared \
  --disable-static \
  --enable-fortran=all \
  --enable-romio \
  --disable-dependency-tracking \
  FFLAGS="-w" FCFLAGS="-w"

%make_build

%install
%make_install

# Remove libtool archives (not needed for shared-only build)
find %{buildroot} -name '*.la' -delete

# Create modulefile
mkdir -p %{buildroot}%{_datadir}/modules/mpich5
cat > %{buildroot}%{_datadir}/modules/mpich5/%{version} <<EOF
#%%Module
proc ModulesHelp { } {
  puts stderr "MPICH %{version} with OFI (libfabric)"
}
module-whatis "MPICH %{version}"
conflict mpich
conflict openmpi
prepend-path PATH %{_libdir}/mpich5/bin
prepend-path LD_LIBRARY_PATH %{_libdir}/mpich5
prepend-path MANPATH %{_mandir}/mpich5
setenv MPI_HOME %{_libdir}/mpich5
EOF

%files
%license COPYRIGHT
%doc %{_datadir}/doc/mpich5/
%config(noreplace) %{_sysconfdir}/mpixxx_opts.conf
%dir %{_libdir}/mpich5
%dir %{_libdir}/mpich5/bin
%{_libdir}/mpich5/lib*.so.*
%{_libdir}/mpich5/bin/mpirun
%{_libdir}/mpich5/bin/mpiexec
%{_libdir}/mpich5/bin/mpiexec.hydra
%{_libdir}/mpich5/bin/hydra_*
%{_libdir}/mpich5/bin/mpichversion
%{_libdir}/mpich5/bin/mpivars
%{_libdir}/mpich5/bin/parkill
%{_mandir}/mpich5/
%{_datadir}/modules/mpich5/

%files devel
%{_includedir}/mpich5/
%{_libdir}/mpich5/lib*.so
%{_libdir}/mpich5/bin/mpicc
%{_libdir}/mpich5/bin/mpicxx
%{_libdir}/mpich5/bin/mpic++
%{_libdir}/mpich5/bin/mpif77
%{_libdir}/mpich5/bin/mpif90
%{_libdir}/mpich5/bin/mpifort
%{_libdir}/mpich5/pkgconfig/

%changelog
