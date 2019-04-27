clear all; close all; clc;
%% Dynamical model
% Trucks (except leader)
N = 5;
good_N = [1 3 5];
bad_N = [2 4];
% Continuous time model
Ac = [zeros(N), eye(N); zeros(N), zeros(N)];
Bc = [zeros(N); diag(ones(N-1,1), -1) - eye(N)];
B_k = Bc;
F_k = Bc;

for i = 1:length(good_N)    
    F_k(:,good_N(i)) = zeros(2*N,1);
end
for i = 1:length(bad_N)
    B_k(:,bad_N(i)) = zeros(2*N,1); 
end

% Sampling time
Ts = 0.2;

% Discrete time model
A = eye(2*N) + Ts*Ac;
B = Ts*Bc;
B_k = Ts*B_k;
F_k = Ts*F_k;

% Cost function
% J = x(K)' Qf x(K) + sum k=0�(K?1) (x(k)' Q x(k) + u(k)' R u(k))
Kc = 3;
rho = 0.01; % penalty scaling constant
gamma = 1;
K = Kc / Ts;
Qf = 100 * eye(2*N);
Q = eye(2*N);
R_u = rho * eye(1);
R_v = rho * eye(1);
D = 1;
E = D.*eye(2*N);
T = K + 5;

%%
% Zero Sum Case
%

QfN = zeros(2*N,2*N,N);
QN = zeros(2*N,2*N,N);

for player = 1:N
    player_states = [player, player+N];
    QfN(player_states,player_states,player) = Qf(player_states,player_states);
    QN(player_states,player_states,player) = Q(player_states,player_states);
end

PN = nan(2*N,2*N,K+1,N);
qN = nan(2*N,2*N,K+1,N);
rN = nan(2*N,2*N,K+1,N);

for player = 1:N
    PN(:,:,K+1,player) = QfN(:,:,player); % P_T = Q_T
    qN(:,:,K+1,player) = zeros(2*N); % q_T = 0
    rN(:,:,K+1,player) = zeros(2*N); % r_T = 0
end

GammaN = nan(N,2*N,K);
theta = nan(N,2*N,K);
lambda_1 = nan(N,2*N,K);
lambda_2 = nan(N,2*N,K);
phi = nan(N,2*N,K);
alpha = nan(N,K);
alpha_inv = nan(N,K);
beta = nan(N,K);
beta_inv = nan(N,K);
Phi_old = nan(2,2*N);
Psi_old = nan(2,2*N);
F = zeros(N);
G = zeros(N,2*N);
S = zeros(2*N);

