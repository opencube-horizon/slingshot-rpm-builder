%global argobots_version 1.2

Name:           argobots
Version:        %{argobots_version}
Release:        1
Summary:        Argobots — lightweight threading framework for HPC
License:        BSD-2-Clause
URL:            https://github.com/pmodels/argobots
Source0:        argobots-%{version}.tar.gz

BuildRequires:  gcc
BuildRequires:  autoconf
BuildRequires:  automake
BuildRequires:  libtool

%description
Argobots is a lightweight, low-level threading and tasking framework.
It provides user-level threads (ULTs), tasklets, and thread pools optimized
for HPC runtimes. Used by Mercury, MPICH, and other HPC middleware.

%package devel
Summary:        Development files for Argobots
Requires:       %{name} = %{version}-%{release}

%description devel
Development headers and libraries for building against Argobots.

%prep
%setup -q -n argobots-%{version}

%build
test -f configure || ./autogen.sh
%configure \
  --enable-shared \
  --disable-static \
  --enable-perf-opt
%make_build

%install
%make_install
rm -f %{buildroot}%{_libdir}/*.la

%files
%license COPYRIGHT
%{_libdir}/libabt.so.*

%files devel
%{_includedir}/abt.h
%{_libdir}/libabt.so
%{_libdir}/pkgconfig/argobots.pc

%changelog
