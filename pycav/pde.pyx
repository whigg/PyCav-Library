import numpy as np
from scipy.linalg import solve_banded
from scipy.fftpack import fft,ifft,fft2,ifft2

def LW_wave_equation(psi_0, x_list, dx, N, c, a = 1., bound_cond = 'periodic',init_grad = None, init_vel = None):

	dim = len(psi_0.shape)
	len_x = psi_0.shape[0]
	if dim > 1:
		len_y = psi_0.shape[1]

	if dim > 2 or dim < 1:
		print('1D or 2D only, adjust initial wave array')
		return 0

	if dim == 1:
		psi = np.zeros((len_x,N))
		psi[:,0] = psi_0
		x = x_list
		dt = a*dx/c(x).max()
		alpha = a/c(x).max()

	if dim == 2:
		psi = np.zeros((len_x,len_y,N))
		psi[:,:,0] = psi_0
		y = x_list[1]
		x = x_list[0]
		dt = a*dx/c(x,y).max()
		alpha = a/c(x,y).max()

	if init_vel == None:
		def _vel_0():
			def _V(psi_0):
				return np.zeros_like(psi_0)
			return _V
		V = _vel_0()
	else:
		V = init_vel

	t = np.linspace(0.,(N-1)*dt,N)

	# If no gradient function is given then the gradient is estimated from the 
	# initial wave array via finite difference
	if init_grad == None:
		def _grad_0():
			def _grad(psi_0):
				if dim == 1:
					central_grad = np.zeros_like(psi_0)
					psi_right = psi_0[2:]
					psi_left = psi_0[:-2]

					# Central difference
					central_grad[1:-1] = (psi_right-psi_left)/(2.*dx)

					if bound_cond == 'reflective':
						central_grad[0] = 0.0
						central_grad[-1] = 0.0

					else:
					# Forward / backward one-sided finite step at boundary
						central_grad[0] = (psi_0[0]-psi_0[1])/dx
						central_grad[-1] = (psi_0[-2]-psi_0[-1])/dx

					# central_grad initialises the r array
					return central_grad

				if dim == 2:
					central_grad_x = np.zeros_like(psi_0)
					central_grad_y = np.zeros_like(psi_0)
					psi_x_right = psi_0[2:,:]
					psi_x_left = psi_0[:-2,:]
					# initialises r array
					central_grad_x[1:-1,:] = (psi_x_right-psi_x_left)/(2.*dx)

					psi_y_right = psi_0[:,2:]
					psi_y_left = psi_0[:,:-2]
					# initialises l array
					central_grad_y[:,1:-1] = (psi_y_right-psi_y_left)/(2.*dx)

					if bound_cond == 'reflective':
						central_grad_x[0,:] = 0.0
						central_grad_x[-1,:] = 0.0
						central_grad_y[:,0] = 0.0
						central_grad_y[:,-1] = 0.0

					else:
						# Forward/ backward one-sided finite steps at boundaries
						central_grad_x[0,:] = (psi_0[0,:]-psi_0[1,:])/dx
						central_grad_x[-1,:] = (psi_0[-2,:]-psi_0[-1,:])/dx

						central_grad_y[:,0] = (psi_0[:,0]-psi_0[:,1])/dx
						central_grad_y[:,-1] = (psi_0[:,-2]-psi_0[:,-1])/dx

					return central_grad_x,central_grad_y

			return _grad

		D = _grad_0()
	else:
		D = init_grad

	def _initialise(r,s,l = None):
		if dim == 1:
			s[:,0] = V(psi_0)
			r[:,0] = c(x)*D(psi_0)
			return r,s
		if dim == 2:
			s[:,:,0] = V(psi_0)
			r[:,:,0],l[:,:,0] = c(x,y)*D(psi_0)
			return r,s,l			

	def L_step_2D(u,j_x,j_y):
		u_step = (0.25*(u[2:,1:-1,0]+u[1:-1,2:,0]+u[:-2,1:-1,0]+u[1:-1,:-2,0])+0.5*alpha*(c(x[2:],y[1:-1])*j_x[2:,1:-1,0]-c(x[:-2],y[1:-1])*j_x[:-2,1:-1,0])
			+0.5*alpha*(c(x[1:-1],y[2:])*j_y[1:-1,2:,0]-c(x[1:-1],y[:-2])*j_y[1:-1,:-2,0]))
		return u_step

	def _derivatives(psi):
		if dim == 1:
			r = np.zeros((len_x,2))
			s = np.zeros((len_x,2))
		if dim == 2:
			r = np.zeros((len_x,len_y,2))
			s = np.zeros((len_x,len_y,2))
			l = np.zeros((len_x,len_y,2))			

		# Using the Lax-Wendroff Scheme
		for i in range(0,N-1):
			if dim == 1:
				if i == 0:
					r,s = _initialise(r,s)

				r_half = 0.5*(r[1:,0]+r[:-1,0])+0.5*alpha*(c(x[1:])*s[1:,0]-c(x[:-1])*s[:-1,0])
				s_half = 0.5*(s[1:,0]+s[:-1,0])+0.5*alpha*(c(x[1:])*r[1:,0]-c(x[:-1])*r[:-1,0])

				r[1:-1,1] = r[1:-1,0]+alpha*(c(x[1:-1]+dx/2.)*s_half[1:]-c(x[1:-1]-dx/2.)*s_half[:-1])
				s[1:-1,1] = s[1:-1,0]+alpha*(c(x[1:-1]+dx/2.)*r_half[1:]-c(x[1:-1]-dx/2.)*r_half[:-1])

				if bound_cond == 'reflective':
					# At reflective boundaries the gradient is 0
					r[0,:] = 0.0
					r[-1,:] = 0.0
					s[0,1] = s[0,0]+alpha*c(x[1])*r[1,0]
					s[-1,1] = s[-1,0]-alpha*c(x[-2])*r[-2,0]

				if bound_cond == 'periodic':
					r[0,:] = r[-2,:]
					s[0,:] = s[-2,:]
					r[-1,:] = r[1,:]
					s[-1,:] = s[1,:]

				elif bound_cond == 'fixed':
					# At fixed boundaries the velocity is 0
					s[0,:] = 0.0
					s[-1,:] = 0.0
					r[0,1] = r[0,0]+alpha*c(x[1])*s[1,0]
					r[-1,1] = r[-1,0]-alpha*c(x[-2])*s[-2,0]

				psi[:,i+1] = psi[:,i]+0.5*dt*(s[:,1]+s[:,0])

				r[:,0] = r[:,1]
				s[:,0] = s[:,1]

			if dim == 2:
				if i == 0:
					r,s,l = _initialise(r,s,l = l)

				null_flux = np.zeros_like(s)

				r[1:-1,1:-1,1] = L_step_2D(r,s,null_flux)
				l[1:-1,1:-1,1] = L_step_2D(l,null_flux,s)
				s[1:-1,1:-1,1] = L_step_2D(s,r,l)

				if bound_cond == 'reflective':
					# The gradient perpendicular to the boundaries are zero
					r[0,:,:] = 0.0
					r[-1,:,:] = 0.0

					l[:,0,:] = 0.0
					l[:,-1,:] = 0.0

					# Calculating the gradient along the edges
					r[1:-1,0,1] = 0.25*(r[:-2,0,0]+r[2:,0,0]+2*r[1:-1,0,0])+0.5*alpha*(c(x[2:],y[0])[0]*s[2:,0,0]-c(x[:-2],y[0])[0]*s[:-2,0,0])
					l[0,1:-1,1] = 0.25*(l[0,:-2,0]+l[0,2:,0]+2*l[0,1:-1,0])+0.5*alpha*(c(x[0],y[2:])[:,0]*s[0,2:,0]-c(x[0],y[:-2])[:,0]*s[0,:-2,0])
					r[1:-1,-1,1] = 0.25*(r[:-2,-1,0]+r[2:,-1,0]+2*r[1:-1,-1,0])+0.5*alpha*(c(x[2:],y[-1])[0]*s[2:,-1,0]-c(x[:-2],y[-1])[0]*s[:-2,-1,0])
					l[-1,1:-1,1] = 0.25*(l[-1,:-2,0]+l[-1,2:,0]+2*l[-1,1:-1,0])+0.5*alpha*(c(x[-1],y[2:])[:,0]*s[-1,2:,0]-c(x[-1],y[:-2])[:,0]*s[-1,:-2,0])

					# x boundaries
					s[0,1:-1,1] = s[0,1:-1,0]+alpha*c(x[1],y[1:-1])[:,0]*r[1,1:-1,0]+0.5*alpha*(c(x[0],y[2:])[:,0]*l[0,2:,0]-c(x[0],y[:-2])[:,0]*l[0,:-2,0])
					s[-1,1:-1,1] = s[-1,1:-1,0]-alpha*c(x[-2],y[1:-1])[:,0]*r[-2,1:-1,0]+0.5*alpha*(c(x[-1],y[2:])[:,0]*l[-1,2:,0]-c(x[-1],y[:-2])[:,0]*l[-1,:-2,0])

					# y boundaries
					s[1:-1,0,1] = s[1:-1,0,0]+alpha*c(x[1:-1],y[1])[0]*l[1:-1,1,0]+0.5*alpha*(c(x[2:],y[0])[0]*r[2:,0,0]-c(x[:-2],y[0])[0]*r[:-2,0,0])
					s[1:-1,-1,1] = s[1:-1,-1,0]-alpha*c(x[1:-1],y[-2])[0]*l[1:-1,-2,0]+0.5*alpha*(c(x[2:],y[-1])[0]*r[2:,-1,0]-c(x[:-2],y[-1])[0]*r[:-2,-1,0])

					# corners
					s[0,0,1] = s[0,0,0]+0.5*alpha*(4*c(x[1],y[0])[0]*r[1,0,0]-c(x[2],y[0])[0]*r[2,0,0])+0.5*alpha*(4*c(x[0],y[1])[0]*l[0,1,0]-c(x[0],y[2])[0]*l[0,2,0])
					s[0,-1,1] = s[0,-1,0]+0.5*alpha*(4*c(x[1],y[-1])[0]*r[1,-1,0]-c(x[2],y[-1])[0]*r[2,-1,0])-0.5*alpha*(4*c(x[0],y[-2])[0]*l[0,-2,0]-c(x[0],y[-3])[0]*l[0,-3,0])
					s[-1,0,1] = s[-1,0,0]-0.5*alpha*(4*c(x[-2],y[0])[0]*r[-2,0,0]-c(x[-3],y[0])[0]*r[-3,0,0])+0.5*alpha*(4*c(x[-1],y[1])[0]*l[-1,1,0]-c(x[-1],y[2])[0]*l[-1,2,0])
					s[-1,-1,1] = s[-1,-1,0]-0.5*alpha*(4*c(x[-2],y[-1])[0]*r[-2,-1,0]-c(x[-3],y[-1])[0]*r[-3,-1,0])-0.5*alpha*(4*c(x[-1],y[-2])[0]*l[-1,-2,0]-c(x[-1],y[-3])[0]*l[-1,-3,0])

				if bound_cond == 'periodic':
					# Waves on the surface of a torus
					r[0,:,:] = r[-2,:,:]
					r[-1,:,:] = r[1,:,:]

					l[:,0,:] = l[:,-2,:]
					l[:,-1,:] = l[:,1,:]

					# x boundaries
					s[0,1:-1,:] = s[-2,1:-1,:]
					s[-1,1:-1,:] = s[1,1:-1,:]

					# y boundaries
					s[1:-1,0,:] = s[1:-1,-2,:]
					s[1:-1,-1,:] = s[1:-1,1,:]

					# corners
					s[0,0,:] = s[-2,-2,:]
					s[0,-1,:] = s[1,-2,:]
					s[-1,0,:] = s[1,-2,:]
					s[-1,-1,:] = s[1,1,:]

				elif bound_cond == 'fixed':
					s[0,:,:] = 0.0
					s[-1,:,:] = 0.0
					s[:,0,:] = 0.0
					s[:,-1,:] = 0.0

					r[0,:,1] = r[0,:,0]+alpha*c(x[1],y)[:,0]*s[1,:,0]
					r[-1,:,1] = r[-1,:,0]-alpha*c(x[-2],y)[:,0]*s[-2,:,0]

					l[:,0,1] = l[:,0,0]+alpha*c(x,y[1])[0]*s[:,1,0]
					l[:,-1,1] = l[:,-1,0]-alpha*c(x,y[-2])[0]*s[:,-2,0]

				psi[:,:,i+1] = psi[:,:,i]+0.5*dt*(s[:,:,1]+s[:,:,0])

				r[:,:,0] = r[:,:,1]
				l[:,:,0] = l[:,:,1]
				s[:,:,0] = s[:,:,1]


		return psi

	def _main_step(psi):
		psi = _derivatives(psi)

	_main_step(psi)

	return psi, t