for k=K:-1:1   
    
    for player=1:N
        
        alpha(player,k) = R_u + B_k(:,player)' * PN(:,:,k+1,player) * B_k(:,player);        
        alpha_inv(player,k) = inv(alpha(player,k));
        
        beta(player,k) = -gamma^2 * R_v + F_k(:,player)' * PN(:,:,k+1,player) * F_k(:,player);
        beta_inv(player,k) = inv(beta(player,k));
        
        mu_k = alpha_inv(player,k) * B_k(:,player)' * PN(:,:,k+1,player) * F_k(:,player) * beta_inv(player,k) * F_k(:,player)';
        zeta_k = beta_inv(player,k) * F_k(:,player)' * PN(:,:,k+1,player) * B_k(:,player) * alpha_inv(player,k) * B_k(:,player)';
        kappa_inv = inv(eye(1) - mu_k * PN(:,:,k+1,player) * B_k(:,player));
        eta_inv = inv(eye(1) - zeta_k * PN(:,:,k+1,player) * F_k(:,player));
        
        theta(player,:,k) = kappa_inv * (mu_k*PN(:,:,k+1,player) - alpha_inv(player,k) * B_k(:,player)' * PN(:,:,k+1,player)) * A;
        lambda_1(player,:,k) = kappa_inv * (mu_k - alpha_inv(player,k) * B_k(:,player)') * qN(:,:,k+1,player)';
        
        phi(player,:,k) = eta_inv * (zeta_k * PN(:,:,k+1,player) - beta_inv(player,k) * F_k(:,player)' * PN(:,:,k+1,player)) * A;
        lambda_2(player,:,k) = eta_inv * (zeta_k - beta_inv(player,k) * F_k(:,player)') * qN(:,:,k+1,player)';
        
        PN(:,:,k,player) = Q + A' * PN(:,:,k+1,player) * A + theta(player,:,k)'*alpha(player,k)*theta(player,:,k) + ...
                            phi(player,:,k)'*beta(player,k)*phi(player,:,k) + 2*theta(player,:,k)'*B_k(:,player)'*PN(:,:,k+1,player)*A + ...
                            2*phi(player,:,k)'*F_k(:,player)'*PN(:,:,k+1,player)*A + ...
                            theta(player,:,k)'*B_k(:,player)'*PN(:,:,k+1,player)*F_k(:,player)*phi(player,:,k) + ...
                            phi(player,:,k)'*F_k(:,player)'*PN(:,:,k+1,player)*B_k(:,player)*theta(player,:,k);
        
        qN(:,:,k,player) = (lambda_1(player,:,k)'*alpha(player,k)*theta(player,:,k) + lambda_2(player,:,k)' * beta(player,k)*phi(player,:,k) + ...
                            lambda_1(player,:,k)'*B_k(:,player)'*PN(:,:,k+1,player) * (A + F_k(:,player) * phi(player,:,k)) + ...
                            lambda_2(player,:,k)'*F_k(:,player)'*PN(:,:,k+1,player) * (A + B_k(:,player) * theta(player,:,k)) + ...
                            qN(:,:,k+1,player)'*(A + B_k(:,player) * theta(player,:,k) + F_k(:,player) * phi(player,:,k)) - E)';
                        
        rN(:,:,k,player)   =  rN(:,:,k+1,player) + lambda_1(player,:,k)'*alpha(player,k)*lambda_1(player,:,k) + ...
                            lambda_2(player,:,k)' * beta(player,k)*lambda_2(player,:,k) + ...
                            lambda_1(player,:,k)'*B_k(:,player)'*PN(:,:,k+1,player) * F_k(:,player) * lambda_2(player,:,k) + ...
                            lambda_2(player,:,k)'*F_k(:,player)'*PN(:,:,k+1,player) * B_k(:,player) * lambda_1(player,:,k) + ...
                            2*K*D^2*eye(2*N) + 2*qN(:,:,k+1,player)'*(B_k(:,player) * lambda_1(player,:,k) + F_k(:,player) * lambda_2(player,:,k));
                        
    end
end

%% optimal feedback law
xN = nan(2*N,T);
xN(:,1) = [zeros(N,1); -0.5 *ones(N,1)];
uN = zeros(N,T);
vN = zeros(N,T);
for t = 1:T-1
    if t <= K
        uN(:,t) = theta(:,:,t) * xN(:,t) + lambda_1(:,:,t); 
        vN(:,t) = phi(:,:,t) * xN(:,t) + lambda_2(:,:,t); 
    end 
    xN(:,t+1) = A * xN(:,t) + B_k * uN(:,t) + F_k * vN(:,t);
end


figure
plot(1:T,xN(1:N,:))
grid on
xlabel('time')
legend('Truck 1', 'Truck 2', 'Truck 3', 'Truck 4','Truck 5');
title('Position')

figure
plot(1:T,uN)
grid on
xlabel('time')
legend('Truck 1', 'Truck 2', 'Truck 3', 'Truck 4','Truck 5');
title('Control (acceleration)')

% Truck trajectory
wN = [diag(ones(N,1), -1) - eye(N+1)] \ [- [ones(1,T), 0.5*ones(1,T)]; [zeros(N,T), xN(N+1:end,:)]];
yN = -ones(2*T,1)*(0:N) + cumsum(wN');

figure
plot(1:2*T,yN);
grid on
title('Truck trajectories (Nash equilibrium)')
xlim([T-5 2*T])
xlabel('time')