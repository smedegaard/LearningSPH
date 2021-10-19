"""
Generating 2D WCSPH (AV) taylor green vortex decay flow
"""

using NPZ, Plots, Statistics, LaTeXStrings


T = 20
t_save = 1   #initial time for saving

IC = "Vrandn"
vmag = 1.0  #initial magnitude of TG velocity
# IC = "TG"
method = "AV_neg_rel"

#params:
β = 2.0  #usual value of params for alpha and β but these depend on problem
α = 1.0
θ = 5e-1;

c = 10.0
g = 7.0
h = 0.335
cdt = 0.4;
dt = cdt * h / c;
# p_gt = [c, 0.0];


# D = 3;
# gsp = 4; #produces grid of 2^gsp x 2^gsp x 2^gsp number of particles
# p = Iterators.product((2*pi/(2^gsp)):(2*pi/(2^gsp)):2*pi, (2*pi/(2^gsp)):(2*pi/(2^gsp)):2*pi, (2*pi/(2^gsp)):(2*pi/(2^gsp)):2*pi)
# p = vec(collect.(p)) #particles
# N = length(p)
# m = (2. * pi)^D / N;

t_start = 20;
traj_gt = npzread("./data/traj_N4096_T50_ts1_h0.335_Vrandn_cdt0.4_c10.0_α1.0_β2.0_θ0.5_AV_neg_rel.npy");
vels_gt = npzread("./data/vels_N4096_T50_ts1_h0.335_Vrandn_cdt0.4_c10.0_α1.0_β2.0_θ0.5_AV_neg_rel.npy");
rhos_gt = npzread("./data/rhos_N4096_T50_ts1_h0.335_Vrandn_cdt0.4_c10.0_α1.0_β2.0_θ0.5_AV_neg_rel.npy");

# traj_gt = npzread("../3d_semi_inf/data/traj_N4096_T50_ts1_h0.335_Vrandn_cdt0.4_c10.0_α1.0_β2.0_θ0.5_AV_neg_rel.npy");
# vels_gt = npzread("../3d_semi_inf/data/vels_N4096_T50_ts1_h0.335_Vrandn_cdt0.4_c10.0_α1.0_β2.0_θ0.5_AV_neg_rel.npy");
# rhos_gt = npzread("../3d_semi_inf/data/rhos_N4096_T50_ts1_h0.335_Vrandn_cdt0.4_c10.0_α1.0_β2.0_θ0.5_AV_neg_rel.npy");

traj_gt = traj_gt[t_start:end, :, :]
vels_gt = vels_gt[t_start:end, :, :]
rhos_gt = rhos_gt[t_start:end, :]

N = size(traj_gt)[2];
D = size(traj_gt)[3];
m = (2. * pi)^D / N; #so that ρ₀ = 1;

# sigma = (10. / (7. * pi * h * h)); #2D normalizing factor
sigma = 1/(pi*h^3)  #3D normalizing factor

function W(r, h)
  q = r / h;   if (q > 2.)   return 0.;   end
  if (q > 1.)   return (sigma * (2. - q)^3 / 4.);   end
  return (sigma * (1. - 1.5 * q * q * (1. - q / 2.)));
end

# H(r) = (d W / d r) / r
function H(r, h)
  q = r / h;   if (q > 2.)   return 0.;   end
  if (q > 1.)   return (-3. * sigma * (2. - q)^2 / (4. * h * r));   end
  return (sigma * (-3. + 9. * q / 4.) / h^2);
end


function Pres(rho)
  return (c^2 * (rho^g - 1.) / g) ;
end

# P(rho) / rho^2
function P_d_rho2(rho)
  return (c^2 * (rho^g - 1.) / g) / (rho^2);
end