def CN_diffusion_equation(T_0, D, x_list, dx, N, s = 0.25, wall_T = [0.0,0.0,0.0,0.0]):

	dim = len(T_0.shape)
	len_x = T_0.shape[0]
	if dim > 1:
		len_y = T_0.shape[1]

	if dim > 2 or dim < 1:
		print('1D or 2D only, adjust initial wave array')
		return 0

	if dim == 1:
		dt = s*dx**2
		x = x_list

	elif dim == 2:
		y = x_list[1]
		x = x_list[0]
		dt = s*dx**2

	t = np.linspace(0.,(N-1)*dt,N)

	if dim == 1:
		T = np.zeros((len_x,N))
		T[:,0] = T_0

	if dim == 2:
		T = np.zeros((len_x,len_y,N))
		T[:,:,0] = T_0

	def _explicit_step(j):
		if dim == 1:
			T[1:-1,j+1] = T[1:-1,j]+s*(D(x[1:-1]+dx/2.)*(T[2:,j]-T[1:-1,j])-D(x[1:-1]-dx/2.)*(T[1:-1,j]-T[:-2,j]))

			T[0,:] = wall_T[0]
			T[-1,:] = wall_T[1]

		if dim == 2:
			for n in range(1,len_x-1):
				for m in range(1,len_y-1):
					T[n,m,j+1] = (T[n,m,j]+s*(D(x[n]+dx/2.,y[m])*(T[n+1,m,j]-T[n,m,j])-D(x[n]-dx/2.,y[m])*(T[n,m,j]-T[n-1,m,j])+
										 +D(x[n],y[m]+dx/2.)*(T[n,m+1,j]-T[n,m,j])-D(x[n],y[m]-dx/2.)*(T[n,m,j]-T[n,m-1,j])))

			T[0,:,:] = wall_T[0]
			T[-1,:,:] = wall_T[1]
			T[:,0,:] = wall_T[2]
			T[:,-1,:] = wall_T[3]

	def _central_diff(q,j,coord = None):
		if dim == 1:
			len_q = q.shape[0]
		elif dim == 2:
			len_q = q[0].shape[0]

		A = np.zeros((len_q-2,len_q-2))
		B = np.zeros((len_q-2,len_q-2))
		C = np.zeros((len_q-2))

		for i in range(len_q-2):
			if dim == 1:
				D_forward = D(q[i]+dx/2.)
				D_backward = D(q[i]-dx/2.)

			elif dim == 2:
				if coord == 'x':
					D_forward = D(q[0][i]+dx/2.,q[1])
					D_backward = D(q[0][i]-dx/2.,q[1])
				if coord == 'y':
					D_forward = D(q[1],q[0][i]+dx/2.)
					D_backward = D(q[1],q[0][i]-dx/2.)					
		
			A_q = np.zeros((len_q-2))
			A_q[i] = 1.+0.5*s*D_forward+0.5*s*D_backward
			if i == 0:
				A_q[i+1] = -0.5*s*D_forward
			elif i == len_x-3:
				A_q[i-1] = -0.5*s*D_backward
			else:
				A_q[i+1] = -0.5*s*D_forward
				A_q[i-1] = -0.5*s*D_backward
			A[i,:] = A_q

		B = 2.*np.identity(len_q-2)-A

		if dim == 1:
			C[0] = s*D(dx/2.)*wall_T[0]
			C[-1] = s*D(q[-1]-dx/2.)*wall_T[1]

		elif dim == 2:
			if coord == 'x':
				C[0] = s*D(dx/2.,q[1])*wall_T[0]
				C[-1] = s*D(q[0][-1]-dx/2.,q[1])*wall_T[1]				
			if coord == 'y':
				C[0] = s*D(q[1],dx/2.)*wall_T[2]
				C[-1] = s*D(q[1],q[0][-1]-dx/2.)*wall_T[3]	

		return A,B,C

	def _diagonal_form(A,q):
		if dim == 1:
			len_q = q.shape[0]
		elif dim == 2:
			len_q = q[0].shape[0]

		ab = np.zeros((3,len_q-2))

		ab[0,1:] = np.diagonal(A,1)
		ab[1,:] = np.diagonal(A,0)
		ab[2,:-1] = np.diagonal(A,-1)

		return ab	

	def _CN_step(j):
		if dim == 1:
			A,B,C = _central_diff(x,j)

			T[1:-1,j+1] = solve_banded((1,1),_diagonal_form(A,x),np.dot(B,T[1:-1,j])+C)

		if dim == 2:
			T_intermediate = np.zeros_like(T[:,:,0])
			for l in range(1,len_x-1):
				q = [y,x[l]]
				A_y,B_y,C_y = _central_diff(q,j,coord = 'y')
				T_intermediate[l,1:-1] = solve_banded((1,1),_diagonal_form(A_y,q),np.dot(B_y,T[l,1:-1,j])+C_y)

			for l in range(1,len_y-1):
				q = [x,y[l]]
				A_x,B_x,C_x = _central_diff(q,j,coord = 'x')
				T[1:-1,l,j+1] = solve_banded((1,1),_diagonal_form(A_x,q),np.dot(B_x,T_intermediate[1:-1,l])+C_x)

			T_intermediate[0,:] = wall_T[0]
			T_intermediate[-1,:] = wall_T[1]
			T_intermediate[:,0] = wall_T[2]
			T_intermediate[:,-1] = wall_T[3]

	def _main_step():
		_explicit_step(0)
		for k in range(1,N-1):
			_CN_step(k)

	_main_step()

	return T,t

