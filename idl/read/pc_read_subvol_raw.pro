; +
; NAME:
;       PC_READ_SUBVOL_RAW
;
; PURPOSE:
;       Read sub-volumes from var.dat, or other VAR files in an efficient way!
;
;       Returns one array from a snapshot (var) file generated by a
;       Pencil Code run, and another array with the variable labels.
;       If you need to be efficient, please use 'io_hdf5' or 'pc_collect.x'
;       to combine distributed varfiles before reading them in IDL.
;       This routine can also read reduced datasets from 'pc_reduce.x'.
;
; CATEGORY:
;       Pencil Code, File I/O
;
; CALLING SEQUENCE:
;       pc_read_subvol_raw, object=object, varfile=varfile, tags=tags,       $
;           datadir=datadir, var_list=var_list, varcontent=varcontent,       $
;           start_param=start_param, run_param=run_param, allprocs=allprocs, $
;           xs=xs, xe=xe, ys=ys, ye=ye, zs=zs, ze=ze, /addghosts, /trimall,  $
;           dim=dim, sub_dim=sub_dim, grid=grid, sub_grid=sub_grid,          $
;           time=time, name=name, /quiet, /swap_endian, /f77, /reduced
;
; KEYWORD PARAMETERS:
;    datadir: Specifies the root data directory. Default: './data'.  [string]
;    varfile: Name of the snapshot. Default: 'var.dat' or 'var.h5'.  [string]
;       time: Timestamp of the snapshot.                             [float]
;       name: Name to be used for the generated sub_grid structure.  [string]
;   allprocs: Load distributed (0) or collective (1 or 2) varfiles.  [integer]
;   /reduced: Load previously reduced collective varfiles (implies allprocs=1).
;        dim: Dimension structure of the global 3D-setup.            [struct]
;    sub_dim: Returns a dimension structure of the loaded sub-volume.[struct]
;       grid: Grid structure of the global 3D-setup.                 [struct]
;   sub_grid: Returns a grid structure of the loaded sub-volume.     [struct]
;
;      xs/xe: starting/ending x-coordinate of the sub-volume.        [integer]
;      ys/ye: starting/ending y-coordinate of the sub-volume.        [integer]
;      zs/ze: starting/ending z-coordinate of the sub-volume.        [integer]
;             Default values are the first/last physical grid points [l1:l2,m1:m2,n1:n2].
;
;     object: Array with the loaded data is retured.                 [4D-array]
;       tags: Structure of tag names and their indices withhin data. [structure]
;   var_list: Array of varcontent idlvars to read (default = all).   [string(*)]
;
; /addghosts: Adds ghost layers to the given x/y/z starting/ending coordinates.
;   /trimall: Remove ghost layers from the returned data, dim and grid.
;     /quiet: Suppress any information messages and summary statistics.
;
; EXAMPLES:
;
; * Load a sub-volume and display it in a GUI:
;       pc_read_subvol_raw, obj=vars, tags=tags, var_list=["lnrho","uu"], xs=10, xe=14, ys=11, ye=49
;       cmp_cslice, { uz:vars[*,*,*,tags.uz], lnrho:vars[*,*,*,tags.lnrho] }
;
; * Load a sub-volume including ghost cells and compute some physical quantity:
;       pc_read_subvol_raw, obj=vars, tags=tags, sub_dim=dim, sub_grid=grid, xs=10, xe=14, ys=11, ye=49, /addghosts
;       HR_ohm = pc_get_quantity ('HR_ohm', vars, tags, dim=dim)
;       tvscl, HR_ohm[*,*,0]          ; Display lowest physical z-layer.
;       tvscl, HR_ohm[dim.nx-1,*,*]   ; Display rightmost physical yz-cut.
;       cslice, HR_ohm                ; Explore 3D sub-volume in a GUI.
;
; MODIFICATION HISTORY:
;       $Id$
;       Adapted from: pc_read_slice_raw.pro, 4th May 2012
;
;-
pro pc_read_subvol_raw, object=object, varfile=varfile, tags=tags, datadir=datadir, var_list=var_list, varcontent=varcontent, start_param=start_param, run_param=run_param, trimall=trimall, allprocs=allprocs, reduced=reduced, xs=xs, xe=xe, ys=ys, ye=ye, zs=zs, ze=ze, addghosts=addghosts, dim=dim, sub_dim=sub_dim, grid=grid, sub_grid=sub_grid, time=time, name=name, quiet=quiet, swap_endian=swap_endian, f77=f77

	; Use common block belonging to derivative routines etc. so they can be set up properly.
	common cdat, x, y, z, mx, my, mz, nw, ntmax, date0, time0, nghostx, nghosty, nghostz
	common cdat_limits, l1, l2, m1, m2, n1, n2, nx, ny, nz
	common cdat_grid, dx_1, dy_1, dz_1, dx_tilde, dy_tilde, dz_tilde, lequidist, lperi, ldegenerated
	common pc_precision, zero, one, precision, data_type, data_bytes, type_idl
	common cdat_coords, coord_system

	; Default settings.
	default, reduced, 0
	default, addghosts, 0
	default, swap_endian, 0
	if (keyword_set (name)) then name += "_" else name = "pc_read_subvol_raw_"
	if (keyword_set (reduced)) then allprocs = 1

	; Default data directory.
	datadir = pc_get_datadir(datadir)

	; Name and path of varfile to read.
	if (not keyword_set (varfile)) then begin
		varfile = 'var.dat'
		if (file_test (datadir+'/allprocs/var.h5')) then varfile = 'var.h5'
	end else begin
		if (file_test (datadir+'/allprocs/'+varfile+'.h5')) then varfile += '.h5'
	end

	; Get necessary dimensions quietly.
	if (n_elements (dim) eq 0) then pc_read_dim, object=dim, datadir=datadir, reduced=reduced, /quiet

	; Local shorthand for some parameters.
	nxgrid = dim.nxgrid
	nygrid = dim.nygrid
	nzgrid = dim.nzgrid
	nwgrid = nxgrid * nygrid * nzgrid
	mxgrid = dim.mxgrid
	mygrid = dim.mygrid
	mzgrid = dim.mzgrid
	mwgrid = mxgrid * mygrid * mzgrid
	nghostx = dim.nghostx
	nghosty = dim.nghosty
	nghostz = dim.nghostz

	; Subvolume grid indizes.
	xgs = xs
	ygs = ys
	zgs = zs
	if (addghosts) then begin
		default, xs, 0
		default, ys, 0
		default, zs, 0
		default, xe, xs + nxgrid - 1
		default, ye, ys + nygrid - 1
		default, ze, zs + nzgrid - 1
		xge = xe + 2 * nghostx
		yge = ye + 2 * nghosty
		zge = ze + 2 * nghostz
	end else begin
		default, xs, 0
		default, ys, 0
		default, zs, 0
		default, xe, mxgrid - 1
		default, ye, mygrid - 1
		default, ze, mzgrid - 1
		xge = xe
		yge = ye
		zge = ze
	end
	xns = xgs + nghostx
	xne = xge - nghostx
	yns = ygs + nghosty
	yne = yge - nghosty
	zns = zgs + nghostz
	zne = zge - nghostz
	gx_delta = xge - xgs + 1
	gy_delta = yge - ygs + 1
	gz_delta = zge - zgs + 1

	if (any ([xgs, xne-xns, ygs, yne-yns, zgs, zne-zns] lt 0) or any ([xge, yge, zge] ge [mxgrid, mygrid, mzgrid])) then $
		message, 'pc_read_subvol_raw: sub-volume indices are invalid.'

	; Get necessary parameters quietly.
	if (size (start_param, /type) ne 8) then $
		pc_read_param, object=start_param, dim=dim, datadir=datadir, /quiet
	if (size (run_param, /type) ne 8) then begin
		if (file_test (datadir+'/param2.nml')) then begin
			pc_read_param, object=run_param, /param2, dim=dim, datadir=datadir, /quiet
		endif else begin
			print, 'Could not find '+datadir+'/param2.nml'
		endelse
	endif

	; Set the coordinate system.
	coord_system = start_param.coord_system

	; Read the grid, if needed.
	if (size (grid, /type) ne 8) then $
		pc_read_grid, object=grid, dim=dim, param=start_param, datadir=datadir, allprocs=allprocs, reduced=reduced, /quiet

	; Read timestamp.
	pc_read_var_time, time=time, varfile=varfile, datadir=datadir, allprocs=allprocs, reduced=reduced, procdim=procdim, param=start_param, /quiet

	; Generate dim structure of the sub-volume.
	sub_dim = dim
	sub_dim.mx = gx_delta
	sub_dim.my = gy_delta
	sub_dim.mz = gz_delta
	sub_dim.nx = gx_delta - 2*nghostx
	sub_dim.ny = gy_delta - 2*nghosty
	sub_dim.nz = gz_delta - 2*nghostz
	sub_dim.mxgrid = sub_dim.mx
	sub_dim.mygrid = sub_dim.my
	sub_dim.mzgrid = sub_dim.mz
	sub_dim.nxgrid = sub_dim.nx
	sub_dim.nygrid = sub_dim.ny
	sub_dim.nzgrid = sub_dim.nz
	sub_dim.mw = sub_dim.mx * sub_dim.my * sub_dim.mz
	sub_dim.l1 = nghostx
	sub_dim.m1 = nghosty
	sub_dim.n1 = nghostz
	sub_dim.l2 = sub_dim.mx - nghostx - 1
	sub_dim.m2 = sub_dim.my - nghosty - 1
	sub_dim.n2 = sub_dim.mz - nghostz - 1

	; Overwrite with sub-volume dimensions for correct derivatives.
	nx = sub_dim.nx
	ny = sub_dim.ny
	nz = sub_dim.nz
	nw = nx * ny * nz
	mx = sub_dim.mx
	my = sub_dim.my
	mz = sub_dim.mz
	mw = mx * my * mz
	l1 = sub_dim.l1
	l2 = sub_dim.l2
	m1 = sub_dim.m1
	m2 = sub_dim.m2
	n1 = sub_dim.n1
	n2 = sub_dim.n2

	; Crop grid.
	x = grid.x[xgs:xge]
	y = grid.y[ygs:yge]
	z = grid.z[zgs:zge]

	; Prepare for derivatives.
	dx = grid.dx
	dy = grid.dy
	dz = grid.dz
	dx_1 = grid.dx_1[xgs:xge]
	dy_1 = grid.dy_1[ygs:yge]
	dz_1 = grid.dz_1[zgs:zge]
	dx_tilde = grid.dx_tilde[xgs:xge]
	dy_tilde = grid.dy_tilde[ygs:yge]
	dz_tilde = grid.dz_tilde[zgs:zge]
	Ox = grid.Ox
	Oy = grid.Oy
	Oz = grid.Oz
	Lx = grid.Lx
	Ly = grid.Ly
	Lz = grid.Lz
	if (xge-xgs ne mxgrid-1) then begin
		Ox = grid.x[xns]
		Lx = total (1.0/grid.dx_1[xns:xne])
		lperi[0] = 0
	endif
	if (yge-ygs ne mygrid-1) then begin
		Oy = grid.y[yns]
		Ly = total (1.0/grid.dy_1[yns:yne])
		lperi[1] = 0
	endif
	if (zge-zgs ne mzgrid-1) then begin
		Oz = grid.z[zns]
		Lz = total (1.0/grid.dz_1[zns:zne])
		lperi[2] = 0
	endif
	ldegenerated = [ xge-xgs, yge-ygs, zge-zgs ] lt 2 * [ nghostx, nghosty, nghostz ]

	if (keyword_set (reduced)) then name += "reduced_"

	; Remove ghost zones from grid, if requested.
	if (keyword_set (trimall)) then begin
		x = x[l1:l2]
		y = y[m1:m2]
		z = z[n1:n2]
		dx_1 = dx_1[l1:l2]
		dy_1 = dy_1[m1:m2]
		dz_1 = dz_1[n1:n2]
		dx_tilde = dx_tilde[l1:l2]
		dy_tilde = dy_tilde[m1:m2]
		dz_tilde = dz_tilde[n1:n2]
		ldegenerated = [ l1, m1, n1 ] eq [ l2, m2, n2 ]
		name += "trimmed_"
	endif

	if (not keyword_set (quiet)) then begin
		print, ' t = ', time
		print, ''
	endif

	name += strtrim (xgs, 2)+"_"+strtrim (xge, 2)+"_"+strtrim (ygs, 2)+"_"+strtrim (yge, 2)+"_"+strtrim (zgs, 2)+"_"+strtrim (zge, 2)
	sub_grid = create_struct (name=name, $
		['t', 'x', 'y', 'z', 'dx', 'dy', 'dz', 'Ox', 'Oy', 'Oz', 'Lx', 'Ly', 'Lz', 'dx_1', 'dy_1', 'dz_1', 'dx_tilde', 'dy_tilde', 'dz_tilde', 'lequidist', 'lperi', 'ldegenerated', 'x_off', 'y_off', 'z_off'], $
		time, x, y, z, dx, dy, dz, Ox, Oy, Oz, Lx, Ly, Lz, dx_1, dy_1, dz_1, dx_tilde, dy_tilde, dz_tilde, lequidist, lperi, ldegenerated, xns-nghostx, yns-nghosty, zns-nghostz)

	; Load HDF5 varfile if requested or available.
	if (strmid (varfile, strlen(varfile)-3) eq '.h5') then begin
		time = pc_read ('time', file=varfile, datadir=datadir)
		if (size (varcontent, /type) ne 8) then begin
			varcontent = pc_varcontent(datadir=datadir,dim=dim,param=param,par2=par2,quiet=quiet,scalar=scalar,noaux=noaux,run2D=run2D,down=ldownsampled,single=single)
		end
		quantities = varcontent[*].idlvar
		num_quantities = n_elements (quantities)
		if (keyword_set (trimall)) then begin
			xgs = xns
			ygs = yns
			zgs = zns
			gx_delta -= 2*nghostx
			gy_delta -= 2*nghosty
			gz_delta -= 2*nghostz
		end
		object = dblarr (gx_delta, gy_delta, gz_delta, num_quantities)
		tags = { time:time }
		start = [ xgs, ygs, zgs ]
		count = [ gx_delta, gy_delta, gz_delta ]
		for pos = 0L, num_quantities-1 do begin
			if (quantities[pos] eq 'dummy') then continue
			num_skip = varcontent[pos].skip
			if (num_skip eq 2) then begin
				length = strlen (quantities[pos])
				if ((length eq 2) and (strmid (quantities[pos], 0, 1) eq strmid (quantities[pos], 1, 1))) then length--
				label = strmid (quantities[pos], 0, length)
				object[*,*,*,pos] = pc_read ('data/'+label+'x', start=start, count=count, dim=dim)
				object[*,*,*,pos+1] = pc_read ('data/'+label+'y', start=start, count=count, dim=dim)
				object[*,*,*,pos+2] = pc_read ('data/'+label+'z', start=start, count=count, dim=dim)
				tags = create_struct (tags, quantities[pos], pos + indgen (num_skip+1), label+'x', pos, label+'y', pos+1, label+'z', pos+2)
				pos += num_skip
			end else if (num_skip ge 1) then begin
				tags = create_struct (tags, quantities[pos], pos + indgen (num_skip+1))
				for comp = 0, num_skip do begin
				label = quantities[pos] + strtrim(comp+1, 2)
				object[*,*,*,pos+comp] = pc_read ('data/'+label, start=start, count=count, dim=dim)
				tags = create_struct (tags, label, pos + comp)
				end
				pos += num_skip
			end else begin
				object[*,*,*,pos] = pc_read ('data/'+quantities[pos], start=start, count=count, dim=dim)
				tags = create_struct (tags, quantities[pos], pos)
			end
		end
		h5_close_file
		return
	end

	; Automatically switch to allprocs, if necessary.
	if (size (allprocs, /type) eq 0) then begin
		if (file_test (datadir+'/allprocs/'+varfile)) then begin
			allprocs = 1
		end else if (file_test (datadir+'/proc0/'+varfile) and file_test (datadir+'/proc1/', /directory) and not file_test (datadir+'/proc1/'+varfile)) then begin
			allprocs = 2
		end
	end
	default, allprocs, 0

	; Set f77 keyword according to allprocs.
	if (allprocs eq 1) then default, f77, 0
	default, f77, 1

	; Read local dimensions.
	ipx_start = 0
	ipy_start = 0
	ipz_start = 0
	if (allprocs eq 1) then begin
		procdim = dim
		ipx_end = 0
		ipy_end = 0
		ipz_end = 0
	end else begin
		pc_read_dim, object=procdim, proc=0, datadir=datadir, /quiet
		if (allprocs eq 2) then begin
			ipx_end = 0
			ipy_end = 0
			procdim.nx = procdim.nxgrid
			procdim.ny = procdim.nygrid
			procdim.mx = procdim.mxgrid
			procdim.my = procdim.mygrid
			procdim.mw = procdim.mx * procdim.my * procdim.mz
		end else begin
			ipx_start = xgs / procdim.nx
			ipy_start = ygs / procdim.ny
			ipx_end   = (xe - 2 * nghostx) / procdim.nx
			ipy_end   = (ye - 2 * nghosty) / procdim.ny
		end
		ipz_start = zs / procdim.nz
		ipz_end   = (ze - 2 * nghostz) / procdim.nz
	end

	; Read meta data and set up variable/tag lists.
	if (size (varcontent, /type) ne 8) then $
		varcontent = pc_varcontent(datadir=datadir,dim=dim,param=start_param,quiet=quiet)
	totalvars = (size(varcontent))[1]
	if (size (var_list, /type) eq 0) then begin
		var_list = varcontent[*].idlvar
		var_list = var_list[where (var_list ne "dummy")]
	endif

	; Display information about the files contents.
	content = ''
	for iv=0L, totalvars-1L do begin
		content += ', '+varcontent[iv].variable
		; For vector quantities skip the required number of elements of the f array.
		iv += varcontent[iv].skip
	endfor
	content = strmid (content, 2)

	tags = { time:time }
	read_content = ''
	indices = [ -1 ]
	num_read = 0
	num = n_elements (var_list)
	for ov=0L, num-1L do begin
		tag = var_list[ov]
		iv = where (varcontent[*].idlvar eq tag)
		if (iv ge 0) then begin
			if (varcontent[iv].skip eq 2) then begin
				label = strmid (tag, 0, 1)
				tags = create_struct (tags, tag, [num_read, num_read+1, num_read+2])
				tags = create_struct (tags, label+"x", num_read, label+"y", num_read+1, label+"z", num_read+2)
				indices = [ indices, iv, iv+1, iv+2 ]
				num_read += 3
			endif else begin
				tags = create_struct (tags, tag, num_read)
				indices = [ indices, iv ]
				num_read++
			endelse
			read_content += ', '+varcontent[iv].variable
		endif
	endfor
	read_content = strmid (read_content, 2)
	if (not keyword_set (quiet)) then begin
		print, ''
		print, 'The file '+varfile+' contains: ', content
		if (strlen (read_content) lt strlen (content)) then print, 'Will read only: ', read_content
		print, ''
		print, 'The sub-volume dimension is ', sub_dim.mx, sub_dim.my, sub_dim.mz
		print, ''
	endif
	if (f77 eq 0) then markers = 0 else markers = 1

	if (num_read le 0) then begin
		if (not keyword_set (quiet)) then message, 'WARNING: nothing to read!'
	end else begin
		indices = indices[where (indices ge 0)]

		; Initialize output buffer.
		object = make_array (gx_delta, gy_delta, gz_delta, num_read, type=type_idl)
	end

	; Iterate over processors.
	for ipz = ipz_start, ipz_end do begin
		if (num_read le 0) then continue
		for ipy = ipy_start, ipy_end do begin
			for ipx = ipx_start, ipx_end do begin
				; Set sub-volume parameters.
				if (ipx eq ipx_start) then px_start = xgs - ipx * procdim.nx else px_start = nghostx
				if (ipy eq ipy_start) then py_start = ygs - ipy * procdim.ny else py_start = nghosty
				if (ipz eq ipz_start) then pz_start = zgs - ipz * procdim.nz else pz_start = nghostz
				if (ipx eq ipx_end) then px_end = xge - ipx * procdim.nx else px_end = procdim.mx - 1 - nghostx
				if (ipy eq ipy_end) then py_end = yge - ipy * procdim.ny else py_end = procdim.my - 1 - nghosty
				if (ipz eq ipz_end) then pz_end = zge - ipz * procdim.nz else pz_end = procdim.mz - 1 - nghostz
				px_delta = px_end - px_start + 1
				py_delta = py_end - py_start + 1
				pz_delta = pz_end - pz_start + 1

				; Initialize read buffer.
				buffer = make_array (px_delta, type=type_idl)

				; Initialize processor specific parameters.
				iproc = ipx + ipy*dim.nprocx + ipz*dim.nprocx*dim.nprocy
				if (ipx eq ipx_start) then x_off = 0 else x_off = nghostx + ipx * procdim.nx - xgs
				if (ipy eq ipy_start) then y_off = 0 else y_off = nghosty + ipy * procdim.ny - ygs
				if (ipz eq ipz_start) then z_off = 0 else z_off = nghostz + ipz * procdim.nz - zgs
				if (allprocs eq 1) then begin
					if (keyword_set (reduced)) then procdir = 'reduced' else procdir = 'allprocs'
				end else begin
					procdir = 'proc' + strtrim (iproc, 2)
				end

				; Build the full path and filename.
				filename = datadir+'/'+procdir+'/'+varfile

				; Check for existence and read the data.
				if (not file_test(filename)) then message, 'ERROR: File not found "'+filename+'"'

				; Open a varfile and read some data!
				openr, lun, filename, swap_endian=swap_endian, /get_lun
				mx = long64 (procdim.mx)
				mxy = mx * procdim.my
				mxyz = mxy * procdim.mz
				for pos = 0, num_read-1 do begin
					pa = indices[pos]
					for pz = pz_start, pz_end do begin
						for py = py_start, py_end do begin
							point_lun, lun, data_bytes * (px_start + py*mx + pz*mxy + pa*mxyz) + long64 (markers*4)
							readu, lun, buffer
							object[x_off:x_off+px_delta-1,y_off+py-py_start,z_off+pz-pz_start,pos] = buffer
						endfor
					endfor
				endfor
				close, lun
				free_lun, lun
			end
		end
	end

	; Tidy memory a little.
	undefine, buffer

	; Remove ghost zones from data, if requested.
	if (keyword_set (trimall) and (num_read ge 1)) then object = object[l1:l2,m1:m2,n1:n2,*]

END

