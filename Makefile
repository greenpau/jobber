# GNU-standard vars (cf. http://www.gnu.org/prep/standards/html_node/Makefile-Conventions.html)
SHELL = /bin/sh
prefix = /usr/local
exec_prefix = ${prefix}
bindir = ${exec_prefix}/bin
libexecdir = ${exec_prefix}/libexec
srcdir = .
INSTALL = install
INSTALL_PROGRAM = ${INSTALL}
GO_EXE_BUILD_ARGS=

GO_WKSPC ?= ${abspath ../../../..}
LIB = jobber.a
TEST_TMPDIR = ${PWD}
DIST_PKG_NAME = jobber-$(shell cat ${srcdir}/version)

# read lists of source files
include common/sources.mk \
		jobbermaster/sources.mk \
		jobfile/sources.mk \
		packaging/sources.mk
FINAL_LIB_SOURCES := \
	$(COMMON_SOURCES:%=common/%) \
	$(JOBFILE_SOURCES:%=jobfile/%)
FINAL_LIB_TEST_SOURCES := \
	$(COMMON_TEST_SOURCES:%=common/%) \
	$(JOBFILE_TEST_SOURCES:%=jobfile/%)
FINAL_MASTER_SOURCES := $(MASTER_SOURCES:%=jobbermaster/%)
FINAL_MASTER_TEST_SOURCES := $(MASTER_TEST_SOURCES:%=jobbermaster/%)
FINAL_PACKAGING_SOURCES := $(PACKAGING_SOURCES:%=packaging/%)

GO_SOURCES := \
	${FINAL_LIB_SOURCES} \
	${FINAL_LIB_TEST_SOURCES} \
	${FINAL_MASTER_SOURCES} \
	${FINAL_MASTER_TEST_SOURCES}
OTHER_SOURCES := \
	Makefile \
	common/sources.mk \
	jobbermaster/sources.mk \
	jobfile/sources.mk \
	packaging/sources.mk \
	buildtools \
	README.md \
	LICENSE \
	version \
	Godeps \
	${FINAL_PACKAGING_SOURCES}

ALL_SOURCES := \
	${GO_SOURCES} \
	${OTHER_SOURCES}

LDFLAGS = -ldflags "-X github.com/dshearer/jobber/common.jobberVersion=`cat version`"

SE_FILES = se_policy/jobber.fc \
           se_policy/jobber.if \
           se_policy/jobber.te \
           ${wildcard se_policy/include/**} \
           se_policy/Makefile \
           se_policy/policygentool

.PHONY : all
all : lib ${GO_WKSPC}/bin/jobbermaster

.PHONY : check
check : ${FINAL_LIB_TEST_SOURCES} ${FINAL_MASTER_TEST_SOURCES}
	TMPDIR="${TEST_TMPDIR}" go test github.com/dshearer/jobber/jobfile

.PHONY : installcheck
installcheck :
	./test_installation

.PHONY : installdirs
installdirs :
	"${srcdir}/buildtools/mkinstalldirs" "${DESTDIR}${bindir}" "${DESTDIR}${libexecdir}"

.PHONY : install
install : installdirs ${GO_WKSPC}/bin/jobbermaster
	# install files
	"${INSTALL_PROGRAM}" "${GO_WKSPC}/bin/jobbermaster" "${DESTDIR}${libexecdir}"

.PHONY : uninstall
uninstall :
	-rm "${DESTDIR}${libexecdir}/jobbermaster"

dist : ${ALL_SOURCES}
	mkdir -p "dist-tmp/${DIST_PKG_NAME}" `dirname "${DESTDIR}${DIST_PKG_NAME}.tgz"`
	"${srcdir}/buildtools/srcsync" ${ALL_SOURCES} "dist-tmp/${DIST_PKG_NAME}"
	tar -C dist-tmp -czf "${DESTDIR}${DIST_PKG_NAME}.tgz" "${DIST_PKG_NAME}"
	rm -rf dist-tmp

.PHONY : clean
clean :
	-go clean -i github.com/dshearer/jobber/common
	-go clean -i github.com/dshearer/jobber/jobfile
	-go clean -i "github.com/dshearer/jobber/jobbermaster"
	rm -f "${DESTDIR}${DIST_PKG_NAME}.tgz"
	


.PHONY : lib
lib : ${FINAL_LIB_SOURCES}
	go install ${LDFLAGS} "github.com/dshearer/jobber/common"
	go install ${LDFLAGS} "github.com/dshearer/jobber/jobfile"

${GO_WKSPC}/bin/jobbermaster : ${FINAL_MASTER_SOURCES} lib
	go install ${LDFLAGS} ${GO_EXE_BUILD_ARGS} github.com/dshearer/jobber/jobbermaster


## OLD:

/etc/init.d/jobber : jobber_init
	install -T -o root -g root -m 0755 "$<" "$@"
	chkconfig --add jobber
	chkconfig jobber on

/var/lock/subsys/jobber : ${DESTDIR}/sbin/${DAEMON} /etc/init.d/jobber
	service jobber restart

se_policy/.installed : ${SE_FILES}
	-[ -f /etc/sysconfig/selinux ] && ${MAKE} -C se_policy && semodule -i "$<" -v && restorecon -Rv /usr/local /etc/init.d
	touch "$@"

.PHONY : uninstall-bin
uninstall-bin :
	rm -f "${DESTDIR}/bin/${CLIENT}" "${DESTDIR}/sbin/${DAEMON}"

.PHONY : uninstall-centos
uninstall-centos :
	service jobber stop
	chkconfig jobber off
	chkconfig --del jobber
	rm -f /etc/init.d/jobber
	-[ -f /etc/sysconfig/selinux ] && semodule -r jobber -v
	rm -f se_policy/.installed