def split_step_schrodinger(psi_0, dx, dt, V, N, x_0 = 0., k_0 = None, m = 1.0, non_linear = False):

	len_x = psi_0.shape[0]

	x = x_0 + dx*np.arange(len_x)

	dk_x = (2*np.pi)/(len_x*dx)
	if k_0 == None:
		k_0 = -np.pi/dx
	k_x = k_0+dk_x*np.arange(len_x)

	psi_x = np.zeros((len_x,N), dtype = np.complex128)
	psi_k = np.zeros((len_x,N), dtype = np.complex128)
	psi_mod_x = np.zeros((len_x), dtype = np.complex128)
	psi_mod_k = np.zeros((len_x), dtype = np.complex128)
	psi_x[:,0] = psi_0

	if not non_linear:
		V_n = V(x)
	else:
		V_n = V(x,psi_0)

	def _compute_psi_mod(j):
		return (dx/np.sqrt(2*np.pi))*psi_x[:,j]*np.exp(-1.0j*k_x[0]*x)

	def _compute_psi(j):
		psi_x[:,j] = (np.sqrt(2*np.pi)/dx)*psi_mod_x*np.exp(1.0j*k_x[0]*x)
		psi_k[:,j] = psi_mod_k*np.exp(-1.0j*x[0]*dk_x*np.arange(len_x))

	def _x_half_step(j,ft = True):
		if ft == True:
			psi_mod_x[:] = ifft(psi_mod_k[:])
		if non_linear:
			V_n[:] = V(x,psi_x[:,j])
		psi_mod_x[:] = psi_mod_x[:]*np.exp(-1.0j*(dt/2.)*V_n)	

	def _k_full_step():
		psi_mod_k[:] = fft(psi_mod_x[:])
		psi_mod_k[:] = psi_mod_k[:]*np.exp(-1.0j*k_x**2*dt/(2.*m))		

	def _main_loop():
		psi_mod_x[:] = _compute_psi_mod(0)

		for i in range(N-1):
			_x_half_step(i,ft = False)
			_k_full_step()
			_x_half_step(i)
			_compute_psi(i+1)

	_main_loop()

	return psi_x,psi_k,k_x