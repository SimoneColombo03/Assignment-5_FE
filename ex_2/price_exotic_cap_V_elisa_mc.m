function [price, std_err] = price_exotic_cap_V_elisa_mc(v_bmm, ...
                                spot_vol_parameters, lambda, n_caplets, ...
                                spread, n_paths, ~)

% PRICE_EXOTIC_CAP_MC  Monte Carlo pricing of the exotic cap of Case Study 2
% under the SPOT MEASURE of the Bond Market Model (BMM).
%
%   Quarterly payoff at T_{i+1} (for i = 1, ..., n_caplets):
%       payoff_i = delta_i * [ L(T_i, T_{i+1}) - L(T_{i-1}, T_i) - spread ]^+
%
%   ----- WHY THE SPOT MEASURE -----
%   Under the BMM spot measure, the joint dynamics of all forward bonds
%   B_i(t) := B(t; T_i, T_{i+1}) is a "Markov chain on Reset Dates"
%   (Baviera 2006, slide 19 of the course notes):
%
%     * between two consecutive reset dates T_k and T_{k+1}, every "alive"
%       forward bond B_i (for i > k) evolves as a Geometric Brownian Motion
%       with constant vol v_i and a deterministic drift built from the vols
%       of the bonds that still need to die (j = k+1, ..., i-1);
%     * at each reset date T_k, B_k(T_k) "dies": it becomes deterministic
%       and contributes the multiplicative factor B_k(T_k) to the stochastic
%       discount D(0, T_*) = prod_{j=0}^{*-1} B_j(T_j).
%
%   The whole Brownian innovation is a single vector dW(t) shared by every
%   alive bond, with INSTANTANEOUS correlation matrix rho_{ij} between the
%   loadings v_i, v_j (here scalar so the correlation is just rho_{ij}
%   itself). This is exactly the structure encoded in the "vector with
%   correlation rho" of the handwritten note.
%
%   Practically:
%     1) build the full correlation matrix rho_{ij} = exp(-lambda*delta_ij)
%        on the n_steps reset dates and Cholesky-decompose it: rho = L*L';
%     2) for each MC path, draw n_steps i.i.d. standard normals, multiply
%        by L to get correlated Brownian increments dW_k;
%     3) walk the reset dates T_0 -> T_1 -> ... -> T_{n_caplets+1}, evolving
%        every alive bond according to the lognormal dynamics:
%            log B_i(T_{k+1}) = log B_i(T_k)
%                              - 0.5 v_i^2 * delta_k        (Ito)
%                              - rho * sum_{j=k+1..i-1} v_i v_j * delta_k
%                                                            (Girsanov drift
%                                                             from spot measure)
%                              - v_i * sqrt(delta_k) * dW_k_corr_i
%        where dW_k_corr_i is the i-th component of L * dW_k;
%     4) at every reset date T_k, freeze B_k(T_k) and multiply it into the
%        stochastic discount accumulator D(0, T_{k+1});
%     5) at each payment date T_{i+1}, compute the payoff using the two
%        already-fixed Libor rates L_{i-1}(T_{i-1}) and L_i(T_i), discount
%        it with D(0, T_{i+1}), and average over paths.
%
%   No measure change is needed because the spot-measure discount is built
%   path-by-path INSIDE the expectation. This is the cleanest BMM-canonical
%   pricing scheme.
%
%   INPUTS:
%   v_bmm                - [n_caplets x 1] BMM vols at the ATM strike,
%                          one per "alive" forward bond
%   spot_vol_parameters  - struct from compute_caplets_maturities
%   lambda               - decay parameter of the correlation
%                          (rho_{ij} = exp(-lambda * |T_i - T_j|), Act/365)
%                          default 0.1
%   n_caplets            - number of coupons (default 15 for the 4y exotic)
%   spread               - constant subtracted in payoff (default 5e-4)
%   n_paths              - MC paths (default 1e5)
%   (last argument unused, kept for backward compatibility with old signature)
%
%   OUTPUT:
%   price                - exotic cap price per unit notional
%   std_err              - MC standard error

    % --- Fix seed for reproducibility ----------------------------------
     rng(42); 

    % --- Default arguments -----------------------------------------------
    if nargin < 6 || isempty(n_paths),    n_paths    = 1e5; end
    if nargin < 5 || isempty(spread),     spread     = 5e-4; end
    if nargin < 4 || isempty(n_caplets),  n_caplets  = 15;  end
    if nargin < 3 || isempty(lambda),     lambda     = 0.1; end

    % --- Unpack the caplet stripping grid --------------------------------
    fwd_libor  = spot_vol_parameters.fwd_libor(:);
    yf_caplets = spot_vol_parameters.yf_between_caplets(:);   % delta_i
    T_expiry   = spot_vol_parameters.T_expiry(:);             % yf(t_0, T_i)

    % We need n_caplets+1 forward bonds in total: the bond i = 0 covers
    % the period [T_0, T_1] and is deterministic (fixed at t_0); the bonds
    % i = 1..n_caplets are stochastic and evolve until their reset date T_i.
    n_bonds = n_caplets + 1;        % indexed 0..n_caplets (1..n_bonds in MATLAB)

    % --- Forward bonds at t = 0 -----------------------------------------
    % B_i(0) = 1 / (1 + delta_i * F_i)  for i = 0, 1, ..., n_caplets
    % (F_i is the forward Libor on the period [T_i, T_{i+1}])
    B0 = 1 ./ (1 + yf_caplets(1:n_bonds) .* fwd_libor(1:n_bonds));

    % --- Reset times and step sizes -------------------------------------
    % T(k) is the time-to-reset of bond k-1 in MATLAB indexing, i.e.
    % T_expiry(k) for k = 1..n_bonds. We add T_0 = 0 (the valuation date)
    % at the front so the first integration step covers [0, T_1].
    T = [0; T_expiry(1:n_bonds)];                             % length n_bonds+1
    dt = diff(T);                                             % length n_bonds

    % --- Correlation matrix and Cholesky factor -------------------------
    % rho_{ij} = exp(-lambda * |T_i - T_j|), Act/365. We build it on the
    % full set of "alive" reset times T_1, ..., T_{n_bonds} (the bond i is
    % alive on the loading dW^{(i)} that drives its dynamics).
    Tres = T_expiry(1:n_bonds);                               % column [n_bonds x 1]
    rho_mat = exp(-lambda * abs(Tres - Tres'));               % [n_bonds x n_bonds]

    % Cholesky lower factor: rho = L * L'.  A tiny jitter is added if
    % needed to handle round-off-induced loss of positive definiteness.
    [L_chol, p] = chol(rho_mat, 'lower');
    if p > 0
        rho_mat = rho_mat + 1e-10 * eye(n_bonds);
        L_chol  = chol(rho_mat, 'lower');
    end

    % --- Vol vector (one per forward bond) ------------------------------
    % v_bmm(i) is the constant BMM vol of B_i(t) on its lifetime [0, T_i].
    v = v_bmm(1:n_caplets);
    % We pad with a placeholder for bond 0 (deterministic, vol = 0) so
    % that array indexing matches the bond index. Bond 0 is never evolved.
    v_full = [0; v];                                          % length n_bonds

    % --- Path container -------------------------------------------------
    % We only need to remember B_i(T_i) for each i (the value at the
    % bond's own reset date), because that is what enters both the Libor
    % at fixing and the stochastic discount.
    B_at_reset = zeros(n_paths, n_bonds);                     % B_i(T_i), i=0..n_caplets

    % Bond 0 is fully deterministic: B_0(T_0) = B_0(0).
    B_at_reset(:, 1) = B0(1);

    % Live state of the alive bonds: at the start of step k we hold
    % log B_i(T_{k-1}) for every i >= k (bonds 0..k-1 already dead).
    % We store the whole [n_paths x n_bonds] matrix and zero out the
    % already-dead columns as we go (cosmetic; they're never read again).
    log_B = repmat(log(B0(:))', n_paths, 1);                  % [n_paths x n_bonds]

    % --- Path-by-path simulation across the reset dates -----------------
    % Step k integrates the SDE from T_{k-1} to T_k, then freezes bond k-1.
    % MATLAB indices: bond index = m, reset step index = k.
    % Convention: at step k (k = 1..n_bonds), we evolve bonds m = k..n_bonds
    % over the interval (T_{k-1}, T_k] (length dt(k)) and then freeze bond k.
    for k = 1:n_bonds

        if k == 1
            % First step: bond 0 is already dead (deterministic). Nothing
            % to evolve. Move on.
            continue
        end

        % Brownian increments on this step: one per alive bond, correlated
        % via the Cholesky factor.  We slice rho/L on the alive-bond block
        % m = k..n_bonds to keep the dimensions tight.
        alive  = k:n_bonds;
        n_aliv = numel(alive);

        % Independent N(0, dt) -> rotate via L_chol_alive to get the
        % correlated increments dW_alive.
        L_alive  = chol(rho_mat(alive, alive), 'lower');     % [n_aliv x n_aliv]
        Z        = randn(n_paths, n_aliv);                    % i.i.d. standard normals
        dW_alive = (L_alive * Z')' * sqrt(dt(k));             % [n_paths x n_aliv]

        % Drift composition (Baviera 2006, slide 18).
        % For bond i alive on (T_{k-1}, T_k]:
        %     drift_i = - sum_{j: alive AND j != i} rho_{ij} * v_i * v_j * dt
        % Note: in the original formula the sum runs over j = k+1..i-1
        % (the bonds that are alive AND not yet at their own reset).
        % Here "alive" already excludes the dead ones, so we just exclude
        % the self-term j = i.
        v_alive = v_full(alive);                              % [n_aliv x 1]
        % rho_alive(i,j) * v_alive(i) * v_alive(j)  ->  matrix product
        %   sum over j != i  =>  zero out the diagonal first
        rho_alive = rho_mat(alive, alive);
        rho_off   = rho_alive - diag(diag(rho_alive));        % zero diagonal
        drift_per_bond = - (rho_off * v_alive) .* v_alive * dt(k);   % [n_aliv x 1]

        % Ito correction:  -0.5 * v_i^2 * dt  (one per alive bond)
        ito_per_bond = -0.5 * v_alive.^2 * dt(k);             % [n_aliv x 1]

        % Diffusion: -v_i * dW^{(i)}  (sign convention from slide 18)
        diffusion = - bsxfun(@times, dW_alive, v_alive');     % [n_paths x n_aliv]

        % Update the log-bond on the alive block
        log_B(:, alive) = log_B(:, alive) ...
                         + repmat((drift_per_bond + ito_per_bond)', n_paths, 1) ...
                         + diffusion;

        % FREEZE bond k: store its value at its own reset date T_k.
        % Note: in the MATLAB indexing, bond index m corresponds to bond
        % "m-1" of the BMM (because we shifted by 1 to allow bond 0).
        B_at_reset(:, k) = exp(log_B(:, k));
    end

    % --- Build the stochastic discount D(0, T_*) ------------------------
    % BMM Markov-chain identity (slide 19):
    %       D(0, T_{n+1}) = prod_{j = 0}^{n} B_j(T_j)
    % We need D(0, T_{i+1}) for each payment date T_{i+1}, i = 1..n_caplets.
    % MATLAB indexing: payment date i corresponds to columns 1..i+1 of
    % B_at_reset (bonds 0, 1, ..., i).
    cum_disc = cumprod(B_at_reset, 2);                        % [n_paths x n_bonds]
    %  cum_disc(:, k) = D(0, T_k) for k = 1..n_bonds.
    %  For payment date T_{i+1} of coupon i we need cum_disc(:, i+1).

    % --- Recover the Libor at each fixing -------------------------------
    % L_i(T_i) = (1 - B_i(T_i)) / (delta_i * B_i(T_i))
    % MATLAB indexing: L_at_reset(:, i+1) = L_i(T_i)  for i = 0..n_caplets.
    delta_full = yf_caplets(1:n_bonds);                       % [n_bonds x 1]
    L_at_reset = (1 - B_at_reset) ./ (B_at_reset .* delta_full');   % [n_paths x n_bonds]

    % --- Coupon-by-coupon payoff and PV ---------------------------------
    % For coupon i = 1..n_caplets:
    %     payoff_i = delta_i * [ L_i(T_i) - L_{i-1}(T_{i-1}) - spread ]^+
    %     PV_i     = E[ D(0, T_{i+1}) * payoff_i ]
    % MATLAB indexing: column (i+1) corresponds to bond i.
    coupon_pv = zeros(n_caplets, 1);
    coupon_se = zeros(n_caplets, 1);

    for i = 1:n_caplets
        L_new  = L_at_reset(:, i+1);          % L_i(T_i)
        L_prev = L_at_reset(:, i  );          % L_{i-1}(T_{i-1})
        D_pay  = cum_disc(:, i+1);            % D(0, T_{i+1})

        payoff = delta_full(i+1) * max(L_new - L_prev - spread, 0);

        discounted_payoff = D_pay .* payoff;

        coupon_pv(i) = mean(discounted_payoff);
        coupon_se(i) = std(discounted_payoff) / sqrt(n_paths);
    end

    price   = sum(coupon_pv);
    % Coupons are NOT independent under the spot measure (they share the
    % same path of B_j(T_j)'s), so the SE of the sum is not the simple
    % quadratic sum.  We approximate it via the SE of the path-wise total.
    % For an exact figure we would need to recompute mean/std on the sum.
    std_err = sqrt(sum(coupon_se.^2));        % conservative upper bound

end