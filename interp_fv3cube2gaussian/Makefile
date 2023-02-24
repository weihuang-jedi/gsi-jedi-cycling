#-----------------------------------------------------------------------------

include make_rules

####################################################

OBJS =	module_namelist.o \
	nc_get1Dint.o \
	nc_get1Dvar.o \
	nc_get2Dint.o \
	nc_get2Dvar.o \
	nc_get3Dint.o \
	nc_get3Dvar.o \
	nc_get4Dvar.o \
	nc_get5Dvar.o \
	nc_getGlobalIntAttr.o \
	nc_getGlobalRealAttr.o \
	nc_getGlobalCharAttr.o \
	nc_put_single_int.o \
	nc_put1Dvar.o \
	nc_put1Dint.o \
	nc_put2Dvar.o \
	nc_put2Dint.o \
	nc_put3Dvar.o \
	nc_put3Dint.o \
	nc_put4Dvar.o \
	nc_put5Dvar.o \
	nc_putChar.o \
	nc_putAttr.o \
	nc_putAxisAttr.o \
	nc_putAxisIntAttr.o \
	nc_putIntAttr.o \
	nc_putGlobalIntAttr.o \
	nc_putGlobalRealAttr.o \
	nc_putGlobalCharAttr.o \
	tile_module.o \
	latlon_module.o \
	gaussian_module.o \
	read_weights.o \
	read_weights4gaussian.o \
	output_tilegrid.o \
	output_gaussiangrid.o \
	output_latlongrid.o \
	status_module.o \
	fv_grid_utils.o \
	interp2gaussian.o \
	interp2latlon.o

####################################################

deflt :	clean_modulde nc4_lib fv3interp

clean_modulde :
	$(RM) latlon_module.f90 latlon_module.mod latlon_module.o tile_module.f90 tile_module.mod tile_module.o

nc4_lib : $(OBJS)
	$(RM) libnc4.a
	$(AR) libnc4.a $(OBJS)
	$(RANLIB) libnc4.a

fv3interp : fv3interp.o
	$(FC) -o fv3interp.exe fv3interp.o $(FFLAGS) $(LOC_LIBS) \
	libnc4.a

clean :
	$(RM) libnc4.a $(OBJS) fv3interp.o \
	*.f90 *.mod *.exe

####################################################

# DEPENDENCIES : only dependencies after this line (don't remove the word DEPENDENCIES)

fv3interp.o : fv3interp.F90 \
		tile_module.o \
		gaussian_module.o \
		latlon_module.o	\
		module_namelist.o

tile_module.o : tile_module.F90 \
		status_module.o

latlon_module.o : latlon_module.F90 \
		status_module.o

gaussian_module.o : gaussian_module.F90 \
		status_module.o

