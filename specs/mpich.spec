%global mpich_version 4.3.2

Name:           mpich
Version:        %{mpich_version}
Release:        1
Summary:        High-performance MPI implementation (OFI/libfabric backend)
License:        MIT
URL:            https://www.mpich.org
Source0:        mpich-%{version}.tar.gz

BuildRequires:  gcc
BuildRequires:  gcc-c++
BuildRequires:  gcc-fortran
BuildRequires:  python3
BuildRequires:  hwloc-devel
# openSUSE calls it libnuma-devel; EL ships the same headers in numactl-devel
%if 0%{?suse_version}
BuildRequires:  libnuma-devel
%else
BuildRequires:  numactl-devel
%endif
BuildRequires:  libfabric-devel

Requires:       libfabric

%description
MPICH is a high-performance and widely portable implementation of the
MPI standard (MPI-1, MPI-2, and MPI-3). This build uses the OFI
(libfabric) network layer with the ch4 device for Slingshot support.

%package devel
Summary:        Development files for MPICH
Requires:       %{name} = %{version}-%{release}
Requires:       gcc-fortran

%description devel
Headers, modules, and compiler wrappers for building MPI applications
with MPICH.

%prep
%setup -q -n mpich-%{version}

%build
%configure \
  --prefix=%{_prefix} \
  --libdir=%{_libdir}/mpich \
  --includedir=%{_includedir}/mpich \
  --bindir=%{_libdir}/mpich/bin \
  --mandir=%{_mandir}/mpich \
  --docdir=%{_datadir}/doc/mpich \
  --with-device=ch4:ofi \
  --with-libfabric \
  --enable-shared \
  --disable-static \
  --enable-fortran=all \
  --enable-romio \
  --disable-dependency-tracking \
%if 0%{?suse_version}
  FFLAGS="-w" FCFLAGS="-w"
%else
  # EL forces -pie at link; keep the distro Fortran flags (incl. -fPIE) and only append -w,
  # otherwise a bare -w drops PIE codegen and the hardened linker rejects the objects
  FFLAGS="%{build_fflags} -w" FCFLAGS="%{build_fflags} -w"
%endif

%make_build

%install
%make_install

# Remove libtool archives (not needed for shared-only build)
find %{buildroot} -name '*.la' -delete

# Create modulefile
mkdir -p %{buildroot}%{_datadir}/modules/mpich
cat > %{buildroot}%{_datadir}/modules/mpich/%{version} <<EOF
#%%Module
proc ModulesHelp { } {
  puts stderr "MPICH %{version} with OFI (libfabric)"
}
module-whatis "MPICH %{version}"
prepend-path PATH %{_libdir}/mpich/bin
prepend-path LD_LIBRARY_PATH %{_libdir}/mpich
prepend-path MANPATH %{_mandir}/mpich
setenv MPI_HOME %{_libdir}/mpich
EOF

%files
%license COPYRIGHT
%doc %{_datadir}/doc/mpich/
%config(noreplace) %{_sysconfdir}/mpixxx_opts.conf
%dir %{_libdir}/mpich
%dir %{_libdir}/mpich/bin
%{_libdir}/mpich/lib*.so.*
%{_libdir}/mpich/bin/mpirun
%{_libdir}/mpich/bin/mpiexec
%{_libdir}/mpich/bin/mpiexec.hydra
%{_libdir}/mpich/bin/hydra_*
%{_libdir}/mpich/bin/mpichversion
%{_libdir}/mpich/bin/mpivars
%{_libdir}/mpich/bin/parkill
%{_mandir}/mpich/
%{_datadir}/modules/mpich/

%files devel
%{_includedir}/mpich/
%{_libdir}/mpich/lib*.so
%{_libdir}/mpich/bin/mpicc
%{_libdir}/mpich/bin/mpicxx
%{_libdir}/mpich/bin/mpic++
%{_libdir}/mpich/bin/mpif77
%{_libdir}/mpich/bin/mpif90
%{_libdir}/mpich/bin/mpifort
%{_libdir}/mpich/pkgconfig/

%changelog
