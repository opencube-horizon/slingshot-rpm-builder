%define isal_version %{?isal_ver}%{!?isal_ver:2.32.1}

Name:           libisal
Version:        %{isal_version}
Release:        1
Summary:        Intel Intelligent Storage Acceleration Library
License:        BSD-3-Clause
URL:            https://github.com/intel/isa-l

Source0:        isa-l-%{version}.tar.gz

BuildRequires:  autoconf automake libtool
%ifarch x86_64
BuildRequires:  nasm >= 2.14
%endif

%description
ISA-L is a collection of optimized low-level functions targeting storage
applications. It includes CRC, erasure codes, hashing, and compression.

%package devel
Summary:        Development files for ISA-L
Requires:       %{name} = %{version}-%{release}

%description devel
Headers and libraries for developing applications using ISA-L.

%prep
%autosetup -n isa-l-%{version}

%build
./autogen.sh
%configure --prefix=%{_prefix} --libdir=%{_libdir}
%make_build

%install
%make_install
rm -f %{buildroot}%{_libdir}/*.la

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%files
%license LICENSE
%{_libdir}/libisal.so.*

%files devel
%{_includedir}/isa-l.h
%{_includedir}/isa-l/
%{_libdir}/libisal.so
%{_libdir}/libisal.a
%{_libdir}/pkgconfig/libisal.pc