function compute_Π(XX, VV, rhoi, rhoj, α, β, h, c)
  if (XX'*VV < 0)
    μ = h*(XX'*VV)/(sum(XX.^2) + 0.01*h^2)
    Π = (-α*c*μ + β * μ^2)/((rhoi + rhoj)/2)
  end
  if (XX'*VV >= 0)
    Π = 0.0
  end
  return Π
end

#NEIGHBORHOOD LIST
# The whole (2 pi)^2 torus is divided into n_hash^2 squares with the
# size l_hash. We have l_hash >= h. The particles interact if they
# differ in their "hash" coordinates no more than 2 (i.e., r < 2 h).
n_hash = floor(Int, 2. * pi / h);   l_hash = 2. * pi / n_hash;

function obtain_sph_av_A(X, V, α, β, h, c, θ)
  μ = 0.0
  Π = 0.0
  A = zeros(N,D);
  rho = zeros(N);
  mPdrho2 = zeros(N);
  tke = 0.5*mean(V[: ,1].^2 .+ V[: ,2].^2 .+ V[: ,3].^2);

# putting coordinates inside the (2 pi)^2 torus, building hash
  hash = [Set() for i in 1 : n_hash, j in 1 : n_hash, k in 1 : n_hash];
  for n in 1 : N
    for i in 1 : D
      while (X[n, i] < 0.)   X[n, i] += 2. * pi;   end
      while (X[n, i] > 2. * pi)   X[n, i] -= 2. * pi;  end
    end
    push!(hash[floor(Int, X[n, 1] / l_hash) + 1,
               floor(Int, X[n, 2] / l_hash) + 1,
               floor(Int, X[n, 3] / l_hash) + 1], n);
  end
# computing rho
  XX = zeros(D);
  for n in 1 : N
    x_hash = [floor(Int, X[n, 1] / l_hash) + 1,
              floor(Int, X[n, 2] / l_hash) + 1,
              floor(Int, X[n, 3] / l_hash) + 1];
    for xa_hash in x_hash[1] - 2 : x_hash[1] + 2
      xb_hash = xa_hash;    while (xb_hash < 1)    xb_hash += n_hash;   end
      while (xb_hash > n_hash)    xb_hash -= n_hash;   end
      for ya_hash in x_hash[2] - 2 : x_hash[2] + 2
        yb_hash = ya_hash;    while (yb_hash < 1)    yb_hash += n_hash;   end
        while (yb_hash > n_hash)    yb_hash -= n_hash;   end
        for za_hash in x_hash[3] - 2 : x_hash[3] + 2
          zb_hash = za_hash;    while (zb_hash < 1)    zb_hash += n_hash;   end
          while (zb_hash > n_hash)    zb_hash -= n_hash;   end
          for n2 in hash[xb_hash, yb_hash, zb_hash]

            close = true; r2 = 0.;
            for i in 1 : D
              XX[i] = X[n, i] - X[n2, i];
              while (XX[i] > pi)   XX[i] -= 2. * pi;   end
              while (XX[i] < -pi)   XX[i] += 2. * pi;   end
              r2 += XX[i] * XX[i];
              if (r2 > 4. * h * h)   close = false; break;   end
            end
            if (close)
              tmp = m * W(sqrt(r2), h); rho[n] += tmp;
            end
          end
        end
    end   end
  end
  for n in 1 : N
    mPdrho2[n] = m * P_d_rho2(rho[n]);
  end

  XX = zeros(D); VV = zeros(D);
  # computing A
  for n in 1 : N
    # A[n, :] = obtain_forcing_A(X[n, :]);
    x_hash = [floor(Int, X[n, 1] / l_hash) + 1,
              floor(Int, X[n, 2] / l_hash) + 1,
              floor(Int, X[n, 3] / l_hash) + 1];
    for xa_hash in x_hash[1] - 2 : x_hash[1] + 2
      xb_hash = xa_hash;    while (xb_hash < 1)    xb_hash += n_hash;   end
      while (xb_hash > n_hash)    xb_hash -= n_hash;   end
      for ya_hash in x_hash[2] - 2 : x_hash[2] + 2
        yb_hash = ya_hash;    while (yb_hash < 1)    yb_hash += n_hash;   end
        while (yb_hash > n_hash)    yb_hash -= n_hash;   end
        for za_hash in x_hash[3] - 2 : x_hash[3] + 2
          zb_hash = za_hash;    while (zb_hash < 1)    zb_hash += n_hash;   end
          while (zb_hash > n_hash)    zb_hash -= n_hash;   end
          for n2 in hash[xb_hash, yb_hash, zb_hash]

            close = true;   r2 = 0.;
            for i in 1 : D
              XX[i] = X[n, i] - X[n2, i];
              VV[i] = V[n, i] - V[n2, i];
              while (XX[i] > pi)   XX[i] -= 2. * pi;   end
              while (XX[i] < -pi)   XX[i] += 2. * pi;   end
              r2 += XX[i] * XX[i];
              if (r2 > 4. * h * h)   close = false; break;   end
            end
            if (close)
              Π = compute_Π(XX, VV, rho[n], rho[n2], α, β, h, c)
              tmp = -(mPdrho2[n] + mPdrho2[n2] + m*Π) * H(sqrt(r2), h);
              for i in 1 : D
                A[n, i] += tmp * XX[i] #+ θ * (V[n, i] - mean(V[:, i]));
              end
            end
          end
        end
    end   end
  end
  for i in 1 : D
    A[:, i] += (θ/tke) * (V[:, i] .- mean(V[:, i]))
  end
  return A, rho
end



#---------------Initial conditions (and boundary condistion)

function obtain_vrand_ic()
  X = zeros(N, D); V = zeros(N, D);
  for n in 1 : N
    X[n, 1] = p[n][1] + 0.005 * (rand() - 0.5)
    X[n, 2] = p[n][2] + 0.005 * (rand() - 0.5)
    X[n, 3] = p[n][3] + 0.005 * (rand() - 0.5)
  end
  X = mod.(X, 2*pi);

  # for n in 1 : N
  #   #Taylor green intitial condition
  #   V[n, 1] = vmag * sin(X[n, 1]) * cos(X[n, 2]) * cos(X[n, 3])
  #   V[n, 2] = -vmag * cos(X[n, 1]) * sin(X[n, 2]) * cos(X[n, 3]);
  #   for i in 1 : D
  #     while (X[n, i] < 0.)   X[n, i] += 2. * pi;   end
  #     while (X[n, i] > 2. * pi)   X[n, i] -= 2. * pi;  end
  #   end
  # end

  if IC == "Vrandn"
    V = vmag * randn(N, D)
  end
  return X, V
end


function obtain_gt_ic(traj_gt, vels_gt)
  X = traj_gt[1, :, :] #initial conditions
  V = vels_gt[1, :, :] #initial conditions
  return X, V
end



#-------------- Integration

function vel_verlet(α, β, h, c, θ, T)
  """
  velocity verlet without external forcing
    returns trajectories, velocitys and densities of particles
  """

  # X, V = obtain_vrand_ic()   #initial conditions
  X, V = obtain_gt_ic(traj_gt, vels_gt)

  traj, vels = zeros(T+1,N,D), zeros(T+1,N,D); rhos = zeros(T+1, N);
	traj[1, :, :] = X; vels[1, :, :] = V;
	A, rho = obtain_sph_av_A(X, V, α, β, h, c, θ);
	rhos[1,:] = rho;

	for k in 1 : T
	  A, rho = obtain_sph_av_A(X, V, α, β, h, c, θ)

	  #Verlet
	  for n in 1 : N
  		for i in 1 : D
			V[n, i] += 0.5 * dt * A[n, i];
			X[n, i] += dt * V[n, i];
			while (X[n, i] < 0.)   X[n, i] += 2. * pi;   end
			while (X[n, i] > 2. * pi)   X[n, i] -= 2. * pi;   end
  		end
	  end

	  A, rho = obtain_sph_av_A(X, V, α, β, h, c, θ)

	  for n in 1 : N   for i in 1 : D
		  V[n, i] += 0.5 * dt * A[n, i] #+ stochastic_term();
	  end   end

	  vels[k + 1, :, :] = V;
	  traj[k + 1, :, :] = X;
	  rhos[k + 1, :] = rho;
	  println("time step:  ", k)
	end
	return traj, vels, rhos
end

# traj, vels, rhos = vel_verlet(α, β, h, c, θ, T)


function gen_data_files(traj, vels, rhos, pos_path, vel_path, rho_path)
    println(" ****************** Saving data files ***********************")
    # npzwrite(pos_data, pos[t_save:end,:,:])
    # npzwrite(vel_data, vel[t_save:end,:,:])
	npzwrite(pos_path, traj[t_save:end,:,:])
	npzwrite(vel_path, vels[t_save:end,:,:])
	npzwrite(rho_path, rhos[t_save:end,:])
end


θ_range = 1e-1 : 0.3 : 1.7
for θ in θ_range
  println("   ***********************************************   ")
  println(" θ = ", θ)
  println("    ")
  pos_path = "./data/traj_N$(N)_T$(T)_ts$(t_save)_h$(h)_$(IC)_cdt$(cdt)_c$(c)_α$(α)_β$(β)_θ$(θ)_$(method).npy"
  vel_path = "./data/vels_N$(N)_T$(T)_ts$(t_save)_h$(h)_$(IC)_cdt$(cdt)_c$(c)_α$(α)_β$(β)_θ$(θ)_$(method).npy"
  rho_path = "./data/rhos_N$(N)_T$(T)_ts$(t_save)_h$(h)_$(IC)_cdt$(cdt)_c$(c)_α$(α)_β$(β)_θ$(θ)_$(method).npy"

  traj, vels, rhos = vel_verlet(α, β, h, c, θ, T)
  gen_data_files(traj, vels, rhos, pos_path, vel_path, rho_path)
end



#
# function obtain_tke(vels)
#   tke = zeros(T);
#   for k in 1 : T
#       tke[k] = 0.5*mean(vels[k,:,1].^2 .+ vels[k,:,2].^2 .+ vels[k,:,3].^2)
#   end
#   return tke
# end
#
# tke = obtain_tke(vels)
#
# function compute_Re(vels)
#   Re = zeros(T+1)
#   V = 0.0
#   L = 2*pi
#   ν = 1/10 * α * c * h
#   for t in 1 : (T+1)
#     V = maximum(vels[t, :, :])
#     Re[t] = L*V/ν
#   end
#   return Re
# end
#
# Re = compute_Re(vels)
#
# function compute_turb_ke(vels)
# 	turb_ke = zeros(T);
# 	for t in 1 : T
# 		avg_KE = 0.5*mean(vels[t, :, 1].^2 .+ vels[t, :, 2].^2 .+ vels[t, :, 3].^2)
# 		dec_ke = 0.5 * (mean(vels[t, :, 1])^2 + mean(vels[t, :, 2])^2 + mean(vels[t, :, 3])^2)
# 		turb_ke[t] = avg_KE - dec_ke
# 	end
# 	return turb_ke
# end
#
# turb_ke = compute_turb_ke(vels)
#
#
#
# #
#
# #-----------Outputs
# #-----------Outputs
# pos_path = "./data/traj_N$(N)_T$(T)_ts$(t_save)_h$(h)_$(IC)_cdt$(cdt)_c$(c)_α$(α)_β$(β)_θ$(θ)_$(method).npy"
# vel_path = "./data/vels_N$(N)_T$(T)_ts$(t_save)_h$(h)_$(IC)_cdt$(cdt)_c$(c)_α$(α)_β$(β)_θ$(θ)_$(method).npy"
# rho_path = "./data/rhos_N$(N)_T$(T)_ts$(t_save)_h$(h)_$(IC)_cdt$(cdt)_c$(c)_α$(α)_β$(β)_θ$(θ)_$(method).npy"
#
# sim_path = "./sims/traj_N$(N)_T$(T)_ts$(t_save)_h$(h)_$(IC)_cdt$(cdt)_c$(c)_α$(α)_β$(β)_θ$(θ)_$(method).mp4"
# file_out_tke = "./figures/tke_N$(N)_T$(T)_ts$(t_save)_h$(h)_$(IC)_cdt$(cdt)_c$(c)_α$(α)_β$(β)_θ$(θ)_$(method).png"
# file_out_re = "./figures/re_N$(N)_T$(T)_ts$(t_save)_h$(h)_$(IC)_cdt$(cdt)_c$(c)_α$(α)_β$(β)_θ$(θ)_$(method).png"
# file_out_turb_ke = "./figures/turb_ke_N$(N)_T$(T)_ts$(t_save)_h$(h)_$(IC)_cdt$(cdt)_c$(c)_α$(α)_β$(β)_θ$(θ)_$(method).png"
#
# function gen_data_files(traj, vels, rhos)
#     println(" ****************** Saving data files ***********************")
#     # npzwrite(pos_data, pos[t_save:end,:,:])
#     # npzwrite(vel_data, vel[t_save:end,:,:])
# 	npzwrite(pos_path, traj[t_save:end,:,:])
# 	npzwrite(vel_path, vels[t_save:end,:,:])
# 	npzwrite(rho_path, rhos[t_save:end,:])
# end
#
#
#
# function simulate(pos, sim_time=5)
#     gr(size=(1000,800))
#     println("**************** Simulating the particle flow ***************")
#     #theme(:juno)
#     n_2 = round(Int,N/2)
#     anim = @animate for i ∈ 1:(T+1)
#          Plots.scatter(pos[i, 1:n_2, 1], pos[i, 1:n_2, 2], pos[i, 1:n_2, 3],
#          title = "WCSPH_$(method): N=$(N), h=$(h), c=$(c)", xlims = [0, 2*pi], ylims = [0,2*pi], zlims = [0,2*pi], legend = false)
#          Plots.scatter!(pos[i, (n_2+1):end, 1], pos[i, (n_2+1):end, 2], pos[i, (n_2+1):end, 3], color = "red")
#     end
#     gif(anim, sim_path, fps = round(Int, T/sim_time))
#     println("****************  Simulation COMPLETE  *************")
# end
#
#
# function plot_KE_fluc()
#     gr(size=(500,400))
#     println("*************** generating plots ******************")
#
#     plt3 = plot(tke, label=L"Avg(KE)", color="blue", linewidth = 2.25)
#     title!("Average kinetic energy")
#     xlabel!(L"t")
#     ylabel!(L"Avg KE")
#     display(plt3)
#
# 	# plt = plot(turb_ke, label=L"k", color="blue", linewidth = 2.25)
#   #   title!("Turbulent kinetic energy, θ = $(θ)")
#   #   xlabel!(L"t")
#   #   ylabel!(L"turbulent KE")
#   #   display(plt)
#   #   savefig(plt, file_out_turb_ke)
# end
#
#
# function plotting_Re()
#   plt = plot(Re, label=L"Re", color="blue", linewidth = 2.25)
#   title!("Reynolds number")
#   xlabel!(L"t")
#   ylabel!(L"Re")
#   display(plt)
#   savefig(plt, file_out_re)
# end
#
#
# #UAHPC seems to need this formatting
# ENV["GKSwstype"]="100"
#
# gen_data_files(traj, vels, rhos)
# plot_KE_fluc()
# plotting_Re()
# simulate(traj, 10)
